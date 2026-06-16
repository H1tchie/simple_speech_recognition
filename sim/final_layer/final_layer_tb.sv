`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   final_layer_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.1
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  test bench for final layer of neural network
 */
//////////////////////////////////////////////////////////////////////////////
module final_layer_tb;

    // Parameters for the testbench (these should match the values in your `nn_parameters` package)
      // Example input size
    parameter OUT_SIZE_4 = 3;  // Example output size

    // Testbench signals
    logic clk;
    logic rst;
    logic signed [31:0] input_vector [OUT_SIZE_4-1:0];
    logic [1:0] output_value ;
    

    // Instantiate the module under test (MUT)
    final_layer mut (
        .input_vector(input_vector),
        .output_value(output_value),
        .clk(clk),
        .rst(rst)
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
        input_vector = '{40'd500, 40'd300000, 40'd2000000};

        // Wait for the combinational logic to process the inputs
        #30000;

        // Display the results
        $display("Input Vector: %p", input_vector);
        $display(" output_value: %p", output_value);
        
        // End the simulation
        $stop;
    end

endmodule
