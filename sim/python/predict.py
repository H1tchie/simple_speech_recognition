#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 23 14:53:53 2024

@author: ferdziu10
"""

import numpy as np
import librosa
from tensorflow.keras.models import load_model
import os

def extract_features(file_path):
    try:
        y, sr = librosa.load(file_path, sr=None)
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        mfccs_mean = np.mean(mfccs, axis=1)
        mfccs_std = np.std(mfccs, axis=1)
        return np.concatenate([mfccs_mean, mfccs_std])
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return None

def predict(file_path, model):
    feature = extract_features(file_path)
    if feature is not None:
        feature = np.expand_dims(feature, axis=0)
        prediction = model.predict(feature)
        return np.argmax(prediction)
    else:
        return None

# Load the trained model
model = load_model('sound_classification_model.h5')

# Path to the new audio file
file_path = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/test/other_test1.wav'  # Upewnij się, że plik istnieje w tej lokalizacji

# Predict
if os.path.exists(file_path):
    prediction = predict(file_path, model)
    print(prediction)
    if prediction is not None:
        classes = ['on', 'off', 'other']
        print(f'Predicted class: {classes[prediction]}')
    else:
        print("Error in feature extraction")
else:
    print("Plik nie istnieje. Sprawdź ścieżkę.")
