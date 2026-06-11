#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
wav_to_simfile.py - konwersja nagrania WAV na plik probek dla SYMULACJI.

Wynik: jeden 12-bitowy odczyt "ADC" w hex na linie (format jak input_adcoff2.txt),
czyli dokladnie to, co czyta ssr_axi_lite_tb.sv ($fscanf "%h").

Nie wymaga librosy ani scipy - korzysta tylko z modulu 'wave' (stdlib).
Obsluguje WAV PCM 16-bit (najczestszy). Stereo jest mieszane do mono.

CZESTOTLIWOSC PROBKOWANIA:
  Opcja --sr resampluje do zadanej czestotliwosci (domyslnie BEZ resamplingu).
  Nagranie powinno miec taka sama czestotliwosc jak dane treningowe (dla mowy
  zwykle 8 kHz), wiec zwykle uzyjesz --sr 8000. Resampling jest w czystym
  Pythonie (interpolacja liniowa + prosty filtr przy zmniejszaniu) - nie
  trzeba instalowac ffmpeg ani scipy.

Uzycie:
  python3 wav_to_simfile.py on.wav generated_files/my_audio.txt --sr 8000
  python3 wav_to_simfile.py on.wav out.txt --sr 8000 --max 16384
"""
import sys
import wave
import struct
import argparse


def resample_linear(samples, sr_in, sr_out):
    """Prosty resampling: lekkie usrednianie przy zmniejszaniu + interpolacja liniowa."""
    if sr_out == sr_in or len(samples) < 2:
        return samples
    # Anty-aliasing przy downsamplingu: ruchoma srednia o szerokosci ~ sr_in/sr_out.
    if sr_out < sr_in:
        win = max(1, int(round(sr_in / sr_out)))
        if win > 1:
            sm = []
            acc = 0
            for i in range(len(samples)):
                acc += samples[i]
                if i >= win:
                    acc -= samples[i - win]
                sm.append(acc // min(i + 1, win))
            samples = sm
    n_out = int(len(samples) * sr_out / sr_in)
    step = (len(samples) - 1) / max(1, (n_out - 1))
    out = []
    for i in range(n_out):
        pos = i * step
        i0 = int(pos)
        i1 = min(i0 + 1, len(samples) - 1)
        frac = pos - i0
        out.append(int(round(samples[i0] * (1 - frac) + samples[i1] * frac)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav", help="wejsciowy plik WAV (PCM 16-bit)")
    ap.add_argument("out", help="wyjsciowy plik .txt z probkami hex")
    ap.add_argument("--max", type=int, default=0,
                    help="maksymalna liczba probek (0 = wszystkie)")
    ap.add_argument("--sr", type=int, default=0,
                    help="docelowa czestotliwosc [Hz] (0 = bez resamplingu; zwykle 8000)")
    ap.add_argument("--bits", type=int, default=12, help="rozdzielczosc ADC (domyslnie 12)")
    args = ap.parse_args()

    wf = wave.open(args.wav, "rb")
    n_ch = wf.getnchannels()
    sampwidth = wf.getsampwidth()
    sr = wf.getframerate()
    n_frames = wf.getnframes()
    raw = wf.readframes(n_frames)
    wf.close()

    if sampwidth != 2:
        sys.exit(f"BLAD: obslugiwany jest tylko WAV PCM 16-bit (ten ma {sampwidth*8}-bit).")

    # rozpakuj 16-bit signed
    total = len(raw) // 2
    samples = struct.unpack("<%dh" % total, raw[:total * 2])

    # stereo -> mono (srednia kanalow)
    if n_ch > 1:
        mono = []
        for i in range(0, len(samples) - n_ch + 1, n_ch):
            mono.append(sum(samples[i:i + n_ch]) // n_ch)
        samples = mono

    if not samples:
        sys.exit("BLAD: brak probek w pliku.")

    # resampling do zadanej czestotliwosci (opcjonalny)
    out_sr = sr
    if args.sr and args.sr != sr:
        samples = resample_linear(list(samples), sr, args.sr)
        out_sr = args.sr

    # normalizacja do [-1,1] po maksimum, potem skala do zakresu ADC (jak WAVtoADC.py)
    peak = max(1, max(abs(s) for s in samples))
    max_adc = (1 << (args.bits - 1)) - 1
    min_adc = -(1 << (args.bits - 1))

    out_vals = []
    for s in samples:
        v = int(round(s / peak * max_adc))
        if v > max_adc:
            v = max_adc
        if v < min_adc:
            v = min_adc
        out_vals.append(v)

    if args.max > 0:
        out_vals = out_vals[:args.max]

    with open(args.out, "w") as f:
        for v in out_vals:
            f.write("%04x\n" % (v & 0xFFFF))   # 12-bit U2 zapakowane w 4 hex

    print(f"WAV wejscie: {sr} Hz, {n_ch} kanal(y), {n_frames} ramek")
    print(f"Zapisano {len(out_vals)} probek do {args.out} (czestotliwosc wyjsciowa: {out_sr} Hz)")
    if out_sr != 8000:
        print(f"UWAGA: czestotliwosc wyjsciowa {out_sr} Hz != 8000 Hz. Rozwaz --sr 8000.")


if __name__ == "__main__":
    main()
