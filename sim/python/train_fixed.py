# -*- coding: utf-8 -*-
"""
train_fixed.py - trening sieci na cechach FIXED-POINT (bit-w-bit jak RTL).
Uzywa dsp_fixed.py (musi byc w tym samym folderze).

Po treningu:
  - zapisuje model
  - generuje wagi int8 do dense_layer_1/2 (bloki assign)
  - generuje ROM-y .mem (window, cos, sin, mel, dct)
  - confusion matrix

trening = symulacja = sprzet (te same cechy fixed-point)
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

from dsp_fixed import (extract_features_fixed, WIN_Q15, COS_Q15, SIN_Q15,
                       FB_Q15, DCT_Q12, NMELS, NMFCC, NFFT, NBINS, FRAME)

# ============================================================
# 1. WCZYTAJ DANE - cechy fixed-point
# ============================================================
def load_dir(directory, label):
    X,y=[],[]
    for f in os.listdir(directory):
        if f.endswith('.wav'):
            try:
                wav,sr=sf.read(os.path.join(directory,f))
                if wav.ndim>1: wav=wav.mean(1)
                feat=extract_features_fixed(wav)
                if feat is not None:
                    X.append(feat); y.append(label)
            except Exception as e:
                print(f"  skip {f}: {e}")
    print(f"Loaded {len(X)} from {directory}")
    return X,y

on_dir  = 'C:/Users/ferdz/Desktop/audio_samples/onn'
off_dir = 'C:/Users/ferdz/Desktop/audio_samples/offf'
oth_dir = 'C:/Users/ferdz/Desktop/audio_samples/othh'

X_on,y_on   = load_dir(on_dir,0)
X_off,y_off = load_dir(off_dir,1)
X_oth,y_oth = load_dir(oth_dir,2)

X=np.array(X_on+X_off+X_oth,dtype=np.float32)
y=np.array(y_on+y_off+y_oth)
print(f"\nX shape: {X.shape}, range [{X.min():.0f}, {X.max():.0f}]")

X_train,X_test,y_train,y_test=train_test_split(
    X,y,test_size=0.2,random_state=42,stratify=y)
y_train_cat=to_categorical(y_train,3)
y_test_cat =to_categorical(y_test,3)

# ============================================================
# 2. NORMALIZACJA - siec lubi male wejscia, ale RTL daje surowe int
#    Rozwiazanie: input_scale wbudowany w pierwsza warstwe przez trening.
#    Trenujemy na surowych cechach (tak jak RTL je wystawi).
# ============================================================
cw=compute_class_weight('balanced',classes=np.array([0,1,2]),y=y_train)
cw_dict={0:cw[0],1:cw[1],2:cw[2]}

model=Sequential([
    Dense(32,activation='relu',input_shape=(26,)),
    Dropout(0.3),
    Dense(3,activation='softmax')
])
model.compile(optimizer=Adam(0.001),loss='categorical_crossentropy',metrics=['accuracy'])
model.fit(X_train,y_train_cat,epochs=200,batch_size=32,
          class_weight=cw_dict,validation_data=(X_test,y_test_cat),verbose=1)

# ============================================================
# 3. CONFUSION MATRIX
# ============================================================
y_pred=model.predict(X_test)
cm=confusion_matrix(np.argmax(y_test_cat,1),np.argmax(y_pred,1))
plt.figure(figsize=(8,6))
sns.heatmap(cm,annot=True,fmt='d',cmap='Blues',
            xticklabels=['on','off','other'],yticklabels=['on','off','other'])
plt.xlabel('Predicted');plt.ylabel('True')
plt.title('Confusion Matrix - FIXED-POINT cechy')
plt.show()
acc=model.evaluate(X_test,y_test_cat,verbose=0)[1]
print(f"\nTest Accuracy (fixed): {acc:.4f}")

# ============================================================
# 4. ZAPISZ WAGI int8 + ROM-y .mem
# ============================================================
OUT='C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/'
os.makedirs(OUT,exist_ok=True)

# --- wagi sieci do blokow assign (jak dotychczas) ---
def num(n): return f"8'd{n}," if n>=0 else f"-8'd{-n},"
dense=[l for l in model.layers if 'dense' in l.name]
for li,layer in enumerate(dense):
    W,b=layer.get_weights()
    Wq=np.clip(np.round(W*127),-128,127).astype(int)
    bq=np.clip(np.round(b*127),-128,127).astype(int)
    with open(OUT+f'dense{li+1}_assign.txt','w') as f:
        for i in range(Wq.shape[0]):
            row=' '.join(num(v) for v in Wq[i])
            f.write(f"assign weight_matrix[{i}] = {{{row.rstrip(',')}}};\n")
        brow=' '.join(num(v) for v in bq)
        f.write(f"assign bias_vector = {{{brow.rstrip(',')}}};\n")
    print(f"dense{li+1}: W{Wq.shape} b{bq.shape} -> dense{li+1}_assign.txt")

# --- ROM-y .mem (hex, signed) ---
def to_hex16(v):
    v=int(v)
    if v<0: v+=65536
    return f"{v&0xFFFF:04X}"

def save_mem(arr,path):
    with open(path,'w') as f:
        for v in np.array(arr).flatten():
            f.write(to_hex16(v)+'\n')

save_mem(WIN_Q15, OUT+'window_hamming_256.mem')
save_mem(COS_Q15, OUT+'dft_cos_256.mem')   # NBINS*NFFT
save_mem(SIN_Q15, OUT+'dft_sin_256.mem')
save_mem(FB_Q15,  OUT+'mel_fb_26.mem')      # NMELS*NBINS
save_mem(DCT_Q12, OUT+'dct_13x26.mem')      # NMFCC*NMELS
print("\nROM-y .mem zapisane:")
print(f"  window_hamming_256.mem : {WIN_Q15.size}")
print(f"  dft_cos_256.mem        : {COS_Q15.size}")
print(f"  dft_sin_256.mem        : {SIN_Q15.size}")
print(f"  mel_fb_26.mem          : {FB_Q15.size}")
print(f"  dct_13x26.mem          : {DCT_Q12.size}")

model.save('sound_model_fixed.h5')
print("\nGotowe. Wagi + ROM-y wygenerowane.")
