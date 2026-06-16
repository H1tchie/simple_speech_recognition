//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   dct_unit
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   DCT-II ortonormalna: mfcc[k] = (sum_n DCT[k][n]*logmel[n]) >>> 12
                k=0..N_MFCC-1, n=0..N_MELS-1. DCT Q4.12 z ROM (N_MFCC*N_MELS).

                Architektura: buforuje N_MELS logmel jednej ramki, potem
                liczy 13 wspolczynnikow sekwencyjnie (MAC po 26 kazdy).
                Wystawia AXI-Stream: mfcc per coeff, tlast na ostatnim (k=12),
                tuser=frame_id.

                ROM: dct_13x26.mem (N_MFCC*N_MELS=338), addr=k*N_MELS+n.
                logmel signed Q10, DCT signed Q12 -> produkt, akum 48-bit signed.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module dct_unit (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (logmel per filtr) ---
    input  logic signed [LOG_W-1:0]     s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (mfcc per coeff) ---
    output logic signed [MFCC_W-1:0]    m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // --- ROM DCT (Q4.12) ---
    logic signed [DCT_W-1:0] dct_rom [N_MFCC*N_MELS-1:0];
    initial $readmemh("dct_13x26.mem", dct_rom);

    // --- bufor logmel jednej ramki ---
    logic signed [LOG_W-1:0] logmel_buf [N_MELS-1:0];
    logic [$clog2(N_MELS)-1:0] wr_idx;
    logic [$clog2(N_FRAMES)-1:0] frame_id;

    // --- liczniki ---
    logic [$clog2(N_MFCC)-1:0] k_idx;   // ktory coeff (0..12)
    logic [$clog2(N_MELS)-1:0] n_idx;   // ktory mel w MAC (0..25)

    // --- akumulator 48-bit signed ---
    logic signed [47:0] acc;

    typedef enum logic [1:0] {S_LOAD, S_MAC, S_OUT, S_NEXT} state_t;
    state_t state;

    integer i;

    // addr ROM = k_idx*N_MELS + n_idx
    logic [$clog2(N_MFCC*N_MELS)-1:0] rom_addr;
    assign rom_addr = k_idx*N_MELS + n_idx;

    // produkt signed: DCT(Q12) * logmel(Q10)
    logic signed [DCT_W+LOG_W-1:0] prod;
    assign prod = dct_rom[rom_addr] * logmel_buf[n_idx];

    assign s_tready = (state == S_LOAD);

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= S_LOAD;
            wr_idx   <= '0;
            k_idx    <= '0;
            n_idx    <= '0;
            acc      <= '0;
            frame_id <= '0;
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata  <= '0;
            m_tuser  <= '0;
            for (i=0;i<N_MELS;i++) logmel_buf[i] <= '0;
        end else begin
            case (state)
                S_LOAD: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    if (s_tvalid && s_tready) begin
                        logmel_buf[wr_idx] <= s_tdata;
                        frame_id <= s_tuser;
                        if (s_tlast) begin
                            wr_idx <= '0;
                            k_idx  <= '0;
                            n_idx  <= '0;
                            acc    <= '0;
                            state  <= S_MAC;
                        end else begin
                            wr_idx <= wr_idx + 1;
                        end
                    end
                end

                S_MAC: begin
                    acc <= acc + prod;
                    if (n_idx == N_MELS-1) begin
                        n_idx <= '0;
                        state <= S_OUT;
                    end else begin
                        n_idx <= n_idx + 1;
                    end
                end

                S_OUT: begin
                    m_tdata  <= acc >>> Q12;   // >>>12, Q10 wynik
                    m_tvalid <= 1'b1;
                    m_tuser  <= frame_id;
                    m_tlast  <= (k_idx == N_MFCC-1);
                    if (m_tready) state <= S_NEXT;
                end

                S_NEXT: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    acc      <= '0;
                    n_idx    <= '0;
                    if (k_idx == N_MFCC-1) begin
                        k_idx <= '0;
                        state <= S_LOAD;
                    end else begin
                        k_idx <= k_idx + 1;
                        state <= S_MAC;
                    end
                end

                default: state <= S_LOAD;
            endcase
        end
    end

endmodule : dct_unit
