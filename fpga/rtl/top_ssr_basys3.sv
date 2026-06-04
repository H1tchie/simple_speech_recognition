`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr_basys3
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       3.0
 Last modified: 2026-01
 Description:   Board-level wrapper Basys3 (XC7A35T).
                AXI4-Lite jest tu tied-off (stand-alone build); w
                docelowym build'zie z MicroBlaze/PicoRV32 ten wrapper
                zostalby zastapiony block-design'em z procesorem.
*/
//////////////////////////////////////////////////////////////////////////////

module top_ssr_basys3 (
    input  wire        clk,         // 100 MHz (W5)
    input  wire        btnU,        // sync reset (active-high na plytce)
    input  wire        btnC,        // start
    input  wire        sw0,         // enable LED update
    output wire        led0,
    output wire [1:0]  led_cmd      // led[2:1] = command_id
);

    // Sync reset
    logic [3:0] rst_sync;
    always_ff @(posedge clk) rst_sync <= {rst_sync[2:0], btnU};
    wire rst_n = ~rst_sync[3];

    logic [1:0] cmd_id;
    assign led_cmd = cmd_id;

    top_ssr u_top_ssr (
        .clk(clk),
        .rst_n(rst_n),

        // AXI tied-off
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

        .start_btn (btnC),
        .but_enable(sw0),
        .led0      (led0),
        .command_id(cmd_id)
    );

endmodule
