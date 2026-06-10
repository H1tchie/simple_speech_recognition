# =============================================================================
#  create_microblaze_bd.tcl  -  STARTOWY szkielet block design z MicroBlaze
#
#  Buduje podsystem: MicroBlaze + pamiec lokalna + zegar + reset + AXI
#  Interconnect + AXI GPIO (LED), oraz dodaje top_ssr jako modul RTL.
#
#  !!! UWAGA - to scaffold, nie gotowiec !!!
#  - Wersje IP (VLNV) zaleza od wersji Vivado; jesli ktoras sie nie zgodzi,
#    Vivado wskaze poprawna - podmien.
#  - Dopiecie magistrali AXI do top_ssr i mapy adresow najwygodniej zrobic
#    przez "Run Connection Automation" + "Assign Address" w GUI (1-2 klikniecia).
#  - Najpewniejsza sciezka to GUI wg docs/MICROBLAZE_AXI.md; ten skrypt
#    tylko przyspiesza utworzenie podsystemu procesora.
#
#  Uzycie (z katalogu glownego repo, po utworzeniu projektu create_project.tcl):
#    vivado -mode batch -source fpga/scripts/create_microblaze_bd.tcl
# =============================================================================

set bd_name ssr_mb

# wymaga otwartego projektu; jesli nie - otworz utworzony przez create_project.tcl
if {[catch {current_project}]} {
    set _here [file dirname [file normalize [info script]]]
    open_project [file join [file dirname $_here] build ssr_project.xpr]
}

create_bd_design $bd_name

# --- MicroBlaze + automatyka (pamiec lokalna, INTC, debug) ---
set mb [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:* microblaze_0]

# --- zegar i reset ---
set clkw [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:* clk_wiz_0]
set rst  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst_0]

# --- AXI Interconnect ---
set ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* axi_ic_0]

# --- AXI GPIO do diod LED (konspekt 4.9: LED przez GPIO procesora) ---
set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:* axi_gpio_led]
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_ALL_OUTPUTS {1}] $gpio

# --- nasz IPcore jako modul RTL (referencja do top_ssr) ---
# Wymaga, by top_ssr.sv (i pakiety) byly w zrodlach projektu.
set ssr [create_bd_cell -type module -reference top_ssr top_ssr_0]

puts "============================================================"
puts "==> Block design '$bd_name' utworzony z MicroBlaze + GPIO + top_ssr."
puts "==> DALEJ W GUI (patrz docs/MICROBLAZE_AXI.md):"
puts "    1. Run Block Automation (MicroBlaze: lokalna pamiec, INTC, debug)."
puts "    2. Run Connection Automation (clk_wiz<-sys clock, reset z przycisku)."
puts "    3. Polacz s_axi (AXI4-Lite) top_ssr_0 do AXI Interconnect (Connection Automation)."
puts "    4. Address Editor -> Assign Address (zapisz baze top_ssr -> do ssr_main.c)."
puts "    5. led/command_id top_ssr_0 lub axi_gpio_led -> Make External -> przypisz piny (XDC)."
puts "    6. Validate Design (F6), Generate Output Products, Create HDL Wrapper, ustaw jako Top."
puts "============================================================"

# zapis BD
save_bd_design
