//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ssr_axi_lite_v1_0_S00_AXI
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.0
 Description:   Slave AXI4-Lite opakowujacy rdzen ssr_core.
                Procesor MicroBlaze:
                  - strumieniuje probki audio (zapis do rejestru SAMPLE),
                  - "zatrzaskuje" wynik i odczytuje go (rejestr RESULT).

   MAPA REJESTROW (offset wzgledem bazy peryferium):
     0x00  SAMPLE  (W)  : [11:0]  probka audio; KAZDY zapis -> 1 takt sample_valid
     0x04  CTRL    (W)  : bit0 soft_reset (impuls), bit1 latch (zatrzasnij wynik),
                          bit2 but_enable (poziom; zezwala led_logic na zmiane diody)
     0x08  STATUS  (R)  : bit0 result_valid
     0x0C  RESULT  (R)  : [1:0] wynik (0=other,1=on,2=off)
 */
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 1 ps

module ssr_axi_lite_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4
)
(
    // ---- sygnaly funkcjonalne wyprowadzone na zewnatrz IP ----
    output wire        led0,

    // ---- AXI4-Lite ----
    input  wire        S_AXI_ACLK,
    input  wire        S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [2:0]  S_AXI_AWPROT,
    input  wire        S_AXI_AWVALID,
    output wire        S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    input  wire        S_AXI_WVALID,
    output wire        S_AXI_WREADY,
    output wire [1:0]  S_AXI_BRESP,
    output wire        S_AXI_BVALID,
    input  wire        S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [2:0]  S_AXI_ARPROT,
    input  wire        S_AXI_ARVALID,
    output wire        S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0]  S_AXI_RRESP,
    output wire        S_AXI_RVALID,
    input  wire        S_AXI_RREADY
);

//------------------------------------------------------------------------------
// AXI4-Lite signals (standardowy szablon Xilinx)
//------------------------------------------------------------------------------
reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
reg                          axi_awready;
reg                          axi_wready;
reg [1:0]                    axi_bresp;
reg                          axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
reg                          axi_arready;
reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
reg [1:0]                    axi_rresp;
reg                          axi_rvalid;

localparam integer ADDR_LSB          = (C_S_AXI_DATA_WIDTH/32) + 1; // =2 dla 32b
localparam integer OPT_MEM_ADDR_BITS = 1;                          // 4 rejestry

wire slv_reg_wren;
wire slv_reg_rden;
integer byte_index;
reg aw_en;

assign S_AXI_AWREADY = axi_awready;
assign S_AXI_WREADY  = axi_wready;
assign S_AXI_BRESP   = axi_bresp;
assign S_AXI_BVALID  = axi_bvalid;
assign S_AXI_ARREADY = axi_arready;
assign S_AXI_RDATA   = axi_rdata;
assign S_AXI_RRESP   = axi_rresp;
assign S_AXI_RVALID  = axi_rvalid;

//------------------------------------------------------------------------------
// Write address channel
//------------------------------------------------------------------------------
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_awready <= 1'b0;
        aw_en       <= 1'b1;
    end else begin
        if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
            axi_awready <= 1'b1;
            aw_en       <= 1'b0;
        end else if (S_AXI_BREADY && axi_bvalid) begin
            aw_en       <= 1'b1;
            axi_awready <= 1'b0;
        end else begin
            axi_awready <= 1'b0;
        end
    end
end

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_awaddr <= 0;
    end else if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
        axi_awaddr <= S_AXI_AWADDR;
    end
end

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_wready <= 1'b0;
    end else if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
        axi_wready <= 1'b1;
    end else begin
        axi_wready <= 1'b0;
    end
end

assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

//------------------------------------------------------------------------------
// Rejestry sterujace / strobik probki
//------------------------------------------------------------------------------
reg  [11:0] sample_data;     // dane probki podawane do rdzenia
reg         sample_valid;    // 1-taktowy strob nowej probki
reg         but_enable;      // zezwolenie dla led_logic
reg         soft_reset_req;  // zlecenie miekkiego resetu rdzenia
reg         latch_req;       // zlecenie zatrzasniecia wyniku

