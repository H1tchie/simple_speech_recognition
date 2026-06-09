`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: window  out[i] = sat16((x[i]*win[i]) >>> 15), win = Q1.15 (Hamming)
module tb_window;
  localparam int N = 512;
  logic clk=0,rst_n; always #5 clk=~clk;
  logic signed [15:0] sd; logic sv,sr,sl; logic [15:0] su;
  logic signed [15:0] md; logic mv,mr,ml; logic [15:0] mu;

  window dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.s_axis_tuser(su),.m_axis_tdata(md),.m_axis_tvalid(mv),
    .m_axis_tready(mr),.m_axis_tlast(ml),.m_axis_tuser(mu));

  function automatic signed [15:0] sat16(input signed [31:0] v);
    if (v>32767) return 16'sd32767; else if (v<-32768) return -16'sd32768; else return v[15:0];
  endfunction

  logic [15:0] win [0:N-1];
  logic signed [15:0] x [0:N-1], exp [0:N-1];
  integer i,o,errs; logic signed [31:0] prod;
  initial begin
    $readmemh("window_hamming_512.mem",win);
    for(i=0;i<N;i=i+1) x[i] = $signed((i*1777+9)%50000)-25000;
    for(i=0;i<N;i=i+1) begin prod = x[i]*$signed({1'b0,win[i]}); exp[i]=sat16(prod>>>15); end
    rst_n=0; sv=0; sl=0; sd=0; su=0; mr=1; errs=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin for(i=0;i<N;) begin if(sr) begin sd=x[i]; sv=1; sl=(i==N-1); i=i+1; end else sv=0; @(negedge clk); end sv=0; sl=0; end
      begin o=0; while(o<N) begin @(posedge clk); #1; if(mv&&mr) begin
        if(md!==exp[o]) begin errs=errs+1; if(errs<=5) $display("  [%0d] got=%0d exp=%0d",o,md,exp[o]); end o=o+1; end end end
    join
    if(errs==0) $display("PASS tb_window (%0d probek)",N);
    else        $display("FAIL tb_window: %0d/%0d niezgodnosci",errs,N);
    $finish;
  end
  initial begin #200us; $display("FAIL tb_window: TIMEOUT"); $finish; end
endmodule
