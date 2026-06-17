## =========================================================================
## Zedboard - constraints dla top_ssr (PYNQ + AXI DMA)
## Zegar (FCLK_CLK0) generuje Zynq PS - NIE definiujemy go tutaj.
## Constrainujemy tylko piny fizyczne: LED + opcjonalny przycisk.
## =========================================================================

## ---- LED0 -> Zedboard LD0 ----
set_property -dict { PACKAGE_PIN T22  IOSTANDARD LVCMOS33 } [get_ports { led0 }];

## ---- (opcjonalnie) wiecej diod ----
## LD0=T22, LD1=T21, LD2=U22, LD3=U21, LD4=V22, LD5=W22, LD6=U19, LD7=U14
set_property -dict { PACKAGE_PIN T21  IOSTANDARD LVCMOS33 } [get_ports { led1 }];
# set_property -dict { PACKAGE_PIN U22  IOSTANDARD LVCMOS33 } [get_ports { led2 }];

## ---- (opcjonalnie) przycisk BTNC jako hardware start/reset ----
# set_property -dict { PACKAGE_PIN P16  IOSTANDARD LVCMOS33 } [get_ports { btn_center }];


