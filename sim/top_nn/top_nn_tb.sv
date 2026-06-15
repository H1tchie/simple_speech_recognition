`timescale 1ns/1ps
module top_nn_tb;
    localparam IN_SIZE = 26;  

    logic signed [15:0] input_vector [IN_SIZE-1:0];
    logic [1:0] output_value;  
    logic clk, rst;

    top_nn uut (
        .clk,
        .rst,
        .input_vector(input_vector),
        .output_value(output_value)
    );

    always #5 clk = ~clk;

    task automatic run_test(input string mem_file, input string label);
        // Zeruj input
        for (int i = 0; i < IN_SIZE; i++) 
            input_vector[i] = '0;
        
        // Trzymaj reset
        rst = 1;
        #1000;
        
        // Zaladuj dane PODCZAS resetu
        $readmemh(mem_file, input_vector);
        #100;
        
        // Dopiero teraz zwolnij reset - siec startuje z poprawnymi danymi
        rst = 0;
        
        #300000;
        $display("output_value: %0d (0=other, 1=on, 2=off) <- %s", output_value, label);
        $display("---");
    endtask

    initial begin
        clk = 0;
        rst = 0;
        for (int i = 0; i < IN_SIZE; i++) 
            input_vector[i] = '0;
        #100;

        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoron_0.mem",  "ON_BAD  -> oczekiwane 1");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoron_1.mem",  "ON_GOOD  -> oczekiwane 1");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoron_2.mem",  "ON_BAD  -> oczekiwane 1");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoroff_0.mem", "OFF_BAD -> oczekiwane 2");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoroff_5.mem", "OFF_GOOD -> oczekiwane 2");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoroth_15.mem", "OTH_GOOD -> oczekiwane 0");
        run_test("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/input_vectoroth_16.mem", "OTH_BAD -> oczekiwane 0");
      

        $stop;
    end
endmodule
