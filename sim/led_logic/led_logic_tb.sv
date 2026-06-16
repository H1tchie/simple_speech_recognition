`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   led_logic_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for test control
 */
//////////////////////////////////////////////////////////////////////////////

module led_logic_tb;

//------------------------------------------------------------------------------
// Local variables
//------------------------------------------------------------------------------

logic clk;
logic rst;
logic [1:0] speech_rec;
logic but;
logic led0;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------

led_logic uut (
    .clk(clk),
    .rst(rst),
    .speech_rec(speech_rec),
    .but(but),
    .led0(led0)
);

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------

always #5 clk = ~clk; // 100MHz clock

//------------------------------------------------------------------------------
// Testbench logic
//------------------------------------------------------------------------------

initial begin
    // Initialize signals
    clk = 0;
    rst = 0;
    speech_rec = 2'b00;
    but = 0;
    
    // Apply reset
    rst = 1;
    #10;
    rst = 0;

    // Test Case 1: Initial state after reset
    // Expected: led0 = 0
    #10;
    assert(led0 == 1'd0) else $error("Test Case 1 failed");

    // Test Case 2: Button pressed, speech_rec = 01 (turn on LED)
    // Expected: led0 = 1
    but = 1;
    speech_rec = 2'b01;
    #10;
    assert(led0 == 1'd1) else $error("Test Case 2 failed");

    // Test Case 3: Button pressed, speech_rec = 10 (turn off LED)
    // Expected: led0 = 0
    speech_rec = 2'b10;
    #10;
    assert(led0 == 1'd0) else $error("Test Case 3 failed");

    // Test Case 4: Button pressed, speech_rec = 00 (no change)
    // Expected: led0 = 0
    speech_rec = 2'b00;
    #10;
    assert(led0 == 1'd0) else $error("Test Case 4 failed");

    // Test Case 5: Button released, speech_rec = 01 (no change because button not pressed)
    // Expected: led0 = 0
    but = 0;
    speech_rec = 2'b01;
    #10;
    assert(led0 == 1'd0) else $error("Test Case 5 failed");

    // Test Case 6: Button pressed, speech_rec = 01 (turn on LED)
    // Expected: led0 = 1
    but = 1;
    #10;
    assert(led0 == 1'd1) else $error("Test Case 6 failed");

    // Test Case 7: Assert reset during operation
    // Expected: led0 = 0
    rst = 1;
    #10;
    assert(led0 == 1'd0) else $error("Test Case 7 failed");

    $display("All test cases passed.");
    $finish;
end

endmodule