#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Jul 23 14:53:53 2024

@author: ferdziu10
"""

import numpy as np
import librosa
import os
import soundfile as sf

def add_noise(y, noise_factor=0.005):
    noise = np.random.randn(len(y))
    augmented_data = y + noise_factor * noise
    return augmented_data

def shift_time(y, shift_max=2):
    shift = np.random.randint(len(y) // shift_max)
    direction = np.random.choice([-1, 1])
    return np.roll(y, direction * shift)

def change_pitch(y, sr, pitch_factor=2.0):
    return librosa.effects.pitch_shift(y, sr=sr, n_steps=pitch_factor)

def change_speed(y, speed_factor=1.5):
    return librosa.effects.time_stretch(y, rate=speed_factor)

def augment_audio(file_path, output_dir, augmentations=5):
    y, sr = librosa.load(file_path, sr=None)
    
    # Create augmentations
    augmented_samples = [y]
    for _ in range(augmentations):
        augmented_samples.append(add_noise(y))
        augmented_samples.append(shift_time(y))
        augmented_samples.append(change_pitch(y, sr, pitch_factor=2.0))
        augmented_samples.append(change_speed(y, speed_factor=1.5))
    
    # Save augmented samples
    base_name = os.path.basename(file_path).split('.')[0]
    for i, sample in enumerate(augmented_samples):
        augmented_file_path = os.path.join(output_dir, f"{base_name}_aug_{i}.wav")
        sf.write(augmented_file_path, sample, sr)

# Paths
on_dir = '/Users/Ferdek/Downloads/Simple-speech-recognisition/python/WAV/on'
off_dir = '/Users/Ferdek/Downloads/Simple-speech-recognisition/python/WAV/off'
augmented_on_dir = '/Users/Ferdek/Downloads/Simple-speech-recognisition/python/WAV/augmented_on'
augmented_off_dir = '/Users/Ferdek/Downloads/Simple-speech-recognisition/python/WAV/augmented_off'

# Create directories if they don't exist
os.makedirs(augmented_on_dir, exist_ok=True)
os.makedirs(augmented_off_dir, exist_ok=True)

# Augment "on" samples
for file in os.listdir(on_dir):
    if file.endswith('.wav'):
        file_path = os.path.join(on_dir, file)
        augment_audio(file_path, augmented_on_dir)

# Augment "off" samples
for file in os.listdir(off_dir):
    if file.endswith('.wav'):
        file_path = os.path.join(off_dir, file)
        augment_audio(file_path, augmented_off_dir)
