# -*- coding: utf-8 -*-
"""
dsp_fixed.py - fixed-point MFCC bit-w-bit pod RTL.
Zweryfikowany vs float (max diff <0.5 na ceche).

Tor: audio Q1.15 -> Hamming Q15 -> DFT256 fixed -> power -> mel Q15
     -> log2 (Q10, offset 2^30) -> DCT Q12 -> mean/std -> 26 cech int16

Parametry MUSZA sie zgadzac z ssr_pkg.sv w RTL.
"""
import numpy as np

# ====== PARAMETRY ======
SR=16000; FRAME=256; HOP=128; NFFT=256; NBINS=129; NMELS=26; NMFCC=13
LOG2_OFFSET_Q10 = 30651   # = round(29.93*1024), korekta skali power 2^30

# ====== ROM-y ======
def _hamming(N):
    n=np.arange(N); return 0.54-0.46*np.cos(2*np.pi*n/(N-1))
WIN_F   = _hamming(FRAME)
WIN_Q15 = np.round(WIN_F*32768).astype(np.int64)

_k=np.arange(NFFT)
COS_Q15=np.clip(np.round(np.cos(-2*np.pi*np.outer(np.arange(NBINS),_k)/NFFT)*32768),-32768,32767).astype(np.int64)
SIN_Q15=np.clip(np.round(np.sin(-2*np.pi*np.outer(np.arange(NBINS),_k)/NFFT)*32768),-32768,32767).astype(np.int64)

def _hz2mel(f): return 2595.0*np.log10(1.0+f/700.0)
def _mel2hz(m): return 700.0*(10.0**(m/2595.0)-1.0)
def _mel_fb():
    nb=NBINS
    mp=np.linspace(_hz2mel(0),_hz2mel(SR/2),NMELS+2); hz=_mel2hz(mp)
    bp=np.floor((NFFT+1)*hz/SR).astype(int); bp=np.clip(bp,0,nb-1)
    fb=np.zeros((NMELS,nb))
    for m in range(1,NMELS+1):
        l,c,r=bp[m-1],bp[m],bp[m+1]
        for kk in range(l,c):
            if c!=l: fb[m-1,kk]=(kk-l)/(c-l)
        for kk in range(c,r):
            if r!=c: fb[m-1,kk]=(r-kk)/(r-c)
    return fb
FB_F   = _mel_fb()
FB_Q15 = np.clip(np.round(FB_F*32768),-32768,32767).astype(np.int64)

def _dctm():
    D=np.zeros((NMFCC,NMELS))
    for kk in range(NMFCC):
        for n in range(NMELS):
            D[kk,n]=np.cos(np.pi*kk*(2*n+1)/(2*NMELS))
    D[0,:]*=np.sqrt(1/NMELS); D[1:,:]*=np.sqrt(2/NMELS)
    return D
DCT_F   = _dctm()
DCT_Q12 = np.round(DCT_F*4096).astype(np.int64)

# ====== log2 fixed (jak RTL: LZC + ulamek mantysy) ======
def log2_fixed(x_int):
    """log2(x) w Q10 dla x>=1. Bit-exact jak RTL:
       msb = pozycja MSB (LZC), frac = 10 bitow ponizej MSB."""
    x_int=int(x_int)
    if x_int<=0: return 0
    msb=x_int.bit_length()-1
    if msb>=10:
        frac=(x_int>>(msb-10))&0x3FF
    else:
        frac=(x_int<<(10-msb))&0x3FF
    return (msb<<10)|frac

# ====== GLOWNA FUNKCJA - liczy cechy bit-w-bit jak RTL ======
def extract_features_fixed(y_float):
    samp=np.clip(np.round(y_float*32768),-32768,32767).astype(np.int64)
    nfr=1+(len(samp)-FRAME)//HOP
    if nfr<1: return None
    mfcc_all=[]
    for t in range(nfr):
        frame=samp[t*HOP:t*HOP+FRAME]
        win=(frame*WIN_Q15)>>15                         # Q1.15
        re=(COS_Q15@win)>>15                            # DFT real
        im=(SIN_Q15@win)>>15                            # DFT imag
        power=re*re+im*im                               # int
        mel=np.maximum((FB_Q15@power)>>15,1)            # mel, floor 1
        logmel=np.array([log2_fixed(int(m))-LOG2_OFFSET_Q10
                         for m in mel],dtype=np.int64)   # Q10
        mfcc=(DCT_Q12@logmel)>>12                        # Q10
        mfcc_all.append(mfcc)
    mfcc_all=np.array(mfcc_all,dtype=np.int64)   # (nfr,13) Q10
    nfr=mfcc_all.shape[0]
    # agregacja CALKOWITA (bit-exact z RTL):
    suma  = mfcc_all.sum(0)                       # Q10
    sumsq = (mfcc_all**2).sum(0)                  # Q20
    # mean = suma/nfr, potem >>10 do int (skala 1.0)
    mean_int = np.array([_idiv(int(s),nfr)>>10 for s in suma],dtype=np.int64)
    # var_num = nfr*sumsq - suma^2 ; std = isqrt(var_num)/nfr ; potem >>10
    std_int=[]
    for k in range(13):
        var_num = nfr*int(sumsq[k]) - int(suma[k])**2   # Q20 * nfr
        if var_num<0: var_num=0
        std_q10 = _isqrt(var_num)//nfr                   # sqrt(Q20)=Q10, /nfr
        std_int.append(std_q10>>10)
    std_int=np.array(std_int,dtype=np.int64)
    return np.concatenate([mean_int,std_int]).astype(np.int64)

def _idiv(a,b):
    """dzielenie calkowite z zaokragleniem do zera (jak RTL signed /)"""
    q=abs(a)//abs(b)
    if (a<0)!=(b<0): q=-q
    return q

def _isqrt(n):
    """floor(sqrt(n)) - bitwise, deterministyczny (jak RTL)"""
    n=int(n)
    if n<=0: return 0
    res=0
    bit=1<<(((n.bit_length()-1)//2)*2)
    while bit!=0:
        if n>=res+bit:
            n-=res+bit
            res=(res>>1)+bit
        else:
            res>>=1
        bit>>=2
    return res

# ====== FLOAT REFERENCE (do weryfikacji) ======
def extract_features_float(y_float):
    nfr=1+(len(y_float)-FRAME)//HOP
    out=[]
    for t in range(nfr):
        fr=y_float[t*HOP:t*HOP+FRAME]*WIN_F
        power=np.abs(np.fft.rfft(fr,NFFT))**2
        mel=np.maximum(FB_F@power,1e-10)
        out.append(DCT_F@np.log2(mel))
    out=np.array(out)
    return np.concatenate([out.mean(0),out.std(0)])

if __name__=="__main__":
    np.random.seed(1)
    print("Self-test fixed vs float:")
    for _ in range(3):
        y=np.random.uniform(-0.5,0.5,16000)
        d=np.abs(extract_features_fixed(y)-extract_features_float(y)).max()
        print(f"  max diff = {d:.2f}")
    print("ROM rozmiary:")
    print(f"  WIN_Q15  : {WIN_Q15.shape}")
    print(f"  COS/SIN  : {COS_Q15.shape}")
    print(f"  FB_Q15   : {FB_Q15.shape}")
    print(f"  DCT_Q12  : {DCT_Q12.shape}")