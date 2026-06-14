//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   final_layer
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       3.4
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  final layer of neural network
 */
//////////////////////////////////////////////////////////////////////////////

import nn_parameters::*;

module final_layer (
    input clk,
    input rst,
    input logic signed [DATA_WIDTH_2-1:0] input_vector [OUT_SIZE_2-1:0],
    output logic [DATA_WIDTH_FINAL-1:0] output_value
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

logic [1:0] output_value_nxt ;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------

always_ff @(posedge clk) begin
    if(rst) begin
        output_value <= '0;
    end else begin
        output_value <= output_value_nxt;
    end
end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------

always_comb begin
        if(input_vector[0] > input_vector[1] && input_vector[0] > input_vector[2]) 
            output_value_nxt = 2'b01;
        else if(input_vector[2] > input_vector[0] && input_vector[2] > input_vector[1])
            output_value_nxt = 2'b00;
        else  
            output_value_nxt = 2'b10;
                  
end

endmodule