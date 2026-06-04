#!/usr/bin/env python3
"""
gen_mel_filterbank.py
=====================
Generuje współczynniki Mel filter bank do ROM modułu mel_filter_bank.sv.

Wyjście:
  - mel_bank_dense.mem - dense [N_MELS x N_BINS] w Q1.15 (row-major)
  - mel_bank.csv       - wersja czytelna dla skryptów weryfikacyjnych

Filtry trójkątne na skali mel, znormalizowane do max=1 w paśmie.

Usage:
    python tools/gen_mel_filterbank.py --n-mels 26 --n-fft 512 --fs 16000 \
        --output rtl/dsp/mel_bank_dense.mem
"""

import argparse
from pathlib import Path

import numpy as np


def hz_to_mel(f): return 2595.0 * np.log10(1.0 + f / 700.0)
def mel_to_hz(m): return 700.0 * (10.0 ** (m / 2595.0) - 1.0)


def build_mel_bank(n_mels: int, n_fft: int, fs: int,
                   fmin: float, fmax: float) -> np.ndarray:
    mel_pts = np.linspace(hz_to_mel(fmin), hz_to_mel(fmax), n_mels + 2)
    hz_pts = mel_to_hz(mel_pts)
    bin_pts = np.floor((n_fft + 1) * hz_pts / fs).astype(int)
    fbank = np.zeros((n_mels, n_fft // 2 + 1), dtype=np.float64)
    for m in range(1, n_mels + 1):
        l, c, r = bin_pts[m - 1], bin_pts[m], bin_pts[m + 1]
        for k in range(l, c):
            if c != l:
                fbank[m - 1, k] = (k - l) / (c - l)
        for k in range(c, r):
            if r != c:
                fbank[m - 1, k] = (r - k) / (r - c)
    return fbank


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-mels", type=int, default=26)
    p.add_argument("--n-fft", type=int, default=512)
    p.add_argument("--fs", type=int, default=16000)
    p.add_argument("--fmin", type=float, default=0.0)
    p.add_argument("--fmax", type=float, default=None)
    p.add_argument("--output", required=True, help="plik .mem (dense)")
    p.add_argument("--csv", default=None, help="opcjonalny dump CSV")
    args = p.parse_args()

    fmax = args.fmax if args.fmax is not None else args.fs / 2.0
    fbank = build_mel_bank(args.n_mels, args.n_fft, args.fs, args.fmin, fmax)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="ascii") as f:
        f.write(f"// Mel filterbank dense [N_MELS x N_BINS] Q1.15, "
                f"{fbank.shape[0]}x{fbank.shape[1]}, fs={args.fs}\n")
        for m in range(fbank.shape[0]):
            for k in range(fbank.shape[1]):
                q = int(round(fbank[m, k] * (1 << 15)))
                q = max(0, min((1 << 15) - 1, q))
                f.write(f"{q & 0xFFFF:04x}\n")

    if args.csv:
        np.savetxt(args.csv, fbank, fmt="%.10f", delimiter=",")
        print(f"OK: CSV -> {args.csv}")

    print(f"OK: dense ROM -> {out} ({args.n_mels} x {fbank.shape[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
