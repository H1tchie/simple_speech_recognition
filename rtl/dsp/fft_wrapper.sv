//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   fft_wrapper
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       2.0  (wlasny staloprzecinkowy DFT)
 Last modified: 2026-01
 Description:   512-punktowy DFT w arytmetyce calkowitej (Q1.15), w pelni
                deterministyczny i odtwarzalny 1:1 w Pythonie
                (tools/train/dsp_fixed.py). Zastepuje czarnoskrzynkowe
                xfft IP - dzieki temu trening sieci, symulacja i sprzet
                liczą DOKLADNIE to samo.

                Dla projektu offline (probki z BRAM, nie real-time) koszt
                O(N^2) jest akceptowalny: ~512*257 cykli MAC na ramke +
                isqrt; przy 100 MHz ~kilkadziesiat ms na slowo.

                Wspolczynniki obrotu: ROM twiddle_{cos,sin}_512.mem
                (Q1.15, generowane przez tools/gen_twiddle_rom.py).

                Potok:
                  re = (sum_n x[n]*cos((k*n) mod 512)) >>> 15
                  im = (sum_n -x[n]*sin((k*n) mod 512)) >>> 15
                  |X[k]| = isqrt(re^2 + im^2)
                  norm[k] = |X[k]| * 32767 / max_k(|X|)    (Q1.15, per-ramka)

                Wyjscie: N_BINS=257 wartosci, tlast na ostatniej, tuser=frame_id.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module fft_wrapper #(
    parameter int SIM_MODE = 1   // zachowane dla zgodnosci interfejsu (nieuzywane)
) (
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic signed [SAMPLE_WIDTH-1:0] s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,
    input  logic [15:0]                s_axis_tuser,

    output logic [SAMPLE_WIDTH-1:0]    m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast,
    output logic [15:0]                m_axis_tuser
);

    localparam int IDX_W = $clog2(FRAME_LEN);

    // ROM twiddle (Q1.15 signed)
    logic signed [SAMPLE_WIDTH-1:0] cos_rom [0:N_FFT-1];
    logic signed [SAMPLE_WIDTH-1:0] sin_rom [0:N_FFT-1];
    initial begin
        $readmemh("twiddle_cos_512.mem", cos_rom);
        $readmemh("twiddle_sin_512.mem", sin_rom);
    end

    // isqrt(x) - calkowity pierwiastek (floor), bit po bicie
    function automatic logic [39:0] isqrt80(input logic [79:0] x);
        logic [79:0] rem, root, bit_v;
        begin
            rem = x; root = 0;
            bit_v = 80'h4000_0000_0000_0000_0000;   // 2^78
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
            return root[39:0];
        end
    endfunction

    logic signed [SAMPLE_WIDTH-1:0] frame_buf [0:FRAME_LEN-1];
    logic [IDX_W-1:0]               in_idx;
    logic [15:0]                    pending_frame_id;

    logic [39:0] mag_buf [0:N_BINS-1];
    logic [39:0] max_mag;

    typedef enum logic [2:0] {
        S_COLLECT = 3'd0,
        S_DFT     = 3'd1,
        S_OUTPUT  = 3'd2
    } state_t;
    state_t state;

    logic [$clog2(N_BINS):0] k_idx;
    logic [IDX_W:0]          n_idx;
    logic signed [55:0]      re_acc, im_acc;
    logic [$clog2(N_BINS):0] out_idx;

    // biezacy iloczyn k*n mod 512
    logic [IDX_W-1:0] tw_idx;
    assign tw_idx = (k_idx * n_idx) & (N_FFT-1);

    assign s_axis_tready = (state == S_COLLECT);

    // skalowanie wyjscia: norm = mag*32767/max
    logic [31:0] norm_val;
    logic [55:0] norm_num;
    always_comb begin
        if (max_mag == 0) begin norm_val = '0; norm_num = '0; end
        else begin norm_num = mag_buf[out_idx] * 32767; norm_val = norm_num / max_mag; end
    end

    logic signed [55:0] re_s, im_s;
    logic [79:0]        mag_sq;
    logic [39:0]        mag_k;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= S_COLLECT;
            in_idx <= '0; k_idx <= '0; n_idx <= '0; out_idx <= '0;
            re_acc <= '0; im_acc <= '0; max_mag <= '0;
            pending_frame_id <= '0;
            m_axis_tvalid <= 1'b0; m_axis_tdata <= '0;
            m_axis_tlast <= 1'b0; m_axis_tuser <= '0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            case (state)
                S_COLLECT: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        frame_buf[in_idx] <= s_axis_tdata;
                        pending_frame_id  <= s_axis_tuser;
                        if (s_axis_tlast) begin
                            in_idx  <= '0;
                            k_idx   <= '0;
                            n_idx   <= '0;
                            re_acc  <= '0;
                            im_acc  <= '0;
                            max_mag <= '0;
                            state   <= S_DFT;
                        end else begin
                            in_idx <= in_idx + 1'b1;
                        end
                    end
                end

                S_DFT: begin
                    if (n_idx == FRAME_LEN) begin
                        // koniec sumowania dla biezacego k -> magnitude
                        re_s = re_acc >>> 15;
                        im_s = im_acc >>> 15;
                        mag_sq = $unsigned(re_s*re_s) + $unsigned(im_s*im_s);
                        mag_k  = isqrt80(mag_sq);
                        mag_buf[k_idx] <= mag_k;
                        if (mag_k > max_mag) max_mag <= mag_k;
                        re_acc <= '0; im_acc <= '0; n_idx <= '0;
                        if (k_idx == N_BINS-1) begin
                            k_idx   <= '0;
                            out_idx <= '0;
                            state   <= S_OUTPUT;
                        end else begin
                            k_idx <= k_idx + 1'b1;
                        end
                    end else begin
                        re_acc <= re_acc + frame_buf[n_idx] * cos_rom[tw_idx];
                        im_acc <= im_acc - frame_buf[n_idx] * sin_rom[tw_idx];
                        n_idx  <= n_idx + 1'b1;
                    end
                end

                S_OUTPUT: begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        m_axis_tdata  <= norm_val[SAMPLE_WIDTH-1:0];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (out_idx == N_BINS-1);
                        m_axis_tuser  <= pending_frame_id;
                        if (out_idx == N_BINS-1) begin
                            state <= S_COLLECT;
                        end else begin
                            out_idx <= out_idx + 1'b1;
                        end
                    end
                end

                default: state <= S_COLLECT;
            endcase
        end
    end

endmodule
