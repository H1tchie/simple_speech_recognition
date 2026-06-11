//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   mean_std
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: MS_ARRAY_WIDTH24-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Calculating mean and std from mel data
 */
//////////////////////////////////////////////////////////////////////////////
 import ap_parameters::*;
module mean_std (
    input logic clk,
    input logic rst,
    input logic valid_in,
    input logic [MSIN_DATA_WIDTH-1:0] data_in [MS_ARRAY_WIDTH-1:0],
    output logic [NN_DATA_WIDTH-1:0] mean,
    output logic [NN_DATA_WIDTH-1:0] std,
    output logic valid_out
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic [MS_DATA_WIDTH-1:0] sum_nxt;
    logic [MS_DATA_WIDTH-1:0] sum_sq_nxt;
    logic [MS_DATA_WIDTH-1:0] mean_nxt;
    logic [MS_DATA_WIDTH-1:0] variance_nxt;
    logic [MSIN_DATA_WIDTH-1:0] stddev_nxt;
    logic [MSIN_DATA_WIDTH-1:0] guess, guess_next;
    logic [MSIN_DATA_WIDTH-1:0] i;
    logic valid_nxt;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
    always_ff @(posedge clk ) begin
        if (rst) begin
            valid_out  <= 0;
            mean <= 0;
            std <= 0;
        end else begin
            mean <= mean_nxt[MSIN_DATA_WIDTH-1:0];    
            std <= stddev_nxt; 
            valid_out <= valid_nxt;
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
    always_comb begin
        valid_nxt = valid_in;
        sum_nxt = 0;
        sum_sq_nxt = 0;

        // Computing sum
        for (i = 0; i < MS_ARRAY_WIDTH; i = i + 1) begin
            sum_nxt = sum_nxt + data_in[i];
        end

        // computing mean
        mean_nxt = sum_nxt / MS_ARRAY_WIDTH;

        // Computing sum of squares subtraction from mean
        for (i = 0; i < MS_ARRAY_WIDTH; i = i + 1) begin
            sum_sq_nxt = sum_sq_nxt + (data_in[i] - mean_nxt) * (data_in[i] - mean_nxt);
        end

        // computing variance
        variance_nxt = sum_sq_nxt / MS_ARRAY_WIDTH;

        // computing std
        //stddev_nxt = $clog2(variance_nxt);
        // Algorithm Newtona-Raphsona fully combitional
        guess = variance_nxt >> 1;  // First approximation

        for (i = 0; i < 2; i = i + 1) begin
                guess_next = (guess + variance_nxt / guess) >> 1;
                guess = guess_next;
                end
        stddev_nxt = guess;
    end


endmodule
