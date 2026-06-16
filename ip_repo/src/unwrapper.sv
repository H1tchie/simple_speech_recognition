//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   unwrapper
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Uncombine data from frames to simple wire for FFT performance
 */
//////////////////////////////////////////////////////////////////////////////
import ap_parameters::*;
module unwrapper(
    input logic clk,
    input logic rst,
    input logic [ADC_DATA_WIDTH-1:0] in [FRAME_ARRAY_WIDTH-1:0],
    input logic window_ready,
    output logic wrapper_ready,
    output logic [ADC_DATA_WIDTH-1:0] out 
    );

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic [ADC_DATA_WIDTH-1:0] out_nxt;
    logic [ADC_DATA_WIDTH-1:0] regi [FRAME_ARRAY_WIDTH-1:0];
    logic [ADC_DATA_WIDTH-1:0] regi_nxt [FRAME_ARRAY_WIDTH-1:0];
    logic wrapper_ready_nxt;
    logic [ADC_DATA_WIDTH-1:0] j;
    logic [ADC_DATA_WIDTH-1:0] j_nxt;
    integer i,k ;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if(rst) begin
            out <= '0;
            for(k=0; k<FRAME_ARRAY_WIDTH; k++)begin
            regi[k] <= '0;
            end
            j <= '0;
            wrapper_ready <= '0;
            end else begin
            out <= out_nxt;
            for(k=0; k<FRAME_ARRAY_WIDTH; k++)begin
            regi[k] <= regi_nxt[k];
            end
            wrapper_ready <= wrapper_ready_nxt;
            j <= j_nxt;
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
    always_comb begin
        if(window_ready & j < FRAME_ARRAY_WIDTH) begin
            for(i=0; i<FRAME_ARRAY_WIDTH; i++)
            regi_nxt[i] = in[i];
            out_nxt = regi[j];
            wrapper_ready_nxt = 1;
            j_nxt = j + 1;
        end else begin
        for(i=0; i<FRAME_ARRAY_WIDTH; i++)
        regi_nxt[i] = regi[i];
        out_nxt = out;
        wrapper_ready_nxt = '0;
        j_nxt = '0;
        end
    end
endmodule