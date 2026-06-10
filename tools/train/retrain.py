#!/usr/bin/env python3
"""
retrain.py
==========
JEDNA KOMENDA do przeuczenia sieci na Twoich nagraniach.

Co robi:
  1. (jesli trzeba) liczy cechy z data/train/<on|off|other>/*.wav
  2. dzieli zbior na train/val (stratyfikowanie)
  3. trenuje siec (QAT, czysty NumPy) z doborem skali wejscia i wag
  4. wybiera najlepszy wariant wg trafnosci liczonej BITOWO-DOKLADNYM
     modelem sprzetu (forward_int) -> to realna trafnosc na FPGA
  5. zapisuje 4 pliki .mem do rtl/neural_network/ (siec gotowa do syntezy)
  6. drukuje raport: trafnosc, macierz pomylek, zakresy wartosci

Uzycie:
    python tools/train/retrain.py
    python tools/train/retrain.py --epochs 600 --seed 1
    python tools/train/retrain.py --emit-sv     # dodatkowo wypisz bloki assign
"""

import argparse
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import nn_int_model as nnm                 # noqa: E402
import parse_existing_weights as pw        # noqa: E402
import extract_features as ef              # noqa: E402

NN_DIR = ROOT / "rtl" / "neural_network"
CLASSES = ef.CLASSES

# Cechy z tools/train/dsp_fixed.py SA JUZ liczbami int16 w skali Q5.10 -
# DOKLADNIE tym, co wystawia feature_aggregator i co konsumuje siec w RTL.
# Dlatego skala wejscia = 1 (zadnego dodatkowego mnozenia).
FEATURE_SCALE = 1.0


def stratified_split(y, val_frac=0.25, seed=0):
    rng = np.random.default_rng(seed)
    tr, va = [], []
    for c in np.unique(y):
        idx = np.where(y == c)[0]
        rng.shuffle(idx)
        k = max(1, int(round(len(idx) * val_frac))) if len(idx) > 2 else 0
        va.extend(idx[:k])
        tr.extend(idx[k:])
    return np.array(tr, dtype=int), np.array(va, dtype=int)


def confusion(y_true, y_pred, n=len(CLASSES)):
    M = np.zeros((n, n), dtype=int)
    for t, p in zip(y_true, y_pred):
        M[t, p] += 1
    return M


