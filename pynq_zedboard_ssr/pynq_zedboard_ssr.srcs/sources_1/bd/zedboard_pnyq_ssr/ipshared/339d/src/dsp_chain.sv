//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   dsp_chain
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Laczy 8 modulow DSP w lancuch AXI4-Stream:
                framing -> window -> dft -> power -> mel -> log2 -> dct -> aggregator
                Wejscie : AXI-Stream probek Q1.15 (z BRAM lub TB)
                Wyjscie : AXI-Stream 26 cech int16 (do sieci)
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module dsp_chain (
    input  logic clk,
    input  logic rst,

    // --- wejscie: probki audio Q1.15 ---
    input  logic signed [SAMPLE_W-1:0]  s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,    // koniec nagrania

    // --- wyjscie: 26 cech int16 ---
    output logic signed [FEAT_W-1:0]    m_tdata,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FEATURES)-1:0] m_tuser
);

    // --- magistrale miedzy modulami ---
    // framing -> window
    logic signed [SAMPLE_W-1:0] fr_data;  logic fr_valid, fr_ready, fr_last;
    logic [$clog2(N_FRAMES)-1:0] fr_user;
    // window -> dft
    logic signed [SAMPLE_W-1:0] wn_data;  logic wn_valid, wn_ready, wn_last;
    logic [$clog2(N_FRAMES)-1:0] wn_user;
    // dft -> power
    logic signed [DFT_W-1:0] df_re, df_im; logic df_valid, df_ready, df_last;
    logic [$clog2(N_FRAMES)-1:0] df_user;
    // power -> mel
    logic [POWER_W-1:0] pw_data; logic pw_valid, pw_ready, pw_last;
    logic [$clog2(N_FRAMES)-1:0] pw_user;
    // mel -> log2
    logic [MEL_W-1:0] ml_data; logic ml_valid, ml_ready, ml_last;
    logic [$clog2(N_FRAMES)-1:0] ml_user;
    // log2 -> dct
    logic signed [LOG_W-1:0] lg_data; logic lg_valid, lg_ready, lg_last;
    logic [$clog2(N_FRAMES)-1:0] lg_user;
    // dct -> aggregator
    logic signed [MFCC_W-1:0] dc_data; logic dc_valid, dc_ready, dc_last;
    logic [$clog2(N_FRAMES)-1:0] dc_user;

    framing u_framing (
        .clk, .rst,
        .s_tdata(s_tdata), .s_tvalid(s_tvalid), .s_tready(s_tready), .s_tlast(s_tlast),
        .m_tdata(fr_data), .m_tvalid(fr_valid), .m_tready(fr_ready),
        .m_tlast(fr_last), .m_tuser(fr_user)
    );

    window u_window (
        .clk, .rst,
        .s_tdata(fr_data), .s_tvalid(fr_valid), .s_tready(fr_ready),
        .s_tlast(fr_last), .s_tuser(fr_user),
        .m_tdata(wn_data), .m_tvalid(wn_valid), .m_tready(wn_ready),
        .m_tlast(wn_last), .m_tuser(wn_user)
    );

    dft u_dft (
        .clk, .rst,
        .s_tdata(wn_data), .s_tvalid(wn_valid), .s_tready(wn_ready),
        .s_tlast(wn_last), .s_tuser(wn_user),
        .m_tdata_re(df_re), .m_tdata_im(df_im),
        .m_tvalid(df_valid), .m_tready(df_ready), .m_tlast(df_last), .m_tuser(df_user)
    );

    power u_power (
        .clk, .rst,
        .s_tdata_re(df_re), .s_tdata_im(df_im),
        .s_tvalid(df_valid), .s_tready(df_ready), .s_tlast(df_last), .s_tuser(df_user),
        .m_tdata(pw_data), .m_tvalid(pw_valid), .m_tready(pw_ready),
        .m_tlast(pw_last), .m_tuser(pw_user)
    );

    mel_filter u_mel (
        .clk, .rst,
        .s_tdata(pw_data), .s_tvalid(pw_valid), .s_tready(pw_ready),
        .s_tlast(pw_last), .s_tuser(pw_user),
        .m_tdata(ml_data), .m_tvalid(ml_valid), .m_tready(ml_ready),
        .m_tlast(ml_last), .m_tuser(ml_user)
    );

    log2_unit u_log2 (
        .clk, .rst,
        .s_tdata(ml_data), .s_tvalid(ml_valid), .s_tready(ml_ready),
        .s_tlast(ml_last), .s_tuser(ml_user),
        .m_tdata(lg_data), .m_tvalid(lg_valid), .m_tready(lg_ready),
        .m_tlast(lg_last), .m_tuser(lg_user)
    );

    dct_unit u_dct (
        .clk, .rst,
        .s_tdata(lg_data), .s_tvalid(lg_valid), .s_tready(lg_ready),
        .s_tlast(lg_last), .s_tuser(lg_user),
        .m_tdata(dc_data), .m_tvalid(dc_valid), .m_tready(dc_ready),
        .m_tlast(dc_last), .m_tuser(dc_user)
    );

    feature_aggregator u_agg (
        .clk, .rst,
        .s_tdata(dc_data), .s_tvalid(dc_valid), .s_tready(dc_ready),
        .s_tlast(dc_last), .s_tuser(dc_user),
        .m_tdata(m_tdata), .m_tvalid(m_tvalid), .m_tready(m_tready),
        .m_tlast(m_tlast), .m_tuser(m_tuser)
    );

endmodule : dsp_chain
