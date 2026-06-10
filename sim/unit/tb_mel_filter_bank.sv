`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: mel_filter_bank  mel[m] = sum_k (|X[k]|*coeff[m,k]) >> 15
module tb_mel_filter_bank;
  localparam int NB = N_BINS;     // 257
  localparam int NM = N_MELS;     // 26
  logic clk=0,rst_n; always #5 clk=~clk;
  logic [15:0] sd; logic sv,sr,sl; logic [15:0] su;
  logic [31:0] md; logic mv,mr,ml; logic [15:0] mu;

  mel_filter_bank dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.s_axis_tuser(su),.m_axis_tdata(md),.m_axis_tvalid(mv),
    .m_axis_tready(mr),.m_axis_tlast(ml),.m_axis_tuser(mu));

  logic [15:0] coeff [0:NM*NB-1];
  logic [15:0] mag [0:NB-1];
  logic [31:0] exp [0:NM-1];
  integer i,m,k,o,errs; logic [63:0] acc;
  initial begin
    $readmemh("mel_bank_dense.mem",coeff);
    for(k=0;k<NB;k=k+1) mag[k] = (k*257+13) % 32768;   // pseudo-widmo
    for(m=0;m<NM;m=m+1) begin acc=0;
      for(k=0;k<NB;k=k+1) acc = acc + ((mag[k]*coeff[m*NB+k]) >> 15);
      exp[m]=acc[31:0]; end
    rst_n=0; sv=0; sl=0; sd=0; su=0; mr=1; errs=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin for(i=0;i<NB;) begin if(sr) begin sd=mag[i]; sv=1; sl=(i==NB-1); i=i+1; end else sv=0; @(negedge clk); end sv=0; sl=0; end
      begin o=0; while(o<NM) begin @(posedge clk); #1; if(mv&&mr) begin
        if(md!==exp[o]) begin errs=errs+1; if(errs<=5) $display("  mel[%0d] got=%0d exp=%0d",o,md,exp[o]); end o=o+1; end end end
    join
    if(errs==0) $display("PASS tb_mel_filter_bank (%0d filtrow)",NM);
    else        $display("FAIL tb_mel_filter_bank: %0d/%0d niezgodnosci",errs,NM);
    $finish;
  end
  initial begin #500us; $display("FAIL tb_mel_filter_bank: TIMEOUT"); $finish; end
endmodule
