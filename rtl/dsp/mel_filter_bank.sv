//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   mel_filter_bank
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Aplikuje N_MELS=26 trojkatnych filtrow Mel na widmie
                amplitudowym |X[k]|.

                Strategia: kazda probka wejsciowa |X[k]| aktualizuje
                wszystkie N_MELS akumulatorow (jeden cykl na filtr).
                Po otrzymaniu tlast wystawia N_MELS energii po kolei,
                jedna na takt (gdy m_axis_tready=1), z tlast na ostatniej.

                Wspolczynniki: dense ROM z tools/gen_mel_filterbank.py
                (Q1.15 unsigned, [N_MELS x N_BINS]).
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module mel_filter_bank #(
    parameter string COEFF_FILE = "mel_bank_dense.mem"
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // wejscie - |X[k]|
    input  logic [SAMPLE_WIDTH-1:0]    s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,
    input  logic [15:0]                s_axis_tuser,

    // wyjscie - N_MELS energii
    output logic [MEL_ACC_WIDTH-1:0]   m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast,
    output logic [15:0]                m_axis_tuser
);

    localparam int BIN_W = $clog2(N_BINS);
    localparam int MEL_W = $clog2(N_MELS);

    logic [SAMPLE_WIDTH-1:0] mel_rom [0:N_MELS*N_BINS-1];
    initial begin
        $readmemh(COEFF_FILE, mel_rom);
    end

    logic [MEL_ACC_WIDTH-1:0] accum [0:N_MELS-1];

    typedef enum logic [1:0] {
        S_IDLE   = 2'd0,
        S_ACCUM  = 2'd1,
        S_OUTPUT = 2'd2,
        S_CLEAR  = 2'd3
    } state_t;

    state_t state;
    logic [BIN_W-1:0] bin_idx;
    logic [MEL_W:0]   mel_idx;
    logic [15:0]      pending_frame_id;
    logic             frame_last_seen;
    logic [SAMPLE_WIDTH-1:0] x_latched;

    assign s_axis_tready = (state == S_IDLE);

    logic [2*SAMPLE_WIDTH-1:0] product;
    assign product = x_latched * mel_rom[mel_idx[MEL_W-1:0] * N_BINS + bin_idx];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            bin_idx          <= '0;
            mel_idx          <= '0;
            pending_frame_id <= '0;
            frame_last_seen  <= 1'b0;
            m_axis_tvalid    <= 1'b0;
            m_axis_tdata     <= '0;
            m_axis_tlast     <= 1'b0;
            m_axis_tuser     <= '0;
            x_latched        <= '0;
            for (int i = 0; i < N_MELS; i++) accum[i] <= '0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        x_latched        <= s_axis_tdata;
                        pending_frame_id <= s_axis_tuser;
                        frame_last_seen  <= s_axis_tlast;
                        mel_idx          <= '0;
                        state            <= S_ACCUM;
                    end
                end

                S_ACCUM: begin
                    accum[mel_idx[MEL_W-1:0]] <=
                        accum[mel_idx[MEL_W-1:0]] + (product >> 15);
                    if (mel_idx == N_MELS-1) begin
                        mel_idx <= '0;
                        if (frame_last_seen) begin
                            state   <= S_OUTPUT;
                            bin_idx <= '0;
                        end else begin
                            bin_idx <= bin_idx + 1'b1;
                            state   <= S_IDLE;
                        end
                    end else begin
                        mel_idx <= mel_idx + 1'b1;
                    end
                end

                S_OUTPUT: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        m_axis_tdata  <= accum[mel_idx[MEL_W-1:0]];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (mel_idx == N_MELS-1);
                        m_axis_tuser  <= pending_frame_id;
                        if (mel_idx == N_MELS-1) begin
                            state <= S_CLEAR;
                        end else begin
                            mel_idx <= mel_idx + 1'b1;
                        end
                    end
                end

                S_CLEAR: begin
                    for (int i = 0; i < N_MELS; i++) accum[i] <= '0;
                    bin_idx         <= '0;
                    mel_idx         <= '0;
                    frame_last_seen <= 1'b0;
                    state           <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
