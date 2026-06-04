# Simple Speech Recognition (FPGA, Basys3) — v3

Projekt zaliczeniowy z **Systemów dedykowanych w układach programowalnych**.

Autorzy: **Kacper Ferdek, Mateusz Gibas**
Platforma: **Digilent Basys3 (Xilinx Artix-7 XC7A35T)**

## Opis

System rozpoznaje proste komendy głosowe (`on`, `off`, `other`) realizując pełen łańcuch przetwarzania MFCC w FPGA jako IPcore, zgodnie z konspektem przedmiotu.

**Sieć neuronowa pochodzi z wcześniejszej wersji projektu** (3-warstwowy MLP, 26→32→3→2-bit; wagi i biasy wpisane jako `assign` w plikach `dense_layer_*.sv`). Reszta projektu (DSP pipeline, AXI, generator próbek z BRAM, narzędzia Python) została napisana od nowa zgodnie z konspektem.

## Architektura

```
samples.mem (BRAM)
   │
   ▼ AXI4-Stream
bram_stream_source
   │
   ▼  AXI4-Stream
preemphasis  ─ y[n] = x[n] − 0.97·x[n−1]
   │
   ▼  AXI4-Stream  +  tuser=frame_id  +  tlast=koniec ramki
framing  ─  FRAME_LEN=512, HOP=256 (50% overlap)
   │
   ▼  AXI4-Stream
window  ─  Hamming (ROM Q1.15 z gen_window_rom.py)
   │
   ▼  AXI4-Stream
fft_wrapper  ─  512-pkt FFT (SIM_MODE | xfft IP), output |X[k]|, N_BINS=257
   │
   ▼  AXI4-Stream
mel_filter_bank  ─  26 filtrów trójkątnych (dense ROM z gen_mel_filterbank.py)
   │
   ▼  AXI4-Stream
mfcc  ─  log2 (LZC) + DCT-II (ROM z gen_dct_coeffs.py), 13 coeffs/ramka
   │
   ▼  AXI4-Stream  +  flush=src_done
feature_aggregator  ─  mean+std MFCC po wszystkich ramkach → 26 cech
   │
   ▼  AXI4-Stream (26 × signed [15:0])
top_nn_axis  ─  wrapper AXI dla top_nn z poprzedniej wersji
   │
   ▼  AXI4-Stream (1 × 2-bit)
led_logic / AXI4-Lite RESULT
```

Sterowanie IPcorem przez **AXI4-Lite slave** (mapa rejestrów poniżej) — można podpiąć MicroBlaze/PicoRV32. W wersji stand-alone na Basys3 ten sam start jest też dostępny przez przycisk **BTNC**.

## Mapa rejestrów AXI4-Lite

| Offset | Rejestr  | RW  | Bity                                        |
|--------|----------|-----|---------------------------------------------|
| 0x00   | CTRL     | W   | [0] start, [1] soft_reset                   |
| 0x04   | STATUS   | R   | [0] busy, [1] done, [2] error               |
| 0x08   | RESULT   | R   | [1:0] command_id (00=other, 01=on, 10=off)  |
| 0x0C   | CONFIG   | RW  | rezerwa                                     |

Typowy ciąg z procesora:
1. zapis 1 do CTRL → IPcore startuje
2. polling STATUS aż done=1
3. odczyt RESULT → command_id

## Struktura katalogów

```
.
├── rtl/
│   ├── ssr_pkg.sv                  globalne parametry (FRAME_LEN, N_FFT, ...)
│   ├── data_source/
│   │   └── bram_stream_source.sv   AXI-Stream master z BRAM (samples.mem)
│   ├── dsp/                        łańcuch przetwarzania - cały nowy
│   │   ├── preemphasis.sv
│   │   ├── framing.sv
│   │   ├── window.sv               (+ window_hamming_512.mem)
│   │   ├── fft_wrapper.sv
│   │   ├── mel_filter_bank.sv      (+ mel_bank_dense.mem)
│   │   ├── mfcc.sv                 (+ dct_coeffs.mem)
│   │   └── feature_aggregator.sv
│   ├── neural_network/             SIEĆ Z POPRZEDNIEJ WERSJI (bez zmian)
│   │   ├── nn_parameters.sv
│   │   ├── dense_layer_1.sv        wagi/biasy w assign
│   │   ├── dense_layer_2.sv
│   │   ├── final_layer.sv
│   │   ├── top_nn.sv
│   │   └── top_nn_axis.sv          NOWY: wrapper AXI4-Stream
│   ├── led_logic/                  z poprzedniej wersji (bez zmian)
│   ├── axi/
│   │   └── axi4lite_regs.sv        slave AXI4-Lite (CTRL/STATUS/RESULT/CONFIG)
│   └── top_ssr.sv                  integracja IPcore
├── fpga/
│   ├── rtl/top_ssr_basys3.sv       board-level wrapper
│   ├── constraints/top_ssr_basys3.xdc
│   └── scripts/                    generate_bitstream.tcl, project_details.tcl, ...
├── sim/
│   ├── top_ssr/                    system testbench
│   ├── preemphasis/                unit testbench
│   └── common/
├── tools/                          generatory Python + workflow shell
│   ├── wav_to_mem.py               .wav → .mem (Q1.15)
│   ├── gen_window_rom.py
│   ├── gen_mel_filterbank.py
│   ├── gen_dct_coeffs.py
│   ├── gen_reference.py            golden reference per stage
│   ├── verify.py
│   ├── build_all.py                orchestrator
│   ├── requirements.txt
│   ├── run_simulation.sh           (zachowany workflow z v1)
│   ├── generate_bitstream.sh
│   ├── program_fpga.sh
│   └── ...
├── data/                           próbki audio + wygenerowane .mem
├── doc/                            konspekt, raport, lista kontrolna
├── env.sh                          inicjalizacja środowiska
├── README.md
└── CHANGES.md                      lista zmian vs poprzedniej wersji
```

