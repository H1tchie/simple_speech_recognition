`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   preemphasis_tb
 Description:   Unit test dla preemphasis.sv. Laduje samples.mem,
                wypycha probki na strumien wejsciowy, zapisuje wyjscie
                w preemphasis_out.txt (jeden Q1.15 hex na linie).
                Wynik mozna porownac z reference z gen_reference.py:
                  python tools/verify.py build/preemphasis_out.txt \\
                      data/results/on/pre_emphasis.csv --fmt q15
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module preemphasis_tb;

    localparam int NUM_SAMP = 16384;

    logic clk = 0;
    logic rst_n;
    always #5 clk = ~clk;

    logic signed [SAMPLE_WIDTH-1:0] in_data, out_data;
    logic in_valid, in_ready, in_last;
    logic out_valid, out_ready, out_last;

    logic signed [SAMPLE_WIDTH-1:0] samples [0:NUM_SAMP-1];
    int in_idx = 0;
    int out_count = 0;
    int fout;

    preemphasis dut (
        .clk, .rst_n,
        .s_axis_tdata(in_data),
        .s_axis_tvalid(in_valid),
        .s_axis_tready(in_ready),
        .s_axis_tlast(in_last),
        .m_axis_tdata(out_data),
        .m_axis_tvalid(out_valid),
        .m_axis_tready(out_ready),
        .m_axis_tlast(out_last)
    );

    assign out_ready = 1'b1;

    initial begin
        $readmemh("samples.mem", samples);
        fout = $fopen("preemphasis_out.txt", "w");
        if (!fout) begin $display("BLAD: cannot open output"); $finish; end

        rst_n = 0;
        in_data = '0; in_valid = 0; in_last = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;

        @(posedge clk);

        while (in_idx < NUM_SAMP) begin
            @(posedge clk);
            in_data  <= samples[in_idx];
            in_valid <= 1'b1;
            in_last  <= (in_idx == NUM_SAMP-1);
            if (in_ready) in_idx++;
        end
        @(posedge clk);
        in_valid <= 1'b0;
        in_last  <= 1'b0;

        repeat (100) @(posedge clk);
        $display("[TB] received %0d samples", out_count);
        $fclose(fout);
        $finish;
    end

    always_ff @(posedge clk) begin
        if (rst_n && out_valid && out_ready) begin
            $fwrite(fout, "%04x\n", out_data & 16'hFFFF);
            out_count <= out_count + 1;
        end
    end

    initial begin
        #100ms;
        $display("[TB] TIMEOUT"); $finish;
    end

endmodule
