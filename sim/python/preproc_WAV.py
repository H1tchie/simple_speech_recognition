#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 23 14:53:53 2024

@author: ferdziu10
"""

import numpy as np
import librosa

def extract_features(file_path):
    y, sr = librosa.load(file_path, sr=None)
    mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
    mfccs_mean = np.mean(mfccs, axis=1)
    mfccs_std = np.std(mfccs, axis=1)
    print(mfccs)
    return np.concatenate([mfccs_mean, mfccs_std])

def save_features_to_mem(features, mem_file, bit_width=16):
    max_value = 2**bit_width - 1
    min_value = 0

    # Scale features to fit in the desired range
    scaled_features = np.clip(features, min_value, max_value)
    
    # Save as .mem file
    with open(mem_file, 'w') as f:
        for feature in scaled_features:
            # Convert each feature to an integer and then to hexadecimal
            feature_int = int(round(feature))  # Round to the nearest integer
            hex_val = format(feature_int, '0{}X'.format(bit_width // 4))  # Convert to hex
            f.write(f"{hex_val}\n")

# Path to the WAV file
wav_file_path = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/test/otherrec.wav'
mem_output_file = 'C:/Users/Kacper/Desktop/UEC/Projekt/Simple-speech-recognisition/python/WAV/other.mem'

# Extract features
features = extract_features(wav_file_path)

# Save features to a .mem file
save_features_to_mem(features, mem_output_file, bit_width=16)

print(f"Features from {wav_file_path} saved to {mem_output_file}")

