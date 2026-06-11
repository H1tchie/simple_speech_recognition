module top_ap(
    input logic clk,
    input logic rst,
    input logic [11:0] adc_data,
    output logic signed [15:0] output_vector [25:0]
);

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------
logic s_ready_res;
logic s_ready_mel;
logic m_valid_mel;
logic m_valid_res;
logic [15:0] mel_out [39:0];
logic [15:0] reshape_out [19:0];
logic [15:0] imag_out;
logic [15:0] real_out;
logic [31:0] magnitude;
//logic [11:0] emph_out;
logic [11:0] framed_out [63:0];
logic frame_ready;
logic window_ready;
logic wrapper_ready;
logic fft_ready;
logic [11:0] window_out [63:0];
logic [11:0] wrap_win;
logic [15:0] shift_win;
logic [15:0] mean;
logic [15:0] std;
logic [15:0] unsigned_vector [25:0];
logic valid_fifo;
logic frame_ready_1;

//------------------------------------------------------------------------------
// module instances
//------------------------------------------------------------------------------
/*pre_emphasis u_pre_emphasis(
    .clk,
    .rst,
    .sample_in(adc_data),
    .sample_out(emph_out)
);*/
framing u_framing(
    .clk,
    .rst,
    .sample_in(adc_data),
    .frame_out(framed_out),
    .frame_ready
);
windowing u_windowing(
    .clk,
    .rst,
    .frame_in(framed_out),
    .frame_ready,
    .window_ready,
    .windowed_frame(window_out)
);
unwrapper u_unwrapper(
    .clk,
    .rst,
    .window_ready,
    .wrapper_ready,
    .in(window_out),
    .out(wrap_win)
);
zero_padding u_zero_padding(
    .data_in(wrap_win),
    .data_out(shift_win)
);

FFT64 u_FFT64(
    .clock(clk),
    .reset(rst),
    .di_en(wrapper_ready),
    .di_re(shift_win),
    .di_im('0),
    .do_im(imag_out),
    .do_re(real_out),
    .do_en(fft_ready)
);

magnitude u_magnitude(
    .clk,
    .rst,
    .imag_part(imag_out),
    .real_part(real_out),
    .magnitude
);
/*framing_1 u_framing_1(
    .clk,
    .rst,
    .sample_in(magnitude),
    .frame_out(mel_out),
    .frame_ready(frame_ready_1)
);*/
mel_filter_bank u_mel_filter_bank(
    .clk,
    .reset(rst),
    .in(magnitude),
    .out(mel_out),
    .s_ready(s_ready_mel),
    .m_valid(m_valid_mel),
    .s_valid(fft_ready),
    .m_ready(fft_ready)
);
reshape_output u_reshape_output(
    .clk,
    .reset(rst),
    .in(mel_out),
    .out(reshape_out),
    .s_ready(s_ready_res),
    .s_valid(m_valid_mel),
    .m_ready(m_valid_mel),
    .m_valid(m_valid_res)
);
mean_std u_mean_std(
    .clk,
    .rst,
    .data_in(reshape_out),
    .mean,
    .std,
    .valid_in(m_valid_res),
    .valid_out(valid_fifo)
);
fifo u_fifo(
    .clk,
    .rst,
    .valid(valid_fifo),
    .data_in1(mean),
    .data_in2(std),
    .data_out(unsigned_vector)
);

convert_to_signed u_convert_to_signed(
    .unsigned_vector(unsigned_vector),
    .signed_vector(output_vector)
);

endmodule