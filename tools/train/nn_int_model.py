#!/usr/bin/env python3
"""
nn_int_model.py
Wspolny model sieci:
  forward_int(...) - bitowo-dokladna replika sprzetowej sciezki
     (dense_layer.sv + final_layer.sv). Zrodlo prawdy = liczy to, co FPGA.
       h[j] = ReLU( sat24( sum_i x[i]*W1[i][j] + b1[j] ) )
       y[k] =       sat32( sum_j h[j]*W2[j][k] + b2[k] )
       argmax(y) -> kod 2-bit (0->01, 1->10, 2->00)
  train_qat(...) - trening swiadomy kwantyzacji (QAT) w czystym NumPy (STE).
Konwencje: wejscie x int16, wagi/biasy int8, brak przeskalowania miedzy
warstwami (zgodnie z RTL).
"""
import numpy as np
WB_MIN, WB_MAX = -128, 127


def _sat(v, width):
    hi = (1 << (width - 1)) - 1; lo = -(1 << (width - 1))
    return np.clip(v, lo, hi)


def forward_int(X, W1, b1, W2, b2, return_logits=False):
    X = np.asarray(X, dtype=np.int64); W1 = np.asarray(W1, dtype=np.int64)
    W2 = np.asarray(W2, dtype=np.int64); b1 = np.asarray(b1, dtype=np.int64)
    b2 = np.asarray(b2, dtype=np.int64)
    acc1 = _sat(X @ W1 + b1[None, :], 24)
    h = np.maximum(acc1, 0)
    acc2 = _sat(h @ W2 + b2[None, :], 32)
    cls = np.argmax(acc2, axis=1)
    return (cls, acc2) if return_logits else cls


def argmax_to_code(cls):
    table = {0: 0b01, 1: 0b10, 2: 0b00}
    return np.array([table[int(c)] for c in np.atleast_1d(cls)])


def _q_ste(w, scale):
    return np.clip(np.round(w * scale), WB_MIN, WB_MAX)


def train_qat(X, y, n_classes=3, in_scale=1.0, epochs=400, lr=0.02,
              seed=0, w_scale1=64.0, w_scale2=64.0, verbose=True):
    rng = np.random.default_rng(seed)
    N, n_in = X.shape; n_hid = 32
    X_int = np.clip(np.round(X * in_scale), -32768, 32767).astype(np.float64)
    W1f = rng.normal(0, np.sqrt(2.0/n_in), size=(n_in, n_hid)) / w_scale1
    b1f = np.zeros(n_hid)
    W2f = rng.normal(0, np.sqrt(2.0/n_hid), size=(n_hid, n_classes)) / w_scale2
    b2f = np.zeros(n_classes)
    Y = np.eye(n_classes)[y]

    def softmax(z):
        z = z - z.max(axis=1, keepdims=True); e = np.exp(z)
        return e / e.sum(axis=1, keepdims=True)

    best = None; best_acc = -1.0
    for ep in range(epochs):
        W1q = _q_ste(W1f, w_scale1); W2q = _q_ste(W2f, w_scale2)
        b1q = _q_ste(b1f, w_scale1); b2q = _q_ste(b2f, w_scale2)
        a1 = X_int @ W1q + b1q[None, :]
        h = np.maximum(a1, 0.0)
        a2 = h @ W2q + b2q[None, :]
        a2n = a2 / (np.abs(a2).max() + 1e-9) * 8.0
        p = softmax(a2n)
        loss = -np.mean(np.sum(Y * np.log(p + 1e-12), axis=1))
        dz2 = (p - Y) / N
        dW2 = h.T @ dz2; db2 = dz2.sum(axis=0)
        dh = dz2 @ W2q.T; dh[a1 <= 0] = 0.0
        dW1 = X_int.T @ dh; db1 = dh.sum(axis=0)
        W1f -= lr * dW1 / (np.abs(dW1).max() + 1e-9)
        b1f -= lr * db1 / (np.abs(db1).max() + 1e-9)
        W2f -= lr * dW2 / (np.abs(dW2).max() + 1e-9)
        b2f -= lr * db2 / (np.abs(db2).max() + 1e-9)

        W1i = _q_ste(W1f, w_scale1).astype(int); b1i = _q_ste(b1f, w_scale1).astype(int)
        W2i = _q_ste(W2f, w_scale2).astype(int); b2i = _q_ste(b2f, w_scale2).astype(int)
        Xi = np.clip(np.round(X * in_scale), -32768, 32767).astype(int)
        acc = (forward_int(Xi, W1i, b1i, W2i, b2i) == y).mean()
        if acc > best_acc:
            best_acc = acc
            best = dict(W1=W1i.astype(np.int32), b1=b1i.astype(np.int32),
                        W2=W2i.astype(np.int32), b2=b2i.astype(np.int32))
        if verbose and (ep % 50 == 0 or ep == epochs-1):
            print(f"  epoch {ep:4d}  loss={loss:.4f}  acc_int={acc:.3f}  best={best_acc:.3f}")

    best.update(in_scale=in_scale, w_scale1=w_scale1,
                w_scale2=w_scale2, train_acc=best_acc)
    return best


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    X = rng.integers(-2000, 2000, size=(5, 26))
    W1 = rng.integers(-40, 40, (26, 32)); b1 = rng.integers(-10, 10, 32)
    W2 = rng.integers(-40, 40, (32, 3));  b2 = rng.integers(-10, 10, 3)
    cls, lg = forward_int(X, W1, b1, W2, b2, return_logits=True)
    print("forward_int OK:", cls, "kody:", argmax_to_code(cls))
