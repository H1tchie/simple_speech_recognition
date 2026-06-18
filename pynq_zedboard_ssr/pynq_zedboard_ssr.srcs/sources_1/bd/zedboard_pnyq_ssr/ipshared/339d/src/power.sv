//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   power
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Magnitude squared: power[k] = re[k]^2 + im[k]^2.
                Pass-through AXI-Stream: kazdy bin (re,im) -> jeden power.
                re,im signed 32-bit (skala Q1.15 z DFT).
                power unsigned POWER_W=48 (worst-case full-scale ~2^42).
                Pelna precyzja - bez obcinania (mel liczy z pelnego power).
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module power (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (re,im per bin) ---
    input  logic signed [DFT_W-1:0]     s_tdata_re,
    input  logic signed [DFT_W-1:0]     s_tdata_im,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (power per bin) ---
    output logic [POWER_W-1:0]          m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // re^2 + im^2. re,im signed 32-bit -> kwadrat do 64-bit, suma miesci sie w 48
    logic signed [2*DFT_W-1:0] re_sq, im_sq;   // 64-bit
    logic        [2*DFT_W-1:0] pwr_full;       // 64-bit (re^2,im^2 >=0)

    assign re_sq    = s_tdata_re * s_tdata_re;  // >=0
    assign im_sq    = s_tdata_im * s_tdata_im;  // >=0
    assign pwr_full = re_sq + im_sq;

    assign s_tready = m_tready;

    always_ff @(posedge clk) begin
        if (rst) begin
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata  <= '0;
            m_tuser  <= '0;
        end else begin
            if (s_tvalid && s_tready) begin
                m_tdata  <= pwr_full[POWER_W-1:0];  // 48-bit (z zapasem do 2^48)
                m_tvalid <= 1'b1;
                m_tlast  <= s_tlast;
                m_tuser  <= s_tuser;
            end else if (m_tready) begin
                m_tvalid <= 1'b0;
                m_tlast  <= 1'b0;
            end
        end
    end

endmodule : power
