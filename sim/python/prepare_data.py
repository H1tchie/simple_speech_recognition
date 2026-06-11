#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 23 14:53:53 2024

@author: ferdziu10
"""

import numpy as np
import librosa
import os
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.utils import to_categorical

def extract_features(file_path):
    y, sr = librosa.load(file_path, sr=None)
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfccs_mean = np.mean(mfccs, axis=1)
    mfccs_std = np.std(mfccs, axis=1)
    return np.concatenate([mfccs_mean, mfccs_std])

# Path to directories
on_dir = '/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/dataset/on'
off_dir = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/dataset/off'
other_dir = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/dataset/other'

# Load and extract features
X, y = [], []
for file in os.listdir(on_dir):
    if file.endswith('.wav'):
        feature = extract_features(os.path.join(on_dir, file))
        X.append(feature)
        y.append(0)

for file in os.listdir(off_dir):
    if file.endswith('.wav'):
        feature = extract_features(os.path.join(off_dir, file))
        X.append(feature)
        y.append(1)

for file in os.listdir(other_dir):
    if file.endswith('.wav'):
        feature = extract_features(os.path.join(other_dir, file))
        X.append(feature)
        y.append(2)
print(len(X),len(y))

X = np.array(X)
y = np.array(y)

"""# Encode labels
label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)
y_categorical = to_categorical(y_encoded)"""

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
print(X_train[:10], y_train[:10])
# Save prepared data
np.save('X_train.npy', X_train)
np.save('X_test.npy', X_test)
np.save('y_train.npy', y_train)
np.save('y_test.npy', y_test)

