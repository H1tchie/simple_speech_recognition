`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: mfcc = log2(LZC) energii mel -> DCT (Q5.10).
// W Vivado: ustaw ten modul jako Simulation Top. Wymaga dct_coeffs.mem w projekcie.
module tb_mfcc;
  localparam int NM = N_MELS;   // 26
  localparam int NC = N_MFCC;   // 13
  logic clk=0,rst_n; always #5 clk=~clk;
  logic [31:0] sd; logic sv,sr,sl; logic [15:0] su;
  logic signed [15:0] md; logic mv,mr,ml; logic [15:0] mu;

  mfcc dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.s_axis_tuser(su),.m_axis_tdata(md),.m_axis_tvalid(mv),
    .m_axis_tready(mr),.m_axis_tlast(ml),.m_axis_tuser(mu));

  function automatic signed [15:0] sat16(input signed [31:0] v);
    if (v>32767) return 16'sd32767; else if (v<-32768) return -16'sd32768; else return v[15:0];
  endfunction
  // log2_approx 1:1 jak mfcc.sv (Q5.10)
  function automatic signed [15:0] log2approx(input logic [31:0] x);
    integer msb,b; logic [31:0] mant; logic [15:0] r;
    begin
      if (x==0) return 16'sd0;
      msb=0; for (b=0;b<32;b=b+1) if (x[b]) msb=b;   // najwyzszy ustawiony bit (bez break)
      if (msb>0) mant = ((x-(1<<msb))<<10) >> msb; else mant=0;
      r = (msb<<10) | (mant & 16'h03FF);
      return r;
    end
  endfunction

  logic signed [15:0] dctrom [0:NC*NM-1];
  logic [31:0] mel [0:NM-1];
  logic signed [15:0] logb [0:NM-1];
  logic signed [15:0] exp [0:NC-1];
  integer i,c,m,o,errs; logic signed [47:0] acc;
  initial begin
    $readmemh("dct_coeffs.mem",dctrom);
    for (m=0;m<NM;m=m+1) mel[m] = (m+1)*37000 + 12345;   // pseudo-energie
    for (m=0;m<NM;m=m+1) logb[m] = log2approx(mel[m]);
    for (c=0;c<NC;c=c+1) begin acc=0;
      for (m=0;m<NM;m=m+1) acc = acc + ((logb[m]*dctrom[c*NM+m]) >>> 15);
      exp[c] = sat16(acc); end
    rst_n=0; sv=0; sl=0; sd=0; su=0; mr=1; errs=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin for(i=0;i<NM;) begin if(sr) begin sd=mel[i]; sv=1; sl=(i==NM-1); i=i+1; end else sv=0; @(negedge clk); end sv=0; sl=0; end
      begin o=0; while(o<NC) begin @(posedge clk); #1; if(mv&&mr) begin
        if(md!==exp[o]) begin errs=errs+1; if(errs<=5) $display("  mfcc[%0d] got=%0d exp=%0d",o,md,exp[o]); end o=o+1; end end end
    join
    if(errs==0) $display("PASS tb_mfcc (%0d wspolczynnikow)",NC);
    else        $display("FAIL tb_mfcc: %0d/%0d niezgodnosci",errs,NC);
    $finish;
  end
  initial begin #200us; $display("FAIL tb_mfcc: TIMEOUT"); $finish; end
endmodule