wire [1:0]  core_value;      // biezacy wynik klasyfikacji z rdzenia
reg  [1:0]  result_reg;      // zatrzasniety wynik
reg         result_valid;    // wynik gotowy do odczytu

// Generator miekkiego resetu (rozciagniety na kilka taktow)
reg  [3:0]  rst_cnt;
wire        core_rst = (~S_AXI_ARESETN) | (rst_cnt != 4'd0);

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        sample_data    <= 12'd0;
        sample_valid   <= 1'b0;
        but_enable     <= 1'b0;
        soft_reset_req <= 1'b0;
        latch_req      <= 1'b0;
        rst_cnt        <= 4'd0;
        result_reg     <= 2'b00;
        result_valid   <= 1'b0;
    end else begin
        // strobiki domyslnie 0 (jednotaktowe)
        sample_valid   <= 1'b0;
        soft_reset_req <= 1'b0;
        latch_req      <= 1'b0;

        // dekodowanie zapisu
        if (slv_reg_wren) begin
            case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                2'h0: begin // SAMPLE
                    if (S_AXI_WSTRB[0]) sample_data[7:0]  <= S_AXI_WDATA[7:0];
                    if (S_AXI_WSTRB[1]) sample_data[11:8] <= S_AXI_WDATA[11:8];
                    sample_valid <= 1'b1;
                end
                2'h1: begin // CTRL
                    if (S_AXI_WSTRB[0]) begin
                        soft_reset_req <= S_AXI_WDATA[0];
                        latch_req      <= S_AXI_WDATA[1];
                        but_enable     <= S_AXI_WDATA[2];
                    end
                end
                default: ; // STATUS/RESULT - tylko do odczytu
            endcase
        end

        // rozciagniety reset rdzenia
        if (soft_reset_req) rst_cnt <= 4'd15;
        else if (rst_cnt != 4'd0) rst_cnt <= rst_cnt - 4'd1;

        // zatrzask wyniku
        if (soft_reset_req) begin
            result_valid <= 1'b0;
        end else if (latch_req) begin
            result_reg   <= core_value;
            result_valid <= 1'b1;
        end
    end
end

//------------------------------------------------------------------------------
// Write response channel
//------------------------------------------------------------------------------
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_bvalid <= 1'b0;
        axi_bresp  <= 2'b0;
    end else begin
        if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID) begin
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; // OKAY
        end else if (S_AXI_BREADY && axi_bvalid) begin
            axi_bvalid <= 1'b0;
        end
    end
end

//------------------------------------------------------------------------------
// Read address channel
//------------------------------------------------------------------------------
always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_arready <= 1'b0;
        axi_araddr  <= 0;
    end else begin
        if (~axi_arready && S_AXI_ARVALID) begin
            axi_arready <= 1'b1;
            axi_araddr  <= S_AXI_ARADDR;
        end else begin
            axi_arready <= 1'b0;
        end
    end
end

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_rvalid <= 1'b0;
        axi_rresp  <= 2'b0;
    end else begin
        if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b0; // OKAY
        end else if (axi_rvalid && S_AXI_RREADY) begin
            axi_rvalid <= 1'b0;
        end
    end
end

assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;

// Mux odczytu
reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata_mux;
always @(*) begin
    case (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
        2'h2:    axi_rdata_mux = {31'b0, result_valid};        // STATUS
        2'h3:    axi_rdata_mux = {30'b0, result_reg};          // RESULT
        default: axi_rdata_mux = 32'h0000_0000;
    endcase
end

always @(posedge S_AXI_ACLK) begin
    if (S_AXI_ARESETN == 1'b0) begin
        axi_rdata <= 0;
    end else if (slv_reg_rden) begin
        axi_rdata <= axi_rdata_mux;
    end
end

//------------------------------------------------------------------------------
// Instancja rdzenia rozpoznawania mowy
//------------------------------------------------------------------------------
ssr_core u_ssr_core (
    .clk          (S_AXI_ACLK),
    .rst          (core_rst),
    .sample_in    (sample_data),
    .sample_valid (sample_valid),
    .but          (but_enable),
    .value        (core_value),
    .led0         (led0)
);

endmodule
