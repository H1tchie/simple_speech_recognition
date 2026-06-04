#!/usr/bin/env python3
"""
gen_twiddle_rom.py
Generuje ROM-y wspolczynnikow obrotu (twiddle) dla 512-pkt DFT:
  rtl/dsp/twiddle_cos_512.mem  : cos(2*pi*i/512), Q1.15 signed, i=0..511
  rtl/dsp/twiddle_sin_512.mem  : sin(2*pi*i/512), Q1.15 signed, i=0..511
Te same wartosci czyta stałoprzecinkowy DFT w RTL (fft_wrapper.sv) i model
Pythona (tools/train/dsp_fixed.py), wiec FFT jest identyczny bit-w-bit.
"""
from pathlib import Path
import numpy as np

N = 512
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "rtl" / "dsp"


def q15(x):
    v = int(np.round(x * 32768.0))
    v = max(-32768, min(32767, v))   # cos(0)=1 -> 32768 -> clip do 32767
    return v & 0xFFFF


def write(path, vals, header):
    with open(path, "w") as f:
        f.write(f"// {header}\n")
        for v in vals:
            f.write(f"{v:04x}\n")


def main():
    i = np.arange(N)
    cos = [q15(np.cos(2*np.pi*k/N)) for k in i]
    sin = [q15(np.sin(2*np.pi*k/N)) for k in i]
    write(OUT / "twiddle_cos_512.mem", cos, "cos(2pi i/512) Q1.15 signed, i=0..511")
    write(OUT / "twiddle_sin_512.mem", sin, "sin(2pi i/512) Q1.15 signed, i=0..511")
    print(f"Zapisano twiddle_cos_512.mem i twiddle_sin_512.mem ({N} wpisow)")


if __name__ == "__main__":
    main()
