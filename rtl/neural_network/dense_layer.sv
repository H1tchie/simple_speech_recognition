//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   dense_layer
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       4.1  (poprawiona sciezka MAC + porty packed)
 Last modified: 2026-01
 Description:   W pelni sekwencyjna, deterministyczna warstwa gesta:
                   out[j] = activation( sum_i in[i]*W[i][j] + bias[j] )
                Zmiany vs 3.x:
                 - poprawna sciezka MAC: dokladnie iloczyn skalarny + jeden
                   bias (poprzednio bias akumulowal sie co takt, a potok
                   gubil ostatni skladnik),
                 - czytelny uchwyt start/done,
                 - PORTY SPLASZCZONE do wektorow packed (input_bus/output_bus);
                   unpacked array na porcie nie propaguje sie przez polaczenie
                   w iverilogu. Element k zajmuje bity [k*WIDTH +: WIDTH].
                Akumulacja w ACC_WIDTH=48, na koncu saturacja do OUT_WIDTH
                i opcjonalny ReLU (USE_RELU). Wagi/biasy z .mem (int8 hex):
                  - weights row-major, index = i*OUT_SIZE + j ; bias OUT_SIZE
*/
//////////////////////////////////////////////////////////////////////////////

import nn_parameters::*;

module dense_layer #(
    parameter int    IN_SIZE     = 26,
    parameter int    OUT_SIZE    = 32,
    parameter int    IN_WIDTH    = 16,
    parameter int    OUT_WIDTH   = 24,
    parameter int    USE_RELU    = 1,
    parameter string WEIGHT_FILE = "dense1_weights.mem",
    parameter string BIAS_FILE   = "dense1_bias.mem"
) (
    input  logic                           clk,
    input  logic                           rst,
    input  logic                           start,
    input  logic [IN_SIZE*IN_WIDTH-1:0]    input_bus,
    output logic [OUT_SIZE*OUT_WIDTH-1:0]  output_bus,
    output logic                           done
);

    localparam int ACC_WIDTH = 48;
    localparam int IDX_W      = $clog2(IN_SIZE + 1);

    logic signed [IN_WIDTH-1:0] in_v [IN_SIZE-1:0];
    always_comb
        for (int k = 0; k < IN_SIZE; k++)
            in_v[k] = input_bus[k*IN_WIDTH +: IN_WIDTH];

    logic signed [WB_WIDTH-1:0] weight_mem [0:IN_SIZE*OUT_SIZE-1];
    logic signed [WB_WIDTH-1:0] bias_mem   [0:OUT_SIZE-1];
    initial begin
        $readmemh(WEIGHT_FILE, weight_mem);
        $readmemh(BIAS_FILE,   bias_mem);
    end

    typedef enum logic [1:0] {
        S_IDLE = 2'd0, S_MAC = 2'd1, S_FINISH = 2'd2, S_DONE = 2'd3
    } state_t;

    state_t state;
    logic [IDX_W-1:0]            idx;
    logic signed [ACC_WIDTH-1:0] acc   [OUT_SIZE-1:0];
    logic signed [OUT_WIDTH-1:0] out_v [OUT_SIZE-1:0];

    always_comb
        for (int k = 0; k < OUT_SIZE; k++)
            output_bus[k*OUT_WIDTH +: OUT_WIDTH] = out_v[k];

    logic signed [ACC_WIDTH-1:0] withb;
    localparam logic signed [ACC_WIDTH-1:0] OUT_HI = (48'sd1 <<< (OUT_WIDTH-1)) - 48'sd1;
    localparam logic signed [ACC_WIDTH-1:0] OUT_LO = -(48'sd1 <<< (OUT_WIDTH-1));

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; done <= 1'b0; idx <= '0;
            for (int j = 0; j < OUT_SIZE; j++) begin
                acc[j] <= '0; out_v[j] <= '0;
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        for (int j = 0; j < OUT_SIZE; j++) acc[j] <= '0;
                        idx <= '0; state <= S_MAC;
                    end
                end
                S_MAC: begin
                    for (int j = 0; j < OUT_SIZE; j++)
                        acc[j] <= acc[j] + $signed(in_v[idx]) *
                                  $signed(weight_mem[idx*OUT_SIZE + j]);
                    if (idx == IN_SIZE-1) state <= S_FINISH;
                    else                  idx <= idx + 1'b1;
                end
                S_FINISH: begin
                    for (int j = 0; j < OUT_SIZE; j++) begin
                        withb = acc[j] + $signed(bias_mem[j]);
                        if (USE_RELU != 0 && withb < 0) out_v[j] <= '0;
                        else if (withb > OUT_HI)        out_v[j] <= OUT_HI[OUT_WIDTH-1:0];
                        else if (withb < OUT_LO)        out_v[j] <= OUT_LO[OUT_WIDTH-1:0];
                        else                            out_v[j] <= withb[OUT_WIDTH-1:0];
                    end
                    state <= S_DONE;
                end
                S_DONE: begin done <= 1'b1; state <= S_IDLE; end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
