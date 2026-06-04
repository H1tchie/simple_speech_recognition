//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   window
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Mnozenie kolejnych probek ramki przez wspolczynnik okna
                Hamminga (Q1.15 unsigned, prekalkulowany w ROM przez
                tools/gen_window_rom.py).
                Wejscie/wyjscie: AXI4-Stream signed Q1.15.
                Wynik mnozenia signed Q1.15 * unsigned Q1.15 -> Q2.30,
                redukowany do Q1.15 z saturacja.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module window #(
    parameter string ROM_FILE = "window_hamming_512.mem"
) (
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic signed [SAMPLE_WIDTH-1:0] s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,
    input  logic [15:0]                s_axis_tuser,

    output logic signed [SAMPLE_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast,
    output logic [15:0]                m_axis_tuser
);

    localparam int IDX_W = $clog2(FRAME_LEN);

    logic [SAMPLE_WIDTH-1:0] win_rom [0:FRAME_LEN-1];
    initial begin
        $readmemh(ROM_FILE, win_rom);
    end

    logic [IDX_W-1:0] sample_idx;

    assign s_axis_tready = !m_axis_tvalid || m_axis_tready;

    logic signed [2*SAMPLE_WIDTH:0] product;
    logic signed [SAMPLE_WIDTH-1:0] product_sat;

    always_comb begin
        product = s_axis_tdata * $signed({1'b0, win_rom[sample_idx]});
        if ((product >>> 15) > $signed({1'b0, {(SAMPLE_WIDTH-1){1'b1}}}))
            product_sat = {1'b0, {(SAMPLE_WIDTH-1){1'b1}}};
        else if ((product >>> 15) < $signed({1'b1, {(SAMPLE_WIDTH-1){1'b0}}}))
            product_sat = {1'b1, {(SAMPLE_WIDTH-1){1'b0}}};
        else
            product_sat = (product >>> 15);
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sample_idx    <= '0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= '0;
        end else begin
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
            end

            if (s_axis_tvalid && s_axis_tready) begin
                m_axis_tdata  <= product_sat;
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= s_axis_tlast;
                m_axis_tuser  <= s_axis_tuser;
                sample_idx    <= s_axis_tlast ? '0 : sample_idx + 1'b1;
            end
        end
    end

endmodule
