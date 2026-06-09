//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   axi4lite_regs
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2026-01
 Description:   Standardowy AXI4-Lite slave z 4 rejestrami 32-bit do
                sterowania IPcorem z poziomu softcore'a (MicroBlaze 
                PicoRV32) - konspekt sekcja 3.1.

                Mapa rejestrow:
                  0x00 CTRL    [W]  bit0=start, bit1=soft_reset
                  0x04 STATUS  [R]  bit0=busy, bit1=done, bit2=error
                  0x08 RESULT  [R]  command_id [3:0] + flags
                  0x0C CONFIG  [RW] reserved
*/
//////////////////////////////////////////////////////////////////////////////

module axi4lite_regs #(
    parameter int ADDR_WIDTH = 4
) (
    input  logic                       aclk,
    input  logic                       aresetn,

    input  logic [ADDR_WIDTH-1:0]      s_axi_awaddr,
    input  logic [2:0]                 s_axi_awprot,
    input  logic                       s_axi_awvalid,
    output logic                       s_axi_awready,

    input  logic [31:0]                s_axi_wdata,
    input  logic [3:0]                 s_axi_wstrb,
    input  logic                       s_axi_wvalid,
    output logic                       s_axi_wready,

    output logic [1:0]                 s_axi_bresp,
    output logic                       s_axi_bvalid,
    input  logic                       s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]      s_axi_araddr,
    input  logic [2:0]                 s_axi_arprot,
    input  logic                       s_axi_arvalid,
    output logic                       s_axi_arready,

    output logic [31:0]                s_axi_rdata,
    output logic [1:0]                 s_axi_rresp,
    output logic                       s_axi_rvalid,
    input  logic                       s_axi_rready,

    output logic                       start,
    output logic                       soft_reset,
    output logic [31:0]                config_reg,
    input  logic                       busy,
    input  logic                       done,
    input  logic                       error,
    input  logic [31:0]                result
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL   = 4'h0;
    localparam logic [ADDR_WIDTH-1:0] ADDR_STATUS = 4'h4;
    localparam logic [ADDR_WIDTH-1:0] ADDR_RESULT = 4'h8;
    localparam logic [ADDR_WIDTH-1:0] ADDR_CONFIG = 4'hC;

    logic [31:0] ctrl_q;
    logic        aw_en;
    logic        start_pulse;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            aw_en         <= 1'b1;
            ctrl_q        <= '0;
            config_reg    <= '0;
            start_pulse   <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en)
                s_axi_awready <= 1'b1;
            else
                s_axi_awready <= 1'b0;

            if (!s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en)
                s_axi_wready <= 1'b1;
            else
                s_axi_wready <= 1'b0;

            if (s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid) begin
                case (s_axi_awaddr)
                    ADDR_CTRL: begin
                        ctrl_q <= s_axi_wdata;
                        if (s_axi_wdata[0]) start_pulse <= 1'b1;
                    end
                    ADDR_CONFIG: config_reg <= s_axi_wdata;
                    default: ;
                endcase
            end

            if (s_axi_awready && s_axi_awvalid && !s_axi_bvalid &&
                s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                aw_en        <= 1'b0;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
                aw_en        <= 1'b1;
            end
        end
    end

    assign start      = start_pulse;
    assign soft_reset = ctrl_q[1];

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= '0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid)
                s_axi_arready <= 1'b1;
            else
                s_axi_arready <= 1'b0;

            if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                case (s_axi_araddr)
                    ADDR_CTRL:   s_axi_rdata <= ctrl_q;
                    ADDR_STATUS: s_axi_rdata <= {29'd0, error, done, busy};
                    ADDR_RESULT: s_axi_rdata <= result;
                    ADDR_CONFIG: s_axi_rdata <= config_reg;
                    default:     s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
