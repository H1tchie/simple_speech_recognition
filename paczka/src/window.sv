//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   window
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Mnozy kazda probke ramki przez wspolczynnik okna Hamminga.
                w[n] = (sample[n] * hamming[n]) >>> 15   (Q1.15 * Q1.15 -> Q1.15)

                ROM okna ladowany z window_hamming_256.mem (Q1.15).
                Pass-through AXI-Stream: kazda probka wejsciowa -> jedna wyjsciowa,
                tlast/tuser przepisywane. Indeks w ramce liczony lokalnie,
                zerowany na tlast.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module window (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (ramki z framing) ---
    input  logic signed [SAMPLE_W-1:0]  s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (ramki po oknie) ---
    output logic signed [SAMPLE_W-1:0]  m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // --- ROM okna Hamminga (Q1.15) ---
    logic signed [WIN_W-1:0] win_rom [FRAME_LEN-1:0];
    initial $readmemh("window_hamming_256.mem", win_rom);

    // --- indeks probki w ramce ---
    logic [$clog2(FRAME_LEN)-1:0] idx;

    // iloczyn Q1.15 * Q1.15 = Q2.30, po >>>15 -> Q1.15
    logic signed [2*SAMPLE_W-1:0] product;
    assign product = s_tdata * win_rom[idx];

    // gotowi przyjac gdy downstream gotowy (pass-through)
    assign s_tready = m_tready;

    always_ff @(posedge clk) begin
        if (rst) begin
            idx      <= '0;
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata  <= '0;
            m_tuser  <= '0;
        end else begin
            if (s_tvalid && s_tready) begin
                // wystaw probke po oknie
                m_tdata  <= product >>> Q15;   // Q1.15
                m_tvalid <= 1'b1;
                m_tlast  <= s_tlast;
                m_tuser  <= s_tuser;
                // licznik indeksu w ramce
                if (s_tlast)
                    idx <= '0;
                else
                    idx <= idx + 1;
            end else if (m_tready) begin
                // brak nowych danych - zwolnij valid
                m_tvalid <= 1'b0;
                m_tlast  <= 1'b0;
            end
        end
    end

endmodule : window
