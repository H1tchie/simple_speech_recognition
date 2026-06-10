`timescale 1ns/1ps
import ssr_pkg::*;
// Test jednostkowy: framing -> ramki FRAME_LEN, krok HOP, numeracja frame_id.
// nframes = 1 + (M-FRAME_LEN)/HOP. W Vivado: Set as Top.
module tb_framing;
  localparam int M = 1536;
  localparam int EXP_FRAMES = 1 + (M-FRAME_LEN)/HOP_LEN;   // 5
  logic clk=0,rst_n; always #5 clk=~clk;
  logic signed [15:0] sd; logic sv,sr,sl;
  logic signed [15:0] md; logic mv,mr,ml; logic [15:0] mu;

  framing dut(.clk,.rst_n,.s_axis_tdata(sd),.s_axis_tvalid(sv),.s_axis_tready(sr),
    .s_axis_tlast(sl),.m_axis_tdata(md),.m_axis_tvalid(mv),.m_axis_tready(mr),
    .m_axis_tlast(ml),.m_axis_tuser(mu));

  integer i, frames, in_frame_cnt, errs, exp_id;
  initial begin
    rst_n=0; sv=0; sl=0; sd=0; mr=1; errs=0; frames=0; in_frame_cnt=0; exp_id=0;
    repeat(4) @(negedge clk); rst_n=1; @(negedge clk);
    fork
      begin // feeder (respektuje ready)
        for(i=0;i<M;) begin if(sr) begin sd=$signed(i); sv=1; sl=(i==M-1); i=i+1; end else sv=0; @(negedge clk); end
        sv=0; sl=0;
      end
      begin // monitor wyjscia
        forever begin @(posedge clk); #1;
          if(mv && mr) begin
            in_frame_cnt = in_frame_cnt + 1;
            if(mu !== exp_id[15:0]) begin errs=errs+1; if(errs<=4) $display("  frame_id got=%0d exp=%0d",mu,exp_id); end
            if(ml) begin
              if(in_frame_cnt != FRAME_LEN) begin errs=errs+1; $display("  ramka %0d ma %0d probek (exp %0d)",frames,in_frame_cnt,FRAME_LEN); end
              frames=frames+1; in_frame_cnt=0; exp_id=exp_id+1;
            end
          end
        end
      end
    join_any
    // poczekaj az ostatnie ramki splyna
    repeat(2000) @(posedge clk);
    if(frames==EXP_FRAMES && errs==0) $display("PASS tb_framing (%0d ramek po %0d probek)",frames,FRAME_LEN);
    else $display("FAIL tb_framing: frames=%0d (exp %0d), errs=%0d",frames,EXP_FRAMES,errs);
    $finish;
  end
  initial begin #500us; $display("FAIL tb_framing: TIMEOUT"); $finish; end
endmodule
