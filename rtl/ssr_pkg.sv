//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ssr_pkg
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Globalne parametry projektu Simple Speech Recognition.
                Wartości MUSZĄ być zgodne z konfiguracją tools/gen_*.py.
*/
//////////////////////////////////////////////////////////////////////////////

package ssr_pkg;

    // ----- ścieżka danych -----
    localparam int SAMPLE_WIDTH = 16;       // Q1.15 sample
    localparam int FRAME_LEN    = 512;
    localparam int HOP_LEN      = 256;
    localparam int N_FFT        = 512;
    localparam int N_BINS       = N_FFT/2 + 1;   // 257

    // ----- pre-emphasis -----
    localparam logic [15:0] ALPHA_Q15 = 16'h7C29;  // 0.97

    // ----- mel / mfcc -----
    localparam int N_MELS      = 26;
    localparam int N_MFCC      = 13;
    localparam int MEL_ACC_WIDTH  = 32;
    localparam int MFCC_WIDTH     = 16;
    localparam int LOG_WIDTH      = 16;

    // ----- features -> NN -----
    localparam int N_FEATURES = 26;     // 13 mean + 13 std

    // ----- BRAM source -----
    localparam int NUM_SAMPLES = 16384;  // 1.024 s @ 16 kHz

endpackage : ssr_pkg
