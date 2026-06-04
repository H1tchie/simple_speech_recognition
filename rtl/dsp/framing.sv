//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   framing
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Podzial strumienia probek na ramki FRAME_LEN=512 z krokiem
                HOP_LEN=256 (50% overlap). Zapisuje probki w buforze
                circular o pojemnosci 2*FRAME_LEN; po nazbieraniu pelnej
                ramki wystawia ja AXI4-Stream-em (jedna probka na takt
                jesli m_axis_tready=1), z tuser = frame_id i tlast na
                ostatniej probce ramki.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module framing (
    input  logic                       clk,
    input  logic                       rst_n,

    // wejscie
    input  logic signed [SAMPLE_WIDTH-1:0] s_axis_tdata,
    input  logic                       s_axis_tvalid,
    output logic                       s_axis_tready,
    input  logic                       s_axis_tlast,

    // wyjscie
    output logic signed [SAMPLE_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast,
    output logic [15:0]                m_axis_tuser    // frame_id
);

    localparam int BUF_DEPTH = 2 * FRAME_LEN;
    localparam int IDX_W     = $clog2(BUF_DEPTH);
    localparam int CNT_W     = $clog2(FRAME_LEN + 1);

    logic signed [SAMPLE_WIDTH-1:0] buf_mem [0:BUF_DEPTH-1];

    logic [IDX_W-1:0] wr_ptr;
    logic [CNT_W-1:0] samples_in_buf;
    logic [IDX_W-1:0] rd_base;        // wskaznik poczatku biezacej ramki
    logic [CNT_W-1:0] read_count;
    logic [15:0]      frame_id;
    logic             frame_active;

    // Wejscie akceptowane gdy nie wystawiamy aktywnie ramki
    assign s_axis_tready = !frame_active;

    // Zapis do bufora
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wr_ptr         <= '0;
            samples_in_buf <= '0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                buf_mem[wr_ptr] <= s_axis_tdata;
                wr_ptr <= (wr_ptr == BUF_DEPTH-1) ? '0 : wr_ptr + 1'b1;
                samples_in_buf <= samples_in_buf + 1'b1;
            end
            // Po zakonczeniu ramki "konsumujemy" HOP_LEN probek z bufora
            if (frame_active && (read_count == FRAME_LEN-1) &&
                m_axis_tvalid && m_axis_tready) begin
                samples_in_buf <= samples_in_buf - HOP_LEN[CNT_W-1:0] +
                                  ((s_axis_tvalid && s_axis_tready) ? 1'b1 : 1'b0);
            end
        end
    end

    // Wystawianie ramki
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rd_base       <= '0;
            read_count    <= '0;
            frame_id      <= '0;
            frame_active  <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= '0;
        end else begin
            if (!frame_active && (samples_in_buf >= FRAME_LEN[CNT_W-1:0])) begin
                frame_active  <= 1'b1;
                read_count    <= '0;
                m_axis_tdata  <= buf_mem[rd_base];
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= 1'b0;
                m_axis_tuser  <= frame_id;
            end else if (frame_active && m_axis_tvalid && m_axis_tready) begin
                if (read_count == FRAME_LEN-1) begin
                    frame_active  <= 1'b0;
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    rd_base       <= ((rd_base + HOP_LEN[IDX_W-1:0]) >= BUF_DEPTH) ?
                                     (rd_base + HOP_LEN[IDX_W-1:0] - BUF_DEPTH) :
                                     (rd_base + HOP_LEN[IDX_W-1:0]);
                    frame_id      <= frame_id + 1'b1;
                end else begin
                    read_count   <= read_count + 1'b1;
                    m_axis_tdata <= buf_mem[(rd_base + read_count + 1'b1) % BUF_DEPTH];
                    m_axis_tlast <= (read_count == FRAME_LEN-2);
                end
            end
        end
    end

endmodule
