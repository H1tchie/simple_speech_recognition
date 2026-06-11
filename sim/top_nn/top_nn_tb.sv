`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   led_nn_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for neural network top module
 */
//////////////////////////////////////////////////////////////////////////////

module top_nn_tb;

    // Parameters
    localparam IN_SIZE = 26;  


    // Testbench signals
    logic signed [15:0] input_vector [IN_SIZE-1:0];  // Unpacked array
    logic [1:0] output_value;  
    logic clk;
    logic rst;
    // Instantiate the top_nn module
    top_nn uut (
        .input_vector(input_vector),
        .output_value(output_value),
        .clk(clk),
        .rst(rst)
    );
    always #5 clk = ~clk;
    // Stimulus process
    initial begin
        clk = 0;
        rst = 0;

        #1000;
        rst = 1;
        #1000;
        rst = 0;
        // Initialize input_vector with values from a preprocessed WAV file(can choose from: input_vector***.mem ***-oth[],on[],off[])
        $readmemh("../python/generated_files/input_vectoroth.mem", input_vector);

        // Wait for some time to observe output

        #300000;
        // Display intermediate and output probabilities
        $display(" output_value: %p;; 0-nothing, 1-on, 2-off", output_value);

        // Finish simulation
        $stop;
    end

endmodule
