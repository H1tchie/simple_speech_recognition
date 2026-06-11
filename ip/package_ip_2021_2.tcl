#-----------------------------------------------------------------------------
# package_ip_2021_2.tcl   (Vivado 2021.2)
#
# Pakuje rdzen SSR (DSP + siec) jako custom IP AXI4-Lite "ssr_axi_lite".
# Uruchom z katalogu glownego repozytorium:
#   vivado -mode batch -source ip/package_ip_2021_2.tcl
# lub w konsoli Tcl Vivado:  cd <repo>; source ip/package_ip_2021_2.tcl
#
# Wynik:  ip_repo/ssr_axi_lite_1.0
#-----------------------------------------------------------------------------

set repo     [pwd]
set part     xc7a35tcpg236-1
set ip_name  ssr_axi_lite
set ip_dir   $repo/ip_repo/${ip_name}_1.0
set tmp_proj $repo/ip_repo/_pkg_proj

file mkdir $repo/ip_repo
file delete -force $tmp_proj
file delete -force $ip_dir

create_project pkg_${ip_name} $tmp_proj -part $part -force

set sv_files [list \
    $repo/rtl/ssr_axi/ssr_axi_lite_v1_0.sv \
    $repo/rtl/ssr_axi/ssr_axi_lite_v1_0_S00_AXI.sv \
    $repo/rtl/ssr_axi/ssr_core.sv \
    $repo/rtl/led_logic/led_logic.sv \
    $repo/rtl/audio_processing_opt/ap_parameters.sv \
    $repo/rtl/audio_processing_opt/framing_axi.sv \
    $repo/rtl/audio_processing_opt/top_ap_axi.sv \
    $repo/rtl/audio_processing_opt/windowing.sv \
    $repo/rtl/audio_processing_opt/unwrapper.sv \
    $repo/rtl/audio_processing_opt/zero_padding.sv \
    $repo/rtl/audio_processing_opt/magnitude.sv \
    $repo/rtl/audio_processing_opt/mean_std.sv \
    $repo/rtl/audio_processing_opt/fifo.sv \
    $repo/rtl/audio_processing_opt/convert_to_signed.sv \
    $repo/rtl/audio_processing_opt/mel_filter/mel_filter_bank.sv \
    $repo/rtl/audio_processing_opt/mel_filter/reshape_output.sv \
    $repo/rtl/audio_processing_opt/mel_filter/dB_LUT.sv \
    $repo/rtl/audio_processing_opt/mel_filter/multiplier.sv \
    $repo/rtl/neural_network_optim/nn_parameters.sv \
    $repo/rtl/neural_network_optim/dense_layer_1.sv \
    $repo/rtl/neural_network_optim/dense_layer_2.sv \
    $repo/rtl/neural_network_optim/final_layer.sv \
    $repo/rtl/neural_network_optim/top_nn.sv \
]

set v_files [list \
    $repo/rtl/audio_processing_opt/fft/Butterfly.v \
    $repo/rtl/audio_processing_opt/fft/DelayBuffer.v \
    $repo/rtl/audio_processing_opt/fft/FFT64.v \
    $repo/rtl/audio_processing_opt/fft/Multiply.v \
    $repo/rtl/audio_processing_opt/fft/SdfUnit.v \
    $repo/rtl/audio_processing_opt/fft/Twiddle64.v \
]

add_files -norecurse $sv_files
add_files -norecurse $v_files
set_property file_type {SystemVerilog} [get_files -filter {FILE_TYPE == Verilog && NAME =~ *.sv}]

set_property top ssr_axi_lite_v1_0 [current_fileset]
update_compile_order -fileset sources_1

# --- Pakowanie (skladnia stabilna w 2021.2) ---
ipx::package_project -root_dir $ip_dir -vendor agh.edu.pl -library user \
    -taxonomy /UserIP -import_files -set_current true -force

set core [ipx::current_core]
set_property name         $ip_name $core
set_property version      1.0      $core
set_property display_name "SSR AXI4-Lite (speech recognition core)" $core
set_property description   "Rdzen rozpoznawania mowy sterowany z MicroBlaze przez AXI4-Lite" $core
set_property vendor_display_name "AGH" $core
set_property supported_families {artix7 Production} $core

# Rozpoznanie interfejsu AXI4-Lite + skojarzenie zegara/resetu
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::associate_bus_interfaces -busif S00_AXI -clock s00_axi_aclk $core
ipx::associate_bus_interfaces -busif S00_AXI -reset s00_axi_aresetn $core

ipx::create_xgui_files $core
ipx::update_checksums  $core
ipx::save_core         $core

puts "==============================================="
puts " IP spakowane (2021.2): $ip_dir"
puts " Dodaj sciezke ip_repo do IP Catalog projektu BD."
puts "==============================================="

close_project