## Quick start

### 1. Środowisko Python

```bash
pip install -r tools/requirements.txt
```

### 2. Generacja ROM-ów i (opcjonalnie) golden reference

```bash
python tools/build_all.py
```

Bez nagrań w `data/*.wav` zostaną wygenerowane same ROM-y (window, mel, DCT). Z nagraniami dodatkowo `samples.mem` i `data/results/<cmd>/*.csv` per komenda.

### 3. Próbki do BRAM

```bash
# Pojedyncza komenda:
python tools/wav_to_mem.py data/on.wav data/samples.mem --max-samples 16384
```

Lub użyj wygenerowanego `data/samples.mem.example` (syntetyczny chirp) żeby uruchomić symulację bez nagrań.

### 4. Symulacja

```bash
. env.sh
run_simulation -t preemphasis     # unit test
run_simulation -t top_ssr         # cały pipeline (uwaga: SIM_MODE FFT = O(N²), długo!)
run_simulation -g -t top_ssr      # GUI
```

Weryfikacja przeciw referencji:

```bash
python tools/verify.py sim/build/preemphasis_out.txt data/results/on/pre_emphasis.csv --fmt q15
```

### 5. Bitstream

```bash
generate_bitstream     # → fpga/build/.../ssr_project.bit
program_fpga
```

### 6. Praca z płytką

| Element | Funkcja |
|---|---|
| **BTNU** | reset systemu |
| **BTNC** | start rozpoznawania |
| **SW0**  | enable: pozwala led_logic aktualizować LED0 |
| **LED0** | wynik klasyfikacji on/off |
| **LED1, LED2** | command_id w binarce (00/01/10) |

## Parametry potoku (RTL ↔ Python — muszą się zgadzać)

| Parametr | Wartość | Plik |
|---|---|---|
| fs | 16 000 Hz | wav_to_mem.py, gen_reference.py |
| Format | Q1.15 signed | wszędzie |
| FRAME_LEN | 512 | `ssr_pkg::FRAME_LEN` |
| HOP_LEN | 256 (50% overlap) | `ssr_pkg::HOP_LEN` |
| N_FFT | 512 | `ssr_pkg::N_FFT` |
| α (pre-emphasis) | 0.97 (Q1.15 = 0x7C29) | `ssr_pkg::ALPHA_Q15` |
| N_MELS | 26 | `ssr_pkg::N_MELS` |
| N_MFCC | 13 | `ssr_pkg::N_MFCC` |
| N_FEATURES (do NN) | 26 (13 mean + 13 std) | `ssr_pkg::N_FEATURES` |

## Zgodność z konspektem

| Sekcja konspektu | Realizacja |
|---|---|
| 2.2 .wav → .mem (Q1.15) | `tools/wav_to_mem.py` |
| 2.2 golden reference (librosa) | `tools/gen_reference.py` |
| 2.3 BRAM init przez .mem/.coe | `bram_stream_source.sv` (`$readmemh`) |
| 3.1 procesor + IPcore + AXI | `axi4lite_regs.sv` (slave AXI4-Lite) + AXI4-Stream między modułami |
| 3.2 diagram blokowy (pipeline) | `top_ssr.sv` |
| 4.3 Pre-emphasis y[n]=x[n]−0.97·x[n−1] | `preemphasis.sv` |
| 4.4 Framing + Windowing (Hamming) | `framing.sv`, `window.sv` |
| 4.5 FFT + magnitude | `fft_wrapper.sv` (SIM_MODE + hook na xfft IP) |
| 4.6 Mel filter bank | `mel_filter_bank.sv` |
| 4.7 Log + DCT (MFCC) | `mfcc.sv` (log2 LZC, DCT-II ortonormalna) |
| 4.8 Klasyfikator | `top_nn_axis.sv` (MLP z poprzedniej wersji w wrapperze AXI-Stream) |
| 4.9 Wyjście LED | `led_logic.sv` |
| 5. Weryfikacja jednostkowa + system | `sim/*`, `tools/verify.py` |

### Klasyfikator: NN zamiast DTW/euclidean

