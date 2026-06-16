`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ssr_axi_lite_tb
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.0
 Description:   Testbench AXI4-Lite dla peryferium ssr_axi_lite.
                Symuluje to, co w sprzecie robi MicroBlaze:
                  - reset rdzenia (CTRL.soft_reset),
                  - strumieniowanie probek z pliku (zapisy do SAMPLE),
                  - zatrzask wyniku (CTRL.latch),
                  - odczyt STATUS i RESULT.
                Plik z probkami: ten sam format co w oryginale
                (4-cyfrowy hex, jedna probka na linie).
 */
//////////////////////////////////////////////////////////////////////////////
module ssr_axi_lite_tb;

    localparam ADDR_W = 4;
    localparam DATA_W = 32;
    // sciezka do pliku z probkami (dostosuj wzgledem katalogu symulacji)
    //localparam string DATA_FILE = "../python/generated_files/vec_off.txt";
    //localparam string DATA_FILE = "../python/generated_files/vec_on.txt";
     localparam string DATA_FILE = "../python/generated_files/vec_other.txt";
    localparam int    MAX_SAMPLES = 16384;  // ile probek wczytac/wyslac

    // offsety rejestrow
    localparam SAMPLE = 4'h0;
    localparam CTRL   = 4'h4;
    localparam STATUS = 4'h8;
    localparam RESULT = 4'hC;

    logic clk = 0;
    logic aresetn = 0;
    always #5 clk = ~clk;   // 100 MHz

    // AXI4-Lite
    logic [ADDR_W-1:0] awaddr;  logic awvalid;  logic awready;
    logic [DATA_W-1:0] wdata;   logic [3:0] wstrb; logic wvalid; logic wready;
    logic [1:0] bresp;          logic bvalid;   logic bready;
    logic [ADDR_W-1:0] araddr;  logic arvalid;  logic arready;
    logic [DATA_W-1:0] rdata;   logic [1:0] rresp; logic rvalid; logic rready;
    wire  led0;

    ssr_axi_lite_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(DATA_W),
        .C_S00_AXI_ADDR_WIDTH(ADDR_W)
    ) dut (
        .led0           (led0),
        .s00_axi_aclk   (clk),
        .s00_axi_aresetn(aresetn),
        .s00_axi_awaddr (awaddr),
        .s00_axi_awprot (3'b000),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata  (wdata),
        .s00_axi_wstrb  (wstrb),
        .s00_axi_wvalid (wvalid),
        .s00_axi_wready (wready),
        .s00_axi_bresp  (bresp),
        .s00_axi_bvalid (bvalid),
        .s00_axi_bready (bready),
        .s00_axi_araddr (araddr),
        .s00_axi_arprot (3'b000),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata  (rdata),
        .s00_axi_rresp  (rresp),
        .s00_axi_rvalid (rvalid),
        .s00_axi_rready (rready)
    );

    // ---- proste taski BFM AXI4-Lite ----
    task automatic axi_write(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
        begin
            @(posedge clk);
            awaddr <= addr; awvalid <= 1'b1;
            wdata  <= data; wstrb <= 4'hF; wvalid <= 1'b1;
            bready <= 1'b1;
            // czekaj na przyjecie adresu i danych
            fork
                begin wait(awready); @(posedge clk); awvalid <= 1'b0; end
                begin wait(wready);  @(posedge clk); wvalid  <= 1'b0; end
            join
            wait(bvalid); @(posedge clk); bready <= 1'b0;
        end
    endtask

    task automatic axi_read(input [ADDR_W-1:0] addr, output [DATA_W-1:0] data);
        begin
            @(posedge clk);
            araddr <= addr; arvalid <= 1'b1; rready <= 1'b1;
            wait(arready); @(posedge clk); arvalid <= 1'b0;
            wait(rvalid);  data = rdata; @(posedge clk); rready <= 1'b0;
        end
    endtask

    // ---- scenariusz ----
    integer fd, code, i, n;
    logic [15:0] hexval;
    logic [11:0] sample;
    logic [DATA_W-1:0] status, result;

    initial begin
        awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        awaddr=0; wdata=0; wstrb=0; araddr=0;
        aresetn = 0;
        repeat (10) @(posedge clk);
        aresetn = 1;
        repeat (5) @(posedge clk);

        // soft reset rdzenia
        axi_write(CTRL, 32'h1);
        repeat (20) @(posedge clk);

        // strumieniowanie probek z pliku
        fd = $fopen(DATA_FILE, "r");
        if (fd == 0) begin
            $display("BLAD: nie mozna otworzyc %s", DATA_FILE);
            $finish;
        end
        n = 0;
        while (!$feof(fd) && n < MAX_SAMPLES) begin
            code = $fscanf(fd, "%h\n", hexval);
            if (code == 1) begin
                sample = hexval[11:0];
                axi_write(SAMPLE, {20'b0, sample});
                n++;
            end
        end
        $fclose(fd);
        $display("Wyslano %0d probek.", n);

        // zatrzask wyniku + zezwolenie na diode
        axi_write(CTRL, 32'h6);   // bit1 latch, bit2 but_enable
        repeat (10) @(posedge clk);

        axi_read(STATUS, status);
        axi_read(RESULT, result);
        $display("STATUS=0x%08h (valid=%0d)", status, status[0]);
        $display("RESULT=%0d  (0=other,1=on,2=off)", result[1:0]);
        $display("LED0=%0b", led0);

        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
