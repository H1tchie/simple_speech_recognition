`timescale 1ns/1ps
// Walidacja top_nn (porty packed) vs model Pythona.
import nn_parameters::*;
module tb_nn_validate;
    localparam int NVEC = 12;
    logic clk = 0, rst, start, done;
    logic [IN_SIZE_1*16-1:0] input_bus;
    logic [1:0] out_code;
    always #5 clk = ~clk;
    top_nn dut (.clk, .rst, .start, .input_bus(input_bus),
                .output_value(out_code), .done(done));
    logic [15:0] vmem [0:NVEC*26-1];
    int fout, r, c;
    initial begin
        $readmemh("/tmp/nn_test_vectors.mem", vmem);
        fout = $fopen("/tmp/nn_rtl_out.txt","w");
        rst = 1; start = 0; input_bus = '0;
        repeat (6) @(posedge clk); rst = 0; @(posedge clk);
        for (r = 0; r < NVEC; r++) begin
            for (c = 0; c < 26; c++) input_bus[c*16 +: 16] = vmem[r*26 + c];
            @(posedge clk); start = 1; @(posedge clk); start = 0;
            do @(posedge clk); while (!done);
            @(posedge clk);
            $fwrite(fout, "%0d\n", out_code);
        end
        $fclose(fout); $finish;
    end
    initial begin #400us; $display("TIMEOUT"); $finish; end
endmodule