Konspekt sekcja 4.8 wymaga klasyfikatora; jako *wersję podstawową* wymienia minimum euclidean. **Naszą realizacją jest sieć neuronowa** (3-warstwowy MLP, 26→32→3 + argmax → 2-bit), która jest mocniejszym klasyfikatorem niż minimum dystansu. Wagi i biasy są int8, ładowane z plików `rtl/neural_network/dense*.mem` przez `$readmemh` — dzięki temu przeuczenie sprowadza się do nadpisania tych plików (patrz niżej).

## Przeuczanie sieci na własnych nagraniach

Ścieżka obliczeniowa warstw jest zweryfikowana **bit w bit** względem modelu w Pythonie (`tools/train/nn_int_model.py` ↔ `sim/common/tb_nn_validate.sv`), więc trafność z treningu = realna trafność na FPGA.

**Krok 1.** Wrzuć nagrania `.wav` (16 kHz, mono, pojedyncze słowo) do folderów:

```
data/train/on/      data/train/off/      data/train/other/
```

Zalecane ~30–50 nagrań na klasę, w miarę równo. `other` = inne dźwięki / cisza / mowa spoza komend.

**Krok 2.** Z katalogu głównego projektu:

```bash
pip install -r tools/requirements.txt   # raz (numpy, soundfile, scipy)
python tools/train/retrain.py
```

Skrypt: policzy 26 cech z każdego nagrania (tą samą logiką co `gen_reference.py`), przeuczy sieć (QAT w czystym NumPy), wybierze najlepszy wariant wg trafności liczonej bitowo-dokładnym modelem sprzętu, **nadpisze `rtl/neural_network/dense*.mem`** i wypisze raport (trafność + macierz pomyłek). Architektura sieci się nie zmienia.

Przydatne flagi: `--epochs 600` (dłuższy trening), `--seed 1` (inna inicjalizacja), `--emit-sv` (dodatkowo zapisze bloki `assign` jako kopię).

**Skala cech.** Trening używa skali **Q5.10 (×1024)** — dokładnie tej, w której `feature_aggregator` wystawia mean+std MFCC. Wytrenowane wagi konsumują więc wprost wyjście potoku, **bez żadnych zmian w RTL**.

> Uwaga: cechy do treningu liczone są na „idealnym" (float) potoku. Potok RTL jest jego stałoprzecinkowym przybliżeniem (log2 LZC, FFT Q1.15, DCT całkowitoliczbowy), więc po syntezie warto sprawdzić wynik na kilku realnych nagraniach; w razie potrzeby dograj więcej danych i przeucz ponownie.

## Zasoby FPGA (szacunkowo)

Pełna implementacja wymaga regeneracji bitstream'u; szacunkowe oczekiwania (Artix-7):

| Zasób | Oczekiwane |
|---|---|
| LUT | ~4 500 |
| FF  | ~2 500 |
| DSP48 | 10–14 (FFT, mel, NN multipliers) |
| BRAM | 4–6 (samples, window ROM, mel ROM) |
| f_clk | 100 MHz |

## Uwagi implementacyjne

- **FFT**: `fft_wrapper.sv` ma dwa tryby. `SIM_MODE=1` (domyślny) używa programowego DFT O(N²) - tylko do symulacji funkcjonalnej. Do bitstream'u przełącz na `SIM_MODE=0` i wygeneruj w Vivado IP Catalog `xfft v9.x` (512-pkt, fixed-point, scaled) — wzorzec podpięcia jest w komentarzu pliku.
- **log2 w MFCC**: zaaproksymowane przez Leading Zero Count (`log2_approx`) — wystarczająca precyzja dla MFCC, oszczędność LUT-a vs. tabela.
- **feature_aggregator**: mean+std MFCC dla całej wypowiedzi → 26 cech. To dopasowuje się dokładnie do `IN_SIZE_1=26` istniejącej sieci. `gen_reference.py` używa tej samej formuły, więc weryfikacja vs. Python jest poprawna.
- **NN AXI wrapper**: `top_nn_axis.sv` buforuje 26 cech, daje puls `start` do `top_nn` i czeka na `done` (czysty uchwyt, bez zgadywania latencji). `top_nn` sekwencjonuje `dense_layer_1 → dense_layer_2 → final_layer` po sygnałach `done`.

## TODO

- [ ] Per-stage testbenche dla `framing`, `window`, `fft_wrapper`, `mel_filter_bank`, `mfcc`, `feature_aggregator`
- [ ] Wygenerowanie `xfft` IP i przełączenie `SIM_MODE=0`
- [ ] Block design z MicroBlaze podpiętym do AXI4-Lite slave + minimalny program C
- [x] Re-trening sieci na cechach z nowego pipeline — narzędzia w `tools/train/`, jedna komenda `python tools/train/retrain.py` (patrz sekcja „Przeuczanie sieci")
- [ ] Regeneracja bitstreamu (poprzedni v2 `results/top_ssr_basys3.bit` jest nieaktualny)
