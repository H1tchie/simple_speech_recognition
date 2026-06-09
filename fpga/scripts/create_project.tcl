# Copyright (C) 2023  AGH University of Science and Technology
#
# Description:
#   Tworzy projekt Vivado (.xpr) z samych zrodel - do OTWARCIA w GUI.
#   Nie uruchamia syntezy; po wykonaniu masz gotowy, klikalny projekt.
#
#   Szczegoly (nazwa, uklad, top, listy plikow .sv/.mem/.xdc) sa czytane
#   z project_details.tcl, dzieki czemu jest spojnie z generate_bitstream.tcl.
#
# Uzycie (z dowolnego katalogu):
#   # 1) tylko utworz projekt, potem otworz go recznie w Vivado:
#   vivado -mode batch -source fpga/scripts/create_project.tcl
#   #    -> powstaje  fpga/build/ssr_project.xpr
#   #    -> w Vivado:  File > Open Project... > fpga/build/ssr_project.xpr
#
#   # 2) od razu otworz projekt w GUI:
#   vivado -mode gui   -source fpga/scripts/create_project.tcl

# --- przejdz do katalogu fpga/ (sciezki w project_details.tcl sa wzgledne) ---
set _script_dir [file dirname [file normalize [info script]]]
set _fpga_dir   [file dirname $_script_dir]
cd $_fpga_dir

source scripts/project_details.tcl

set proj_dir build

# usun stary projekt, jesli istnieje (czysty start)
if {[file exists $proj_dir]} {
    puts "==> Usuwam istniejacy katalog projektu: $proj_dir"
    file delete -force $proj_dir
}

# --- utworz projekt ---
create_project ${project_name} ${proj_dir} -part ${target} -force

# --- zrodla projektowe (.sv) ---
if {[info exists ::sv_files]} {
    add_files -norecurse -fileset sources_1 ${::sv_files}
    set_property file_type SystemVerilog [get_files -filter {FILE_TYPE == Verilog}]
}
if {[info exists ::verilog_files]} { add_files -norecurse -fileset sources_1 ${::verilog_files} }
if {[info exists ::vhdl_files]}    { add_files -norecurse -fileset sources_1 ${::vhdl_files} }

# --- pliki pamieci (.mem czytane przez $readmemh w RTL) ---
# dodajemy tylko te, ktore istnieja (np. samples.mem bywa generowane pozniej),
# zeby projekt zawsze dalo sie otworzyc
if {[info exists ::mem_files]} {
    set _mems {}
    foreach _m ${::mem_files} {
        if {[file exists $_m]} { lappend _mems $_m } else {
            puts "==> POMIJAM brakujacy plik .mem: $_m"
        }
    }
    if {[llength $_mems] > 0} { add_files -norecurse -fileset sources_1 $_mems }
}

# --- ograniczenia (XDC, piny Basys3) ---
if {[info exists ::xdc_files]} {
    add_files -norecurse -fileset constrs_1 ${::xdc_files}
}

# --- modul nadrzedny syntezy ---
set_property top ${top_module} [current_fileset]
update_compile_order -fileset sources_1

# --- testbench systemowy do symulacji z GUI (opcjonalnie) ---
set _tb [file normalize ../sim/top_ssr/top_ssr_tb.sv]
if {[file exists $_tb]} {
    add_files -norecurse -fileset sim_1 $_tb
    set_property top top_ssr_tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    puts "==> Dodano testbench symulacyjny (sim_1 top = top_ssr_tb)"
}

puts "============================================================"
puts "==> Projekt utworzony: ${_fpga_dir}/${proj_dir}/${project_name}.xpr"
puts "==> Otworz w Vivado:   File > Open Project > ${proj_dir}/${project_name}.xpr"
puts "==> Synteza+bitstream: source scripts/generate_bitstream.tcl"
puts "============================================================"
