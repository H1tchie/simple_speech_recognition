//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   preemphasis
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Filtr pre-emphasis y[n] = x[n] - alpha*x[n-1].
                Wejscie/wyjscie: AXI4-Stream 16-bit signed (Q1.15).
                alpha = 0.97 w Q1.15 = 0x7C29.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module preemphasis (
    input  logic                       clk,
    input  logic                       rst_n,

    // AXI4-Stream slave
    input  logic signed [SAMPLE_WIDTH-1:0] s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,

    // AXI4-Stream master
    output logic signed [SAMPLE_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast
);

    logic signed [SAMPLE_WIDTH-1:0] x_prev;

    // Akceptuj wejscie gdy mozemy wystawic wynik
    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

    // Obliczenia w pelnej precyzji
    logic signed [SAMPLE_WIDTH+15:0] mult_prev;
    logic signed [SAMPLE_WIDTH+15:0] x_ext;
    logic signed [SAMPLE_WIDTH+15:0] y_full;
    logic signed [SAMPLE_WIDTH-1:0]  y_sat;

    always_comb begin
        mult_prev = $signed({1'b0, ALPHA_Q15}) * x_prev;          // Q2.30
        x_ext     = {{1{s_axis_tdata[SAMPLE_WIDTH-1]}}, s_axis_tdata, 15'b0};
        y_full    = x_ext - mult_prev;

        if ((y_full >>> 15) > $signed({1'b0, {(SAMPLE_WIDTH-1){1'b1}}}))
            y_sat = {1'b0, {(SAMPLE_WIDTH-1){1'b1}}};
        else if ((y_full >>> 15) < $signed({1'b1, {(SAMPLE_WIDTH-1){1'b0}}}))
            y_sat = {1'b1, {(SAMPLE_WIDTH-1){1'b0}}};
        else
            y_sat = (y_full >>> 15);
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_prev        <= '0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            if (s_axis_tvalid && s_axis_tready) begin
                m_axis_tdata  <= y_sat;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= s_axis_tlast;
                x_prev        <= s_axis_tdata;
            end
        end
    end

endmodule
