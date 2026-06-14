//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   framing_axi
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.0
 Last modified: 2025
 Coding style:  safe, with FPGA sync reset
 Description:   Wersja modulu "framing" sterowana sygnalem sample_valid.
                Identyczna numerycznie jak oryginal (ten sam bufor, ta sama
                kolejnosc), ale indeks ramki przesuwa sie TYLKO gdy
                sample_valid = 1. Dzieki temu probki moga byc dostarczane
                wolno, po jednej na transakcje AXI4-Lite (zamiast jedna na
                takt zegara, jak w wersji z ADC).
 */
//////////////////////////////////////////////////////////////////////////////
import ap_parameters::*;
module framing_axi (
    input  logic clk,
    input  logic rst,
    input  logic [ADC_DATA_WIDTH-1:0] sample_in,
    input  logic sample_valid,                                   // nowy sygnal
    output logic [ADC_DATA_WIDTH-1:0] frame_out [0:FRAME_ARRAY_WIDTH-1],
    output logic frame_ready
);
//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
    logic [ADC_DATA_WIDTH-1:0] frame_out_nxt [0:FRAME_ARRAY_WIDTH-1];
    logic [ADC_DATA_WIDTH-1:0] buffer [0:FRAME_ARRAY_WIDTH-1];
    logic [ADC_DATA_WIDTH-1:0] buffer_nxt [0:FRAME_ARRAY_WIDTH-1];
    logic [7:0] index;
    logic [7:0] index_nxt;
    logic frame_ready_nxt;
    integer i, k;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            index <= 8'd0;
            frame_ready <= 1'b0;
            for (i = 0; i < FRAME_ARRAY_WIDTH; i++) begin
                frame_out[i] <= 12'd0;
                buffer[i] <= 12'd0;
            end
        end else begin
            index <= index_nxt;
            frame_ready <= frame_ready_nxt;
            for (i = 0; i < FRAME_ARRAY_WIDTH; i++) begin
                frame_out[i] <= frame_out_nxt[i];
                buffer[i] <= buffer_nxt[i];
            end
        end
    end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
    always_comb begin
        index_nxt = index;
        frame_ready_nxt = 1'b0;
        for (k = 0; k < FRAME_ARRAY_WIDTH; k++) begin
            buffer_nxt[k] = buffer[k];
            frame_out_nxt[k] = frame_out[k];
        end
        // Probka jest pobierana tylko gdy host (MicroBlaze) zapisze nowa wartosc.
        if (sample_valid) begin
            buffer_nxt[index] = sample_in;
            if (index == 8'd63) begin
                index_nxt = 8'd0;
                frame_ready_nxt = 1'b1;
                for (k = 0; k < FRAME_ARRAY_WIDTH; k++) begin
                    frame_out_nxt[k] = buffer[k];
                end
            end else begin
                index_nxt = index + 8'd1;
            end
        end
    end

endmodule
