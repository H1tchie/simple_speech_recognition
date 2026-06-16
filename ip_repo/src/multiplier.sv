//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   multiplier
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       1.0
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  Simple multiplying module
 */
/////////////////////////////////////////////////////////////////////////////
module multiplier (
    input logic clk,            
    input logic rst,            
    input logic [31:0] a,       
    input logic [15:0] b,       
    output logic [31:0] p
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
logic [47:0] product;
logic [47:0] product_nxt;
logic [31:0] p_nxt;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------
always_ff @(posedge clk) begin
    if (rst) begin
        p <= 32'd0;
        product <= 48'd0;    
    end else begin
        p <= p_nxt;
        product <= product_nxt;    
    end
end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------
always_comb begin
    product_nxt = a * b;
    p_nxt = product[47:16];  
end

endmodule
