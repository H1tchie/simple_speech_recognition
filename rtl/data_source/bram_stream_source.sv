//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   bram_stream_source
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       2.0
 Last modified: 2026-01
 Description:   Czyta próbki Q1.15 z BRAM (zainicjowanej plikiem .mem przez
                $readmemh) i wystawia jako AXI4-Stream master. Sterowane
                pulsem 'start'. Asercja 'done' przez 1 cykl po wystawieniu
                ostatniej próbki (tlast=1).
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module bram_stream_source #(
    parameter int    NUM_SAMP   = NUM_SAMPLES,
    parameter string INIT_FILE  = "samples.mem"
) (
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic                       start,

    output logic                       busy,
    output logic                       done,

    // AXI4-Stream master
    output logic signed [SAMPLE_WIDTH-1:0] m_axis_tdata,
    output logic                       m_axis_tvalid,
    input  logic                       m_axis_tready,
    output logic                       m_axis_tlast
);

    localparam int ADDR_W = (NUM_SAMP > 1) ? $clog2(NUM_SAMP) : 1;

    (* ram_style = "block" *)
    logic signed [SAMPLE_WIDTH-1:0] mem [0:NUM_SAMP-1];

    initial begin
        $readmemh(INIT_FILE, mem);
    end

    logic [ADDR_W-1:0] addr;
    logic              running;

    assign busy = running;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr          <= '0;
            running       <= 1'b0;
            done          <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !running) begin
                running       <= 1'b1;
                addr          <= '0;
                m_axis_tdata  <= mem[0];
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= (NUM_SAMP == 1);
            end else if (running) begin
                if (m_axis_tvalid && m_axis_tready) begin
                    if (addr == NUM_SAMP-1) begin
                        // Ostatnia probka wyslana
                        running       <= 1'b0;
                        done          <= 1'b1;
                        m_axis_tvalid <= 1'b0;
                        m_axis_tlast  <= 1'b0;
                    end else begin
                        addr          <= addr + 1'b1;
                        m_axis_tdata  <= mem[addr + 1'b1];
                        m_axis_tlast  <= (addr + 1'b1 == NUM_SAMP-1);
                    end
                end
            end
        end
    end

endmodule
