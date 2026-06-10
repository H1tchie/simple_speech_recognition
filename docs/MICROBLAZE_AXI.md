# Dodanie procesora MicroBlaze + AXI (konspekt sekcja 3.1)

Reszta projektu jest już zgodna z konspektem (IPcore DSP, AXI4-Lite slave,
AXI4-Stream wewnątrz potoku, BRAM, LED, weryfikacja). Brakuje **procesora**.
Poniżej krok po kroku, jak dołożyć **MicroBlaze** i podłączyć go do gotowego
IPcore `top_ssr` przez **AXI4-Lite**.

Rola procesora = kontroler (konspekt 3.1): startuje IPcore, czeka na `done`,
odczytuje wynik klasyfikacji, zapala LED. Sama klasyfikacja jest w RTL (sieć).

## 0. Stan wyjściowy
`top_ssr` ma już slave **AXI4-Lite** (`rtl/axi/axi4lite_regs.sv`):

| Adres | Rejestr | Opis |
|------|---------|------|
| 0x00 | CTRL   [W] | bit0=start, bit1=soft_reset |
| 0x04 | STATUS [R] | bit0=busy, bit1=done, bit2=error |
| 0x08 | RESULT [R] | command_id[1:0] (01=on, 10=off, 00=other) |
| 0x0C | CONFIG [RW]| rezerwa |

## 1. Utwórz projekt i block design
1. Utwórz projekt: `vivado -mode batch -source fpga/scripts/create_project.tcl`
   (lub otwórz istniejący `fpga/build/ssr_project.xpr`).
2. **Flow Navigator → IP INTEGRATOR → Create Block Design** (nazwa np. `ssr_mb`).
   (Możesz też uruchomić scaffold: `source fpga/scripts/create_microblaze_bd.tcl`
   — utworzy podsystem; dalej i tak kończysz w GUI wg punktów niżej.)

## 2. Dodaj MicroBlaze i uruchom Block Automation
1. W BD: **+** → dodaj **MicroBlaze**.
2. Kliknij **Run Block Automation** (zielony pasek u góry):
   - Local Memory: 32–64 KB,
   - Local Memory ECC: None,
   - Interrupt Controller: zaznacz (opcjonalnie),
   - Clock Connection: `New Clocking Wizard` (albo istniejący zegar 100 MHz),
   - Debug: Debug Only (lub JTAG).
   To doda automatycznie: pamięć lokalną (LMB), `clk_wiz`, `proc_sys_reset`,
   `mdm` (debug).

## 3. Dodaj IPcore top_ssr do block design
Dwie drogi — wybierz jedną:

**A) Module Reference (prościej):**
1. W BD: **+** → wpisz `top_ssr` → dodaj jako *Module Reference*
   (wymaga, by `top_ssr.sv` i pakiety były w *Design Sources*).
2. Vivado powinien rozpoznać porty `s_axi_*` jako interfejs **AXI4-Lite**.
   Jeśli nie zgrupował: PPM na pinach `s_axi_*` → **Create Interface** →
   AXI4-Lite (lub w properties ustaw interfejs).

**B) Spakuj jako AXI IP (czyściej, „prawdziwy" IPcore):**
1. **Tools → Create and Package New IP → Package your current project**
   (albo wydziel `top_ssr` do osobnego projektu IP).
2. Vivado rozpozna `s_axi_*` jako AXI4-Lite slave. Zakończ pakowanie,
   dodaj repo IP (**Settings → IP → Repository**), potem w BD: **+** → `top_ssr`.

## 4. Połącz AXI i zegar/reset
1. **Run Connection Automation** (zielony pasek) — zaznacz wszystko:
   - `s_axi` w `top_ssr` → Master: `microblaze_0` (Data) przez AXI Interconnect,
   - zegary → wyjście `clk_wiz`,
   - resety → `proc_sys_reset`.
2. Podłącz zewnętrzny zegar płytki (100 MHz, pin W5 na Basys3) do `clk_wiz`
   (Connection Automation → External) i reset (np. przycisk) do `proc_sys_reset`.

## 5. LED i komenda na zewnątrz
- Najprościej: PPM na `led0` / `command_id` w `top_ssr_0` → **Make External**.
- Wg konspektu (LED przez GPIO procesora): dodaj **AXI GPIO** (4-bit, all outputs),
  podłącz przez Connection Automation do MicroBlaze, a jego port `GPIO` →
  Make External → do diod LED. Soft (`sw/ssr_main.c`) zapala LED po odczycie RESULT.

## 6. Adresy
**Address Editor** → **Assign Address** (Ctrl+klik). Zapisz bazę przypisaną do
`top_ssr_0` (np. `0x44A0_0000`) — wstaw ją do `SSR_BASEADDR` w `sw/ssr_main.c`
(albo użyj makra `XPAR_..._BASEADDR` z `xparameters.h`).

## 7. Generacja i wrapper
1. **Validate Design** (F6) — popraw ewentualne braki połączeń.
2. PPM na BD w *Sources* → **Generate Output Products** (Global lub OOC).
3. PPM na BD → **Create HDL Wrapper** (let Vivado manage) → ustaw wrapper jako **Top**.
4. Dodaj/uaktualnij plik XDC z pinami (zegar, reset, LED) — bazuj na
   `fpga/constraints/top_ssr_basys3.xdc`.

## 8. Synteza + bitstream + soft
1. **Generate Bitstream**.
2. **File → Export → Export Hardware** (Include bitstream) → `.xsa`.
3. **Tools → Launch Vitis** (lub Vitis IDE):
   - New Application Project → wybierz `.xsa` → procesor `microblaze_0`,
   - szablon „Empty Application (C)”,
   - wrzuć `sw/ssr_main.c`, ustaw `SSR_BASEADDR` (z `xparameters.h`),
   - Build → Run/Debug na płytce.

## 9. Test końcowy (System test, konspekt sekcja 5)
1. Załaduj próbki do BRAM: `python3 tools/wav_to_mem.py nagranie.wav data/samples.mem --also-coe`
   (do BRAM w Vivado użyj `.coe`, do symulacji `.mem`).
2. Programuj FPGA, uruchom soft.
3. Na konsoli UART (Vitis Serial Terminal, 115200) zobaczysz np.
   `[SSR] komenda = on (kod 1)`, a dioda LED zaświeci wg komendy.

---
**Uwaga uczciwa:** nie miałem dostępu do Vivado, więc nie odpaliłem tej ścieżki
end-to-end — kroki są standardowe dla IP Integratora, ale przy pierwszym
przejściu zweryfikuj nazwy/wersje IP (Vivado podpowie poprawne). Skrypt
`create_microblaze_bd.tcl` to scaffold przyspieszający punkty 2–3.
