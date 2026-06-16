# SSR – wersja z MicroBlaze (audio z pamięci + AXI4-Lite)

Wariant projektu **Simple-speech-recognisition**, w którym – zgodnie z konspektem –
ADC i sygnał z mikrofonu zostały **zastąpione plikiem dźwiękowym ładowanym z pamięci
na płytce**, a danymi steruje **procesor MicroBlaze** komunikujący się z rdzeniem
rozpoznawania mowy przez **AXI4-Lite**. Procesor strumieniuje próbki i **odczytuje wynik**.

---

## 1. Co się zmieniło względem oryginału

Oryginał:

```
mikrofon -> PMOD AD7991 (I2C) -> adc_data -> top_ap (DSP) -> top_nn -> led_logic -> LED
```

Wersja MicroBlaze:

```
                 (plik audio w pamięci jako tablica C w .elf MicroBlaze)
                          │
   MicroBlaze ── AXI4-Lite ──► ssr_axi_lite (custom IP)
        ▲                          │  rejestr SAMPLE -> sample_valid
        │  odczyt RESULT/STATUS     ▼
        └────────────────── ssr_core = top_ap_axi -> top_nn -> led_logic -> LED
                                     ▲
                              AXI UARTLite -> konsola (xil_printf)
```

Kluczowe zmiany:

- **`framing_axi.sv`** – kopia `framing`, ale indeks ramki przesuwa się tylko przy
  `sample_valid = 1`. Numerycznie identyczna z oryginałem, więc nie psuje wytrenowanej
  ścieżki – pozwala jedynie podawać próbki wolno (po jednej na transakcję AXI).
- **`top_ap_axi.sv`** – `top_ap` z `framing` zamienionym na `framing_axi` (dodany port `sample_valid`).
- **`ssr_core.sv`** – rdzeń bez ADC/I2C: `top_ap_axi → top_nn → led_logic`.
- **`ssr_axi_lite_v1_0*.sv`** – peryferium AXI4-Lite (slave) opakowujące `ssr_core`.
- **MicroBlaze + UARTLite** – dodawane w Block Design (skrypty w `bd/` i `ip/`).
- Usunięte z toru: `pmod_adc_ad7991.vhd`, `i2c_master.vhd` (nie są już potrzebne).

Cała reszta (windowing, FFT64, magnitude, mel_filter, mean_std, fifo, dense layers)
**pozostaje bez zmian** – używamy modułów z Twojego repozytorium.

---

## 2. Zawartość paczki

```
rtl/audio_processing_opt/framing_axi.sv      # framing sterowany sample_valid
rtl/audio_processing_opt/top_ap_axi.sv       # top_ap z framing_axi
rtl/ssr_axi/ssr_core.sv                       # rdzeń bez ADC
rtl/ssr_axi/ssr_axi_lite_v1_0_S00_AXI.sv      # slave AXI4-Lite + logika rejestrów
rtl/ssr_axi/ssr_axi_lite_v1_0.sv              # top peryferium (do spakowania jako IP)
ip/package_ip.tcl                             # pakowanie rdzenia jako custom IP
bd/create_bd.tcl                              # budowa Block Design z MicroBlaze
fpga/constraints/top_ssr_mb_basys3.xdc        # constraints (clk, reset, UART, LED)
sw/main.c                                     # aplikacja MicroBlaze
sw/gen_audio_header.py                        # generator audio_samples.h (WAV lub hex)
sw/audio_samples.h                            # przykład (8192 próbki z input_adcoff2.txt)
sim/ssr_axi_lite/ssr_axi_lite_tb.sv           # testbench AXI4-Lite (xsim)
sim/ssr_axi_lite/ssr_axi_lite.prj             # projekt symulacji
README_PL.md                                  # ten plik
```

> Rozpakuj **do katalogu głównego repozytorium** (pliki trafią obok istniejących).
> Ścieżki w skryptach zakładają, że uruchamiasz je z katalogu głównego repo.

