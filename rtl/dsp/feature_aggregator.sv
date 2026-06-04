//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   feature_aggregator
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       2.0  (poprawna wariancja + deterministyczny isqrt)
 Last modified: 2026-01
 Description:   Akumuluje wektory MFCC kolejnych ramek i po sygnale 'flush'
                liczy dla kazdego z N_MFCC=13 wspolczynnikow:
                  mean[m] = sum[m] / N                     (trunc do zera)
                  var[m]  = sum_sq[m]/N - mean[m]^2         (>=0)
                  std[m]  = isqrt(var[m])                   (floor)
                Wystawia 2*N_MFCC=26 cech: 13 srednich, potem 13 std.
                Calosc w arytmetyce calkowitej, 1:1 z tools/train/dsp_fixed.py
                (funkcja aggregate). Brak stratnych obcien posrednich.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module feature_aggregator (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       flush,    // 1-cykl puls -> licz mean/std

    input  logic signed [MFCC_WIDTH-1:0] s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,

    output logic signed [SAMPLE_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast
);

    localparam int ACC_WIDTH   = 32;
    localparam int SQ_WIDTH    = 48;
    localparam int MFCC_W_IDX  = $clog2(N_MFCC);
    localparam int FEAT_W_IDX  = $clog2(N_FEATURES);

    // isqrt(x) floor, bit po bicie
    function automatic logic [23:0] isqrt48(input logic [47:0] x);
        logic [47:0] rem, root, bit_v;
        begin
            rem = x; root = 0;
            bit_v = 48'h4000_0000_0000;       // 2^46
            while (bit_v > x) bit_v = bit_v >> 2;
            while (bit_v != 0) begin
                if (rem >= root + bit_v) begin
                    rem  = rem - (root + bit_v);
                    root = (root >> 1) + bit_v;
                end else begin
                    root = root >> 1;
                end
                bit_v = bit_v >> 2;
            end
            return root[23:0];
        end
    endfunction

    function automatic logic signed [SAMPLE_WIDTH-1:0] sat16s(input logic signed [31:0] v);
        begin
            if (v > 32767)       sat16s = 16'sd32767;
            else if (v < -32768) sat16s = -16'sd32768;
            else                 sat16s = v[15:0];
        end
    endfunction

    logic signed [ACC_WIDTH-1:0] sum    [0:N_MFCC-1];
    logic        [SQ_WIDTH-1:0]  sum_sq [0:N_MFCC-1];
    logic [15:0]                 n_frames;
    logic [MFCC_W_IDX:0]         mfcc_idx;

    logic signed [SAMPLE_WIDTH-1:0] mean_arr [0:N_MFCC-1];
    logic signed [SAMPLE_WIDTH-1:0] std_arr  [0:N_MFCC-1];

    typedef enum logic [2:0] {
        S_COLLECT = 3'd0,
        S_COMPUTE = 3'd1,
        S_OUTPUT  = 3'd2,
        S_CLEAR   = 3'd3
    } state_t;
    state_t state;
    logic [FEAT_W_IDX:0] out_idx;
    logic [MFCC_W_IDX:0] calc_idx;

    assign s_axis_tready = (state == S_COLLECT);

    // rozszerzenie do 32 bitow PRZED mnozeniem (kontekst samookreslony '*'
    // dawalby max(16,16)=16 bitow i obcinal kwadrat MFCC)
    logic signed [31:0] d32;
    assign d32 = $signed(s_axis_tdata);

    // chwilowe wyniki dla biezacego calc_idx
    logic signed [ACC_WIDTH-1:0] mean_full;
    logic        [ACC_WIDTH-1:0] ex2;
    logic signed [ACC_WIDTH-1:0] var_s;
    logic        [ACC_WIDTH-1:0] var_u;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state    <= S_COLLECT;
            mfcc_idx <= '0;
            n_frames <= '0;
            out_idx  <= '0;
            calc_idx <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tlast  <= 1'b0;
            for (int i = 0; i < N_MFCC; i++) begin
                sum[i] <= '0; sum_sq[i] <= '0;
                mean_arr[i] <= '0; std_arr[i] <= '0;
            end
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            case (state)
                S_COLLECT: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        sum[mfcc_idx[MFCC_W_IDX-1:0]] <=
                            sum[mfcc_idx[MFCC_W_IDX-1:0]] + d32;
                        sum_sq[mfcc_idx[MFCC_W_IDX-1:0]] <=
                            sum_sq[mfcc_idx[MFCC_W_IDX-1:0]] +
                            $unsigned(d32 * d32);
                        if (s_axis_tlast || mfcc_idx == N_MFCC-1) begin
                            mfcc_idx <= '0;
                            n_frames <= n_frames + 1'b1;
                        end else begin
                            mfcc_idx <= mfcc_idx + 1'b1;
                        end
                    end
                    if (flush) begin
                        state    <= S_COMPUTE;
                        calc_idx <= '0;
                    end
                end

                S_COMPUTE: begin
                    if (n_frames == 0) begin
                        mean_arr[calc_idx[MFCC_W_IDX-1:0]] <= '0;
                        std_arr[calc_idx[MFCC_W_IDX-1:0]]  <= '0;
                    end else begin
                        mean_full = sum[calc_idx[MFCC_W_IDX-1:0]] / $signed({1'b0, n_frames});
                        ex2       = sum_sq[calc_idx[MFCC_W_IDX-1:0]] / n_frames;
                        var_s     = $signed(ex2) - (mean_full * mean_full);
                        var_u     = (var_s < 0) ? '0 : var_s;
                        mean_arr[calc_idx[MFCC_W_IDX-1:0]] <= sat16s(mean_full);
                        std_arr[calc_idx[MFCC_W_IDX-1:0]]  <=
                            sat16s($signed({1'b0, isqrt48({16'b0, var_u})}));
                    end
                    if (calc_idx == N_MFCC-1) begin
                        calc_idx <= '0;
                        out_idx  <= '0;
                        state    <= S_OUTPUT;
                    end else begin
                        calc_idx <= calc_idx + 1'b1;
                    end
                end

                S_OUTPUT: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        if (out_idx < N_MFCC[FEAT_W_IDX:0])
                            m_axis_tdata <= mean_arr[out_idx[MFCC_W_IDX-1:0]];
                        else begin
                            logic [FEAT_W_IDX:0] sidx;
                            sidx = out_idx - N_MFCC;
                            m_axis_tdata <= std_arr[sidx[MFCC_W_IDX-1:0]];
                        end
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (out_idx == N_FEATURES-1);
                        if (out_idx == N_FEATURES-1) state <= S_CLEAR;
                        else out_idx <= out_idx + 1'b1;
                    end
                end

                S_CLEAR: begin
                    n_frames <= '0;
                    mfcc_idx <= '0;
                    out_idx  <= '0;
                    calc_idx <= '0;
                    for (int i = 0; i < N_MFCC; i++) begin
                        sum[i] <= '0; sum_sq[i] <= '0;
                    end
                    state <= S_COLLECT;
                end

                default: state <= S_COLLECT;
            endcase
        end
    end

endmodule
