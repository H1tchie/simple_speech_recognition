//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   ssr_core
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.0
 Last modified: 2025
 Description:   Rdzen rozpoznawania mowy BEZ ADC i bez mikrofonu.
                Probki audio sa podawane z zewnatrz (z MicroBlaze przez
                AXI4-Lite) jako sample_in + sample_valid.
                Lancuch: top_ap_axi -> top_nn -> led_logic.
                Wyjscia: value (2 bity: 00=other, 01=on, 10=off) oraz led0.
 */
//////////////////////////////////////////////////////////////////////////////
module ssr_core(
    input  logic clk,
    input  logic rst,
    input  logic [11:0] sample_in,     // probka audio z pamieci na plytce
    input  logic sample_valid,         // strob nowej probki
    input  logic but,                  // zezwolenie na zmiane stanu diody
    output logic [1:0] value,          // wynik klasyfikacji
    output logic led0                  // dioda
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
logic signed [15:0] features [25:0];

//------------------------------------------------------------------------------
// module instances
//------------------------------------------------------------------------------
top_ap_axi u_top_ap(
    .clk,
    .rst,
    .adc_data(sample_in),
    .sample_valid(sample_valid),
    .output_vector(features)
);
top_nn u_top_nn(
    .clk,
    .rst,
    .input_vector(features),
    .output_value(value)
);
led_logic u_led_logic(
    .clk,
    .rst,
    .led0,
    .but,
    .speech_rec(value)
);

endmodule
