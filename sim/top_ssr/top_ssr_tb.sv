`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for top module of ssr
 */
//////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module top_ssr_tb;

//------------------------------------------------------------------------------
// Local variables
//------------------------------------------------------------------------------

logic clk;
logic rst;
logic but;
wire scl;  
wire sda;  
logic led0;

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------

always #5 clk = ~clk;  // 100 MHz clock

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------

top_ssr uut (
    .clk(clk),
    .rst(rst),
    .but(but),
    .scl(scl),
    .sda(sda),
    .led0(led0)
);

//------------------------------------------------------------------------------
// Testbench sequence
//------------------------------------------------------------------------------

initial begin
    // Initialize signals
    clk = 0;
    rst = 0;
    but = 0;

    // Apply reset
    #10;
    rst = 1;

    // Deassert reset
    #20;
    rst = 0;

    // Simulate I2C activity on scl and sda
    #30;
    i2c_write(8'hA5);  // Example I2C transaction

    // Simulate button press
    #50;
    but = 1;
    #10;
    but = 0;

    // Wait for some time to observe behavior
    #100;

    // Check the LED output
    $display("LED output: %b", led0);

    // End simulation
    $finish;
end

//------------------------------------------------------------------------------
// Task to simulate I2C Write Operation
//------------------------------------------------------------------------------

task i2c_write(input [7:0] data_byte);
    integer i;
    begin
        // Start condition (SDA goes low while SCL is high)
        force sda = 0;
        #10;
        force scl = 0;

        // Send byte (MSB first)
        for (i = 7; i >= 0; i = i - 1) begin
            force scl = 0;
            #5;
            force sda = data_byte[i];  // Set data bit
            #5;
            force scl = 1; // Clock the data bit
            #10;
        end

        // Acknowledge bit (release SDA and check if it gets pulled low)
        force scl = 0;
        #5;
        release sda; // Release SDA
        #5;
        force scl = 1;
        #10;
        
        // Stop condition (SDA goes high while SCL is high)
        force scl = 0;
        #5;
        force sda = 0;
        #5;
        force scl = 1;
        #5;
        force sda = 1;  // SDA high (stop condition)
        #10;
        release scl;
        release sda;
    end
endtask

endmodule
