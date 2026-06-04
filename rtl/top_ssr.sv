//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_ssr
 Authors:       Kacper Ferdek, Mateusz Gibas
 Version:       3.0
 Last modified: 2026-01
 Description:   Top-level IPcore Simple Speech Recognition.

                Pelny lancuch AXI4-Stream zgodny z konspektem
                (sekcja 3.2):

                BRAM samples -> preemphasis -> framing -> window
                  -> FFT (N=512) -> mel_filter_bank (N_MELS=26)
                  -> mfcc (log + DCT, N_MFCC=13) -> feature_aggregator
                  -> top_nn_axis -> output

                Sterowanie przez AXI4-Lite slave (sekcja 3.1):
                  zapisuje CTRL.start -> rozpoczyna przetwarzanie
                  polluje STATUS.done -> czeka na koniec
                  czyta RESULT -> 2-bit ID komendy

                W wersji stand-alone Basys3 ten sam start jest tez
                dostepny przez BTNC.
*/
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module top_ssr (
    input  logic clk,
    input  logic rst_n,

    // ====== AXI4-Lite control ======
    input  logic [3:0]  s_axi_awaddr,
    input  logic [2:0]  s_axi_awprot,
    input  logic        s_axi_awvalid,
    output logic        s_axi_awready,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    input  logic        s_axi_wvalid,
    output logic        s_axi_wready,
    output logic [1:0]  s_axi_bresp,
    output logic        s_axi_bvalid,
    input  logic        s_axi_bready,
    input  logic [3:0]  s_axi_araddr,
    input  logic [2:0]  s_axi_arprot,
    input  logic        s_axi_arvalid,
    output logic        s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0]  s_axi_rresp,
    output logic        s_axi_rvalid,
    input  logic        s_axi_rready,

    // ====== Stand-alone control (BTNC) ======
    input  logic        start_btn,
    input  logic        but_enable,   // sw0: enable LED update

    // ====== Outputs ======
    output logic        led0,
    output logic [1:0]  command_id    // do podpiecia np. na switche / 7-seg
);

    // ============ AXI4-Lite ============
    logic        axi_start;
    logic        axi_soft_reset;
    logic [31:0] axi_config;
    logic        ipcore_busy;
    logic        ipcore_done;
    logic [31:0] ipcore_result;

    axi4lite_regs u_axi (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr,  .s_axi_awprot,  .s_axi_awvalid, .s_axi_awready,
        .s_axi_wdata,   .s_axi_wstrb,   .s_axi_wvalid,  .s_axi_wready,
        .s_axi_bresp,   .s_axi_bvalid,  .s_axi_bready,
        .s_axi_araddr,  .s_axi_arprot,  .s_axi_arvalid, .s_axi_arready,
        .s_axi_rdata,   .s_axi_rresp,   .s_axi_rvalid,  .s_axi_rready,
        .start(axi_start),
        .soft_reset(axi_soft_reset),
        .config_reg(axi_config),
        .busy(ipcore_busy),
        .done(ipcore_done),
        .error(1'b0),
        .result(ipcore_result)
    );

    // Edge detect na BTNC + OR z AXI start
    logic start_btn_d, start_btn_edge;
    always_ff @(posedge clk) begin
        if (!rst_n) start_btn_d <= 1'b0;
        else        start_btn_d <= start_btn;
    end
    assign start_btn_edge = start_btn & ~start_btn_d;
    wire start_any = axi_start | start_btn_edge;

    wire local_rst_n = rst_n & ~axi_soft_reset;

    // ============ Pipeline streams ============
    // BRAM -> preemphasis
    logic signed [SAMPLE_WIDTH-1:0] s0_data;
    logic s0_valid, s0_ready, s0_last;

    // preemphasis -> framing
    logic signed [SAMPLE_WIDTH-1:0] s1_data;
    logic s1_valid, s1_ready, s1_last;

    // framing -> window
    logic signed [SAMPLE_WIDTH-1:0] s2_data;
    logic [15:0] s2_user;
    logic s2_valid, s2_ready, s2_last;

    // window -> fft
    logic signed [SAMPLE_WIDTH-1:0] s3_data;
    logic [15:0] s3_user;
    logic s3_valid, s3_ready, s3_last;

    // fft -> mel
    logic [SAMPLE_WIDTH-1:0] s4_data;
    logic [15:0] s4_user;
    logic s4_valid, s4_ready, s4_last;

    // mel -> mfcc
    logic [MEL_ACC_WIDTH-1:0] s5_data;
    logic [15:0] s5_user;
    logic s5_valid, s5_ready, s5_last;

    // mfcc -> feature_aggregator
    logic signed [MFCC_WIDTH-1:0] s6_data;
    logic [15:0] s6_user;
    logic s6_valid, s6_ready, s6_last;

    // feature_aggregator -> NN
    logic signed [SAMPLE_WIDTH-1:0] s7_data;
    logic s7_valid, s7_ready, s7_last;

    // NN -> output
    logic [SAMPLE_WIDTH-1:0] s8_data;
    logic s8_valid, s8_ready, s8_last;

    // Source status
    logic src_busy, src_done;

    // ============ Module instances ============
    bram_stream_source #(.INIT_FILE("samples.mem")) u_src (
        .clk, .rst_n(local_rst_n),
        .start(start_any),
        .busy(src_busy), .done(src_done),
        .m_axis_tdata(s0_data),
        .m_axis_tvalid(s0_valid),
        .m_axis_tready(s0_ready),
        .m_axis_tlast(s0_last)
    );

    preemphasis u_pe (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s0_data),
        .s_axis_tvalid(s0_valid),
        .s_axis_tready(s0_ready),
        .s_axis_tlast(s0_last),
        .m_axis_tdata(s1_data),
        .m_axis_tvalid(s1_valid),
        .m_axis_tready(s1_ready),
        .m_axis_tlast(s1_last)
    );

    framing u_fr (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s1_data),
        .s_axis_tvalid(s1_valid),
        .s_axis_tready(s1_ready),
        .s_axis_tlast(s1_last),
        .m_axis_tdata(s2_data),
        .m_axis_tvalid(s2_valid),
        .m_axis_tready(s2_ready),
        .m_axis_tlast(s2_last),
        .m_axis_tuser(s2_user)
    );

    window #(.ROM_FILE("window_hamming_512.mem")) u_win (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s2_data),
        .s_axis_tvalid(s2_valid),
        .s_axis_tready(s2_ready),
        .s_axis_tlast(s2_last),
        .s_axis_tuser(s2_user),
        .m_axis_tdata(s3_data),
        .m_axis_tvalid(s3_valid),
        .m_axis_tready(s3_ready),
        .m_axis_tlast(s3_last),
        .m_axis_tuser(s3_user)
    );

    fft_wrapper #(.SIM_MODE(1)) u_fft (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s3_data),
        .s_axis_tvalid(s3_valid),
        .s_axis_tready(s3_ready),
        .s_axis_tlast(s3_last),
        .s_axis_tuser(s3_user),
        .m_axis_tdata(s4_data),
        .m_axis_tvalid(s4_valid),
        .m_axis_tready(s4_ready),
        .m_axis_tlast(s4_last),
        .m_axis_tuser(s4_user)
    );

    mel_filter_bank #(.COEFF_FILE("mel_bank_dense.mem")) u_mel (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s4_data),
        .s_axis_tvalid(s4_valid),
        .s_axis_tready(s4_ready),
        .s_axis_tlast(s4_last),
        .s_axis_tuser(s4_user),
        .m_axis_tdata(s5_data),
        .m_axis_tvalid(s5_valid),
        .m_axis_tready(s5_ready),
        .m_axis_tlast(s5_last),
        .m_axis_tuser(s5_user)
    );

    mfcc #(.DCT_COEFF_FILE("dct_coeffs.mem")) u_mfcc (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s5_data),
        .s_axis_tvalid(s5_valid),
        .s_axis_tready(s5_ready),
        .s_axis_tlast(s5_last),
        .s_axis_tuser(s5_user),
        .m_axis_tdata(s6_data),
        .m_axis_tvalid(s6_valid),
        .m_axis_tready(s6_ready),
        .m_axis_tlast(s6_last),
        .m_axis_tuser(s6_user)
    );

    // ----- Detektor oproznienia potoku -----
    // flush agregatora dopiero gdy WSZYSTKIE ramki przeszly przez MFCC.
    // FFT ma latencje ~131k cykli/ramke, wiec src_done (koniec strumienia z
    // BRAM) przychodzi duzo wczesniej niz ostatnie MFCC. Liczymy ramki
    // wchodzace do sciezki FFT (s2_last) i konczace MFCC (s6_last); gdy obie
    // liczby zrownaja sie i potok jest bezczynny przez DRAIN_CYCLES, pulsujemy.
    localparam int DRAIN_CYCLES = 4096;
    logic        src_done_seen, agg_flushed, agg_flush;
    logic [15:0] frames_in, frames_out;
    logic [12:0] idle_cnt;
    always_ff @(posedge clk) begin
        if (!local_rst_n) begin
            src_done_seen <= 1'b0; agg_flushed <= 1'b0; agg_flush <= 1'b0;
            frames_in <= '0; frames_out <= '0; idle_cnt <= '0;
        end else begin
            agg_flush <= 1'b0;
            if (src_done) src_done_seen <= 1'b1;
            if (s2_valid && s2_ready && s2_last) frames_in  <= frames_in  + 1'b1;
            if (s6_valid && s6_ready && s6_last) frames_out <= frames_out + 1'b1;
            if (s1_valid || s2_valid || s6_valid || (frames_in != frames_out))
                idle_cnt <= '0;
            else if (src_done_seen && frames_in != 0)
                idle_cnt <= idle_cnt + 1'b1;
            if (!agg_flushed && src_done_seen && frames_in != 0 &&
                frames_in == frames_out && idle_cnt == DRAIN_CYCLES-1) begin
                agg_flush   <= 1'b1;
                agg_flushed <= 1'b1;
            end
        end
    end

    // Po oproznieniu potoku liczymy mean/std z zebranych ramek
    feature_aggregator u_agg (
        .clk, .rst_n(local_rst_n),
        .flush(agg_flush),
        .s_axis_tdata(s6_data),
        .s_axis_tvalid(s6_valid),
        .s_axis_tready(s6_ready),
        .s_axis_tlast(s6_last),
        .m_axis_tdata(s7_data),
        .m_axis_tvalid(s7_valid),
        .m_axis_tready(s7_ready),
        .m_axis_tlast(s7_last)
    );

    top_nn_axis u_nn (
        .clk, .rst_n(local_rst_n),
        .s_axis_tdata(s7_data),
        .s_axis_tvalid(s7_valid),
        .s_axis_tready(s7_ready),
        .s_axis_tlast(s7_last),
        .m_axis_tdata(s8_data),
        .m_axis_tvalid(s8_valid),
        .m_axis_tready(s8_ready),
        .m_axis_tlast(s8_last)
    );

    // ============ Wynik -> LED + AXI RESULT ============
    logic [1:0] nn_value;
    logic       nn_value_valid;

    always_ff @(posedge clk) begin
        if (!local_rst_n) begin
            nn_value       <= 2'b00;
            nn_value_valid <= 1'b0;
        end else if (s8_valid) begin
            nn_value       <= s8_data[1:0];
            nn_value_valid <= 1'b1;
        end
    end

    assign s8_ready = 1'b1;
    assign command_id = nn_value;

    // LED logic z istniejacego repo (bez zmian)
    led_logic u_led_logic (
        .clk,
        .rst(~local_rst_n),       // led_logic uzywa active-high reset
        .led0,
        .but(but_enable),
        .speech_rec(nn_value)
    );

    // Status do AXI
    assign ipcore_busy   = src_busy | s6_valid | s7_valid;
    assign ipcore_done   = nn_value_valid;
    assign ipcore_result = {30'd0, nn_value};

endmodule
