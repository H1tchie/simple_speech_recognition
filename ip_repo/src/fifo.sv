//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   fifo
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Simple fifo which combine data into arrays. And start reading by the oldest data.
 */
//////////////////////////////////////////////////////////////////////////////
import ap_parameters::*;
module fifo (
    input  logic clk,
    input  logic rst,
    input  logic valid,          
    input  logic [NN_DATA_WIDTH-1:0] data_in1, 
    input  logic [NN_DATA_WIDTH-1:0] data_in2, 
    output logic [NN_DATA_WIDTH-1:0] data_out [NN_ARRAY_WIDTH-1:0] 
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic [NN_DATA_WIDTH-1:0] fifo_mem [NN_ARRAY_WIDTH:0];
//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NN_ARRAY_WIDTH; i++) begin
                data_out[i] <= 16'h0000;
            end
        end else  begin
            for (int i = 0; i < NN_ARRAY_WIDTH; i++) begin
                data_out[i] <= fifo_mem[i];
            end
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
    always_comb begin
            if (valid) begin
            // Save first data to fifo
            fifo_mem[0] = data_in1;
            // Save second data to fifo
            fifo_mem[1] = data_in2;
            for (int i = 2; i < NN_ARRAY_WIDTH; i++) begin
                fifo_mem[i] = data_out [i-2];
            end
        end else begin
            for (int i = 0; i < NN_ARRAY_WIDTH; i++) begin
                fifo_mem[i] = data_out[i];
            end
        end
    end



endmodule