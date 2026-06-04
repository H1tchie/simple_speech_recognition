# Copyright (C) 2023  AGH University of Science and Technology
# Project details for generate_bitstream.tcl

set project_name ssr_project
set top_module   top_ssr_basys3
set target       xc7a35tcpg236-1

set xdc_files {
    constraints/top_ssr_basys3.xdc
}

# UWAGA: pakiety (ssr_pkg, nn_parameters) MUSZA byc na poczatku.
set sv_files {
    ../rtl/ssr_pkg.sv
    ../rtl/neural_network/nn_parameters.sv

    ../rtl/data_source/bram_stream_source.sv
    ../rtl/dsp/preemphasis.sv
    ../rtl/dsp/framing.sv
    ../rtl/dsp/window.sv
    ../rtl/dsp/fft_wrapper.sv
    ../rtl/dsp/mel_filter_bank.sv
    ../rtl/dsp/mfcc.sv
    ../rtl/dsp/feature_aggregator.sv

    ../rtl/neural_network/dense_layer.sv
    ../rtl/neural_network/final_layer.sv
    ../rtl/neural_network/top_nn.sv
    ../rtl/neural_network/top_nn_axis.sv

    ../rtl/led_logic/led_logic.sv

    ../rtl/axi/axi4lite_regs.sv
    ../rtl/top_ssr.sv

    rtl/top_ssr_basys3.sv
}

# Memory init files (generowane przez tools/build_all.py)
set mem_files {
    ../rtl/dsp/window_hamming_512.mem
    ../rtl/dsp/twiddle_cos_512.mem
    ../rtl/dsp/twiddle_sin_512.mem
    ../rtl/dsp/mel_bank_dense.mem
    ../rtl/dsp/dct_coeffs.mem
    ../rtl/neural_network/dense1_weights.mem
    ../rtl/neural_network/dense1_bias.mem
    ../rtl/neural_network/dense2_weights.mem
    ../rtl/neural_network/dense2_bias.mem
    ../data/samples.mem
}
