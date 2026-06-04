`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr_tb
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       3.0
 Description:   System testbench dla top_ssr v3.

                Probki audio sa ladowane z samples.mem do BRAM-a w
                bram_stream_source. TB tylko podaje clk/reset, naciska
                BTNC, czeka az AXI status pokaze 'done' i wypisuje wynik.
*/
//////////////////////////////////////////////////////////////////////////////

module top_ssr_tb;

    logic clk = 0;
    logic rst_n;
    logic start_btn;
    logic but_enable;
    logic led0;
    logic [1:0] cmd;

    always #5 clk = ~clk;   // 100 MHz

    top_ssr uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awaddr  ('0),
        .s_axi_awprot  ('0),
        .s_axi_awvalid (1'b0),
        .s_axi_awready (),
        .s_axi_wdata   ('0),
        .s_axi_wstrb   ('0),
        .s_axi_wvalid  (1'b0),
        .s_axi_wready  (),
        .s_axi_bresp   (),
        .s_axi_bvalid  (),
        .s_axi_bready  (1'b1),
        .s_axi_araddr  ('0),
        .s_axi_arprot  ('0),
        .s_axi_arvalid (1'b0),
        .s_axi_arready (),
        .s_axi_rdata   (),
        .s_axi_rresp   (),
        .s_axi_rvalid  (),
        .s_axi_rready  (1'b1),

        .start_btn(start_btn),
        .but_enable(but_enable),
        .led0(led0),
        .command_id(cmd)
    );

    initial begin
        $display("[TB] === top_ssr_tb start ===");

        rst_n = 1'b0;
        start_btn = 1'b0;
        but_enable = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        but_enable = 1'b1;

        $display("[TB] BTNC pulse");
        start_btn = 1'b1;
        repeat (5) @(posedge clk);
        start_btn = 1'b0;

        // Z DFT O(N^2) w SIM_MODE i N=512 ramek to bedzie dlugo.
        // Damy duzy zapas.
        wait (uut.nn_value_valid);
        repeat (10) @(posedge clk);

        $display("[TB] cmd=%0d led0=%b", cmd, led0);
        case (cmd)
            2'b00: $display("[TB] -> other");
            2'b01: $display("[TB] -> on");
            2'b10: $display("[TB] -> off");
            default: $display("[TB] -> ???");
        endcase

        $display("[TB] === top_ssr_tb end ===");
        $finish;
    end

    initial begin
        #500ms;
        $display("[TB] TIMEOUT");
        $finish;
    end

    initial begin
        $dumpfile("top_ssr_tb.vcd");
        $dumpvars(0, top_ssr_tb);
    end

endmodule
