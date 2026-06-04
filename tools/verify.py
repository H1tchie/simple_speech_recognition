#!/usr/bin/env python3
"""
verify.py
=========
Porównanie wyjścia symulacji RTL z golden reference (CSV).

Usage:
    python tools/verify.py sim/build/preemphasis_out.txt \\
        data/results/on/pre_emphasis.csv --fmt q15
"""

import argparse
import numpy as np


def parse_hex16(s: str) -> int:
    v = int(s.strip(), 16) & 0xFFFF
    return v - (1 << 16) if v & 0x8000 else v


def load_rtl(path: str, fmt: str) -> np.ndarray:
    rows = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("//") or s.startswith("#"):
                continue
            toks = [t.strip() for t in s.replace(";", ",").split(",") if t.strip()]
            row = []
            for t in toks:
                if fmt == "q15":
                    row.append(parse_hex16(t) / (1 << 15))
                elif fmt == "float":
                    row.append(float(t))
                elif fmt == "int":
                    row.append(int(t))
                else:
                    raise ValueError(fmt)
            rows.append(row if len(row) > 1 else row[0])
    return np.asarray(rows, dtype=np.float64)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("rtl")
    p.add_argument("ref")
    p.add_argument("--fmt", choices=["q15", "float", "int"], default="q15")
    p.add_argument("--tol", type=float, default=None)
    args = p.parse_args()

    rtl = load_rtl(args.rtl, args.fmt)
    ref = np.loadtxt(args.ref, delimiter=",", ndmin=1)
    n = min(rtl.size, ref.size)
    a, b = rtl.flatten()[:n], ref.flatten()[:n]
    err = np.abs(a - b)
    tol = args.tol if args.tol is not None else (2.0 / (1 << 15) if args.fmt == "q15" else 1e-3)
    fails = int(np.sum(err > tol))
    ok = fails == 0
    print(f"=== verify ===")
    print(f"  N={n}  tol={tol:.4e}")
    print(f"  max|err|={err.max():.4e}  mean|err|={err.mean():.4e}")
    print(f"  fails={fails}  STATUS={'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
