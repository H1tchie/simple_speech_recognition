# -*- coding: utf-8 -*-
"""
Created on Mon Jun 15 19:36:15 2026

@author: ferdz
"""

import numpy as np
from dsp_fixed import WIN_Q15, COS_Q15, SIN_Q15, FB_Q15, DCT_Q12

OUT = 'C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/'

def to_hex16(v):
    v = int(v)
    if v < 0: v += 65536
    return f"{v & 0xFFFF:04X}"

def save_mem(arr, path):
    with open(path, 'w') as f:
        for v in np.array(arr).flatten():
            f.write(to_hex16(v) + '\n')

save_mem(WIN_Q15, OUT + 'window_hamming_256.mem')
save_mem(COS_Q15, OUT + 'dft_cos_256.mem')
save_mem(SIN_Q15, OUT + 'dft_sin_256.mem')
save_mem(FB_Q15,  OUT + 'mel_fb_26.mem')
save_mem(DCT_Q12, OUT + 'dct_13x26.mem')
print("ROM-y przegenerowane (z clampem)")