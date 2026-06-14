//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   convert_to_signed
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Converter from unsigned to signed arrays
 */
//////////////////////////////////////////////////////////////////////////////
 import ap_parameters::*;
module convert_to_signed (
    input  logic [NN_DATA_WIDTH-1:0] unsigned_vector [NN_ARRAY_WIDTH-1:0],  
    output logic signed [NN_DATA_WIDTH-1:0] signed_vector [NN_ARRAY_WIDTH-1:0]  
);

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
    always_comb begin
        for (int i = 0; i < NN_ARRAY_WIDTH; i++) begin
            signed_vector[i] = signed'(unsigned_vector[i]);
        end
    end

endmodule