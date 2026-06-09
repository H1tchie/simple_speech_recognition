`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: feature_aggregator -> 13 mean + 13 std (Q5.10).
// mean=trunc(sum/N), var=trunc(sumsq/N)-mean^2 (>=0), std=isqrt(var). W Vivado: Set as Top.
module tb_feature_aggregator;
  localparam int NC = N_MFCC;        // 13
  localparam int NF = 6;             // liczba ramek
  logic clk=0,rst_n; always #5 clk=~clk;
  logic signed [15:0] sd; logic sv,sr,sl; logic flush;
  logic signed [15:0] md; logic mv,mr,ml;

  feature_aggregator dut(.clk,.rst_n,.flush(flush),
    .s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),.s_axis_tlast(sl),
    .m_axis_tdata(md),.m_axis_tvalid(mv),.m_axis_tready(mr),.m_axis_tlast(ml));

  function automatic signed [15:0] sat16(input signed [31:0] v);
    if (v>32767) return 16'sd32767; else if (v<-32768) return -16'sd32768; else return v[15:0];
  endfunction
  function automatic signed [31:0] tdiv(input signed [31:0] a, input integer b);
    return a / b;   // SV: dzielenie signed obcina do zera
  endfunction
  function automatic logic [23:0] isqrt48(input logic [47:0] x);
    logic [47:0] rem,root,bit_v; integer i;
    begin rem=x; root=0; bit_v=48'h4000_0000_0000;
      for(i=0;i<24;i=i+1) begin
        if(rem>=root+bit_v) begin rem=rem-(root+bit_v); root=(root>>1)+bit_v; end
        else root=root>>1;
        bit_v=bit_v>>2; end
      return root[23:0]; end
  endfunction

  logic signed [15:0] mfcc_v [0:NF-1][0:NC-1];
  logic signed [15:0] exp [0:2*NC-1];
  integer f,c,o,errs; logic signed [31:0] s; logic [47:0] sq; logic signed [31:0] mean,ex2,var_s,d;
  initial begin
    for(f=0;f<NF;f=f+1) for(c=0;c<NC;c=c+1)
      mfcc_v[f][c] = $signed(((f*131+c*977+7)%8000)) - 4000;
    for(c=0;c<NC;c=c+1) begin s=0; sq=0;
      for(f=0;f<NF;f=f+1) begin d=mfcc_v[f][c]; s=s+d; sq=sq+$unsigned(d*d); end
      mean=tdiv(s,NF); ex2=sq/NF; var_s=ex2-mean*mean; if(var_s<0) var_s=0;
      exp[c]=sat16(mean); exp[NC+c]=sat16($signed({1'b0,isqrt48({16'b0,var_s[31:0]})})); end
    rst_n=0; sv=0; sl=0; sd=0; flush=0; mr=1; errs=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    // podaj NF ramek po NC wspolczynnikow
    for(f=0;f<NF;f=f+1) begin
      for(c=0;c<NC;) begin if(sr) begin sd=mfcc_v[f][c]; sv=1; sl=(c==NC-1); c=c+1; end else sv=0; @(negedge clk); end
    end
    sv=0; sl=0; @(negedge clk);
    flush=1; @(negedge clk); flush=0;
    o=0; while(o<2*NC) begin @(posedge clk); #1; if(mv&&mr) begin
      if(md!==exp[o]) begin errs=errs+1; if(errs<=6) $display("  feat[%0d] got=%0d exp=%0d",o,md,exp[o]); end o=o+1; end end
    if(errs==0) $display("PASS tb_feature_aggregator (%0d cech)",2*NC);
    else        $display("FAIL tb_feature_aggregator: %0d/%0d niezgodnosci",errs,2*NC);
    $finish;
  end
  initial begin #100us; $display("FAIL tb_feature_aggregator: TIMEOUT"); $finish; end
endmodule
