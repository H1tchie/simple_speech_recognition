#-----------------------------------------------------------------------------
# create_bd.tcl
#
# Buduje kompletny Block Design dla wersji z MicroBlaze:
#   MicroBlaze + pamiec lokalna + Clocking Wizard + Proc System Reset +
#   AXI Interconnect + AXI UARTLite + custom IP "ssr_axi_lite".
#
# WYMAGANIE: najpierw spakuj IP:   vivado -mode batch -source ip/package_ip.tcl
#
# URUCHOMIENIE (z katalogu glownego repozytorium):
#   vivado -mode batch -source bd/create_bd.tcl
# albo w konsoli Tcl Vivado:  cd <repo>; source bd/create_bd.tcl
#
# UWAGA: nazwy komorek tworzonych przez apply_bd_automation moga roznic sie
# miedzy wersjami Vivado. Jezeli skrypt sie zatrzyma, dokoncz BD recznie wg
# instrukcji w README_PL.md (sekcja "Wariant GUI"). Czesc automatyczna i tak
# wykonuje 90% pracy.
#-----------------------------------------------------------------------------

set repo       [pwd]
set part       xc7a35tcpg236-1
set proj_name  ssr_mb_project
set proj_dir   $repo/build_mb
set bd_name    design_1
set sys_clk    25.0   ;# czestotliwosc rdzenia [MHz] - przy problemach z timingiem zmniejsz

file delete -force $proj_dir
create_project $proj_name $proj_dir -part $part -force

# Repozytorium z naszym custom IP
set_property ip_repo_paths [list $repo/ip_repo] [current_project]
update_ip_catalog

create_bd_design $bd_name
current_bd_design $bd_name

# --- MicroBlaze + automatyczna obudowa (pamiec, zegar, reset, interconnect) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze microblaze_0
apply_bd_automation -rule xilinx.com:bd_rule:microblaze \
  -config { local_mem "64KB" ecc "None" cache "None" \
            debug_module "Debug Only" axi_periph "Enabled" axi_intc "0" \
            clk "New Clocking Wizard (100 MHz)" } \
  [get_bd_cells microblaze_0]

# Zewnetrzny zegar 100 MHz i reset (zostaja utworzone przez automation jako porty)
# Ustaw czestotliwosc wyjsciowa Clocking Wizard na $sys_clk MHz
set clkw [get_bd_cells -quiet clk_wiz_1]
if {$clkw ne ""} {
    set_property -dict [list CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $sys_clk] $clkw
}

# --- UARTLite (konsola dla xil_printf) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite axi_uartlite_0
set_property -dict [list CONFIG.C_BAUDRATE {9600}] [get_bd_cells axi_uartlite_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
            Master {/microblaze_0 (Periph)} Slave {/axi_uartlite_0/S_AXI} \
            intc_ip {New AXI Interconnect} master_apm {0} } \
  [get_bd_intf_pins axi_uartlite_0/S_AXI]
# wyprowadz UART na zewnatrz
make_bd_intf_pins_external [get_bd_intf_pins axi_uartlite_0/UART]
set_property name usb_uart [get_bd_intf_ports UART_0]

# --- Nasze custom IP SSR ---
create_bd_cell -type ip -vlnv agh.edu.pl:user:ssr_axi_lite:1.0 ssr_axi_lite_0
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
  -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
            Master {/microblaze_0 (Periph)} Slave {/ssr_axi_lite_0/S00_AXI} \
            intc_ip {/microblaze_0_axi_periph} master_apm {0} } \
  [get_bd_intf_pins ssr_axi_lite_0/S00_AXI]
# wyprowadz diode na zewnatrz
make_bd_pins_external [get_bd_pins ssr_axi_lite_0/led0]
set_property name led0 [get_bd_ports led0_0]

# --- Finalizacja ---
regenerate_bd_layout
validate_bd_design
save_bd_design

# Wrapper HDL + ustawienie jako top
make_wrapper -files [get_files $bd_name.bd] -top
add_files -norecurse $proj_dir/$proj_name.gen/sources_1/bd/$bd_name/hdl/${bd_name}_wrapper.v
set_property top ${bd_name}_wrapper [current_fileset]

# Constraints
add_files -fileset constrs_1 -norecurse $repo/fpga/constraints/top_ssr_mb_basys3.xdc

update_compile_order -fileset sources_1

puts "==================================================================="
puts " Block Design gotowy. Adres bazowy peryferium sprawdz w Address Editor."
puts " Dalej: Generate Bitstream, potem eksport XSA i aplikacja w Vitis."
puts " (Czestotliwosc rdzenia ustawiona na $sys_clk MHz.)"
puts "==================================================================="
