//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   nn_parameters
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.6
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  package of parameters used in modules in neural network
 */
//////////////////////////////////////////////////////////////////////////////

package nn_parameters;
//parameters for dense 1
localparam DATA_WIDTH_0 = 16;
localparam IN_SIZE_1 = 26;
localparam OUT_SIZE_1 = 32;
localparam DATA_WIDTH_1 = 24;

//parameters for dense 2
localparam IN_SIZE_2 = 32;
localparam OUT_SIZE_2 = 3;
localparam DATA_WIDTH_2 = 32;
localparam DATA_WIDTH_FINAL = 2;

//paramiters for weight and biases
localparam WB_WIDTH = 8;
endpackage