//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_nn_axis
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       2.0
 Description:   Wrapper AXI4-Stream dla sieci top_nn.
                - bufuje N_FEATURES=26 wartosci ze strumienia wejsciowego
                - po skompletowaniu wektora daje puls start do top_nn
                - czeka na done (czysty uchwyt, bez zgadywania latencji)
                - wystawia 2-bit wynik jako 1 transakcje AXI4-Stream master
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;
import nn_parameters::*;

module top_nn_axis (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic signed [SAMPLE_WIDTH-1:0] s_axis_tdata,
    input  logic                           s_axis_tvalid,
    output logic                           s_axis_tready,
    input  logic                           s_axis_tlast,
    output logic [SAMPLE_WIDTH-1:0]        m_axis_tdata,
    output logic                           m_axis_tvalid,
    input  logic                           m_axis_tready,
    output logic                           m_axis_tlast
);
    localparam int FEAT_W_IDX = $clog2(N_FEATURES);

    logic signed [15:0] features [IN_SIZE_1-1:0];
    logic [FEAT_W_IDX:0] feat_idx;

    typedef enum logic [1:0] {
        S_COLLECT = 2'd0, S_START = 2'd1, S_WAIT = 2'd2, S_OUTPUT = 2'd3
    } state_t;
    state_t state;
    logic       nn_start, nn_done;
    logic [1:0] nn_value;

    assign s_axis_tready = (state == S_COLLECT);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_COLLECT; feat_idx <= '0; nn_start <= 1'b0;
            m_axis_tvalid <= 1'b0; m_axis_tdata <= '0; m_axis_tlast <= 1'b0;
            for (int i = 0; i < IN_SIZE_1; i++) features[i] <= '0;
        end else begin
            nn_start <= 1'b0;
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0; m_axis_tlast <= 1'b0;
            end
            case (state)
                S_COLLECT: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        features[feat_idx[FEAT_W_IDX-1:0]] <= s_axis_tdata;
                        if (s_axis_tlast || feat_idx == N_FEATURES-1) begin
                            feat_idx <= '0; state <= S_START;
                        end else feat_idx <= feat_idx + 1'b1;
                    end
                end
                S_START: begin nn_start <= 1'b1; state <= S_WAIT; end
                S_WAIT:  begin if (nn_done) state <= S_OUTPUT; end
                S_OUTPUT: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        m_axis_tdata  <= {14'd0, nn_value};
                        m_axis_tvalid <= 1'b1; m_axis_tlast <= 1'b1;
                        state <= S_COLLECT;
                    end
                end
                default: state <= S_COLLECT;
            endcase
        end
    end

    logic [IN_SIZE_1*16-1:0] feat_bus;
    always_comb
        for (int k = 0; k < IN_SIZE_1; k++)
            feat_bus[k*16 +: 16] = features[k];

    top_nn u_top_nn (
        .clk(clk), .rst(~rst_n), .start(nn_start),
        .input_bus(feat_bus), .output_value(nn_value), .done(nn_done)
    );
endmodule
