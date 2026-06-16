# -*- coding: utf-8 -*-
"""
Created on Mon Jun 15 19:05:50 2026

@author: ferdz
"""

#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LEKKI tor cech MFCC (wersja FLOAT) zaprojektowany pod implementacje RTL.
Parametry dobrane tak, zeby bylo tanio w FPGA:
  FRAME=256, HOP=128, FFT=256, 26 filtrow mel (HTK), log2, DCT-II, 13 coeff
Wyjscie: 26 cech (13 mean + 13 std) -> ta sama architektura sieci 26->32->3.

Ten skrypt slufy do SPRAWDZENIA czy lekkie cechy klasyfikuja dobrze.
Jak wynik OK -> robimy wersje fixed-point i RTL.
"""
import numpy as np
import soundfile as sf
import os
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import confusion_matrix
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.utils import to_categorical
from matplotlib import pyplot as plt
import seaborn as sns

# ============================================================
# PARAMETRY TORU (musza sie potem zgadzac z RTL)
# ============================================================
SR        = 16000
FRAME_LEN = 512
HOP_LEN   = 256
N_FFT     = 512
N_BINS    = N_FFT // 2 + 1      # 129
N_MELS    = 26
N_MFCC    = 13
FMIN      = 0.0
FMAX      = SR / 2.0            # 8000

# ============================================================
# 1. HAMMING WINDOW (taki bedzie ROM w RTL)
# ============================================================
def hamming_window(N):
    n = np.arange(N)
    return 0.54 - 0.46 * np.cos(2 * np.pi * n / (N - 1))

WINDOW = hamming_window(FRAME_LEN)

# ============================================================
# 2. MEL FILTERBANK - HTK style (prostsza formula niz Slaney)
# ============================================================
def hz_to_mel_htk(f):
    return 2595.0 * np.log10(1.0 + f / 700.0)

def mel_to_hz_htk(m):
    return 700.0 * (10.0**(m / 2595.0) - 1.0)

def build_mel_filterbank(sr, n_fft, n_mels, fmin, fmax):
    n_bins = n_fft // 2 + 1
    mel_min = hz_to_mel_htk(fmin)
    mel_max = hz_to_mel_htk(fmax)
    mel_points = np.linspace(mel_min, mel_max, n_mels + 2)
    hz_points = mel_to_hz_htk(mel_points)
    bin_points = np.floor((n_fft + 1) * hz_points / sr).astype(int)
    bin_points = np.clip(bin_points, 0, n_bins - 1)

    fb = np.zeros((n_mels, n_bins))
    for m in range(1, n_mels + 1):
        left, center, right = bin_points[m-1], bin_points[m], bin_points[m+1]
        for k in range(left, center):
            if center != left:
                fb[m-1, k] = (k - left) / (center - left)
        for k in range(center, right):
            if right != center:
                fb[m-1, k] = (right - k) / (right - center)
    return fb

MEL_FB = build_mel_filterbank(SR, N_FFT, N_MELS, FMIN, FMAX)

# ============================================================
# 3. DCT-II ORTONORMALNA (taki bedzie ROM w RTL)
# ============================================================
def build_dct_matrix(n_mfcc, n_mels):
    D = np.zeros((n_mfcc, n_mels))
    for k in range(n_mfcc):
        for n in range(n_mels):
            D[k, n] = np.cos(np.pi * k * (2*n + 1) / (2*n_mels))
    # normalizacja ortonormalna
    D[0, :]  *= np.sqrt(1.0 / n_mels)
    D[1:, :] *= np.sqrt(2.0 / n_mels)
    return D

DCT_M = build_dct_matrix(N_MFCC, N_MELS)

# ============================================================
# 4. EKSTRAKCJA CECH - lekki tor (FLOAT)
# ============================================================
def extract_features_light(file_path):
    y, sr = sf.read(file_path)
    if y.ndim > 1:
        y = y.mean(axis=1)          # mono
    y = y.astype(np.float64)

    # framing bez center/pad
    n_frames = 1 + (len(y) - FRAME_LEN) // HOP_LEN
    if n_frames < 1:
        return None

    mfcc_frames = []
    for t in range(n_frames):
        start = t * HOP_LEN
        frame = y[start:start + FRAME_LEN] * WINDOW

        # FFT i power
        spec = np.fft.rfft(frame, n=N_FFT)     # N_BINS punktow
        power = np.abs(spec)**2

        # mel
        mel_energy = MEL_FB @ power            # 26

        # log2 (z floorem zeby uniknac log(0))
        mel_energy = np.maximum(mel_energy, 1e-10)
        log_mel = np.log2(mel_energy)

        # DCT -> 13 coeff
        mfcc = DCT_M @ log_mel                 # 13
        mfcc_frames.append(mfcc)

    mfcc_frames = np.array(mfcc_frames)        # (n_frames, 13)

    # agregacja mean + std
    mean = mfcc_frames.mean(axis=0)
    std  = mfcc_frames.std(axis=0)
    return np.concatenate([mean, std])         # 26

# ============================================================
# 5. WCZYTAJ DANE
# ============================================================
def load_dir(directory, label):
    X, y = [], []
    for f in os.listdir(directory):
        if f.endswith('.wav'):
            feat = extract_features_light(os.path.join(directory, f))
            if feat is not None:
                X.append(feat)
                y.append(label)
    print(f"Loaded {len(X)} from {directory}")
    return X, y

on_dir  = 'C:/Users/ferdz/Desktop/audio_samples/onn'
off_dir = 'C:/Users/ferdz/Desktop/audio_samples/offf'
oth_dir = 'C:/Users/ferdz/Desktop/audio_samples/othh'

X_on,  y_on  = load_dir(on_dir,  0)
X_off, y_off = load_dir(off_dir, 1)
X_oth, y_oth = load_dir(oth_dir, 2)

X = np.array(X_on + X_off + X_oth)
y = np.array(y_on + y_off + y_oth)

print(f"\nX shape: {X.shape}")
print(f"Feature range: min={X.min():.2f}, max={X.max():.2f}")

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

y_train_cat = to_categorical(y_train, 3)
y_test_cat  = to_categorical(y_test, 3)

# ============================================================
# 6. CLASS WEIGHTS + MODEL (ta sama architektura 26->32->3)
# ============================================================
cw = compute_class_weight('balanced', classes=np.array([0,1,2]), y=y_train)
cw_dict = {0: cw[0], 1: cw[1], 2: cw[2]}

model = Sequential([
    Dense(32, activation='relu', input_shape=(26,)),
    Dropout(0.3),
    Dense(3, activation='softmax')
])
model.compile(optimizer=Adam(0.001), loss='categorical_crossentropy', metrics=['accuracy'])

history = model.fit(
    X_train, y_train_cat,
    epochs=200, batch_size=32,
    class_weight=cw_dict,
    validation_data=(X_test, y_test_cat),
    verbose=1
)

# ============================================================
# 7. CONFUSION MATRIX
# ============================================================
y_pred = model.predict(X_test)
cm = confusion_matrix(np.argmax(y_test_cat, axis=1), np.argmax(y_pred, axis=1))

plt.figure(figsize=(8,6))
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
            xticklabels=['on','off','other'],
            yticklabels=['on','off','other'])
plt.xlabel('Predicted'); plt.ylabel('True')
plt.title('Confusion Matrix - lekki tor cech (FLOAT)')
plt.show()

acc = model.evaluate(X_test, y_test_cat, verbose=0)[1]
print(f"\nTest Accuracy (lekki tor): {acc:.4f}")
print("\nPorownaj z librosa (~88%). Jak podobnie -> idziemy do fixed-point.")

model.save('sound_model_light.h5')
np.save('X_light.npy', X)
np.save('y_light.npy', y)