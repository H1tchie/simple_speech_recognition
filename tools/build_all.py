#!/usr/bin/env python3
"""
build_all.py
============
Jednolinijkowa orkiestracja wszystkich generatorów. Dla każdej komendy
w `data/<cmd>.wav` produkuje:
  - data/<cmd>.mem           - próbki Q1.15
  - data/results/<cmd>/*.csv - golden reference
oraz raz:
  - rtl/dsp/window_hamming_512.mem
  - rtl/dsp/mel_bank_dense.mem
  - rtl/dsp/dct_coeffs.mem
  - data/samples.mem - skopiowane z pierwszej komendy (dla symulacji)

Usage:
    python tools/build_all.py
"""

import subprocess
import sys
from pathlib import Path

THIS = Path(__file__).resolve().parent
ROOT = THIS.parent

COMMANDS = ["on", "off", "up", "down"]
N_FFT = 512
N_MELS = 26
N_MFCC = 13


def run(cmd):
    print(f"  $ {' '.join(str(c) for c in cmd)}")
    r = subprocess.run(cmd)
    if r.returncode != 0:
        print(f"BLAD: {cmd}")
        sys.exit(r.returncode)


def main() -> int:
    py = sys.executable
    data_dir = ROOT / "data"
    rtl_dsp = ROOT / "rtl" / "dsp"

    print("[1/4] Hamming window ROM")
    run([py, str(THIS / "gen_window_rom.py"), str(N_FFT),
         str(rtl_dsp / "window_hamming_512.mem")])

    print("\n[2/4] Mel filterbank ROM")
    run([py, str(THIS / "gen_mel_filterbank.py"),
         "--n-mels", str(N_MELS), "--n-fft", str(N_FFT), "--fs", "16000",
         "--output", str(rtl_dsp / "mel_bank_dense.mem")])

    print("\n[3/4] DCT coefficients ROM")
    run([py, str(THIS / "gen_dct_coeffs.py"),
         "--n-mfcc", str(N_MFCC), "--n-mels", str(N_MELS),
         "--output", str(rtl_dsp / "dct_coeffs.mem")])

    print("\n[3b/4] Twiddle (DFT) ROM-y")
    run([py, str(THIS / "gen_twiddle_rom.py")])

    missing = [c for c in COMMANDS if not (data_dir / f"{c}.wav").exists()]
    if missing:
        print(f"\n[4/4] UWAGA: brak nagrań {missing} w {data_dir}/")
        print("Aby wygenerować pliki próbek nagraj komendy (16 kHz mono, ~1 s)")
        print("Generatory ROM są już gotowe.")
        return 0

    print("\n[4/4] Konwersja .wav -> .mem + golden reference")
    for i, cmd in enumerate(COMMANDS):
        wav = data_dir / f"{cmd}.wav"
        mem = data_dir / f"{cmd}.mem"
        run([py, str(THIS / "wav_to_mem.py"), str(wav), str(mem),
             "--max-samples", "16384"])
        run([py, str(THIS / "gen_reference.py"), str(wav),
             str(data_dir / "results" / cmd)])

    default_mem = data_dir / f"{COMMANDS[0]}.mem"
    samples = data_dir / "samples.mem"
    samples.write_text(default_mem.read_text())
    print(f"\n=> Domyślne probki do symulacji: {samples} (z '{COMMANDS[0]}')")

    print("\nGOTOWE")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
