##=============================================================================
## ZedBoard (XC7Z020-CLG484) - constraints dla design z Zynq PS + SSR + 5 przyciskow
##
## Na Zynq PS piny DDR/UART/MIO sa z presetu plytki - tu dopisujemy tylko
## LED0 oraz 5 przyciskow podpietych do AXI GPIO (wejscie, szerokosc 5).
##
## UWAGA: nazwy portow (led0_0, btn[..]) musza zgadzac sie z portami wrappera
## po Create HDL Wrapper. Jesli Make External nadalo inne nazwy - popraw je
## w nawiasach [get_ports ...] (sprawdz w I/O Ports).
##=============================================================================

## ---- LED0 (LD0) ----
set_property -dict { PACKAGE_PIN T22 IOSTANDARD LVCMOS33 } [get_ports { led0_0 }];

## ---- 5 przyciskow -> AXI GPIO (wejscie 5-bitowe), bank 1.8 V ----
## btn[0] = BTNC, btn[1] = BTNU, btn[2] = BTND, btn[3] = BTNL, btn[4] = BTNR
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS18 } [get_ports { btn[0] }]; # BTNC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS18 } [get_ports { btn[1] }]; # BTNU
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS18 } [get_ports { btn[2] }]; # BTND
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS18 } [get_ports { btn[3] }]; # BTNL
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS18 } [get_ports { btn[4] }]; # BTNR
