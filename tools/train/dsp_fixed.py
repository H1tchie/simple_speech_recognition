#!/usr/bin/env python3
"""
dsp_fixed.py
============
Stałoprzecinkowy potok MFCC w arytmetyce CAŁKOWITEJ, odwzorowujący RTL
co do bitu. To jest WSPÓLNE źródło cech: trening sieci używa dokładnie
tych samych liczb, które liczy sprzęt (ten sam DFT, te same ROM-y,
to samo log2-LZC, ten sam DCT i agregacja).

Etapy (każdy == odpowiedni moduł RTL):
  wav -> Q1.15        (jak tools/wav_to_mem.py)
  preemphasis         (rtl/dsp/preemphasis.sv)
  framing 512/256     (rtl/dsp/framing.sv)
  window Hamming      (rtl/dsp/window.sv,    ROM window_hamming_512.mem)
  DFT 512 + |X|       (rtl/dsp/fft_wrapper.sv, ROM twiddle_{cos,sin}_512.mem)
  mel 26 filtrów      (rtl/dsp/mel_filter_bank.sv, ROM mel_bank_dense.mem)
  log2 (LZC) + DCT    (rtl/dsp/mfcc.sv,      ROM dct_coeffs.mem)
  mean + std (Q5.10)  (rtl/dsp/feature_aggregator.sv)
-> 26 cech int16 (13 mean + 13 std), dokładnie jak na wyjściu potoku.

Funkcja `features_from_samples(x_q15)` zwraca wektor 26 int.
`features_from_wav(path)` ładuje wav i woła powyższe.
"""

import math
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
DSP = ROOT / "rtl" / "dsp"

# --- parametry (zgodne z ssr_pkg.sv) ---
FS = 16_000
ALPHA_Q15 = 0x7C29           # 0.97
FRAME_LEN = 512
HOP_LEN = 256
N_FFT = 512
N_BINS = N_FFT // 2 + 1      # 257
N_MELS = 26
N_MFCC = 13
N_FEATURES = 26


# ---------------- pomocnicze ----------------
def _read_mem(path, signed, width=16):
    vals = []
    for line in open(path):
        line = line.split("//")[0].strip()
        if not line:
            continue
        v = int(line, 16)
        if signed and (v >> (width - 1)) & 1:
            v -= (1 << width)
        vals.append(v)
    return vals


def sat16(v):
    if v > 32767:
        return 32767
    if v < -32768:
        return -32768
    return v


def asr(v, s):
    """Arytmetyczne przesuniecie w prawo (floor), jak Verilog >>> dla signed."""
    return v >> s  # Python >> na int = floor (arytmetyczne)


def trunc_div(a, b):
    """Dzielenie calkowite z obcinaniem do zera (jak Verilog '/')."""
    q = abs(a) // abs(b)
    return -q if (a < 0) != (b < 0) else q


# ROM-y (ladowane raz)
_WIN = None
_COS = None
_SIN = None
_MEL = None
_DCT = None
# macierze do wektoryzacji (budowane raz)
_COSM = None   # (N_BINS, FRAME_LEN)  cos[(k*n)&511]
_SINM = None
_MELM = None   # (N_MELS, N_BINS)
_DCTM = None   # (N_MFCC, N_MELS)
_WINA = None   # (FRAME_LEN,)


def _load_roms():
    global _WIN, _COS, _SIN, _MEL, _DCT, _COSM, _SINM, _MELM, _DCTM, _WINA
    if _WIN is None:
        _WIN = _read_mem(DSP / "window_hamming_512.mem", signed=False)   # Q1.15 unsigned
        _COS = _read_mem(DSP / "twiddle_cos_512.mem", signed=True)
        _SIN = _read_mem(DSP / "twiddle_sin_512.mem", signed=True)
        _MEL = _read_mem(DSP / "mel_bank_dense.mem", signed=False)       # Q1.15 unsigned
        _DCT = _read_mem(DSP / "dct_coeffs.mem", signed=True)            # Q1.15 signed
        kn = (np.outer(np.arange(N_BINS), np.arange(FRAME_LEN)) & (N_FFT - 1))
        cos = np.array(_COS, dtype=np.int64)
        sin = np.array(_SIN, dtype=np.int64)
        _COSM = cos[kn]
        _SINM = sin[kn]
        _MELM = np.array(_MEL, dtype=np.int64).reshape(N_MELS, N_BINS)
        _DCTM = np.array(_DCT, dtype=np.int64).reshape(N_MFCC, N_MELS)
        _WINA = np.array(_WIN, dtype=np.int64)


