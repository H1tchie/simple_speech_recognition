//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_nn
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       4.1  (sekwencjonowanie start/done + magistrale packed)
 Description:   start -> dense_layer_1 -> (done) -> dense_layer_2
                      -> (done) -> final_layer -> (done) -> nn done
                Architektura: 26 -> 32 (ReLU) -> 3 (logity) -> argmax -> 2-bit.
                Wejscie packed input_bus ([IN_SIZE_1*16-1:0]). Wagi z .mem.
*/
//////////////////////////////////////////////////////////////////////////////

import nn_parameters::*;

module top_nn (
    input  logic                       clk,
    input  logic                       rst,
    input  logic                       start,
    input  logic [IN_SIZE_1*16-1:0]    input_bus,
    output logic [1:0]                 output_value,
    output logic                       done
);
    logic [OUT_SIZE_1*DATA_WIDTH_1-1:0] l1_bus;
    logic [OUT_SIZE_2*DATA_WIDTH_2-1:0] l2_bus;
    logic l1_done, l2_done, lf_done;

    dense_layer #(
        .IN_SIZE(IN_SIZE_1), .OUT_SIZE(OUT_SIZE_1), .IN_WIDTH(16),
        .OUT_WIDTH(DATA_WIDTH_1), .USE_RELU(1),
        .WEIGHT_FILE("dense1_weights.mem"), .BIAS_FILE("dense1_bias.mem")
    ) u_dense_layer_1 (
        .clk, .rst, .start(start),
        .input_bus(input_bus), .output_bus(l1_bus), .done(l1_done)
    );

    dense_layer #(
        .IN_SIZE(IN_SIZE_2), .OUT_SIZE(OUT_SIZE_2), .IN_WIDTH(DATA_WIDTH_1),
        .OUT_WIDTH(DATA_WIDTH_2), .USE_RELU(0),
        .WEIGHT_FILE("dense2_weights.mem"), .BIAS_FILE("dense2_bias.mem")
    ) u_dense_layer_2 (
        .clk, .rst, .start(l1_done),
        .input_bus(l1_bus), .output_bus(l2_bus), .done(l2_done)
    );

    final_layer u_final_layer (
        .clk, .rst, .start(l2_done),
        .input_bus(l2_bus), .output_value(output_value), .done(lf_done)
    );

    assign done = lf_done;
endmodule
