`timescale 1ns/1ps
//////////////////////////////////////////////////////////////////////////////
/*
 Testbench end-to-end dla top_system.
 Wgrywa samples.mem (16000 probek Q1.15), przepuszcza przez caly lancuch
 DSP + siec neuronowa i wyswietla wynik klasyfikacji.

 Uzycie:
   - Wygeneruj samples.mem skryptem gen_mem.py
   - Ustaw sciezki ponizej
   - Uruchom symulacje, poczekaj na "*** WYNIK ***"
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;
import nn_parameters::*;

module top_system_tb;

    logic clk, rst;

    // AXI-Stream wejscie audio
    logic signed [SAMPLE_W-1:0] s_tdata;
    logic                       s_tvalid;
    logic                       s_tready;
    logic                       s_tlast;

    // Wyjscie klasyfikatora
    logic [1:0] output_value;
    logic       output_valid;
    logic       busy;

    // Pamiec na probki
    logic signed [SAMPLE_W-1:0] samples [N_SAMPLES-1:0];

    integer i;

    // -----------------------------------------------------------------------
    // DUT
    // -----------------------------------------------------------------------
    top_system uut (
        .clk,
        .rst,
        .s_tdata,
        .s_tvalid,
        .s_tready,
        .s_tlast,
        .output_value,
        .output_valid,
        .busy
    );

    // Zegar 100 MHz
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Task: wyslij jedno nagranie i czekaj na wynik
    // -----------------------------------------------------------------------
    task automatic run_audio(input string mem_file, input string label);
        // Wczytaj probki
        $readmemh("C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/samples_on.mem",  samples);

        // Reset calego systemu
        rst = 1'b1;
        repeat(10) @(posedge clk);
        rst = 1'b0;
        repeat(2) @(posedge clk);

        $display("[%0t] Start: %s", $time, label);

        // Wyslij 16000 probek - poprawny handshake AXI-Stream
        for (i = 0; i < N_SAMPLES; i = i + 1) begin
            s_tdata  = samples[i];
            s_tvalid = 1'b1;
            s_tlast  = (i == N_SAMPLES - 1) ? 1'b1 : 1'b0;
            @(posedge clk);
            while (!s_tready) @(posedge clk);
        end
        s_tvalid = 1'b0;
        s_tlast  = 1'b0;
        s_tdata  = '0;

        // Czekaj na wynik z timeoutem (200ms symulacji)
        fork
            begin
                wait (output_valid == 1'b1);
            end
            begin
                #200_000_000;
                $display("!!! TIMEOUT: system nie zakonczyl w 200ms !!!");
                $stop;
            end
        join_any
        disable fork;

        // Wyswietl wynik
        repeat(2) @(posedge clk);
        $display("*** WYNIK: output_value=%0d  (%s)  <- %s ***",
                 output_value,
                 output_value == 2'd1 ? "ON" :
                 output_value == 2'd2 ? "OFF" : "OTHER",
                 label);
        $display("---");

    endtask

    // -----------------------------------------------------------------------
    // Glowny blok testowy
    // -----------------------------------------------------------------------
    initial begin
        clk      = 0;
        rst      = 1;
        s_tvalid = 0;
        s_tdata  = 0;
        s_tlast  = 0;

        // ---------------------------------------------------------------
        // Dodaj tutaj testy - jeden wywolanie run_audio na nagranie
        // Pierwszy argument: sciezka do pliku .mem (probki Q1.15 hex)
        // Drugi argument:    opis co oczekujesz (do wyswietlenia)
        // ---------------------------------------------------------------

        run_audio(
            "C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/samples_on.mem",
            "ON -> oczekiwane output=1"
        );

        run_audio(
            "C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/samples_off.mem",
            "OFF -> oczekiwane output=2"
        );

        run_audio(
            "C:/Users/ferdz/Desktop/SDUP/sim/python/generated_files/samples_oth.mem",
            "OTHER -> oczekiwane output=0"
        );

        $display("=== Wszystkie testy zakonczone ===");
        $stop;
    end

endmodule : top_system_tb
