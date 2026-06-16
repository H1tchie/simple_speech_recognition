//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   unwrapper
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Uncombine data from frames to simple wire for FFT performance
 */
//////////////////////////////////////////////////////////////////////////////
import ap_parameters::*;
module zero_padding (
    input  logic [ADC_DATA_WIDTH-1:0] data_in,   
    output logic [FFT_DATA_WIDTH-1:0] data_out   
);

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
always_comb begin
    // Zero-padding: add 4(can be changed it depends from fft module and adc data) zeros to MSB
    data_out = {4'b0000, data_in};
end

endmodule