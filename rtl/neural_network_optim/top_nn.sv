//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_nn
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       3.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  top module of neural network connecting all the dense layers
 */
//////////////////////////////////////////////////////////////////////////////
import nn_parameters::*;
module top_nn (
    input logic clk,
    input logic rst,
    input logic signed [15:0] input_vector [IN_SIZE_1-1:0],
    output logic [1:0] output_value 
);


//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    logic signed [23:0] dslayer1_output [OUT_SIZE_1-1:0];
    logic signed [31:0] dslayer2_output [OUT_SIZE_2-1:0];

//------------------------------------------------------------------------------
// module instances
//------------------------------------------------------------------------------


dense_layer_1 u_dense_layer_1 (
    .clk,
    .rst,
    .input_vector(input_vector),
    .output_vector(dslayer1_output)
);

dense_layer_2 u_dense_layer_2 (
    .clk,
    .rst,
    .input_vector(dslayer1_output),
    .output_vector(dslayer2_output)
);

final_layer u_final_layer (
    .clk,
    .rst,
    .input_vector(dslayer2_output),
    .output_value(output_value)
);

endmodule
