#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_audio_header.py - generuje plik naglowkowy audio_samples.h dla MicroBlaze.

Dwa zrodla wejscia:
  A) plik WAV  (wymaga: numpy, librosa)        -> --wav nagranie.wav
  B) gotowy plik z probkami ADC w HEX (jak     -> --txt input_adcoff2.txt
     sim/python/generated_files/input_adcoff2.txt; jeden 4-cyfrowy hex/linia)

Probki sa 12-bitowe, w kodzie U2 (tak jak ADC w oryginalnym projekcie:
patrz WAVtoADC.py). Naglowek zawiera tablice 'audio_samples' (uint16_t,
maska 0x0FFF) oraz stala AUDIO_LEN.

Przyklady:
  python gen_audio_header.py --txt ../sim_input/input_adcoff2.txt \
         --start 8000 --len 8192 --out audio_samples.h
  python gen_audio_header.py --wav komenda_on.wav --len 8192 --out audio_samples.h
"""
import argparse
import numpy as np


def from_wav(path, adc_bits=12):
    import librosa
    y, sr = librosa.load(path, sr=None)
    max_adc = (2 ** (adc_bits - 1)) - 1
    min_adc = -(2 ** (adc_bits - 1))
    y = y / np.max(np.abs(y))
    adc = np.int16(y * max_adc)
    adc = np.clip(adc, min_adc, max_adc)
    return adc.astype(np.int16)


def from_txt(path):
    vals = []
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            v = int(line, 16) & 0xFFFF          # 16-bit U2
            if v & 0x8000:                      # rozszerzenie znaku
                v -= 0x10000
            vals.append(v)
    return np.array(vals, dtype=np.int16)


def main():
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--wav", help="plik WAV")
    src.add_argument("--txt", help="plik HEX (probki ADC, 4 cyfry/linia)")
    ap.add_argument("--start", type=int, default=0, help="indeks pierwszej probki")
    ap.add_argument("--len", type=int, default=0,
                    help="liczba probek (0 = wszystkie od --start do konca)")
    ap.add_argument("--out", default="audio_samples.h")
    args = ap.parse_args()

    data = from_wav(args.wav) if args.wav else from_txt(args.txt)

    start = max(0, args.start)
    end = len(data) if args.len <= 0 else min(len(data), start + args.len)
    data = data[start:end]

    n = len(data)
    if n == 0:
        raise SystemExit("Brak probek do zapisania - sprawdz --start/--len.")

    with open(args.out, "w") as f:
        f.write("/* Wygenerowane automatycznie przez gen_audio_header.py.\n")
        f.write(" * Probki 12-bit (U2) zapakowane do uint16_t (maska 0x0FFF).\n */\n")
        f.write("#ifndef AUDIO_SAMPLES_H\n#define AUDIO_SAMPLES_H\n#include \"xil_types.h\"\n\n")
        f.write(f"#define AUDIO_LEN {n}u\n\n")
        f.write("static const u16 audio_samples[AUDIO_LEN] = {\n")
        for i, s in enumerate(data):
            v = int(s) & 0x0FFF
            f.write(f"0x{v:03x}, ")
            if (i + 1) % 12 == 0:
                f.write("\n")
        f.write("\n};\n\n#endif /* AUDIO_SAMPLES_H */\n")

    print(f"Zapisano {n} probek do {args.out}")


if __name__ == "__main__":
    main()