# ---------------- etapy ----------------
def load_wav_q15(path):
    data, fs = sf.read(path, dtype="float32", always_2d=False)
    if data.ndim > 1:
        data = data.mean(axis=1)
    if fs != FS:
        raise ValueError(f"Wymagana fs={FS}, otrzymano {fs}")
    peak = float(np.max(np.abs(data))) if data.size else 1.0
    if peak > 0:
        data = (data / peak) * 0.99
    q = np.clip(np.round(data * 32768.0), -32768, 32767).astype(np.int64)
    return q.tolist()


def preemphasis(x):
    y = []
    x_prev = 0
    for n in range(len(x)):
        y_full = (x[n] << 15) - ALPHA_Q15 * x_prev
        y.append(sat16(asr(y_full, 15)))
        x_prev = x[n]
    return y


def frame_signal(x):
    n = len(x)
    if n < FRAME_LEN:
        nf = 1
    else:
        nf = 1 + (n - FRAME_LEN) // HOP_LEN
    frames = []
    for i in range(nf):
        s = i * HOP_LEN
        seg = x[s:s + FRAME_LEN]
        if len(seg) < FRAME_LEN:
            seg = seg + [0] * (FRAME_LEN - len(seg))
        frames.append(seg)
    return frames


def window(frame):
    f = np.asarray(frame, dtype=np.int64)
    out = (f * _WINA) >> 15                    # arith shift = >>>15
    return np.clip(out, -32768, 32767)


def dft_mag(frame):
    """Stałoprzecinkowy DFT 512 (matmul) + |X[k]| + normalizacja per-ramka."""
    f = np.asarray(frame, dtype=np.int64)
    re = (_COSM @ f) >> 15                      # (N_BINS,) arith shift
    im = (-(_SINM @ f)) >> 15
    re = re.tolist()
    im = im.tolist()                            # Python int -> brak przepelnienia przy kwadracie
    mags = [math.isqrt(re[k] * re[k] + im[k] * im[k]) for k in range(N_BINS)]
    mx = max(mags)
    if mx == 0:
        return [0] * N_BINS
    return [(m * 32767) // mx for m in mags]    # m>=0 -> // == trunc do zera


def mel(mag):
    m = np.asarray(mag, dtype=np.int64)
    prod = (m[None, :] * _MELM) >> 15           # per-skladnik >>15 (jak RTL)
    return prod.sum(axis=1).tolist()


def log2_approx(x):
    """Mirror mfcc.sv log2_approx: Q5.10, LZC."""
    if x == 0:
        return 0
    msb = x.bit_length() - 1
    if msb > 0:
        mantissa = ((x - (1 << msb)) << 10) >> msb
    else:
        mantissa = 0
    result = (msb << 10) | (mantissa & 0x3FF)
    return result if result < 32768 else result - 65536


def dct(log_buf):
    lb = np.asarray(log_buf, dtype=np.int64)
    acc = ((lb[None, :] * _DCTM) >> 15).sum(axis=1)   # per-skladnik >>>15 (signed)
    return np.clip(acc, -32768, 32767).tolist()


def aggregate(frames_mfcc):
    """Czysta agregacja: mean i std (Q5.10) -> 26 cech int16.
       (Wersja poprawiona: prawdziwa wariancja, deterministyczny isqrt.)"""
    nf = len(frames_mfcc)
    feats = []
    means = []
    stds = []
    for c in range(N_MFCC):
        s = 0
        sq = 0
        for f in range(nf):
            v = frames_mfcc[f][c]
            s += v
            sq += v * v
        if nf == 0:
            mean_full = 0
            var = 0
        else:
            mean_full = trunc_div(s, nf)
            ex2 = trunc_div(sq, nf)
            var = ex2 - mean_full * mean_full
            if var < 0:
                var = 0
        std = math.isqrt(var)
        means.append(sat16(mean_full))
        stds.append(sat16(std))
    feats = means + stds                          # 13 + 13
    return feats


def features_from_samples(x_q15):
    _load_roms()
    x = preemphasis(list(x_q15))
    frames = frame_signal(x)
    mfccs = []
    for fr in frames:
        w = window(fr)
        mag = dft_mag(w)
        me = mel(mag)
        logb = [log2_approx(v) for v in me]
        mfccs.append(dct(logb))
    return aggregate(mfccs)


def features_from_wav(path):
    return features_from_samples(load_wav_q15(str(path)))


if __name__ == "__main__":
    # self-test: krotki sygnal
    import sys
    if len(sys.argv) > 1:
        f = features_from_wav(sys.argv[1])
        print("26 cech:", f)
    else:
        x = (np.round(0.5 * np.sin(2*np.pi*440*np.arange(8000)/FS) * 32768)
             ).astype(int).tolist()
        print("26 cech (sinus 440Hz):", features_from_samples(x))
