#!/usr/bin/env python3
"""
parse_existing_weights.py
Parsuje stare wagi z dense_layer_1.sv/dense_layer_2.sv (z ostatniego
dzialajacego buildu, jesli istnieja) LUB z existing_weights.npz, i zapisuje
pliki .mem (int8 hex) do rtl/neural_network/.

Uwaga: po refaktorze warstwy sa w dense_layer.sv (jeden moduł), wiec ten
skrypt sluzy glownie do jednorazowego wyciagniecia startowych wag z repo
ORAZ jako wzor formatu .mem. Po treningu pliki .mem nadpisuje retrain.py.

Uklad .mem (row-major): index = i*OUT_SIZE + j.
"""
import re, sys
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
NN = ROOT / "rtl" / "neural_network"
IN1, OUT1, IN2, OUT2 = 26, 32, 32, 3


def parse_tokens(text):
    rows = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*\{([^}]*)\}", text):
        idx = int(m.group(1)); vals = []
        for tok in m.group(2).split(","):
            mm = re.match(r"(-?)\s*\d+'d(\d+)", tok.strip())
            if mm:
                v = int(mm.group(2));  v = -v if mm.group(1) == "-" else v
                vals.append(v)
        rows[idx] = vals
    return rows


def parse_bias(text):
    m = re.search(r"bias_vector\s*=\s*\{([^}]*)\}", text)
    if not m: return None
    vals = []
    for tok in m.group(1).split(","):
        mm = re.match(r"(-?)\s*\d+'d(\d+)", tok.strip())
        if mm:
            v = int(mm.group(2));  v = -v if mm.group(1) == "-" else v
            vals.append(v)
    return vals


def load_layer(path, in_size, out_size):
    text = path.read_text(); rows = parse_tokens(text)
    W = np.zeros((in_size, out_size), dtype=np.int32)
    for i in range(in_size):
        W[i, :] = rows[i]
    b = np.asarray(parse_bias(text), dtype=np.int32)
    return W, b


def to_hex8(v):
    v = int(v)
    if not (-128 <= v <= 127): raise ValueError(f"{v} poza int8")
    return f"{(v & 0xFF):02x}"


def write_mem(path, flat, header):
    with open(path, "w") as f:
        f.write(f"// {header}\n")
        for v in flat: f.write(to_hex8(v) + "\n")


def dump_layer_mem(W, b, wpath, bpath, name):
    in_size, out_size = W.shape
    flat = [W[i, j] for i in range(in_size) for j in range(out_size)]
    write_mem(wpath, flat, f"{name} weights row-major i*{out_size}+j int8")
    write_mem(bpath, list(b), f"{name} bias int8")


def main():
    sv1, sv2 = NN / "dense_layer_1.sv", NN / "dense_layer_2.sv"
    npz = Path(__file__).parent / "existing_weights.npz"
    if sv1.exists() and sv2.exists():
        W1, b1 = load_layer(sv1, IN1, OUT1)
        W2, b2 = load_layer(sv2, IN2, OUT2)
        np.savez(npz, W1=W1, b1=b1, W2=W2, b2=b2)
        src = "dense_layer_1/2.sv"
    elif npz.exists():
        d = np.load(npz); W1, b1, W2, b2 = d["W1"], d["b1"], d["W2"], d["b2"]
        src = "existing_weights.npz"
    else:
        print("Brak zrodla wag (ani .sv ani .npz). To OK jesli zaraz "
              "trenujesz od zera przez retrain.py.")
        return 0
    print(f"Zrodlo: {src}")
    print(f"  W1 {W1.shape} [{W1.min()},{W1.max()}]  W2 {W2.shape} [{W2.min()},{W2.max()}]")
    dump_layer_mem(W1, b1, NN/"dense1_weights.mem", NN/"dense1_bias.mem", "dense1")
    dump_layer_mem(W2, b2, NN/"dense2_weights.mem", NN/"dense2_bias.mem", "dense2")
    print(f"Zapisano 4 pliki .mem do {NN}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
