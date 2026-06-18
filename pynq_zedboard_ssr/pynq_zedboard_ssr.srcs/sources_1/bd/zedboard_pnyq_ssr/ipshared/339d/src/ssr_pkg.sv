//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ssr_pkg
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Globalne parametry toru audio processing (MFCC).
                Musza sie zgadzac z dsp_fixed.py w Pythonie.
 */
//////////////////////////////////////////////////////////////////////////////

package ssr_pkg;

    // --- parametry toru (== dsp_fixed.py) ---
    localparam int SR         = 16000;
    localparam int FRAME_LEN  = 256;
    localparam int HOP_LEN    = 128;
    localparam int N_FFT      = 256;
    localparam int N_BINS     = 129;   // N_FFT/2 + 1
    localparam int N_MELS     = 26;
    localparam int N_MFCC     = 13;
    localparam int N_FEATURES = 26;    // 13 mean + 13 std

    localparam int N_SAMPLES  = 16000; // dlugosc nagrania (1s)
    localparam int N_FRAMES   = 1 + (N_SAMPLES - FRAME_LEN) / HOP_LEN; // 124

    // --- formaty danych (bity) ---
    localparam int SAMPLE_W   = 16;    // Q1.15 audio
    localparam int WIN_W      = 16;    // Q1.15 okno
    localparam int TWIDDLE_W  = 16;    // Q1.15 cos/sin
    localparam int DFT_W      = 32;    // re/im akumulacja
    localparam int POWER_W    = 48;   // re^2+im^2, worst-case full-scale ~2^42
    localparam int MELFB_W    = 16;    // Q1.15 mel filter
    localparam int MEL_W      = 48;    // mel energy, worst-case ~2^42
    localparam int MEL_ACC_W  = 64;    // akumulator mel (FB*power)
    localparam int LOG_W      = 24;    // log2 wynik Q14.10 signed
    localparam int DCT_W      = 16;    // Q4.12 dct coeff
    localparam int MFCC_W     = 24;    // mfcc (Q?.10)
    localparam int FEAT_W     = 16;    // cecha int16 do sieci

    // --- log2 offset (korekta skali power 2^30) ---
    localparam int LOG2_OFFSET_Q10 = 30651; // = round(29.93*1024)
    localparam int LOG2_FRAC_BITS  = 10;

    // --- formaty u stalych (bity ulamka) ---
    localparam int Q15 = 15;
    localparam int Q12 = 12;
    localparam int Q10 = 10;

endpackage : ssr_pkg