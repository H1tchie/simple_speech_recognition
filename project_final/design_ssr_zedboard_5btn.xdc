##=============================================================================
## ZedBoard (XC7Z020-CLG484) - constraints dla design_final_wrapper
## (Zynq PS + SSR + 5 przyciskow przez AXI GPIO)
##
## Porty wrappera do oprzewodowania w XDC:
##   led0_0           - dioda LD0
##   gpio_but_tri_i[4:0] - 5 przyciskow (wejscie AXI GPIO)
## DDR_* i FIXED_IO_* -> obslugiwane przez preset ZedBoarda (PS), NIE dotykamy.
##
## Mapowanie przyciskow (zgodne z main.c):
##   gpio_but_tri_i[0] = BTNC -> plik 0 : ON  (good)
##   gpio_but_tri_i[1] = BTNU -> plik 1 : OFF (good)
##   gpio_but_tri_i[2] = BTND -> plik 2 : OTHER (good)
##   gpio_but_tri_i[3] = BTNL -> plik 3 : ON  (bad)
##   gpio_but_tri_i[4] = BTNR -> plik 4 : OTHER (bad)
##=============================================================================

## ---- LED0 (LD0) ----
set_property -dict { PACKAGE_PIN T22 IOSTANDARD LVCMOS33 } [get_ports { led0_0 }];

## ---- 5 przyciskow -> AXI GPIO (gpio_but_tri_i[4:0]), bank 1.8 V ----
set_property -dict { PACKAGE_PIN P16 IOSTANDARD LVCMOS18 } [get_ports { gpio_but_tri_i[0] }]; # BTNC
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS18 } [get_ports { gpio_but_tri_i[1] }]; # BTNU
set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS18 } [get_ports { gpio_but_tri_i[2] }]; # BTND
set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS18 } [get_ports { gpio_but_tri_i[3] }]; # BTNL
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS18 } [get_ports { gpio_but_tri_i[4] }]; # BTNR
