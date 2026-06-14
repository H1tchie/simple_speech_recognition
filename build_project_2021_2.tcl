#=============================================================================
# build_project_2021_2.tcl   (Vivado 2021.2)  -- wersja UTWARDZONA
#
# Sam wykrywa katalog repo (po lokalizacji tego skryptu), sprawdza, czy
# wszystkie pliki istnieja, i przy braku - mowi WPROST ktorego brakuje.
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
set ip_name   ssr_axi_lite
set ip_dir    $repo/ip_repo/${ip_name}_1.0
set proj_name ssr_mb_project
set proj_dir  $repo/build_mb
set bd_name   design_1
set sys_clk   50.0
set run_impl  0

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
set xdc_rel fpga/constraints/top_ssr_mb_basys3.xdc

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
set xdc_path [file join $repo $xdc_rel]
if {![file exists $xdc_path]} { lappend missing $xdc_rel }

if {[llength $missing] > 0} {
    puts "==================================================================="
    puts " ERROR: brakuje [llength $missing] plikow w repo ($repo):"
    foreach m $missing { puts "   - $m" }
    puts " Skopiuj brakujace pliki w te miejsca i uruchom skrypt ponownie."
    puts "==================================================================="
    return
}
puts "### Wszystkie pliki znalezione ([llength $sv_files] sv + [llength $v_files] v + 1 xdc). Buduje..."

puts "### KROK 1/4: pakowanie IP ..."
set tmp_proj $repo/ip_repo/_pkg_proj
file mkdir $repo/ip_repo
file delete -force $tmp_proj
file delete -force $ip_dir
create_project pkg_${ip_name} $tmp_proj -part $part -force
add_files -norecurse $sv_files
add_files -norecurse $v_files
foreach f $sv_files { set_property file_type SystemVerilog [get_files $f] }
set_property top ssr_axi_lite_v1_0 [current_fileset]
update_compile_order -fileset sources_1
ipx::package_project -root_dir $ip_dir -vendor agh.edu.pl -library user \
    -taxonomy /UserIP -import_files -set_current true -force
set core [ipx::current_core]
set_property name         $ip_name $core
set_property version      1.0      $core
set_property display_name "SSR AXI4-Lite (speech recognition core)" $core
set_property vendor_display_name "AGH" $core
set_property supported_families {artix7 Production} $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::associate_bus_interfaces -busif S00_AXI -clock s00_axi_aclk  $core
ipx::associate_bus_interfaces -busif S00_AXI -reset s00_axi_aresetn $core
ipx::create_xgui_files $core
ipx::update_checksums  $core
ipx::save_core         $core
close_project
puts "### IP spakowane: $ip_dir"

puts "### KROK 2/4: tworzenie projektu ..."
file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force
set_property ip_repo_paths [list $repo/ip_repo] [current_project]
update_ip_catalog

puts "### KROK 3/4: budowa Block Design ..."
create_bd_design $bd_name
current_bd_design $bd_name
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:* microblaze_0
apply_bd_automation -rule xilinx.com:bd_rule:microblaze \
  -config { axi_intc {0} axi_periph {Enabled} cache {None} \
            clk {New Clocking Wizard (100 MHz)} debug_module {Debug Only} \
            ecc {None} local_mem {64KB} } \
  [get_bd_cells microblaze_0]
set clkw [get_bd_cells -quiet clk_wiz_1]
if {$clkw ne ""} { set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $sys_clk] $clkw }
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:* axi_uartlite_0
set_property -dict [list CONFIG.C_BAUDRATE {9600}] [get_bd_cells axi_uartlite_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
            Master {/microblaze_0 (Periph)} Slave {/axi_uartlite_0/S_AXI} \
            intc_ip {/microblaze_0_axi_periph} master_apm {0} } \
  [get_bd_intf_pins axi_uartlite_0/S_AXI]
make_bd_intf_pins_external [get_bd_intf_pins axi_uartlite_0/UART]
set_property name usb_uart [get_bd_intf_ports UART_0]
create_bd_cell -type ip -vlnv agh.edu.pl:user:ssr_axi_lite:1.0 ssr_axi_lite_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
            Master {/microblaze_0 (Periph)} Slave {/ssr_axi_lite_0/S00_AXI} \
            intc_ip {/microblaze_0_axi_periph} master_apm {0} } \
  [get_bd_intf_pins ssr_axi_lite_0/S00_AXI]
make_bd_pins_external [get_bd_pins ssr_axi_lite_0/led0]
set_property name led0 [get_bd_ports led0_0]
regenerate_bd_layout
assign_bd_address
validate_bd_design
save_bd_design

puts "### KROK 4/4: wrapper + constraints ..."
generate_target all [get_files ${bd_name}.bd]
set wrapper [make_wrapper -files [get_files ${bd_name}.bd] -top -force]
add_files -norecurse $wrapper
set_property top ${bd_name}_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse $xdc_path
update_compile_order -fileset sources_1

puts "==================================================================="
puts " PROJEKT GOTOWY (Vivado 2021.2)"
puts "   projekt:  $proj_dir/$proj_name.xpr"
puts "   wrapper:  $wrapper"
puts "   rdzen:    $sys_clk MHz"
puts " Adres bazowy ssr_axi_lite_0 sprawdz w Address Editor, potem Generate Bitstream."
puts "==================================================================="

if {$run_impl == 1} {
    puts "### KROK 5: bitstream (potrwa) ..."
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
}
