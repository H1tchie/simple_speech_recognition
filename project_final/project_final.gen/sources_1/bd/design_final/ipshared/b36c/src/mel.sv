//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   mel_filter
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Mel filter bank: mel[m] = (sum_k FB[m][k]*power[k]) >>> 15
                m=0..N_MELS-1, k=0..N_BINS-1. FB Q1.15 z ROM (N_MELS*N_BINS).
                Floor: mel = max(mel,1) (dla log2).

                Architektura: buforuje N_BINS power jednej ramki, potem
                liczy 26 filtrow sekwencyjnie (MAC po 129 binach kazdy).
                Wystawia AXI-Stream: mel per filtr, tlast na ostatnim (m=25),
                tuser=frame_id.

                ROM: mel_fb_26.mem (N_MELS*N_BINS = 3354), addr=m*N_BINS+k.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module mel_filter (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (power per bin) ---
    input  logic [POWER_W-1:0]          s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (mel per filtr) ---
    output logic [MEL_W-1:0]            m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // --- ROM mel filterbank (Q1.15) ---
    logic signed [MELFB_W-1:0] fb_rom [N_MELS*N_BINS-1:0];
    initial $readmemh("mel_fb_26.mem", fb_rom);

    // --- bufor power jednej ramki ---
    logic [POWER_W-1:0] power_buf [N_BINS-1:0];
    logic [$clog2(N_BINS)-1:0] wr_idx;
    logic [$clog2(N_FRAMES)-1:0] frame_id;

    // --- liczniki ---
    logic [$clog2(N_MELS)-1:0] mel_idx;   // ktory filtr (0..25)
    logic [$clog2(N_BINS)-1:0] k_idx;     // ktory bin w MAC (0..128)

    // --- akumulator 64-bit ---
    logic [MEL_ACC_W-1:0] acc;

    typedef enum logic [1:0] {S_LOAD, S_MAC, S_OUT, S_NEXT} state_t;
    state_t state;

    integer i;

    // addr ROM = mel_idx*N_BINS + k_idx
    logic [$clog2(N_MELS*N_BINS)-1:0] rom_addr;
    assign rom_addr = mel_idx*N_BINS + k_idx;

    // produkt: FB(Q1.15, signed ale >=0) * power(unsigned 48b)
    // FB jest nieujemne (filtry trojkatne), traktujemy jako unsigned
    logic [MELFB_W-1:0]      fb_val;
    logic [MEL_ACC_W-1:0]    prod;
    assign fb_val = fb_rom[rom_addr][MELFB_W-1:0];     // 0..32767
    assign prod   = power_buf[k_idx] * fb_val;          // unsigned mult

    assign s_tready = (state == S_LOAD);

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= S_LOAD;
            wr_idx   <= '0;
            mel_idx  <= '0;
            k_idx    <= '0;
            acc      <= '0;
            frame_id <= '0;
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata  <= '0;
            m_tuser  <= '0;
            for (i=0;i<N_BINS;i++) power_buf[i] <= '0;
        end else begin
            case (state)
                // --- ladowanie power jednej ramki ---
                S_LOAD: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    if (s_tvalid && s_tready) begin
                        power_buf[wr_idx] <= s_tdata;
                        frame_id <= s_tuser;
                        if (s_tlast) begin
                            wr_idx  <= '0;
                            mel_idx <= '0;
                            k_idx   <= '0;
                            acc     <= '0;
                            state   <= S_MAC;
                        end else begin
                            wr_idx <= wr_idx + 1;
                        end
                    end
                end

                // --- MAC: 129 binow dla biezacego filtra ---
                S_MAC: begin
                    acc <= acc + prod;
                    if (k_idx == N_BINS-1) begin
                        k_idx <= '0;
                        state <= S_OUT;
                    end else begin
                        k_idx <= k_idx + 1;
                    end
                end

                // --- wystaw mel[mel_idx] = max(acc>>15, 1) ---
                S_OUT: begin
                    m_tdata  <= (acc >> Q15) == 0 ? 'd1 : (acc >> Q15);  // floor 1
                    m_tvalid <= 1'b1;
                    m_tuser  <= frame_id;
                    m_tlast  <= (mel_idx == N_MELS-1);
                    if (m_tready) state <= S_NEXT;
                end

                // --- nastepny filtr lub nowa ramka ---
                S_NEXT: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    acc      <= '0;
                    k_idx    <= '0;
                    if (mel_idx == N_MELS-1) begin
                        mel_idx <= '0;
                        state   <= S_LOAD;
                    end else begin
                        mel_idx <= mel_idx + 1;
                        state   <= S_MAC;
                    end
                end

                default: state <= S_LOAD;
            endcase
        end
    end

endmodule : mel_filter
