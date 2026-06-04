//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   mfcc
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Log + DCT-II na wektorze energii Mel.

                Etap 1 (log2): aproksymacja przez Leading Zero Count:
                    log2(x) ~= msb(x) + ulamek
                  Wynik w Q5.10 (16-bit signed).

                Etap 2 (DCT): mnozenie macierzowe [N_MFCC x N_MELS] z
                wspolczynnikami z ROM (Q1.15 signed, prekalkulowane przez
                tools/gen_dct_coeffs.py).

                Wejscie: strumien N_MELS energii (z mel_filter_bank)
                Wyjscie: strumien N_MFCC=13 wspolczynnikow signed Q5.10
                         (MFCC_WIDTH=16)
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module mfcc #(
    parameter string DCT_COEFF_FILE = "dct_coeffs.mem"
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // wejscie - energie mel
    input  logic [MEL_ACC_WIDTH-1:0]   s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,
    input  logic [15:0]                s_axis_tuser,

    // wyjscie - MFCC
    output logic signed [MFCC_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast,
    output logic [15:0]                m_axis_tuser
);

    localparam int MEL_W      = $clog2(N_MELS);
    localparam int MFCC_W_IDX = $clog2(N_MFCC);

    // ----- log2 (LZC-based) -----
    function automatic logic signed [LOG_WIDTH-1:0] log2_approx(
        input logic [MEL_ACC_WIDTH-1:0] x
    );
        int msb;
        logic found;
        logic [LOG_WIDTH-1:0] result;
        logic [MEL_ACC_WIDTH-1:0] mantissa;
        begin
            if (x == 0) return '0;
            msb = 0;
            found = 1'b0;
            for (int i = MEL_ACC_WIDTH-1; i >= 0; i--) begin
                if (x[i] && !found) begin
                    msb = i;
                    found = 1'b1;
                end
            end
            // log2(x) ~= msb + (x - 2^msb) / 2^msb
            // Format wyjscia: Q5.10 (5 bitow int dla msb 0..31, 10 frakcja)
            if (msb > 0)
                mantissa = ((x - (1 << msb)) << 10) >> msb;
            else
                mantissa = '0;
            result = (msb << 10) | mantissa[9:0];
            return $signed(result);
        end
    endfunction

    // ----- DCT coefficients ROM -----
    logic signed [15:0] dct_rom [0:N_MFCC*N_MELS-1];
    initial begin
        $readmemh(DCT_COEFF_FILE, dct_rom);
    end

    // ----- bufor log(mel) -----
    logic signed [LOG_WIDTH-1:0] log_buf [0:N_MELS-1];

    typedef enum logic [1:0] {
        S_COLLECT = 2'd0,
        S_COMPUTE = 2'd1,
        S_OUTPUT  = 2'd2,
        S_CLEAR   = 2'd3
    } state_t;

    state_t state;
    logic [MEL_W:0]      collect_idx;
    logic [MFCC_W_IDX:0] mfcc_idx;
    logic [MEL_W:0]      dct_inner;
    logic signed [31:0]  dct_acc;
    logic [15:0]         pending_frame_id;

    assign s_axis_tready = (state == S_COLLECT);

    logic signed [31:0] dct_product;
    assign dct_product = log_buf[dct_inner[MEL_W-1:0]] *
                         dct_rom[mfcc_idx[MFCC_W_IDX-1:0] * N_MELS +
                                 dct_inner[MEL_W-1:0]];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state            <= S_COLLECT;
            collect_idx      <= '0;
            mfcc_idx         <= '0;
            dct_inner        <= '0;
            dct_acc          <= '0;
            pending_frame_id <= '0;
            m_axis_tvalid    <= 1'b0;
            m_axis_tdata     <= '0;
            m_axis_tlast     <= 1'b0;
            m_axis_tuser     <= '0;
            for (int i = 0; i < N_MELS; i++) log_buf[i] <= '0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            case (state)
                S_COLLECT: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        log_buf[collect_idx[MEL_W-1:0]] <= log2_approx(s_axis_tdata);
                        pending_frame_id <= s_axis_tuser;
                        if (s_axis_tlast || collect_idx == N_MELS-1) begin
                            collect_idx <= '0;
                            mfcc_idx    <= '0;
                            dct_inner   <= '0;
                            dct_acc     <= '0;
                            state       <= S_COMPUTE;
                        end else begin
                            collect_idx <= collect_idx + 1'b1;
                        end
                    end
                end

                S_COMPUTE: begin
                    dct_acc <= dct_acc + (dct_product >>> 15);
                    if (dct_inner == N_MELS-1) begin
                        state     <= S_OUTPUT;
                        dct_inner <= '0;
                    end else begin
                        dct_inner <= dct_inner + 1'b1;
                    end
                end

                S_OUTPUT: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        // Saturacja do MFCC_WIDTH
                        if (dct_acc > $signed({1'b0, {(MFCC_WIDTH-1){1'b1}}}))
                            m_axis_tdata <= {1'b0, {(MFCC_WIDTH-1){1'b1}}};
                        else if (dct_acc < $signed({1'b1, {(MFCC_WIDTH-1){1'b0}}}))
                            m_axis_tdata <= {1'b1, {(MFCC_WIDTH-1){1'b0}}};
                        else
                            m_axis_tdata <= dct_acc[MFCC_WIDTH-1:0];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (mfcc_idx == N_MFCC-1);
                        m_axis_tuser  <= pending_frame_id;

                        if (mfcc_idx == N_MFCC-1) begin
                            state <= S_CLEAR;
                        end else begin
                            mfcc_idx <= mfcc_idx + 1'b1;
                            dct_acc  <= '0;
                            state    <= S_COMPUTE;
                        end
                    end
                end

                S_CLEAR: begin
                    for (int i = 0; i < N_MELS; i++) log_buf[i] <= '0;
                    state    <= S_COLLECT;
                    mfcc_idx <= '0;
                    dct_acc  <= '0;
                end

                default: state <= S_COLLECT;
            endcase
        end
    end

endmodule
