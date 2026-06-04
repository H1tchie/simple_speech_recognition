#!/usr/bin/env python3
"""
gen_reference.py
================
Liczy w Pythonie wszystkie etapy potoku MFCC dla danego pliku .wav i
zapisuje wyniki pośrednie do CSV (golden reference). Używane przy
weryfikacji RTL (verify.py).

Konfiguracja MUSI byc spójna z parametrami w RTL:
    fs        = 16000 Hz
    PRE_EMPH  = 0.97
    FRAME_LEN = 512
    HOP_LEN   = 256
    N_FFT     = 512
    N_MELS    = 26
    N_MFCC    = 13

Wyjście:
  pre_emphasis.csv  - sygnal po filtrze
  frames.csv        - ramki [n_frames x FRAME_LEN]
  windowed.csv      - ramki po Hamming
  fft_magnitude.csv - |X[k]| [n_frames x N_BINS]
  mel_energy.csv    - energia w pasmach [n_frames x N_MELS]
  log_mel.csv       - log(mel_energy)
  mfcc.csv          - wsp. cepstralne [n_frames x N_MFCC]
  features.csv      - 26 cech (mean+std MFCC) dla sieci neuronowej

Usage:
    python tools/gen_reference.py data/on.wav data/results/on/
"""

import argparse
from pathlib import Path

import numpy as np
import soundfile as sf

FS = 16_000
PRE_EMPH = 0.97
FRAME_LEN = 512
HOP_LEN = 256
N_FFT = 512
N_MELS = 26
N_MFCC = 13


def hz_to_mel(f): return 2595.0 * np.log10(1.0 + f / 700.0)
def mel_to_hz(m): return 700.0 * (10.0 ** (m / 2595.0) - 1.0)


def mel_filterbank(n_mels, n_fft, fs):
    mel_pts = np.linspace(hz_to_mel(0), hz_to_mel(fs / 2), n_mels + 2)
    hz_pts = mel_to_hz(mel_pts)
    bin_pts = np.floor((n_fft + 1) * hz_pts / fs).astype(int)
    fb = np.zeros((n_mels, n_fft // 2 + 1), dtype=np.float64)
    for m in range(1, n_mels + 1):
        l, c, r = bin_pts[m - 1], bin_pts[m], bin_pts[m + 1]
        for k in range(l, c):
            if c != l: fb[m - 1, k] = (k - l) / (c - l)
        for k in range(c, r):
            if r != c: fb[m - 1, k] = (r - k) / (r - c)
    return fb


def dct_matrix(n_mfcc, n_mels):
    n = np.arange(n_mels)
    m = np.arange(n_mfcc)[:, None]
    M = np.cos(np.pi / n_mels * (n + 0.5) * m) * np.sqrt(2.0 / n_mels)
    M[0, :] *= 1.0 / np.sqrt(2.0)
    return M


def load_wav(path):
    data, fs = sf.read(path, dtype="float32", always_2d=False)
    if data.ndim > 1: data = data.mean(axis=1)
    if fs != FS:
        raise ValueError(f"Wymagana fs={FS}, otrzymano {fs}")
    peak = float(np.max(np.abs(data))) if data.size else 1.0
    if peak > 0: data = (data / peak) * 0.99
    return data.astype(np.float64)


def pre_emphasis(x, alpha=PRE_EMPH):
    y = np.empty_like(x)
    y[0] = x[0]
    y[1:] = x[1:] - alpha * x[:-1]
    return y


def frame_signal(x, frame_len, hop):
    n = max(1, 1 + (len(x) - frame_len) // hop)
    out = np.zeros((n, frame_len), dtype=np.float64)
    for i in range(n):
        s = i * hop
        e = s + frame_len
        seg = x[s:e]
        out[i, :len(seg)] = seg
    return out


def hamming(n):
    return 0.54 - 0.46 * np.cos(2.0 * np.pi * np.arange(n) / (n - 1))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("input")
    p.add_argument("output_dir")
    args = p.parse_args()

    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    x = load_wav(args.input)
    print(f"Wczytano {args.input}: {len(x)} próbek")

    x_pe = pre_emphasis(x)
    frames = frame_signal(x_pe, FRAME_LEN, HOP_LEN)
    win = hamming(FRAME_LEN)
    windowed = frames * win[None, :]
    mag = np.abs(np.fft.rfft(windowed, n=N_FFT, axis=1))
    fbank = mel_filterbank(N_MELS, N_FFT, FS)
    mel_energy = mag @ fbank.T
    log_mel = np.log(np.maximum(mel_energy, 1e-10))
    M = dct_matrix(N_MFCC, N_MELS)
    mfcc = log_mel @ M.T

    # Features for NN: mean and std of each MFCC coefficient over frames
    feats_mean = mfcc.mean(axis=0)   # [N_MFCC]
    feats_std = mfcc.std(axis=0)     # [N_MFCC]
    features = np.concatenate([feats_mean, feats_std])  # [26]

    np.savetxt(out / "pre_emphasis.csv", x_pe, fmt="%.8f")
    np.savetxt(out / "frames.csv", frames, fmt="%.8f", delimiter=",")
    np.savetxt(out / "windowed.csv", windowed, fmt="%.8f", delimiter=",")
    np.savetxt(out / "fft_magnitude.csv", mag, fmt="%.8f", delimiter=",")
    np.savetxt(out / "mel_energy.csv", mel_energy, fmt="%.8f", delimiter=",")
    np.savetxt(out / "log_mel.csv", log_mel, fmt="%.8f", delimiter=",")
    np.savetxt(out / "mfcc.csv", mfcc, fmt="%.8f", delimiter=",")
    np.savetxt(out / "features.csv", features, fmt="%.8f")

    print(f"  pre_emphasis  : {x_pe.shape}")
    print(f"  frames        : {frames.shape}")
    print(f"  mfcc          : {mfcc.shape}")
    print(f"  features (NN) : {features.shape}")
    print(f"Wynik -> {out}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
