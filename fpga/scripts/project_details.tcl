# Copyright (C) 2023  AGH University of Science and Technology
# MTM UEC2
# Author: Piotr Kaczmarczyk
#
# Description:
# Project detiles required for generate_bitstream.tcl
# Make sure that project_name, top_module and target are correct.
# Provide paths to all the files required for synthesis and implementation.
# Depending on the file type, it should be added in the corresponding section.
# If the project does not use files of some type, leave the corresponding section commented out.

#-----------------------------------------------------#
#                   Project details                   #
#-----------------------------------------------------#
# Project name                                  -- EDIT
set project_name ssr_project
set project_name ssr_project
set project_name ssr_project

# Top module name                               -- EDIT
set top_module top_ssr_basys3
set top_module top_ssr_basys3
set top_module top_ssr_basys3

# FPGA device
set target xc7a35tcpg236-1

#-----------------------------------------------------#
#                    Design sources                   #
#-----------------------------------------------------#
# Specify .xdc files location                   -- EDIT
set xdc_files {
    constraints/top_ssr_basys3.xdc
    constraints/clk_wiz_4.xdc
}

# Specify SystemVerilog design files location   -- EDIT
set sv_files {
    ../rtl/led_logic/led_logic.sv
    ../rtl/top_ssr.sv 
    ../rtl/audio_processing_opt/framing.sv  
    ../rtl/audio_processing_opt/windowing.sv 
    ../rtl/audio_processing_opt/unwrapper.sv 
    ../rtl/audio_processing_opt/zero_padding.sv 
    ../rtl/audio_processing_opt/mel_filter/mel_filter_bank.sv 
    ../rtl/audio_processing_opt/mel_filter/reshape_output.sv 
    ../rtl/audio_processing_opt/mel_filter/dB_LUT.sv
    ../rtl/audio_processing_opt/mel_filter/multiplier.sv 
    ../rtl/audio_processing_opt/magnitude.sv 
    ../rtl/audio_processing_opt/mean_std.sv 
    ../rtl/audio_processing_opt/fifo.sv
    ../rtl/audio_processing_opt/convert_to_signed.sv 
    ../rtl/audio_processing_opt/top_ap.sv
    ../rtl/audio_processing_opt/ap_parameters.sv
    ../rtl/neural_network_optim/nn_parameters.sv
    ../rtl/neural_network_optim/dense_layer_2.sv
    ../rtl/neural_network_optim/dense_layer_1.sv
    ../rtl/neural_network_optim/final_layer.sv
    ../rtl/neural_network_optim/top_nn.sv
    rtl/top_ssr_basys3.sv
}

# Specify Verilog design files location         -- EDIT
set verilog_files {
    rtl/clk_wiz_4_clk_wiz.v
    ../rtl/audio_processing_opt/fft/Butterfly.v 
    ../rtl/audio_processing_opt/fft/DelayBuffer.v 
    ../rtl/audio_processing_opt/fft/FFT64.v 
    ../rtl/audio_processing_opt/fft/Multiply.v 
    ../rtl/audio_processing_opt/fft/SdfUnit.v 
    ../rtl/audio_processing_opt/fft/Twiddle64.v 
 
}

# Specify VHDL design files location            -- EDIT
set vhdl_files {
    ../rtl/adc/i2c_master.vhd
    ../rtl/adc/pmod_adc_ad7991.vhd
}

# Specify files for a memory initialization     -- EDIT
# set mem_files {
#    path/to/file.data
# }
