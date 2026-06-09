`timescale 1ns/1ps
import ssr_pkg::*;
// Test funkcjonalny: fft_wrapper. Czysty kosinus o prazku K0 ->
// szczyt magnitudy w prazku K0 + normalizacja per-ramka (max == 32767).
// Wymaga twiddle_cos_512.mem / twiddle_sin_512.mem w projekcie. W Vivado: Set as Top.
module tb_fft_wrapper;
  localparam int K0 = 40;
  localparam int NB = N_BINS;     // 257
  real PI; 
  logic clk=0,rst_n; always #5 clk=~clk;
  logic signed [15:0] sd; logic sv,sr,sl; logic [15:0] su;
  logic [15:0] md; logic mv,mr,ml; logic [15:0] mu;

  fft_wrapper dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.s_axis_tuser(su),.m_axis_tdata(md),.m_axis_tvalid(mv),
    .m_axis_tready(mr),.m_axis_tlast(ml),.m_axis_tuser(mu));

  logic signed [15:0] frame [0:FRAME_LEN-1];
  integer i,o; integer peak_idx; logic [15:0] peak_val, last_val; integer errs;
  initial begin
    PI=3.14159265358979;
    for(i=0;i<FRAME_LEN;i=i+1)
      frame[i] = $rtoi(8000.0*$cos(2.0*PI*K0*i/FRAME_LEN));
    rst_n=0; sv=0; sl=0; sd=0; su=0; mr=1; errs=0; peak_idx=0; peak_val=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin for(i=0;i<FRAME_LEN;) begin if(sr) begin sd=frame[i]; sv=1; sl=(i==FRAME_LEN-1); i=i+1; end else sv=0; @(negedge clk); end sv=0; sl=0; end
      begin o=0; while(o<NB) begin @(posedge clk); #1; if(mv&&mr) begin
        if(md===16'hxxxx) errs=errs+1;
        if(md>peak_val) begin peak_val=md; peak_idx=o; end
        last_val=md; o=o+1; end end end
    join
    $display("  szczyt: prazek=%0d wartosc=%0d (oczekiwano prazek=%0d, max=32767)",peak_idx,peak_val,K0);
    if(peak_idx==K0 && peak_val==16'd32767 && errs==0)
      $display("PASS tb_fft_wrapper");
    else
      $display("FAIL tb_fft_wrapper: peak_idx=%0d peak_val=%0d errs=%0d",peak_idx,peak_val,errs);
    $finish;
  end
  initial begin #20ms; $display("FAIL tb_fft_wrapper: TIMEOUT"); $finish; end
endmodule
