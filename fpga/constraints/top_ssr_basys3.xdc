## ============================================================================
## top_ssr_basys3.xdc - Basys3 (Xilinx Artix-7 XC7A35T-CPG236-1)
## Pin mapping for Simple Speech Recognition v3 (offline preprocessing).
## ============================================================================

## Clock 100 MHz
set_property PACKAGE_PIN W5 [get_ports clk]
    set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]

## Buttons
set_property PACKAGE_PIN U18 [get_ports btnC]
    set_property IOSTANDARD LVCMOS33 [get_ports btnC]
set_property PACKAGE_PIN T18 [get_ports btnU]
    set_property IOSTANDARD LVCMOS33 [get_ports btnU]

## Switch
set_property PACKAGE_PIN V17 [get_ports sw0]
    set_property IOSTANDARD LVCMOS33 [get_ports sw0]

## LEDs
set_property PACKAGE_PIN U16 [get_ports led0]
    set_property IOSTANDARD LVCMOS33 [get_ports led0]
set_property PACKAGE_PIN E19 [get_ports {led_cmd[0]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led_cmd[0]}]
set_property PACKAGE_PIN U19 [get_ports {led_cmd[1]}]
    set_property IOSTANDARD LVCMOS33 [get_ports {led_cmd[1]}]

## Config
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
