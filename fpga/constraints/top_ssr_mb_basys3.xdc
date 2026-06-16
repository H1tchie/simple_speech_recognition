## Basys3 - constraints dla wersji SSR z MicroBlaze
## Top = design_1_wrapper (generowany z Block Design)
##
## Porty zewnetrzne BD:
##   clk_100MHz  - wejscie zegara 100 MHz (port zegara z Clocking Wizard)
##   reset       - reset zewnetrzny (przycisk btnC)
##   usb_uart_rxd / usb_uart_txd - USB-UART (mostek FT2232 na plytce)
##   led0        - dioda LD0
##
## UWAGA: nazwy portow zegara i resetu zaleza od tego, jak apply_bd_automation
## nazwalo porty zewnetrzne. Po wygenerowaniu wrappera sprawdz dokladne nazwy
## (Schematic / I/O Ports) i w razie potrzeby popraw nazwy w nawiasach [get_ports ...].
## Typowe nazwy: "clk_100MHz" oraz "reset" (lub "reset_rtl").

## ---- Zegar 100 MHz (W5) ----
set_property PACKAGE_PIN W5 [get_ports clk_100MHz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100MHz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0 5} [get_ports clk_100MHz]

## ---- Reset: przycisk btnC (U18), aktywny w stanie wysokim ----
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## ---- USB-UART (mostek na plytce Basys3) ----
## RsRx = B18 (FPGA odbiera), RsTx = A18 (FPGA nadaje)
set_property PACKAGE_PIN B18 [get_ports usb_uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports usb_uart_rxd]
set_property PACKAGE_PIN A18 [get_ports usb_uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports usb_uart_txd]

## ---- Dioda LD0 (U16) ----
set_property PACKAGE_PIN U16 [get_ports led0]
set_property IOSTANDARD LVCMOS33 [get_ports led0]
