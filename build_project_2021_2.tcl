#=============================================================================
# build_project_2021_2.tcl   (Vivado 2021.2)
#
# Buduje TYLKO strukture projektu RTL i dodaje wszystkie pliki zrodlowe
# rdzenia SSR (DSP + siec + opakowanie AXI4-Lite). Top = ssr_axi_lite_v1_0.
#
# NIE pakuje IP i NIE tworzy Block Design - to robisz recznie:
#   - spakowanie IP:  Tools > Create and Package New IP > Package your current project
#   - Block Design:   recznie w IP Integrator (MicroBlaze + UART + to IP)
#
# URUCHOMIENIE (zawsze przez source, NIE przez wklejanie do konsoli!):
#   vivado -mode batch -source build_project_2021_2.tcl
# albo w konsoli Tcl Vivado:
#   source /pelna/sciezka/do/build_project_2021_2.tcl
#=============================================================================

set script_path [info script]
if {$script_path eq ""} {
    puts "ERROR: uruchom skrypt przez 'source ...', a nie przez wklejanie do konsoli."
    return
}
set repo [file dirname [file normalize $script_path]]
puts "### Repo wykryte jako: $repo"

set part      xc7a35tcpg236-1
set proj_name ssr_core_project
set proj_dir  $repo/build_core
set top_mod   ssr_axi_lite_v1_0

#-----------------------------------------------------------------------------
# Listy plikow zrodlowych (sciezki wzgledne wzgledem repo)
#-----------------------------------------------------------------------------
set sv_rel {
    rtl/ssr_axi/ssr_axi_lite_v1_0.sv
    rtl/ssr_axi/ssr_axi_lite_v1_0_S00_AXI.sv
    rtl/ssr_axi/ssr_core.sv
    rtl/led_logic/led_logic.sv
    rtl/audio_processing_opt/ap_parameters.sv
    rtl/audio_processing_opt/framing_axi.sv
    rtl/audio_processing_opt/top_ap_axi.sv
    rtl/audio_processing_opt/windowing.sv
    rtl/audio_processing_opt/unwrapper.sv
    rtl/audio_processing_opt/zero_padding.sv
    rtl/audio_processing_opt/magnitude.sv
    rtl/audio_processing_opt/mean_std.sv
    rtl/audio_processing_opt/fifo.sv
    rtl/audio_processing_opt/convert_to_signed.sv
    rtl/audio_processing_opt/mel_filter/mel_filter_bank.sv
    rtl/audio_processing_opt/mel_filter/reshape_output.sv
    rtl/audio_processing_opt/mel_filter/dB_LUT.sv
    rtl/audio_processing_opt/mel_filter/multiplier.sv
    rtl/neural_network_optim/nn_parameters.sv
    rtl/neural_network_optim/dense_layer_1.sv
    rtl/neural_network_optim/dense_layer_2.sv
    rtl/neural_network_optim/final_layer.sv
    rtl/neural_network_optim/top_nn.sv
}
set v_rel {
    rtl/audio_processing_opt/fft/Butterfly.v
    rtl/audio_processing_opt/fft/DelayBuffer.v
    rtl/audio_processing_opt/fft/FFT64.v
    rtl/audio_processing_opt/fft/Multiply.v
    rtl/audio_processing_opt/fft/SdfUnit.v
    rtl/audio_processing_opt/fft/Twiddle64.v
}

#-----------------------------------------------------------------------------
# Walidacja: zbuduj listy absolutne i sprawdz istnienie
#-----------------------------------------------------------------------------
set sv_files {}
set v_files  {}
set missing  {}
foreach f $sv_rel {
    set p [file join $repo $f]
    if {[file exists $p]} { lappend sv_files $p } else { lappend missing $f }
}
foreach f $v_rel {
    set p [file join $repo $f]
    if {[file exists $p]} { lappend v_files $p } else { lappend missing $f }
}

if {[llength $missing] > 0} {
    puts "==================================================================="
    puts " ERROR: brakuje [llength $missing] plikow w repo ($repo):"
    foreach m $missing { puts "   - $m" }
    puts " Skopiuj brakujace pliki w te miejsca i uruchom skrypt ponownie."
    puts "==================================================================="
    return
}
puts "### Wszystkie pliki znalezione ([llength $sv_files] sv + [llength $v_files] v)."

#-----------------------------------------------------------------------------
# Utworzenie projektu i dodanie plikow
#-----------------------------------------------------------------------------
file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force

add_files -norecurse $sv_files
add_files -norecurse $v_files
foreach f $sv_files { set_property file_type SystemVerilog [get_files $f] }

set_property top $top_mod [current_fileset]
update_compile_order -fileset sources_1

puts "==================================================================="
puts " STRUKTURA PROJEKTU GOTOWA (Vivado 2021.2)"
puts "   projekt:  $proj_dir/$proj_name.xpr"
puts "   top:      $top_mod"
puts "   plikow:   [expr {[llength $sv_files]+[llength $v_files]}]"
puts " Pakowanie IP i Block Design - recznie."
puts "==================================================================="
