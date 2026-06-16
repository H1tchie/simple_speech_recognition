//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_microblaze
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Opakowanie AXI4-Lite (slave) dla top_system. Pozwala procesorowi
                MicroBlaze (lub ARM na Zynq) sterowac calym rozpoznawaniem mowy:
                  - wpisywac probki audio (Q1.15) -> wrapper podaje je na
                    wejscie AXI-Stream top_system (s_tdata/valid/last),
                  - oznaczyc ostatnia probke (po N_SAMPLES) jako s_tlast,
                  - odczytac wynik klasyfikacji (output_value) i status.

                Probki podajemy pojedynczo: kazdy zapis do rejestru SAMPLE
                wpycha jeden beat na strumien. Przed kolejnym zapisem procesor
                sprawdza STATUS.ready (czy poprzedni beat zostal odebrany).

   MAPA REJESTROW (offset wzgledem bazy peryferium):
     0x00 CTRL      (W) : bit0 soft_reset (impuls; resetuje caly top_system)
     0x04 N_SAMPLES (W) : liczba probek nagrania (do wygenerowania s_tlast)
     0x08 SAMPLE    (W) : [15:0] probka Q1.15; kazdy zapis = jeden beat strumienia
     0x0C STATUS    (R) : bit0 ready (mozna wyslac kolejna probke),
                          bit1 output_valid (wynik gotowy),
                          bit2 busy (trwa przetwarzanie)
     0x10 RESULT    (R) : [1:0] wynik (0=other, 1=on, 2=off)
 */
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ns / 1 ps

module top_microblaze #
(
    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 5      // 8 rejestrow (3 bity wyboru)
)
(
    // funkcjonalne wyjscie (dioda sterowana wynikiem)
    output wire        led0,

    // interfejs AXI4-Lite (slave) - kompatybilny z MicroBlaze
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
    localparam integer OPT_MEM_ADDR_BITS = 2;                            // 8 rejestrow

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
    assign s00_axi_arready  = axi_arready;
    assign s00_axi_rdata   = axi_rdata;
    assign s00_axi_rresp   = axi_rresp;
    assign s00_axi_rvalid  = axi_rvalid;

    // ---- sygnaly do/z top_system ----
    reg  signed [15:0] str_data;     // dane na strumien
    reg                str_valid;    // s_tvalid
    wire               str_ready;    // s_tready (z top_system)
    reg  [31:0]        n_samples;    // liczba probek nagrania
    reg  [31:0]        sample_cnt;   // licznik wyslanych probek
    wire               str_last;
    wire [1:0]         core_value;
    wire               core_ovalid;
    wire               core_busy;

    // strobiki sterujace
    reg                soft_reset_req;
    reg  [3:0]         rst_cnt;
    wire               core_rst = (~s00_axi_aresetn) | (rst_cnt != 4'd0);

    assign str_last  = str_valid && (sample_cnt == (n_samples - 32'd1));
    wire   ready_for_sample = ~str_valid;   // mozna przyjac kolejna probke, gdy nie trzymamy biezacej

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
    // Dekodowanie zapisow + sterowanie strumieniem
    //--------------------------------------------------------------------------
    always @(posedge s00_axi_aclk) begin
        if (~s00_axi_aresetn) begin
            soft_reset_req <= 1'b0;
            n_samples      <= 32'd16000;   // domyslnie dlugosc nagrania
            str_data       <= 16'sd0;
            str_valid      <= 1'b0;
            sample_cnt     <= 32'd0;
            rst_cnt        <= 4'd0;
        end else begin
            soft_reset_req <= 1'b0;   // impuls 1-taktowy

            // zapisy do rejestrow
            if (slv_reg_wren) begin
                case (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
                    3'h0: begin // CTRL
                        if (s00_axi_wstrb[0]) soft_reset_req <= s00_axi_wdata[0];
                    end
                    3'h1: begin // N_SAMPLES
                        n_samples <= s00_axi_wdata;
                    end
                    3'h2: begin // SAMPLE -> wpchnij beat (tylko gdy gotowi)
                        if (ready_for_sample) begin
                            str_data  <= s00_axi_wdata[15:0];
                            str_valid <= 1'b1;
                        end
                    end
                    default: ;
                endcase
            end

            // obsluga handshake strumienia: gdy beat odebrany, zwolnij i licz
            if (str_valid && str_ready) begin
                str_valid <= 1'b0;
                if (str_last) sample_cnt <= 32'd0;       // koniec nagrania -> licznik od nowa
                else          sample_cnt <= sample_cnt + 32'd1;
            end

            // rozciagniety soft reset rdzenia (i wyzerowanie licznika probek)
            if (soft_reset_req) begin
                rst_cnt    <= 4'd15;
                sample_cnt <= 32'd0;
                str_valid  <= 1'b0;
            end else if (rst_cnt != 4'd0) begin
                rst_cnt <= rst_cnt - 4'd1;
            end
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
            3'h3:    rdata_mux = {29'b0, core_busy, core_ovalid, ready_for_sample}; // STATUS
            3'h4:    rdata_mux = {30'b0, core_value};                              // RESULT
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
    // Instancja rdzenia rozpoznawania
    //--------------------------------------------------------------------------
    top_system u_top_system (
        .clk          (s00_axi_aclk),
        .rst          (core_rst),
        .s_tdata      (str_data),
        .s_tvalid     (str_valid),
        .s_tready     (str_ready),
        .s_tlast      (str_last),
        .output_value (core_value),
        .output_valid (core_ovalid),
        .busy         (core_busy)
    );

endmodule