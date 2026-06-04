//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   final_layer
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       4.1
 Description:   Argmax z 3 logitow -> kod 2-bit (0->01, 1->10, 2->00).
                Wejscie packed: [OUT_SIZE_2*DATA_WIDTH_2-1:0].
                Zatrzask na start; done 1 takt pozniej.
*/
//////////////////////////////////////////////////////////////////////////////

import nn_parameters::*;

module final_layer (
    input  logic                                clk,
    input  logic                                rst,
    input  logic                                start,
    input  logic [OUT_SIZE_2*DATA_WIDTH_2-1:0]  input_bus,
    output logic [DATA_WIDTH_FINAL-1:0]         output_value,
    output logic                                done
);
    logic signed [DATA_WIDTH_2-1:0] l [OUT_SIZE_2-1:0];
    always_comb
        for (int k = 0; k < OUT_SIZE_2; k++)
            l[k] = input_bus[k*DATA_WIDTH_2 +: DATA_WIDTH_2];

    logic [1:0] code_nxt;
    always_comb begin
        if (l[0] >= l[1] && l[0] >= l[2]) code_nxt = 2'b01;
        else if (l[1] >= l[2])            code_nxt = 2'b10;
        else                              code_nxt = 2'b00;
    end

    always_ff @(posedge clk) begin
        if (rst) begin output_value <= '0; done <= 1'b0; end
        else begin
            done <= start;
            if (start) output_value <= code_nxt;
        end
    end
endmodule
