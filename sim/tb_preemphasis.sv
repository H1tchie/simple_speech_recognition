`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: preemphasis  y[n] = sat16((x[n]<<15 - 31785*x[n-1]) >>> 15)
module tb_preemphasis;
  localparam int N = 64;
  localparam int ALPHA = 16'h7C29;        // 0.97 w Q1.15 = 31785
  logic clk=0,rst_n; always #5 clk=~clk;
  logic signed [15:0] sd; logic sv,sr,sl;
  logic signed [15:0] md; logic mv,mr,ml;

  preemphasis dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.m_axis_tdata(md),.m_axis_tvalid(mv),.m_axis_tready(mr),.m_axis_tlast(ml));

  function automatic signed [15:0] sat16(input signed [31:0] v);
    if (v>32767) return 16'sd32767; else if (v<-32768) return -16'sd32768; else return v[15:0];
  endfunction

  logic signed [15:0] x [0:N-1];
  logic signed [15:0] exp [0:N-1];
  integer i,o,errs; logic signed [31:0] yfull; logic signed [15:0] xprev;

  initial begin
    // wektor wejsciowy (deterministyczny pseudoszum)
    xprev=0;
    for(i=0;i<N;i=i+1) x[i] = $signed((i*2999 + 131) % 40000) - 20000;
    for(i=0;i<N;i=i+1) begin
      yfull = (x[i] <<< 15) - ALPHA*xprev;
      exp[i] = sat16(yfull >>> 15);
      xprev = x[i];
    end
    rst_n=0; sv=0; sl=0; sd=0; mr=1; errs=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin // master
        for(i=0;i<N;) begin
          if(sr) begin sd=x[i]; sv=1; sl=(i==N-1); i=i+1; end else sv=0;
          @(negedge clk);
        end
        sv=0; sl=0;
      end
      begin // monitor
        o=0;
        while(o<N) begin @(posedge clk); #1;
          if(mv && mr) begin
            if(md!==exp[o]) begin errs=errs+1;
              if(errs<=5) $display("  [%0d] got=%0d exp=%0d",o,md,exp[o]); end
            o=o+1;
          end
        end
      end
    join
    if(errs==0) $display("PASS tb_preemphasis (%0d probek)",N);
    else        $display("FAIL tb_preemphasis: %0d/%0d niezgodnosci",errs,N);
    $finish;
  end
  initial begin #100us; $display("FAIL tb_preemphasis: TIMEOUT"); $finish; end
endmodule
