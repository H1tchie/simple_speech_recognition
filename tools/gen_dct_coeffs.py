#!/usr/bin/env python3
"""
gen_dct_coeffs.py
=================
Generuje macierz DCT-II [N_MFCC x N_MELS] (ortonormalna, zgodna z
librosa.dct(... norm='ortho')) w formacie Q1.15 signed do ROM modułu
mfcc.sv.

Usage:
    python tools/gen_dct_coeffs.py --n-mfcc 13 --n-mels 26 \
        --output rtl/dsp/dct_coeffs.mem
"""

import argparse
from pathlib import Path

import numpy as np


def dct_matrix(n_mfcc: int, n_mels: int) -> np.ndarray:
    n = np.arange(n_mels)
    m = np.arange(n_mfcc)[:, None]
    M = np.cos(np.pi / n_mels * (n + 0.5) * m)
    M *= np.sqrt(2.0 / n_mels)
    M[0, :] *= 1.0 / np.sqrt(2.0)
    return M


def to_q15_hex(value: float) -> str:
    q = int(round(value * (1 << 15)))
    q = max(-(1 << 15), min((1 << 15) - 1, q))
    if q < 0:
        q = (1 << 16) + q
    return f"{q & 0xFFFF:04x}"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--n-mfcc", type=int, default=13)
    p.add_argument("--n-mels", type=int, default=26)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    M = dct_matrix(args.n_mfcc, args.n_mels)
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", encoding="ascii") as f:
        f.write(f"// DCT-II Q1.15, [N_MFCC={args.n_mfcc}, N_MELS={args.n_mels}]\n")
        f.write("// Row-major: M[m=0..N_MFCC-1][n=0..N_MELS-1]\n")
        for m in range(args.n_mfcc):
            for n in range(args.n_mels):
                f.write(to_q15_hex(M[m, n]) + "\n")
    print(f"OK: DCT -> {out}, zakres [{M.min():.4f}, {M.max():.4f}]")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
