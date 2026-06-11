`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ap_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.2
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for audio processing top module
 */
//////////////////////////////////////////////////////////////////////////////
 import ap_parameters::*;
module top_ap_tb;

//------------------------------------------------------------------------------
// Parameters
//------------------------------------------------------------------------------
    parameter DATA_WIDTH = 12; // ADC is 12-bit
    parameter DATA_FILE = "../python/generated_files/input_adcoff2.txt"; // File containing the ADC-like data

//------------------------------------------------------------------------------
// Testbench signals
//------------------------------------------------------------------------------
    reg clk;
    reg rst;
    reg [DATA_WIDTH-1:0] adc_data;
    wire signed [15:0] output_vector [0:25]; // Output from the module under test

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------
    top_ap uut (
        .clk(clk),
        .rst(rst),
        .adc_data(adc_data),
        .output_vector(output_vector)
    );

//------------------------------------------------------------------------------
// Clock generation
//------------------------------------------------------------------------------
    always #5 clk = ~clk; // 100 MHz clock

//------------------------------------------------------------------------------
// Testbench logic
//------------------------------------------------------------------------------
    initial begin
        integer data_file;
        integer scan_result;
        reg [DATA_WIDTH-1:0] data;
        
        // Initialize
        clk = 0;
        rst = 1;
        adc_data = 0;
        
        // Reset pulse
        #10 rst = 0;
        #10 rst = 1;
        rst = 0;

        // Open data file
        data_file = $fopen(DATA_FILE, "r");
        if (data_file == 0) begin
            $display("Error: could not open file %s", DATA_FILE);
            $finish;
        end
        
        // Read and apply data
        while (!$feof(data_file)) begin
            scan_result = $fscanf(data_file, "%h\n", data);
            adc_data = data;
            #10; // Wait for a few clock cycles to simulate processing time
        end
        
        $fclose(data_file);
        #10; // Wait to capture final outputs
        $finish;
    end

    // Capture and display the processed data
    always @(posedge clk) begin
        if (rst) begin
            $display("Time: %0t, ADC Data: %0h", $time, adc_data);
            $monitor("Output Vector: %p", output_vector);
        end
    end

endmodule
