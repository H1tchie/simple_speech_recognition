//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   dense_layer_1
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       3.4
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  first layer of neural network
 */
//////////////////////////////////////////////////////////////////////////////

import nn_parameters::*;

module dense_layer_1 (
    input clk,
    input rst,
    input logic signed [DATA_WIDTH_0-1:0] input_vector [IN_SIZE_1-1:0],
    output logic signed [DATA_WIDTH_1-1:0] output_vector [OUT_SIZE_1-1:0]
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    logic signed [WB_WIDTH-1:0] weight_matrix [IN_SIZE_1-1:0][OUT_SIZE_1-1:0];
    logic signed [WB_WIDTH-1:0] bias_vector [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_1-1:0] output_vector_nxt [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_1-1:0] sum [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_1-1:0] mult [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_1-1:0] sum_nxt [OUT_SIZE_1-1:0];
    logic signed [DATA_WIDTH_1-1:0] mult_nxt [OUT_SIZE_1-1:0];
    logic [7:0] i;
    logic [7:0] i_nxt;

    integer j, k;

assign weight_matrix[0] = {8'd4, 8'd26, 8'd25, 8'd17, -8'd18, -8'd14, -8'd7, 8'd33, -8'd4, 8'd5, 8'd8, -8'd3, 8'd32, 8'd8, -8'd22, -8'd16, 8'd27, 8'd2, 8'd5, -8'd16, 8'd0, -8'd30, 8'd7, 8'd28, 8'd28, 8'd6, 8'd18, 8'd34, -8'd7, -8'd17, -8'd7, -8'd9};
assign weight_matrix[1] = {8'd9, -8'd10, -8'd15, 8'd30, -8'd31, 8'd2, 8'd14, 8'd2, 8'd6, -8'd34, -8'd2, 8'd8, 8'd31, 8'd30, 8'd29, -8'd31, -8'd27, 8'd8, -8'd21, -8'd50, 8'd36, -8'd42, 8'd33, -8'd8, 8'd21, 8'd21, -8'd4, -8'd14, -8'd4, -8'd7, -8'd19, -8'd6};
assign weight_matrix[2] = {8'd8, 8'd17, -8'd17, -8'd8, -8'd23, -8'd34, -8'd24, -8'd19, -8'd32, -8'd23, -8'd12, -8'd19, 8'd3, 8'd26, -8'd15, 8'd2, 8'd40, -8'd25, -8'd2, -8'd27, -8'd18, 8'd2, -8'd40, -8'd1, -8'd21, -8'd31, 8'd8, -8'd39, -8'd37, 8'd0, -8'd20, -8'd28};
assign weight_matrix[3] = {8'd20, -8'd36, 8'd9, 8'd17, -8'd35, -8'd26, -8'd27, 8'd34, -8'd27, 8'd26, -8'd13, -8'd18, -8'd12, 8'd31, 8'd4, 8'd2, -8'd15, -8'd43, -8'd23, -8'd6, 8'd20, -8'd13, 8'd30, 8'd22, -8'd3, 8'd38, 8'd19, -8'd1, -8'd26, -8'd47, 8'd8, -8'd7};
assign weight_matrix[4] = {8'd15, -8'd18, -8'd37, -8'd45, 8'd51, 8'd1, 8'd38, -8'd22, -8'd42, 8'd31, 8'd12, 8'd41, 8'd9, 8'd50, 8'd41, 8'd24, -8'd8, -8'd4, 8'd20, -8'd35, -8'd5, -8'd15, 8'd32, 8'd35, -8'd2, 8'd47, 8'd30, 8'd17, 8'd68, 8'd12, 8'd30, 8'd33};
assign weight_matrix[5] = {-8'd12, 8'd7, -8'd38, -8'd41, 8'd35, 8'd27, -8'd25, 8'd36, -8'd5, 8'd6, -8'd17, 8'd16, -8'd30, 8'd26, -8'd21, 8'd2, -8'd1, 8'd12, 8'd11, -8'd33, 8'd11, -8'd22, -8'd26, 8'd20, -8'd28, 8'd5, 8'd4, -8'd24, -8'd18, -8'd28, 8'd3, -8'd17};
assign weight_matrix[6] = {-8'd19, 8'd23, 8'd29, -8'd44, -8'd10, 8'd15, -8'd20, -8'd19, 8'd20, 8'd7, 8'd52, -8'd4, -8'd6, -8'd69, -8'd20, -8'd10, 8'd3, 8'd48, -8'd19, -8'd37, 8'd2, -8'd12, 8'd30, 8'd11, 8'd9, -8'd36, -8'd3, -8'd38, -8'd10, -8'd51, -8'd16, 8'd16};
assign weight_matrix[7] = {-8'd16, -8'd40, -8'd28, 8'd6, -8'd24, -8'd38, -8'd16, 8'd7, 8'd16, -8'd19, 8'd38, 8'd16, 8'd12, 8'd12, 8'd0, 8'd39, -8'd22, 8'd23, -8'd21, 8'd1, -8'd26, 8'd7, -8'd44, 8'd20, 8'd39, -8'd8, 8'd31, -8'd12, 8'd4, 8'd15, 8'd19, 8'd6};
assign weight_matrix[8] = {-8'd22, 8'd7, 8'd39, 8'd28, -8'd3, 8'd45, -8'd18, -8'd20, 8'd19, -8'd4, 8'd29, -8'd27, 8'd32, -8'd5, 8'd20, 8'd15, 8'd23, 8'd17, -8'd5, 8'd35, 8'd31, -8'd14, 8'd34, -8'd31, 8'd11, -8'd18, 8'd23, 8'd18, 8'd1, -8'd6, 8'd5, 8'd14};
assign weight_matrix[9] = {8'd7, -8'd8, 8'd38, -8'd17, -8'd74, -8'd16, 8'd14, 8'd32, -8'd9, -8'd24, 8'd10, 8'd22, -8'd19, 8'd6, 8'd17, -8'd8, -8'd26, 8'd28, -8'd19, 8'd20, -8'd18, -8'd36, -8'd45, 8'd29, -8'd18, 8'd4, -8'd40, -8'd17, -8'd33, 8'd36, 8'd42, 8'd30};
assign weight_matrix[10] = {8'd82, -8'd29, -8'd1, 8'd7, -8'd17, -8'd25, 8'd10, 8'd10, 8'd3, -8'd41, 8'd12, 8'd17, 8'd31, -8'd33, -8'd45, -8'd10, 8'd5, -8'd3, -8'd34, 8'd22, -8'd33, 8'd30, 8'd36, 8'd34, 8'd13, -8'd29, 8'd17, -8'd26, -8'd43, 8'd23, -8'd15, 8'd11};
assign weight_matrix[11] = {8'd11, 8'd3, -8'd4, -8'd1, -8'd23, -8'd40, -8'd30, -8'd25, 8'd34, 8'd3, 8'd14, 8'd4, -8'd8, -8'd52, -8'd47, 8'd14, 8'd7, 8'd6, -8'd36, 8'd35, -8'd6, -8'd11, -8'd9, -8'd38, 8'd21, -8'd50, 8'd36, 8'd15, -8'd14, -8'd4, -8'd67, 8'd18};
assign weight_matrix[12] = {-8'd17, -8'd2, -8'd29, 8'd35, 8'd53, -8'd25, 8'd19, -8'd29, 8'd53, 8'd13, 8'd3, 8'd18, 8'd2, -8'd50, -8'd10, 8'd25, 8'd15, 8'd0, -8'd18, 8'd13, -8'd72, 8'd36, -8'd3, 8'd23, 8'd4, -8'd37, -8'd1, 8'd5, 8'd8, 8'd34, -8'd26, 8'd14};
assign weight_matrix[13] = {8'd13, -8'd32, 8'd1, 8'd8, -8'd34, -8'd47, -8'd25, -8'd10, -8'd14, -8'd10, 8'd15, -8'd32, -8'd21, 8'd0, 8'd12, -8'd30, -8'd2, 8'd12, -8'd4, -8'd16, -8'd11, -8'd18, -8'd32, -8'd37, -8'd21, 8'd21, -8'd36, -8'd13, -8'd21, 8'd17, -8'd17, -8'd27};
assign weight_matrix[14] = {-8'd8, -8'd34, -8'd31, 8'd26, -8'd10, -8'd11, -8'd43, 8'd25, 8'd9, -8'd15, 8'd27, 8'd26, -8'd35, 8'd30, -8'd42, 8'd34, -8'd38, 8'd1, -8'd11, 8'd27, -8'd23, -8'd49, -8'd32, 8'd25, -8'd17, 8'd9, 8'd12, 8'd18, 8'd12, -8'd22, -8'd24, 8'd13};
assign weight_matrix[15] = {-8'd5, -8'd11, -8'd30, 8'd34, -8'd17, -8'd44, -8'd34, -8'd2, -8'd6, -8'd6, 8'd6, -8'd17, -8'd32, -8'd25, -8'd4, -8'd34, 8'd40, 8'd9, -8'd13, -8'd78, -8'd3, -8'd46, 8'd20, -8'd38, 8'd15, -8'd16, -8'd15, -8'd39, 8'd19, 8'd18, 8'd24, 8'd11};
assign weight_matrix[16] = {8'd24, -8'd26, -8'd15, 8'd16, -8'd32, -8'd37, 8'd14, -8'd5, 8'd2, 8'd30, -8'd29, 8'd14, -8'd28, -8'd35, 8'd16, -8'd18, -8'd19, -8'd2, 8'd3, -8'd22, 8'd2, -8'd45, 8'd32, 8'd15, 8'd16, -8'd16, -8'd15, 8'd10, 8'd10, -8'd30, 8'd28, -8'd26};
assign weight_matrix[17] = {-8'd12, 8'd35, -8'd8, -8'd41, 8'd20, -8'd4, 8'd19, -8'd19, -8'd20, 8'd3, 8'd46, -8'd12, 8'd21, -8'd7, -8'd24, -8'd34, 8'd13, -8'd44, 8'd39, -8'd14, 8'd2, -8'd33, -8'd3, -8'd5, 8'd16, -8'd25, -8'd36, 8'd17, 8'd4, -8'd44, -8'd13, -8'd9};
assign weight_matrix[18] = {8'd16, 8'd4, -8'd37, -8'd39, 8'd1, 8'd21, -8'd11, 8'd15, -8'd7, -8'd26, 8'd21, -8'd30, -8'd18, -8'd33, -8'd26, 8'd25, 8'd11, -8'd8, -8'd13, -8'd22, 8'd17, -8'd41, 8'd22, 8'd38, 8'd36, -8'd42, 8'd10, 8'd17, -8'd13, -8'd9, 8'd8, -8'd15};
assign weight_matrix[19] = {8'd22, -8'd20, -8'd8, -8'd13, -8'd46, -8'd29, 8'd21, -8'd22, -8'd8, -8'd35, -8'd3, -8'd25, 8'd25, 8'd1, 8'd8, 8'd6, -8'd8, -8'd13, 8'd14, 8'd50, -8'd30, 8'd30, 8'd0, 8'd18, 8'd10, -8'd24, -8'd15, 8'd21, -8'd15, -8'd12, -8'd1, -8'd6};
assign weight_matrix[20] = {-8'd39, 8'd6, 8'd4, -8'd41, -8'd60, 8'd13, 8'd28, -8'd38, 8'd6, -8'd33, -8'd12, 8'd17, 8'd12, 8'd18, -8'd13, 8'd23, -8'd36, -8'd42, 8'd28, 8'd0, -8'd36, -8'd10, 8'd47, -8'd15, -8'd9, 8'd0, -8'd18, -8'd24, -8'd32, 8'd11, -8'd30, 8'd3};
assign weight_matrix[21] = {-8'd10, -8'd3, 8'd36, -8'd43, -8'd31, -8'd21, -8'd12, 8'd3, -8'd39, 8'd18, -8'd35, -8'd17, 8'd7, -8'd23, 8'd13, 8'd15, 8'd29, -8'd57, -8'd36, -8'd37, 8'd21, 8'd39, -8'd9, 8'd20, -8'd36, 8'd26, -8'd7, -8'd25, -8'd49, -8'd41, 8'd13, -8'd20};
assign weight_matrix[22] = {-8'd5, -8'd41, -8'd25, 8'd1, 8'd22, 8'd26, 8'd24, -8'd40, -8'd35, -8'd23, -8'd26, -8'd7, 8'd2, -8'd35, -8'd20, 8'd10, -8'd25, -8'd61, 8'd24, -8'd25, 8'd38, 8'd14, 8'd37, 8'd31, -8'd3, -8'd38, -8'd27, 8'd11, -8'd3, -8'd61, 8'd12, -8'd33};
assign weight_matrix[23] = {8'd4, 8'd33, 8'd39, -8'd38, -8'd11, -8'd42, -8'd38, -8'd11, -8'd33, 8'd21, -8'd44, -8'd23, -8'd26, -8'd12, 8'd0, -8'd22, -8'd11, -8'd27, 8'd0, -8'd57, 8'd12, -8'd26, 8'd20, 8'd25, -8'd11, -8'd15, 8'd4, 8'd15, -8'd9, -8'd17, 8'd10, -8'd20};
assign weight_matrix[24] = {-8'd35, 8'd26, -8'd3, 8'd9, -8'd57, -8'd49, -8'd10, 8'd1, -8'd26, -8'd34, -8'd4, -8'd3, -8'd29, 8'd15, -8'd23, -8'd38, 8'd6, -8'd5, -8'd30, -8'd57, 8'd39, -8'd47, 8'd32, -8'd2, -8'd39, 8'd29, 8'd16, -8'd34, -8'd4, -8'd15, 8'd25, -8'd4};
assign weight_matrix[25] = {-8'd2, -8'd25, -8'd30, -8'd38, 8'd21, 8'd16, -8'd34, 8'd5, 8'd0, 8'd25, 8'd33, 8'd35, 8'd19, 8'd6, -8'd43, -8'd15, 8'd23, -8'd61, -8'd20, -8'd86, 8'd13, 8'd28, 8'd0, 8'd5, -8'd35, 8'd3, -8'd28, -8'd25, 8'd4, -8'd3, -8'd19, -8'd37};

assign bias_vector = {-8'd22, 8'd0, 8'd0, -8'd3, -8'd10, -8'd14, -8'd14, 8'd0, 8'd3, 8'd0, -8'd6, -8'd21, 8'd0, -8'd7, -8'd17, 8'd4, 8'd0, -8'd21, -8'd1, 8'd8, -8'd10, 8'd0, -8'd8, 8'd0, 8'd0, -8'd14, 8'd0, 8'd0, -8'd31, -8'd19, -8'd17, -8'd26};

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < OUT_SIZE_1; k++) begin
                output_vector[k] <= '0;
                sum[k] <= '0;
                mult[k] <= '0;
            end
            i <= '0;
        end else begin
            for (k = 0; k < OUT_SIZE_1; k++) begin
                output_vector[k] <= output_vector_nxt[k];
                sum[k] <= sum_nxt[k];
                mult[k] <= mult_nxt[k];
            end
            i <= i_nxt;
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------

    always_comb begin
        if (i < IN_SIZE_1) begin

            // Indeks update
            i_nxt = i + 1;

            // Stage 1: Calculation sum and mult
            for (j = 0; j < OUT_SIZE_1; j++) begin
                sum_nxt[j] = output_vector[j] + bias_vector[j];
                mult_nxt[j] = input_vector[i] * weight_matrix[i][j];
            end

            // Stage 2: Update of output vector 
            for (j = 0; j < OUT_SIZE_1; j++) begin
                output_vector_nxt[j] = mult[j] + sum[j]; // Wykorzystanie zarejestrowanych wartości
            end
            
        end else begin
            // Ending condition
            i_nxt = i;
            for (j = 0; j < OUT_SIZE_1; j++) begin
                sum_nxt[j] = '0;
                mult_nxt[j] = '0;
                if (output_vector[j] < 0) 
                    output_vector_nxt[j] = 0;
                else
                    output_vector_nxt[j] = output_vector[j];
            end
        end
    end
endmodule
