import nn_parameters::*;

module top_nn (
    input logic clk,
    input logic rst,
    input logic signed [15:0] input_vector [IN_SIZE_1-1:0],
    output logic [1:0] output_value,
    output logic done1_out,
output logic done2_out
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic signed [DATA_WIDTH_1-1:0] dslayer1_output [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_2-1:0] dslayer2_output [OUT_SIZE_2-1:0];
    logic done1, done2;
    logic rst_layer2;
    logic rst_final;

//------------------------------------------------------------------------------
// synchronizacja warstw
//------------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (rst) begin
        rst_layer2 <= 1'b1;
        rst_final  <= 1'b1;
    end else begin
        // SET gdy reset globalny, CLEAR gdy done - i już nie wraca do 1
        if (done1 && rst_layer2)
            rst_layer2 <= 1'b0;  // raz opada i zostaje
            
        if (done2 && rst_final)
            rst_final <= 1'b0;   // raz opada i zostaje
    end
end
//------------------------------------------------------------------------------
// module instances
//------------------------------------------------------------------------------
    dense_layer_1 u_dense_layer_1 (
        .clk,
        .rst,
        .input_vector(input_vector),
        .output_vector(dslayer1_output),
        .done(done1)
    );

    dense_layer_2 u_dense_layer_2 (
        .clk,
        .rst(rst_layer2),
        .input_vector(dslayer1_output),
        .output_vector(dslayer2_output),
        .done(done2)
    );

    final_layer u_final_layer (
        .clk,
        .rst(rst_final),
        .input_vector(dslayer2_output),
        .output_value(output_value)
    );

endmodule
