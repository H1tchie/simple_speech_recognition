#=============================================================================
# build_project_2021_2.tcl   (Vivado 2021.2)  -- WSZYSTKO W JEDNYM
#
# Jeden skrypt, ktory:
#   1) pakuje rdzen SSR jako custom IP AXI4-Lite  -> ip_repo/
#   2) tworzy projekt Vivado                       -> build_mb/
#   3) buduje Block Design (MicroBlaze + pamiec + zegar + reset +
#      AXI Interconnect + UARTLite + nasze IP)
#   4) generuje wrapper HDL, dodaje constraints, ustawia top
#   (opcjonalnie) 5) uruchamia synteze + implementacje + bitstream
#
# URUCHOMIENIE z katalogu glownego repozytorium:
#   vivado -mode batch -source build_project_2021_2.tcl
# albo w konsoli Tcl Vivado:  cd <repo>; source build_project_2021_2.tcl
#
# Aby od razu zrobic bitstream, ustaw ponizej:  set run_impl 1
#=============================================================================

set repo      [pwd]
set part      xc7a35tcpg236-1
set ip_name   ssr_axi_lite
set ip_dir    $repo/ip_repo/${ip_name}_1.0
set proj_name ssr_mb_project
set proj_dir  $repo/build_mb
set bd_name   design_1
set sys_clk   50.0   ;# czestotliwosc rdzenia [MHz]; zmniejsz (np. 25), jesli timing nie zamyka
set run_impl  0      ;# 1 = po zbudowaniu uruchom synteze+implementacje+bitstream

#-----------------------------------------------------------------------------
# Wspolne listy plikow zrodlowych
#-----------------------------------------------------------------------------
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

#=============================================================================
# KROK 1: spakowanie rdzenia jako custom IP
#=============================================================================
puts "### KROK 1/4: pakowanie IP ..."
set tmp_proj $repo/ip_repo/_pkg_proj
file mkdir $repo/ip_repo
file delete -force $tmp_proj
file delete -force $ip_dir

create_project pkg_${ip_name} $tmp_proj -part $part -force
add_files -norecurse $sv_files
add_files -norecurse $v_files
set_property file_type {SystemVerilog} [get_files -filter {FILE_TYPE == Verilog && NAME =~ *.sv}]
set_property top ssr_axi_lite_v1_0 [current_fileset]
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_dir -vendor agh.edu.pl -library user \
    -taxonomy /UserIP -import_files -set_current true -force
set core [ipx::current_core]
set_property name         $ip_name $core
set_property version      1.0      $core
set_property display_name "SSR AXI4-Lite (speech recognition core)" $core
set_property description   "Rdzen rozpoznawania mowy sterowany z MicroBlaze przez AXI4-Lite" $core
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

#=============================================================================
# KROK 2: utworzenie projektu + repo IP
#=============================================================================
puts "### KROK 2/4: tworzenie projektu ..."
file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force
set_property ip_repo_paths [list $repo/ip_repo] [current_project]
update_ip_catalog

#=============================================================================
# KROK 3: Block Design
#=============================================================================
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
if {$clkw ne ""} {
    set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $sys_clk] $clkw
}

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

#=============================================================================
# KROK 4: wrapper + constraints + top
#=============================================================================
puts "### KROK 4/4: wrapper + constraints ..."
generate_target all [get_files ${bd_name}.bd]
set wrapper [make_wrapper -files [get_files ${bd_name}.bd] -top -force]
add_files -norecurse $wrapper
set_property top ${bd_name}_wrapper [current_fileset]
add_files -fileset constrs_1 -norecurse $repo/fpga/constraints/top_ssr_mb_basys3.xdc
update_compile_order -fileset sources_1

puts "==================================================================="
puts " PROJEKT GOTOWY (Vivado 2021.2)"
puts "   projekt:  $proj_dir/$proj_name.xpr"
puts "   wrapper:  $wrapper"
puts "   IP:       $ip_dir"
puts "   rdzen:    $sys_clk MHz"
puts " Sprawdz adres bazowy ssr_axi_lite_0 w Address Editor."
puts "==================================================================="

#=============================================================================
# (opcjonalnie) KROK 5: bitstream
#=============================================================================
if {$run_impl == 1} {
    puts "### KROK 5: synteza + implementacja + bitstream (to potrwa) ..."
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    puts "### Bitstream gotowy. Eksportuj XSA: File > Export > Export Hardware (z bitstreamem)."
}
