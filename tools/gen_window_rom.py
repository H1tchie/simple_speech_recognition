#!/usr/bin/env python3
"""
gen_window_rom.py
=================
Generuje współczynniki okna Hamminga w formacie Q1.15 (unsigned, bo
Hamming jest dodatni w zakresie 0.08 .. 1.0) do ROM modułu window.sv.

    w[n] = 0.54 - 0.46 * cos(2*pi*n / (N-1))

Usage:
    python tools/gen_window_rom.py 512 rtl/dsp/window_hamming_512.mem
"""

import argparse
from pathlib import Path

import numpy as np


def gen_hamming_q15(n: int) -> np.ndarray:
    w = 0.54 - 0.46 * np.cos(2.0 * np.pi * np.arange(n) / (n - 1))
    q15 = np.clip(np.round(w * (1 << 15)), 0, (1 << 15) - 1).astype(np.int32)
    return q15


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("n", type=int, help="rozmiar okna (np. 512)")
    p.add_argument("output", help="plik wyjściowy .mem")
    args = p.parse_args()

    coeffs = gen_hamming_q15(args.n)
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="ascii") as f:
        f.write(f"// Hamming window, N={args.n}, Q1.15 unsigned\n")
        for v in coeffs:
            f.write(f"{int(v) & 0xFFFF:04x}\n")
    print(f"OK: {args.n} współczynników do {args.output} "
          f"(min={coeffs.min()}, max={coeffs.max()})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
