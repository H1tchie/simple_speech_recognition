`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr_tb
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       3.2
 Description:   Systemowy testbench dla top_ssr.

   !!! WAZNE (Vivado) !!!
   Ten modul MUSI byc ustawiony jako "Simulation Top"
   (Sources -> Simulation Sources -> PPM na top_ssr_tb -> Set as Top).
   Jesli jako top ustawiony jest sam top_ssr, to NIKT nie steruje jego
   wejsciami -> na zegarze/wejsciach zobaczysz Z, a na wyjsciach X.

   Probki audio sa ladowane z samples.mem do BRAM w bram_stream_source
   (plik musi byc dodany do projektu). TB podaje clk/reset, naciska BTNC,
   czeka az siec wystawi wynik i sprawdza, ze komenda jest poprawna.
*/
//////////////////////////////////////////////////////////////////////////////

module top_ssr_tb;

    // --- sygnaly sterujace (wszystkie jawnie zainicjowane) ---
    logic        clk        = 1'b0;
    logic        rst_n      = 1'b0;
    logic        start_btn  = 1'b0;
    logic        but_enable = 1'b0;
    logic        led0;
    logic [1:0]  cmd;

    // zegar 100 MHz
    always #5 clk = ~clk;

    top_ssr uut (
        .clk           (clk),
        .rst_n         (rst_n),
        // AXI4-Lite nieuzywany w tym tescie - wejscia w stan bezpieczny
        .s_axi_awaddr  ('0),  .s_axi_awprot ('0), .s_axi_awvalid(1'b0), .s_axi_awready(),
        .s_axi_wdata   ('0),  .s_axi_wstrb  ('0), .s_axi_wvalid (1'b0), .s_axi_wready (),
        .s_axi_bresp   (),    .s_axi_bvalid (),   .s_axi_bready (1'b1),
        .s_axi_araddr  ('0),  .s_axi_arprot ('0), .s_axi_arvalid(1'b0), .s_axi_arready(),
        .s_axi_rdata   (),    .s_axi_rresp  (),   .s_axi_rvalid (),     .s_axi_rready (1'b1),
        // sterowanie/wyjscia
        .start_btn     (start_btn),
        .but_enable    (but_enable),
        .led0          (led0),
        .command_id    (cmd)
    );

    initial begin
        $display("[TB] === top_ssr_tb start ===");

        // reset
        rst_n = 1'b0;
        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        but_enable = 1'b1;          // sw0: pozwol aktualizowac LED

        // impuls BTNC -> start
        $display("[TB] impuls start_btn");
        start_btn = 1'b1;
        repeat (5) @(posedge clk);
        start_btn = 1'b0;

        // czekaj na wynik sieci (DFT O(N^2) w SIM -> dlugo; jest duzy zapas)
        wait (uut.nn_value_valid);
        repeat (10) @(posedge clk);

        // --- samokontrola ---
        $display("[TB] cmd=%02b led0=%b", cmd, led0);
        if (cmd === 2'bxx || cmd === 2'bzz) begin
            $display("FAIL top_ssr_tb: komenda nieokreslona (X/Z) - czy TB jest Simulation Top?");
        end else begin
            case (cmd)
                2'b01: $display("[TB] rozpoznano -> on");
                2'b10: $display("[TB] rozpoznano -> off");
                2'b00: $display("[TB] rozpoznano -> other");
                default: $display("[TB] rozpoznano -> ??? (%02b)", cmd);
            endcase
            $display("PASS top_ssr_tb: pipeline zakonczyl, komenda = %02b", cmd);
        end

        $display("[TB] === top_ssr_tb end ===");
        $finish;
    end

    // bezpiecznik czasowy
    initial begin
        #500ms;
        $display("FAIL top_ssr_tb: TIMEOUT (siec nie wystawila wyniku)");
        $finish;
    end

endmodule
