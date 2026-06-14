//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   magnitude
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.7
 Last modified: 2024-08-30
 Coding style: safe, with FPGA sync reset
 Description:  Calculating magnitude from real part and imaginaris part of fft
 */
//////////////////////////////////////////////////////////////////////////////
import ap_parameters::*;
module magnitude(
    input logic clk,
    input logic rst,
    input  logic [FFT_DATA_WIDTH-1:0] real_part,   // 16-bitowa część rzeczywista
    input  logic [FFT_DATA_WIDTH-1:0] imag_part,   // 16-bitowa część urojona
    output logic [MEL_DATA_WIDTH-1:0] magnitude    // 32-bitowy wynik (moduł)
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic [MEL_DATA_WIDTH-1:0] real_squared;
    logic [MEL_DATA_WIDTH-1:0] imag_squared;
    logic [MEL_DATA_WIDTH-1:0] sum_squares, sum_squares1, sum_squares2;
    logic [MEL_DATA_WIDTH-1:0] real_squared_nxt;
    logic [MEL_DATA_WIDTH-1:0] imag_squared_nxt;
    logic [MEL_DATA_WIDTH-1:0] sum_squares_nxt,sum_squares_nxt1,sum_squares_nxt2;
    logic [MEL_DATA_WIDTH-1:0] magnitude_nxt;
    logic [MEL_DATA_WIDTH-1:0] x0;  // approximation of root
    logic [MEL_DATA_WIDTH-1:0] x0_nxt;
    logic [MEL_DATA_WIDTH-1:0] x1; // next approximation
    logic [MEL_DATA_WIDTH-1:0] x1_nxt;
    logic [MEL_DATA_WIDTH-1:0] x2;
    logic [MEL_DATA_WIDTH-1:0] x2_nxt;
    //logic [MEL_DATA_WIDTH-1:0] x3;
    //logic [MEL_DATA_WIDTH-1:0] x3_nxt;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
    always_ff@(posedge clk) begin
        if (rst) begin
            magnitude <= '0;
            real_squared <= '0;
            imag_squared <= '0;
            sum_squares <= '0;
            sum_squares1 <= '0;
            sum_squares2 <= '0;
            x0 <= '0;
            x1 <= '0;
            x2 <= '0;
            //x3 <= '0;
        end else begin
            magnitude <= magnitude_nxt;
            real_squared <= real_squared_nxt;
            imag_squared <= imag_squared_nxt;
            sum_squares <= sum_squares_nxt;
            sum_squares1 <= sum_squares_nxt1;
            sum_squares2 <= sum_squares_nxt2;
            x0 <= x0_nxt;
            x1 <= x1_nxt;
            x2 <= x2_nxt;
            //x3 <= x3_nxt;
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------j
    always_comb begin
        if( real_part == 0 && imag_part == 0) begin
            magnitude_nxt = '0;
            real_squared_nxt = real_squared;
            imag_squared_nxt = imag_squared;
            sum_squares_nxt = sum_squares;
            sum_squares_nxt1 = sum_squares1;
            sum_squares_nxt2 = sum_squares2;
            x0_nxt = x0;
            x1_nxt = x1;
            x2_nxt = x2;
            //x3_nxt = x3;
        end else if(real_part == 0) begin
            magnitude_nxt = {16'h0, imag_part};
            real_squared_nxt = real_squared;
            imag_squared_nxt = imag_squared;
            sum_squares_nxt = sum_squares;
            sum_squares_nxt1 = sum_squares1;
            sum_squares_nxt2 = sum_squares2;
            x0_nxt = x0;
            x1_nxt = x1;
            x2_nxt = x2;
            //x3_nxt = x3;
        end else if(imag_part == 0) begin
            magnitude_nxt = {16'h0, real_part};
            real_squared_nxt = real_squared;
            imag_squared_nxt = imag_squared;
            sum_squares_nxt = sum_squares;
            sum_squares_nxt1 = sum_squares1;
            sum_squares_nxt2 = sum_squares2;
            x0_nxt = x0;
            x1_nxt = x1;
            x2_nxt = x2;
            //x3_nxt = x3;
        end else begin
            real_squared_nxt = real_part * real_part;
            imag_squared_nxt = imag_part * imag_part;
            sum_squares_nxt  = real_squared + imag_squared;
            sum_squares_nxt1 = sum_squares;
            sum_squares_nxt2 = sum_squares1;
            // Newton-Raphson Iterative Process
            x0_nxt = sum_squares;                                                           //do poprawy sum_square w kazdej linijce czyli iteracji musi byc inne czyli trzeba dodac sum square next 1 2 3
            x1_nxt = (x0 + (sum_squares1 / x0)) >> 1;  // Iteration 1
            x2_nxt = (x1 + (sum_squares2 / x1)) >> 1;  // Iteration 2
            magnitude_nxt = x2;  // Final value after iterations
        end
    end

endmodule