`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   desne_layer_2_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for second layer of neural network
 */
//////////////////////////////////////////////////////////////////////////////
module dense_layer_2_tb;

    // Parameters for the testbench (these should match the values in your `nn_parameters` package)
    parameter IN_SIZE_2 = 32;  // Example input size
    parameter OUT_SIZE_2 = 3;  // Example output size

    // Testbench signals
    logic clk;
    logic rst;
    logic signed [23:0] input_vector [IN_SIZE_2-1:0];
    logic signed [31:0] output_vector [OUT_SIZE_2-1:0];

    // Instantiate the module under test (MUT)
    dense_layer_2 mut (
        .clk(clk),
        .rst(rst),
        .input_vector(input_vector),
        .output_vector(output_vector)
    );
    always #5 clk = ~clk;
    initial begin
        clk = 0;
        rst = 0;

        #1000;
        rst = 1;
        #1000;
        rst = 0;
        // Initialize input vector with some values
        $readmemh("../python/generated_files/in_dp1_hex.txt", input_vector);

        // Wait for the combinational logic to process the inputs
        #300000;
        // Display the results
        // Display the results
        $display("Input Vector: %p", input_vector);
        for (int j = 0; j < OUT_SIZE_2; j++) begin
            $display("output_vector[%0d]: %0d", j, output_vector[j]);
        end
        // End the simulation
        $stop;
        end


endmodule
