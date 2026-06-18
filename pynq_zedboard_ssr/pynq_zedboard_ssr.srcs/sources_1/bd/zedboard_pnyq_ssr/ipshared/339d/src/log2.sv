//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   log2_unit
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   log2 staloprzecinkowy (Q10) dla kazdej energii mel.
                Metoda: LZC (pozycja MSB) = czesc calkowita,
                        10 bitow ponizej MSB = czesc ulamkowa (Q10).
                Potem odejmuje LOG2_OFFSET_Q10 (korekta skali power 2^30).

                log2(x) = (msb<<10) | frac_q10  - OFFSET
                  msb       : pozycja najwyzszego ustawionego bitu (0..47)
                  frac_q10  : msb>=10 ? (x>>(msb-10))&0x3FF : (x<<(10-msb))&0x3FF

                Pass-through AXI-Stream: mel -> logmel, tlast/tuser przepisane.
                Wynik signed (po odjeciu offsetu moze byc ujemny).
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module log2_unit (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (mel per filtr) ---
    input  logic [MEL_W-1:0]            s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (logmel per filtr, signed Q10) ---
    output logic signed [LOG_W-1:0]     m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // --- LZC: znajdz pozycje MSB w MEL_W-bitowym slowie ---
    logic [$clog2(MEL_W)-1:0] msb;
    integer b;
    always_comb begin
        msb = '0;
        for (b = 0; b < MEL_W; b++)
            if (s_tdata[b]) msb = b[$clog2(MEL_W)-1:0];
    end

    // --- czesc ulamkowa Q10 (10 bitow ponizej MSB) ---
    logic [LOG2_FRAC_BITS-1:0] frac_q10;
    always_comb begin
        if (msb >= LOG2_FRAC_BITS)
            frac_q10 = (s_tdata >> (msb - LOG2_FRAC_BITS)) & 10'h3FF;
        else
            frac_q10 = (s_tdata << (LOG2_FRAC_BITS - msb)) & 10'h3FF;
    end

    // --- log2 = (msb<<10)|frac - offset ---
    logic signed [LOG_W-1:0] log_raw, log_corr;
    assign log_raw  = $signed({1'b0, msb, frac_q10});           // (msb<<10)|frac, dodatnie
    assign log_corr = log_raw - LOG2_OFFSET_Q10;                // korekta skali

    assign s_tready = m_tready;

    always_ff @(posedge clk) begin
        if (rst) begin
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata  <= '0;
            m_tuser  <= '0;
        end else begin
            if (s_tvalid && s_tready) begin
                m_tdata  <= log_corr;
                m_tvalid <= 1'b1;
                m_tlast  <= s_tlast;
                m_tuser  <= s_tuser;
            end else if (m_tready) begin
                m_tvalid <= 1'b0;
                m_tlast  <= 1'b0;
            end
        end
    end

endmodule : log2_unit