---

## 3. Procedura krok po kroku

### Krok 0 – przygotowanie
1. Sklonuj repo i rozpakuj do niego tę paczkę (scalając katalogi).
2. Wymagane: Vivado + Vitis (ta sama wersja, np. 2022.2/2023.x), płytka Basys3.

### Krok 1 – (opcjonalnie, ale zalecane) sprawdzenie w symulacji
Symulacja zastępuje MicroBlaze testbenchem, który robi to samo (zapisy/odczyty AXI):

```bash
. env.sh
run_simulation -t ssr_axi_lite          # tekstowo
# albo graficznie:
run_simulation -g -t ssr_axi_lite
```

W konsoli powinno pojawić się `RESULT=…` (0=other, 1=on, 2=off). To potwierdza,
że cała ścieżka „AXI → DSP → NN → wynik” działa, zanim wejdziesz w Block Design.

### Krok 2 – spakowanie rdzenia jako custom IP
```bash
vivado -mode batch -source ip/package_ip.tcl
```
Powstaje `ip_repo/ssr_axi_lite_1.0`.

### Krok 3 – budowa Block Design (MicroBlaze + UART + nasze IP)
```bash
vivado -mode batch -source bd/create_bd.tcl
```
Skrypt tworzy projekt `build_mb/`, dodaje MicroBlaze (z pamięcią lokalną 64 KB,
Clocking Wizard, Proc System Reset, AXI Interconnect), AXI UARTLite oraz nasze IP
`ssr_axi_lite`, wyprowadza `usb_uart`, `led0`, zegar i reset, generuje wrapper i
podpina constraints.

> Jeśli skrypt zatrzyma się przez różnice nazw między wersjami Vivado, dokończ BD
> ręcznie wg **sekcji 5 (Wariant GUI)** – to te same czynności.

W **Address Editor** zanotuj adres bazowy `ssr_axi_lite_0` (np. `0x44A0_0000`).

### Krok 4 – bitstream
W otwartym projekcie: **Generate Bitstream** (albo Flow Navigator → Program and Debug).

### Krok 5 – eksport sprzętu
**File → Export → Export Hardware** → *Include bitstream* → zapisz `.xsa`.

### Krok 6 – aplikacja w Vitis
1. Vitis → **Create Platform Component** z wyeksportowanego `.xsa`.
2. **Create Application Component** (szablon „Empty Application (C)”), procesor `microblaze_0`.
3. Skopiuj do `src/` aplikacji pliki **`sw/main.c`** oraz **`sw/audio_samples.h`**.
4. Zbuduj (Build). Jeśli nazwa peryferium w `xparameters.h` jest inna niż założona,
   popraw `#define SSR_BASE …` w `main.c` (albo wpisz adres z Address Editor).

### Krok 7 – (opcjonalnie) własny plik audio
Domyślny `audio_samples.h` to 8192 próbki wycięte z `input_adcoff2.txt`. Aby użyć
własnego nagrania:

```bash
# z pliku WAV (wymaga numpy + librosa):
python sw/gen_audio_header.py --wav komenda_on.wav --len 8192 --out sw/audio_samples.h

# albo z gotowego pliku hex (format jak input_adcoff2.txt):
python sw/gen_audio_header.py --txt sim/python/generated_files/input_adcoff2.txt \
       --start 11000 --len 8192 --out sw/audio_samples.h
```

### Krok 8 – uruchomienie na płytce
1. Podłącz Basys3 (USB programuje i daje UART).
2. Otwórz terminal szeregowy **9600 8N1** (np. w Vitis – Serial Terminal).
3. W Vitis: **Program Device** (FPGA), potem **Run** aplikacji na MicroBlaze.
4. Na UART zobaczysz np.:
   ```
   === SSR / MicroBlaze - rozpoznawanie mowy z pliku w pamieci ===
   Liczba probek audio: 8192
   Wynik klasyfikacji: 1 -> ON  (zapalenie diody)
   ```
   Dioda LD0 ustawi się zgodnie z wynikiem (ON → zapalona, OFF → zgaszona).

