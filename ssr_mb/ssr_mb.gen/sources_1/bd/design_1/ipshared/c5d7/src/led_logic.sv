//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   led_logic
 Authors:       Mateusz Gibas, Kacper Ferdek
 Version:       1.2
 Last modified: 2024-08-29
 Coding style: safe, with FPGA sync reset
 Description:  control the state of the led
 */
//////////////////////////////////////////////////////////////////////////////


module led_logic(
    input  logic clk,          // clock
    input  logic rst,           // reset
    input  logic [1:0] speech_rec, // result of speach recognision 0(other), 1(on), 2(off) 
    input  logic but,           // switch
    output logic led0           // diode
);


//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

logic led0_nxt;

//------------------------------------------------------------------------------
// output register with sync reset
//------------------------------------------------------------------------------

always_ff @(posedge clk) begin
    if(rst)
        led0 <= '0;
    else
        led0 <= led0_nxt;
end

//------------------------------------------------------------------------------
// logic
//------------------------------------------------------------------------------

always_comb begin
    if(but) begin
        case(speech_rec) 
            2'b00: led0_nxt = led0;
            2'b01: led0_nxt = 1;
            2'b10: led0_nxt = 0;
            default: led0_nxt= led0;
        endcase
    end else
        led0_nxt= led0;
end

endmodule