def emit_sv_blocks(W1, b1, W2, b2):
    def row(vals):
        return "{" + ", ".join(
            (f"8'd{v}" if v >= 0 else f"-8'd{-v}") for v in vals) + "}"
    lines = ["// --- dense_layer_1 ---"]
    for i in range(W1.shape[0]):
        lines.append(f"assign weight_matrix[{i}] = {row(W1[i])};")
    lines.append(f"assign bias_vector = {row(b1)};")
    lines.append("// --- dense_layer_2 ---")
    for i in range(W2.shape[0]):
        lines.append(f"assign weight_matrix[{i}] = {row(W2[i])};")
    lines.append(f"assign bias_vector = {row(b2)};")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default=str(ROOT / "data" / "train"))
    ap.add_argument("--dataset", default=str(HERE / "dataset.npz"))
    ap.add_argument("--epochs", type=int, default=500)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--val-frac", type=float, default=0.25)
    ap.add_argument("--emit-sv", action="store_true")
    ap.add_argument("--force-extract", action="store_true")
    args = ap.parse_args()

    # 1) dane
    ds_path = Path(args.dataset)
    if args.force_extract or not ds_path.exists():
        print("== Ekstrakcja cech ==")
        X, y, files = ef.build_dataset(Path(args.data_dir))
        np.savez(ds_path, X=X, y=y, classes=np.array(CLASSES),
                 files=np.array(files))
    d = np.load(ds_path, allow_pickle=True)
    X, y = d["X"].astype(np.float64), d["y"].astype(int)
    print(f"\n== Zbior: {X.shape[0]} probek x {X.shape[1]} cech ==")
    for i, c in enumerate(CLASSES):
        print(f"  {c:5s}: {(y == i).sum()}")
    if X.shape[0] < 6:
        print("\nUWAGA: bardzo malo danych - trafnosc bedzie niepewna. "
              "Zalecane >=20 nagran na klase.")

    maxabs = float(np.abs(X).max()) + 1e-9

    # 2) split
    tr, va = stratified_split(y, args.val_frac, args.seed)
    if len(va) == 0:
        tr = np.arange(len(y)); va = tr
        print("(za malo danych na osobny zbior walidacyjny - walidacja = trening)")
    Xtr, ytr, Xva, yva = X[tr], y[tr], X[va], y[va]

    # 3) skala wejscia = 1: cechy SA juz int16 Q5.10 (bit-w-bit z RTL),
    #    wiec siec uczy sie wprost na liczbach z feature_aggregator.
    in_scale = FEATURE_SCALE
    max_int = int(np.clip(np.round(maxabs * in_scale), 0, 32767))
    print(f"\nCechy int16 Q5.10 (bit-w-bit z RTL)  ->  max|cecha|~{max_int}"
          + ("  (UWAGA: blisko/ponad 32767 - czesc cech sie nasyci, "
             "tak samo jak w RTL)" if max_int > 28000 else ""))

    # grid tylko po skali wag
    w_scales = [4.0, 8.0, 16.0, 32.0, 64.0]
    best = None
    print("\n== Trening (QAT) - dobor skali wag ==")
    for ws in w_scales:
        res = nnm.train_qat(Xtr, ytr, n_classes=len(CLASSES), in_scale=in_scale,
                            epochs=args.epochs, lr=0.02, seed=args.seed,
                            w_scale1=ws, w_scale2=ws, verbose=False)
        Xva_i = np.clip(np.round(Xva * in_scale), -32768, 32767).astype(int)
        acc_va = (nnm.forward_int(Xva_i, res["W1"], res["b1"],
                                  res["W2"], res["b2"]) == yva).mean()
        print(f"  w_scale={int(ws):3d}  val_acc={acc_va:.3f} "
              f"train_acc={res['train_acc']:.3f}")
        if best is None or acc_va > best[0]:
            best = (acc_va, res, in_scale)

    acc_va, res, in_scale = best
    W1, b1, W2, b2 = res["W1"], res["b1"], res["W2"], res["b2"]

    # 4) raport na CALYM zbiorze (bitowo-dokladny model = realny FPGA)
    X_int = np.clip(np.round(X * in_scale), -32768, 32767).astype(int)
    pred = nnm.forward_int(X_int, W1, b1, W2, b2)
    acc_all = (pred == y).mean()
    M = confusion(y, pred)

    print("\n========== RAPORT ==========")
    print(f"Najlepszy wariant: in_scale={in_scale:.4f} "
          f"w_scale={res['w_scale1']:.0f}")
    print(f"Trafnosc walidacyjna (bit-accurate): {acc_va*100:.1f}%")
    print(f"Trafnosc na calym zbiorze          : {acc_all*100:.1f}%")
    print("Macierz pomylek (wiersz=prawda, kol=predykcja):")
    print("            " + "  ".join(f"{c:>6s}" for c in CLASSES))
    for i, c in enumerate(CLASSES):
        print(f"  {c:8s}  " + "  ".join(f"{M[i, j]:6d}" for j in range(len(CLASSES))))
    print(f"Zakres wag:  W1 [{W1.min()},{W1.max()}]  W2 [{W2.min()},{W2.max()}]")
    print(f"Zakres cech int16: [{X_int.min()},{X_int.max()}]")

    # 5) zapis .mem
    pw.dump_layer_mem(W1, b1, NN_DIR / "dense1_weights.mem",
                      NN_DIR / "dense1_bias.mem", "dense1")
    pw.dump_layer_mem(W2, b2, NN_DIR / "dense2_weights.mem",
                      NN_DIR / "dense2_bias.mem", "dense2")
    print(f"\nZapisano wagi do {NN_DIR}/dense[12]_*.mem")

    # zapisz in_scale (informacyjnie - cechy sa juz int16 Q5.10, skala=1)
    with open(HERE / "in_scale.txt", "w") as f:
        f.write(f"{in_scale:.1f}\n")
    print(f"\nCechy = int16 Q5.10 liczone bit-w-bit jak RTL (dsp_fixed.py).\n"
          f"  -> ZERO zmian w RTL: wytrenowane wagi konsumuja WPROST wyjscie "
          f"feature_aggregator.")

    if args.emit_sv:
        sv = emit_sv_blocks(W1, b1, W2, b2)
        (HERE / "weights_assign_blocks.sv.txt").write_text(sv)
        print("Bloki assign zapisane w tools/train/weights_assign_blocks.sv.txt")

    if acc_va < 0.6:
        print("\nUWAGA: niska trafnosc. Wskazowki: wiecej nagran, rowniejsze "
              "klasy, czystsze probki (16 kHz mono, pojedyncze slowo).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
