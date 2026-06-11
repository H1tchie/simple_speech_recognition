//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       2.2
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:   top module of simple speach recognition project
 */
//////////////////////////////////////////////////////////////////////////////

module top_ssr(
    input logic clk,
    input logic rst,
    input logic but,
    inout wire scl,
    inout wire sda,
    output logic led0 
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

logic [1:0] value;
logic [11:0] adc_data;
logic signed [15:0] features [25:0];

//------------------------------------------------------------------------------
// module instances
//------------------------------------------------------------------------------

pmod_adc_ad7991 u_pmod_adc_ad7991(
    .clk,
    .rst,
    .sda,
    .scl,
    .adc_ch0_data(adc_data),
    .adc_ch1_data(),
    .adc_ch2_data(),
    .adc_ch3_data(),
    .i2c_ack_err()
);
top_ap u_top_ap(
    .clk,
    .rst,
    .adc_data,
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
