//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       2.0 (AXI DMA)
 Description:   Opakowanie rdzenia rozpoznawania mowy (top_system) pod przeplyw
                z AXI DMA + PYNQ.

                - WEJSCIE AUDIO: AXI4-Stream slave (s_axis_*), podpinane wprost
                  do portu M_AXIS_MM2S kontrolera AXI DMA. Probki Q1.15 16-bit.
                  Sygnal s_axis_tlast generuje DMA na koncu transferu, wiec nie
                  ma juz rejestru N_SAMPLES ani licznika probek.
                - WYNIK / STEROWANIE: maly slave AXI4-Lite (s00_axi_*), czytany
                  z Pythona przez MMIO:
                      0x00 CTRL   (W): bit0 soft_reset
                      0x04 STATUS (R): bit0 output_valid, bit1 busy, bit2 s_axis_ready
                      0x08 RESULT (R): [1:0] wynik (0=other, 1=on, 2=off)
                - led0: dioda (on -> zapal, off -> zgas).

                Caly modul pracuje w jednej domenie zegara s00_axi_aclk
                (ten sam zegar taktuje strumien, AXI-Lite i rdzen).
 */
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 1 ps

module top_ssr #
(
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 4,
    parameter integer C_S_AXIS_DATA_WIDTH  = 16
)
(
    // ---- AXI4-Stream slave: audio z AXI DMA (M_AXIS_MM2S) ----
    input  wire [C_S_AXIS_DATA_WIDTH-1:0] s_axis_tdata,
    input  wire                           s_axis_tvalid,
    output wire                           s_axis_tready,
    input  wire                           s_axis_tlast,

    // ---- dioda ----
    output wire        led0,

    // ---- AXI4-Lite slave: sterowanie / status / wynik ----
    input  wire        s00_axi_aclk,
    input  wire        s00_axi_aresetn,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_awaddr,
    input  wire [2:0]  s00_axi_awprot,
    input  wire        s00_axi_awvalid,
    output wire        s00_axi_awready,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0]     s00_axi_wdata,
    input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] s00_axi_wstrb,
    input  wire        s00_axi_wvalid,
    output wire        s00_axi_wready,
    output wire [1:0]  s00_axi_bresp,
    output wire        s00_axi_bvalid,
    input  wire        s00_axi_bready,
    input  wire [C_S00_AXI_ADDR_WIDTH-1:0] s00_axi_araddr,
    input  wire [2:0]  s00_axi_arprot,
    input  wire        s00_axi_arvalid,
    output wire        s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axi_rdata,
    output wire [1:0]  s00_axi_rresp,
    output wire        s00_axi_rvalid,
    input  wire        s00_axi_rready
);

    localparam integer ADDR_LSB          = (C_S00_AXI_DATA_WIDTH/32) + 1; // =2
    localparam integer OPT_MEM_ADDR_BITS = 1;                            // 4 rejestry

    // ---- standardowe rejestry AXI4-Lite ----
    reg [C_S00_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    reg                            axi_awready;
    reg                            axi_wready;
    reg [1:0]                      axi_bresp;
    reg                            axi_bvalid;
    reg [C_S00_AXI_ADDR_WIDTH-1:0] axi_araddr;
    reg                            axi_arready;
    reg [C_S00_AXI_DATA_WIDTH-1:0] axi_rdata;
    reg [1:0]                      axi_rresp;
    reg                            axi_rvalid;
    reg                            aw_en;
    wire                           slv_reg_wren;
    wire                           slv_reg_rden;

    assign s00_axi_awready = axi_awready;
    assign s00_axi_wready  = axi_wready;
    assign s00_axi_bresp   = axi_bresp;
    assign s00_axi_bvalid  = axi_bvalid;
    assign s00_axi_arready = axi_arready;
    assign s00_axi_rdata   = axi_rdata;
    assign s00_axi_rresp   = axi_rresp;
    assign s00_axi_rvalid  = axi_rvalid;

    // ---- sygnaly rdzenia ----
    wire [1:0] core_value;
    wire       core_ovalid;
    wire       core_busy;
    wire       core_sready;

    // ---- soft reset (rozciagniety) ----
    reg        soft_reset_req;
    reg [3:0]  rst_cnt;
    wire       core_rst = (~s00_axi_aresetn) | (rst_cnt != 4'd0);

    //--------------------------------------------------------------------------
    // Write address / data channel
    //--------------------------------------------------------------------------
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            axi_awready <= 1'b0; aw_en <= 1'b1;
        end else if (~axi_awready && s00_axi_awvalid && s00_axi_wvalid && aw_en) begin
            axi_awready <= 1'b1; aw_en <= 1'b0;
        end else if (s00_axi_bready && axi_bvalid) begin
            aw_en <= 1'b1; axi_awready <= 1'b0;
        end else begin
            axi_awready <= 1'b0;
        end
    end
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) axi_awaddr <= 0;
        else if (~axi_awready && s00_axi_awvalid && s00_axi_wvalid && aw_en) axi_awaddr <= s00_axi_awaddr;
    end
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) axi_wready <= 1'b0;
        else if (~axi_wready && s00_axi_wvalid && s00_axi_awvalid && aw_en) axi_wready <= 1'b1;
        else axi_wready <= 1'b0;
    end
    assign slv_reg_wren = axi_wready && s00_axi_wvalid && axi_awready && s00_axi_awvalid;

    //--------------------------------------------------------------------------
    // Dekodowanie zapisow (CTRL) + soft reset
    //--------------------------------------------------------------------------
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            soft_reset_req <= 1'b0;
            rst_cnt        <= 4'd0;
        end else begin
            soft_reset_req <= 1'b0;   // impuls 1-taktowy
            if (slv_reg_wren) begin
                case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                    2'h0: if (s00_axi_wstrb[0]) soft_reset_req <= s00_axi_wdata[0]; // CTRL
                    default: ;
                endcase
            end
            if (soft_reset_req)        rst_cnt <= 4'd15;
            else if (rst_cnt != 4'd0)  rst_cnt <= rst_cnt - 4'd1;
        end
    end

    //--------------------------------------------------------------------------
    // Write response
    //--------------------------------------------------------------------------
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            axi_bvalid <= 1'b0; axi_bresp <= 2'b0;
        end else if (axi_awready && s00_axi_awvalid && ~axi_bvalid && axi_wready && s00_axi_wvalid) begin
            axi_bvalid <= 1'b1; axi_bresp <= 2'b0;
        end else if (s00_axi_bready && axi_bvalid) begin
            axi_bvalid <= 1'b0;
        end
    end

    //--------------------------------------------------------------------------
    // Read channel
    //--------------------------------------------------------------------------
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            axi_arready <= 1'b0; axi_araddr <= 0;
        end else if (~axi_arready && s00_axi_arvalid) begin
            axi_arready <= 1'b1; axi_araddr <= s00_axi_araddr;
        end else begin
            axi_arready <= 1'b0;
        end
    end
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            axi_rvalid <= 1'b0; axi_rresp <= 2'b0;
        end else if (axi_arready && s00_axi_arvalid && ~axi_rvalid) begin
            axi_rvalid <= 1'b1; axi_rresp <= 2'b0;
        end else if (axi_rvalid && s00_axi_rready) begin
            axi_rvalid <= 1'b0;
        end
    end
    assign slv_reg_rden = axi_arready & s00_axi_arvalid & ~axi_rvalid;

    reg [C_S00_AXI_DATA_WIDTH-1:0] rdata_mux;
    always @(*) begin
        case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
            2'h1:    rdata_mux = {29'b0, core_sready, core_busy, core_ovalid}; // STATUS
            2'h2:    rdata_mux = {30'b0, core_value};                          // RESULT
            default: rdata_mux = 32'h0;
        endcase
    end
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) axi_rdata <= 0;
        else if (slv_reg_rden) axi_rdata <= rdata_mux;
    end

    //--------------------------------------------------------------------------
    // Dioda: on -> zapal, off -> zgas (gdy wynik gotowy)
    //--------------------------------------------------------------------------
    reg led0_r;
    always @(posedge s00_axi_aclk) begin
        if (core_rst) led0_r <= 1'b0;
        else if (core_ovalid) begin
            if      (core_value == 2'd1) led0_r <= 1'b1;   // on
            else if (core_value == 2'd2) led0_r <= 1'b0;   // off
        end
    end
    assign led0 = led0_r;

    //--------------------------------------------------------------------------
    // Rdzen rozpoznawania - strumien audio wprost z AXI DMA
    //--------------------------------------------------------------------------
    assign s_axis_tready = core_sready;

    top_system u_top_system (
        .clk          (s00_axi_aclk),
        .rst          (core_rst),
        .s_tdata      (s_axis_tdata),
        .s_tvalid     (s_axis_tvalid),
        .s_tready     (core_sready),
        .s_tlast      (s_axis_tlast),
        .output_value (core_value),
        .output_valid (core_ovalid),
        .busy         (core_busy)
    );

endmodule