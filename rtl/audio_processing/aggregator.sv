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
    logic        [47:0] sumsq_acc[N_MFCC-1:0];
    logic [$clog2(N_MFCC)-1:0] coeff_idx;

    // wyniki
    logic signed [FEAT_W-1:0] feat_mem [N_FEATURES-1:0];
    logic [$clog2(N_FEATURES)-1:0] out_idx;

    // stan glowny
    typedef enum logic [2:0] {
        S_ACC, S_VARNUM, S_SQRT, S_DIV, S_NEXTK, S_EMIT, S_DONE
    } state_t;
    state_t state;

    logic [$clog2(N_MFCC)-1:0] calc_k;

    // rejestry posrednie obliczen
    logic signed [63:0] var_num;       // N*sumsq - suma^2
    logic        [47:0] sqrt_rem;      // reszta isqrt
    logic        [23:0] sqrt_res;      // wynik isqrt
    logic        [47:0] sqrt_bit;      // biezacy bit isqrt
    logic [5:0]         sqrt_iter;     // licznik iteracji (0..23)

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
                        sumsq_acc[coeff_idx] <= sumsq_acc[coeff_idx] + s_tdata*s_tdata;
                        if (s_tlast) begin
                            coeff_idx <= '0;
                            if (s_tuser == N_FRAMES-1) begin
                                calc_k <= '0;
                                state  <= S_VARNUM;
                            end
                        end else begin
                            coeff_idx <= coeff_idx + 1;
                        end
                    end
                end

                // ---- C1: policz var_num i przygotuj isqrt ----
                S_VARNUM: begin
                    var_num <= $signed({16'b0, sumsq_acc[calc_k]}) * N
                             - $signed(sum_acc[calc_k]) * $signed(sum_acc[calc_k]);
                    // init isqrt
                    sqrt_res  <= '0;
                    sqrt_bit  <= 48'h1 << 46;   // najwyzszy parzysty bit
                    sqrt_iter <= '0;
                    state     <= S_SQRT;
                end

                // ---- C2..: isqrt, 1 iteracja na cykl (24 cykle) ----
                S_SQRT: begin
                    if (sqrt_iter == 0) begin
                        // pierwsza iteracja: ustaw rem = max(var_num,0)
                        sqrt_rem <= (var_num < 0) ? 48'd0 : var_num[47:0];
                    end
                    // jedna iteracja restoring sqrt
                    if (sqrt_rem >= sqrt_res + sqrt_bit) begin
                        sqrt_rem <= sqrt_rem - (sqrt_res + sqrt_bit);
                        sqrt_res <= (sqrt_res >> 1) + sqrt_bit[23:0];
                    end else begin
                        sqrt_res <= sqrt_res >> 1;
                    end
                    sqrt_bit <= sqrt_bit >> 2;

                    if (sqrt_iter == 23)
                        state <= S_DIV;
                    else
                        sqrt_iter <= sqrt_iter + 1;
                end

                // ---- dzielenia /N (osobny cykl) ----
                S_DIV: begin
                    feat_mem[calc_k]         <= ($signed(sum_acc[calc_k]) / N) >>> Q10;
                    feat_mem[N_MFCC+calc_k]  <= ($signed({1'b0, sqrt_res}) / N) >>> Q10;
                    state <= S_NEXTK;
                end

                // ---- nastepny coeff albo emisja ----
                S_NEXTK: begin
                    if (calc_k == N_MFCC-1) begin
                        out_idx <= '0;
                        state   <= S_EMIT;
                    end else begin
                        calc_k <= calc_k + 1;
                        state  <= S_VARNUM;
                    end
                end

                // ---- emisja 26 cech ----
                S_EMIT: begin
                    m_tdata  <= feat_mem[out_idx];
                    m_tvalid <= 1'b1;
                    m_tuser  <= out_idx;
                    m_tlast  <= (out_idx == N_FEATURES-1);
                    if (m_tready) begin
                        if (out_idx == N_FEATURES-1) begin
                            m_tvalid <= 1'b0;
                            m_tlast  <= 1'b0;
                            state    <= S_DONE;
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