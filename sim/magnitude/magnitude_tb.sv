`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   magnitude_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       2.2
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for computing the magnitude
 */
//////////////////////////////////////////////////////////////////////////////


module magnitude_tb;

//------------------------------------------------------------------------------
// Testbench parameters
//------------------------------------------------------------------------------

parameter FFT_DATA_WIDTH = 16;    // Bit width for real and imaginary parts
parameter MEL_DATA_WIDTH = 32;    // Bit width for the magnitude result

//------------------------------------------------------------------------------
// Testbench signals
//------------------------------------------------------------------------------

reg clk;                         // Clock signal
reg rst;                         // Reset signal
reg [FFT_DATA_WIDTH-1:0] real_part;  // Input real part
reg [FFT_DATA_WIDTH-1:0] imag_part;  // Input imaginary part
wire [MEL_DATA_WIDTH-1:0] magnitude; // Output magnitude result

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------

magnitude uut (
    .clk(clk), 
    .rst(rst), 
    .real_part(real_part), 
    .imag_part(imag_part), 
    .magnitude(magnitude)
);
//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------

always #5 clk = ~clk; // 100 MHz clock (10 ns period)

//------------------------------------------------------------------------------
// Testbench logic
//------------------------------------------------------------------------------

initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    real_part = 0;
    imag_part = 0;
    // Reset the DUT
    #10 rst = 0;
    #10 rst = 1;
    rst = 0;
    //------------------------------------------------------------------------------
    // Apply test vectors
    //------------------------------------------------------------------------------
    
    // Test case 1: real_part = 3, imag_part = 4 (Expected magnitude = 5)
    real_part = 16'd3;
    imag_part = 16'd4;
    #10; // Wait for a few clock cycles
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;// Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 2: real_part = 5, imag_part = 12 (Expected magnitude = 13)
    real_part = 16'd5;
    imag_part = 16'd12;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 3: real_part = 8, imag_part = 15 (Expected magnitude = 17)
    real_part = 16'd8;
    imag_part = 16'd15;
    #10;
    // Test case 4: real_part = 0, imag_part = 0 (Expected magnitude = 0)
    real_part = 16'd0;
    imag_part = 16'd0;
    #10;

    $finish;
end
//------------------------------------------------------------------------------
// Monitor the output
//------------------------------------------------------------------------------
always @(posedge clk) begin
    $display("Time: %0t | real_part: %0d | imag_part: %0d | magnitude: %0d", $time, real_part, imag_part, magnitude);
end
endmodule