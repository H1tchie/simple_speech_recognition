//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ap_parameters
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Package of parameters for audio processing
 */
//////////////////////////////////////////////////////////////////////////////
package ap_parameters;
    //multiplier parameters
    localparam A_WIDTH = 32;
    localparam B_WIDTH = 16;
    localparam P_WIDTH = 32;
    //adc outputs parameters
    localparam ADC_DATA_WIDTH = 12;

    //frame parameters
    localparam FRAME_ARRAY_WIDTH = 64;

    //FFT parameters
    localparam FFT_DATA_WIDTH = 16;

    //MEL parameters
    localparam MEL_DATA_WIDTH = 32;

    //MEAN_STD parameters
    localparam MSIN_DATA_WIDTH = 16;
    localparam MS_DATA_WIDTH = 32;
    localparam MS_ARRAY_WIDTH = 20;

    // neural_network inputs parameters
    localparam NN_ARRAY_WIDTH = 26;
    localparam NN_DATA_WIDTH = 16;
    
    endpackage