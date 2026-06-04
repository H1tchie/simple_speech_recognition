#!/usr/bin/env python3
"""
extract_features.py
===================
Buduje zbior uczacy z nagran .wav ulozonych w folderach klas:

    data/train/on/*.wav
    data/train/off/*.wav
    data/train/other/*.wav

Dla kazdego nagrania liczy 26 cech (13x srednia MFCC + 13x odchylenie std)
DOKLADNIE ten sam staloprzecinkowy potok co RTL (tools/train/dsp_fixed.py),
uczy sie na liczbach, ktore realnie dostanie na FPGA.

Mapowanie klas -> neuron wyjsciowy (zgodne z final_layer.sv / led_logic):
    on    -> neuron 0  (kod 2'b01)
    off   -> neuron 1  (kod 2'b10)
    other -> neuron 2  (kod 2'b00)

Wynik: tools/train/dataset.npz  (X float [N,26], y [N], classes, files)

Uzycie:
    python tools/train/extract_features.py            # domyslnie data/train
    python tools/train/extract_features.py --data-dir sciezka
"""

import argparse
import sys
from pathlib import Path

import numpy as np

# Wspolny, STALOPRZECINKOWY potok cech - identyczny bit-w-bit z RTL.
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
import dsp_fixed as dsp  # noqa: E402

# Kolejnosc = indeks neuronu wyjsciowego sieci
CLASSES = ["on", "off", "other"]
CLASS_TO_LABEL = {c: i for i, c in enumerate(CLASSES)}


def features_from_wav(path: Path) -> np.ndarray:
    """26 cech int16 (Q5.10) z jednego .wav - DOKLADNIE to, co policzy FPGA."""
    return np.asarray(dsp.features_from_wav(str(path)), dtype=np.float64)


def build_dataset(data_dir: Path):
    X, y, files = [], [], []
    missing = []
    for cls in CLASSES:
        cdir = data_dir / cls
        if not cdir.is_dir():
            missing.append(cls)
            continue
        wavs = sorted(cdir.glob("*.wav"))
        print(f"  [{cls:5s}] {len(wavs)} plikow")
        for w in wavs:
            try:
                X.append(features_from_wav(w))
                y.append(CLASS_TO_LABEL[cls])
                files.append(str(w.relative_to(data_dir)))
            except Exception as e:
                print(f"    POMINIETO {w.name}: {e}")
    if missing:
        print(f"\n  UWAGA: brak folderow klas: {missing}")
        print(f"  Oczekiwany uklad: {data_dir}/<{'|'.join(CLASSES)}>/*.wav")
    if not X:
        raise SystemExit(
            "Brak danych. Wrzuc nagrania .wav (16 kHz, mono) do folderow:\n"
            f"  {data_dir}/on/   {data_dir}/off/   {data_dir}/other/")
    return np.asarray(X), np.asarray(y, dtype=np.int64), files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=str(ROOT / "data" / "train"))
    ap.add_argument("--out", default=str(Path(__file__).parent / "dataset.npz"))
    args = ap.parse_args()

    data_dir = Path(args.data_dir)
    print(f"Ekstrakcja cech z: {data_dir}")
    X, y, files = build_dataset(data_dir)
    np.savez(args.out, X=X, y=y, classes=np.array(CLASSES), files=np.array(files))

    print(f"\nZbior: {X.shape[0]} probek x {X.shape[1]} cech")
    for i, c in enumerate(CLASSES):
        print(f"  {c:5s}: {(y == i).sum()} probek")
    print(f"Zakres cech: [{X.min():.2f}, {X.max():.2f}]  "
          f"max|cecha|={np.abs(X).max():.2f}")
    print(f"Zapisano: {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