---

## 4. Mapa rejestrów peryferium `ssr_axi_lite`

| Offset | Nazwa  | Dostęp | Opis |
|-------:|--------|:------:|------|
| `0x00` | SAMPLE | W | `[11:0]` próbka audio; **każdy zapis** generuje 1 takt `sample_valid` |
| `0x04` | CTRL   | W | bit0 `soft_reset` (impuls), bit1 `latch` (zatrzaśnij wynik), bit2 `but_enable` |
| `0x08` | STATUS | R | bit0 `result_valid` |
| `0x0C` | RESULT | R | `[1:0]` wynik: 0=other, 1=on, 2=off |

Sekwencja użycia (robi to `main.c`): `soft_reset` → strumień próbek do `SAMPLE`
→ `latch` → czekaj na `STATUS.valid` → czytaj `RESULT`.

---

## 5. Wariant GUI (gdyby `create_bd.tcl` nie przeszedł)

1. Nowy projekt RTL, część `xc7a35tcpg236-1`.
2. Settings → IP → Repository → dodaj `ip_repo`.
3. **Create Block Design**.
4. Dodaj **MicroBlaze** → *Run Block Automation*: Local Memory 64 KB, Debug „Debug Only”,
   Cache „None”, Interrupt „None”, Clock „New Clocking Wizard (100 MHz)”.
5. W Clocking Wizard ustaw `clk_out1` na **25 MHz** (bezpieczny timing dla rdzenia DSP).
6. Dodaj **AXI Uartlite** (9600) → *Run Connection Automation* (Auto).
7. Dodaj IP **ssr_axi_lite** → *Run Connection Automation* (S00_AXI → Auto).
8. Prawy klik na porcie `led0` → **Make External**; na interfejsie `UART` UARTLite → **Make External**.
9. Sprawdź, że zegar i reset są wyprowadzone na zewnętrzne porty (zegar 100 MHz, reset).
10. **Validate Design** → bez błędów.
11. *Sources* → prawy klik na `.bd` → **Create HDL Wrapper** (let Vivado manage).
12. Dodaj `fpga/constraints/top_ssr_mb_basys3.xdc`; jeśli nazwy portów wrappera są inne
    niż w pliku XDC, popraw nazwy w `[get_ports …]`.
13. Generate Bitstream → Export Hardware (z bitstreamem) → dalej jak w Kroku 6.

---

## 6. Uwagi praktyczne

- **Timing.** Rdzeń DSP w oryginale chodził na 4,5 MHz. Tu domyślnie ustawiam 25 MHz.
  Jeśli implementacja zgłosi negatywny slack, w Clocking Wizard zmniejsz `clk_out1`
  (np. do 10 MHz) lub zmień `set sys_clk` w `bd/create_bd.tcl`.
- **Pamięć.** 8192 próbki = 16 KB; mieści się w 64 KB pamięci lokalnej obok programu.
  Dla długiego nagrania albo zwiększ pamięć lokalną do 128 KB, albo trzymaj audio w
  osobnym Block Memory Generator inicjowanym plikiem `.coe` (MicroBlaze czyta je przez AXI BRAM Ctrl).
- **UART.** Na Basys3 RsRx=B18, RsTx=A18 (mostek USB-UART). Prędkość w IP i w terminalu = 9600.
- **Reset.** `btnC` (U18) jest aktywny w stanie wysokim – Proc System Reset ma `ext_reset_in`
  ustawiony na aktywny-wysoki przez automation; jeśli reset „trzyma”, sprawdź polaryzację.

---

## 7. Co dalej / otwarte decyzje

Patrz wiadomość w czacie – tam zebrałem pytania (długość/źródło audio, częstotliwość
rdzenia, czy audio ma jechać z .elf czy z osobnego BRAM/COE, wersja Vivado).
