//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   feature_aggregator
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       2.0 - WIELOCYKLOWY (timing-friendly)
 Description:   Agreguje MFCC po wszystkich ramkach -> 26 cech (13 mean+13 std).
                Identyczny wynik jak v1, ale obliczenia rozlozone na wiele
                cykli zeby skrocic sciezke kombinacyjna (timing).

                Akumulacja (S_ACC): suma[k]+=mfcc, sumsq[k]+=mfcc^2
                Po ostatniej ramce, dla kazdego coeff k (sekwencyjnie):
                  C1: var_num = N*sumsq - suma*suma        (mnozenia)
                  C2..C25: isqrt iteracyjnie (1 krok/cykl, 24 kroki)
                  C26: mean = (suma/N)>>10, std = (sqrt/N)>>10  (dzielenia)
                Potem emisja 26 cech.

                isqrt jako MASZYNA (1 iteracja/cykl) - nie rozwinieta.
                Dzielenia /N w osobnym cyklu, nie razem z isqrt.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module feature_aggregator (
    input  logic clk,
    input  logic rst,

    input  logic signed [MFCC_W-1:0]    s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    output logic signed [FEAT_W-1:0]    m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FEATURES)-1:0] m_tuser
);

    localparam int N = N_FRAMES;  // 124

    // akumulatory per coeff
    logic signed [31:0] sum_acc  [N_MFCC-1:0];
    logic        [63:0] sumsq_acc[N_MFCC-1:0];
    logic [$clog2(N_MFCC)-1:0] coeff_idx;

    // wyniki
    logic signed [FEAT_W-1:0] feat_mem [N_FEATURES-1:0];
    logic [$clog2(N_FEATURES)-1:0] out_idx;

    // stan glowny
    typedef enum logic [3:0] {
        S_ACC, S_SQ, S_MUL, S_SUB, S_SQRTINIT, S_SQRT, S_DIV, S_NEXTK, S_EMIT, S_DONE
    } state_t;
    state_t state;

    logic [$clog2(N_MFCC)-1:0] calc_k;

    // rejestry posrednie obliczen
    logic signed [95:0] var_num;       // N*sumsq - suma^2
    logic        [95:0] suma_sq;       // suma^2 (osobny cykl)
    logic        [95:0] n_sumsq;       // N*sumsq (osobny cykl)
    logic        [95:0] sqrt_rem;      // reszta isqrt
    logic        [95:0] sqrt_res;      // wynik isqrt (96b dla spojnosci z bit)
    logic        [95:0] sqrt_bit;      // biezacy bit isqrt
    logic [6:0]         sqrt_iter;     // licznik iteracji (0..47)
    logic signed [63:0] mfcc_ext;      // s_tdata rozszerzone do 64b (do kwadratu)
    logic signed [63:0] sum_ext;       // sum_acc rozszerzone do 64b

    integer i;

    assign s_tready = (state == S_ACC);

    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= S_ACC;
            coeff_idx <= '0;
            calc_k    <= '0;
            out_idx   <= '0;
            m_tvalid  <= 1'b0;
            m_tlast   <= 1'b0;
            m_tdata   <= '0;
            m_tuser   <= '0;
            for (i=0;i<N_MFCC;i++) begin
                sum_acc[i]   <= '0;
                sumsq_acc[i] <= '0;
            end
            for (i=0;i<N_FEATURES;i++) feat_mem[i] <= '0;
        end else begin
            case (state)
                // ---- akumulacja po ramkach ----
                S_ACC: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    if (s_tvalid && s_tready) begin
                        sum_acc[coeff_idx]   <= sum_acc[coeff_idx]   + s_tdata;
                        sumsq_acc[coeff_idx] <= sumsq_acc[coeff_idx] + (64'(signed'(s_tdata)) * 64'(signed'(s_tdata)));
                        if (s_tlast) begin
                            coeff_idx <= '0;
                            if (s_tuser == N_FRAMES-1) begin
                                calc_k <= '0;
                                state  <= S_SQ;
                            end
                        end else begin
                            coeff_idx <= coeff_idx + 1;
                        end
                    end
                end

                // ---- C1a: suma^2 (jeden mnoznik) ----
                S_SQ: begin
                    suma_sq <= 96'(signed'(sum_acc[calc_k])) * 96'(signed'(sum_acc[calc_k]));
                    state   <= S_MUL;
                end

                // ---- C1b: N*sumsq (drugi mnoznik) ----
                S_MUL: begin
                    n_sumsq <= 96'(sumsq_acc[calc_k]) * 96'(N);
                    state   <= S_SUB;
                end

                // ---- C1c: var_num = N*sumsq - suma^2, init isqrt ----
                S_SUB: begin
                    var_num   <= $signed(n_sumsq) - $signed(suma_sq);
                    sqrt_res  <= '0;
                    sqrt_bit  <= 96'h1 << 94;
                    sqrt_iter <= '0;
                    state     <= S_SQRTINIT;
                end

                // ---- init isqrt: ustaw sqrt_rem z gotowego var_num ----
                S_SQRTINIT: begin
                    sqrt_rem <= (var_num < 0) ? 96'd0 : var_num[95:0];
                    state    <= S_SQRT;
                end

                // ---- C2..: isqrt, 1 iteracja na cykl (24 cykle) ----
                S_SQRT: begin
                    if (sqrt_rem >= sqrt_res + sqrt_bit) begin
                        sqrt_rem <= sqrt_rem - (sqrt_res + sqrt_bit);
                        sqrt_res <= (sqrt_res >> 1) + sqrt_bit;
                    end else begin
                        sqrt_res <= sqrt_res >> 1;
                    end
                    sqrt_bit <= sqrt_bit >> 2;

                    if (sqrt_iter == 47)
                        state <= S_DIV;
                    else
                        sqrt_iter <= sqrt_iter + 1;
                end

                // ---- dzielenia /N (osobny cykl) ----
                S_DIV: begin
                    feat_mem[calc_k]         <= ($signed(sum_acc[calc_k]) / N) >>> Q10;
                    feat_mem[N_MFCC+calc_k]  <= ($signed({1'b0, sqrt_res[46:0]}) / N) >>> Q10;
                    state <= S_NEXTK;
                end

                // ---- nastepny coeff albo emisja ----
                S_NEXTK: begin
                    if (calc_k == N_MFCC-1) begin
                        out_idx <= '0;
                        state   <= S_EMIT;
                    end else begin
                        calc_k <= calc_k + 1;
                        state  <= S_SQ;
                    end
                end

                // ---- emisja 26 cech ----
                // m_tvalid trzymane caly czas; out_idx inkrementuje gdy m_tready.
                // Po odebraniu ostatniej (out_idx==25 && m_tready) -> S_DONE.
                S_EMIT: begin
                    m_tvalid <= 1'b1;
                    m_tdata  <= feat_mem[out_idx];
                    m_tuser  <= out_idx;
                    m_tlast  <= (out_idx == N_FEATURES-1);
                    if (m_tready) begin
                        if (out_idx == N_FEATURES-1) begin
                            // ostatnia cecha wlasnie odebrana
                            state <= S_DONE;
                        end else begin
                            out_idx <= out_idx + 1;
                        end
                    end
                end

                S_DONE: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                end

                default: state <= S_ACC;
            endcase
        end
    end

endmodule : feature_aggregator
