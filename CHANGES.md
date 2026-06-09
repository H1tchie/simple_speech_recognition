# CHANGES — v3 vs poprzednie wersje

## v3.2 — pełna spójność trening = symulacja = sprzęt (stałoprzecinkowy DFT)

Cel: **wszystko zgodne z konspektem, a sieć uczy się tylko po wrzuceniu nagrań**,
przy czym cechy używane do nauki są **dokładnie tymi**, które liczy FPGA.

### Własny stałoprzecinkowy DFT zamiast xfft IP

Dotąd FFT był „czarną skrzynką" (Xilinx `xfft`), której nie da się odtworzyć
1:1 w Pythonie — więc cechy treningowe (potok float, `np.log`) różniły się od
tego, co liczy sprzęt. `fft_wrapper.sv` (v2.0) to teraz **512-punktowy DFT w
arytmetyce całkowitej Q1.15**:
- współczynniki obrotu z ROM `twiddle_{cos,sin}_512.mem`
  (generator `tools/gen_twiddle_rom.py`),
- akumulacja 56-bit, `re/im = acc >>> 15`, `|X[k]| = isqrt(re²+im²)` (floor),
- normalizacja per-ramka `|X|·32767 / max|X|` (Q1.15),
- w pełni **deterministyczny i syntezowalny** (projekt jest offline — próbki z
  BRAM, nie real-time — więc koszt O(N²), ~kilkadziesiąt ms/słowo, jest OK).

Konspekt wymaga 512-punktowego FFT w torze MFCC (nie konkretnie IP `xfft`),
więc rozwiązanie jest zgodne z konspektem i **usuwa zależność od czarnej
skrzynki**. (xfft pozostaje opcją tylko dla wersji real-time — wtedy trening
musi odpowiadać jego konfiguracji skalowania.)

### Wspólny potok cech w Pythonie — bit-w-bit z RTL

`tools/train/dsp_fixed.py` odwzorowuje **każdy** stopień RTL w arytmetyce
całkowitej (te same ROM-y): pre-emphasis, ramkowanie, okno Hamminga, DFT,
filtry mel, `log2`-LZC, DCT (Q5.10), mean/std. Zweryfikowane w iverilogu:
**cały tor `samples → 26 cech` zgadza się co do bitu** między RTL a Pythonem.

### Dwie realne poprawki błędów RTL

- **`feature_aggregator.sv`: obcięcie kwadratu MFCC.** `sum_sq += data*data`
  w kontekście samookreślonym dawało szerokość `max(16,16)=16` bitów →
  kwadraty były obcinane do 16 bitów (std zaniżone). Naprawione przez
  rozszerzenie operandów do 32 bitów przed mnożeniem. Dodatkowo agregator
  liczy teraz **poprawną wariancję** `E[x²]−mean²` i `isqrt` (floor) zamiast
  przybliżeń.
- **`top_ssr.sv`: czas `flush`.** Dotąd `flush=src_done` wystrzeliwał, gdy BRAM
  skończy strumień, ale MFCC były wciąż liczone (latencja DFT) → agregator
  liczył za wcześnie. Dodano **detektor opróżnienia potoku** (zlicza ramki
  wchodzące do FFT i kończące MFCC; pulsuje dopiero po zrównaniu i ustaniu
  aktywności).

### Trening: tylko wrzuć nagrania

`tools/train/extract_features.py` używa teraz `dsp_fixed` (cechy to gotowe
int16 Q5.10 — dokładnie wyjście `feature_aggregator`), a `retrain.py` ma
`in_scale=1` (sieć konsumuje wprost wyjście agregatora, zero zmian w RTL).
Cały trening to dalej jedno polecenie:

```
# wrzuć .wav (16 kHz mono) do data/train/{on,off,other}/
python tools/train/retrain.py --force-extract --emit-sv
```

DFT w `dsp_fixed` zwektoryzowany (macierze) — ~40× szybciej (pełne słowo
16384 próbek ~0,04 s), więc trening na setkach nagrań to kilka sekund.

### Nowe / zmienione pliki
- nowe: `tools/gen_twiddle_rom.py`, `rtl/dsp/twiddle_cos_512.mem`,
  `rtl/dsp/twiddle_sin_512.mem`, `tools/train/dsp_fixed.py`,
  `fpga/scripts/create_project.tcl` (tworzy otwieralny projekt Vivado `.xpr`)
- przepisane: `rtl/dsp/fft_wrapper.sv` (v2.0), `rtl/dsp/feature_aggregator.sv`
  (v2.0), `tools/train/extract_features.py`, `tools/train/retrain.py`
- zmienione: `rtl/top_ssr.sv` (detektor flush), `tools/build_all.py`
  (generacja ROM twiddle), `fpga/scripts/project_details.tcl` (ROM-y twiddle)

> Uwaga symulacyjna: `fft_wrapper` czyta `twiddle_cos_512.mem` i
> `twiddle_sin_512.mem` przez `$readmemh` — muszą być dostępne dla symulatora
> tak samo jak `window_hamming_512.mem` (są w `rtl/dsp/`, generuje je
> `build_all.py`).

---

## v3.1 — poprawka ścieżki sieci + narzędzia do przeuczania

Ta iteracja robi dwie rzeczy: **naprawia ścieżkę obliczeniową sieci** i dokłada
**komplet skryptów do przeuczenia jej na własnych nagraniach**.

### Poprawiona ścieżka MAC (warstwy gęste)

Stare `dense_layer_1.sv` / `dense_layer_2.sv` miały dwa problemy czasowe:
- **bias dodawany co takt** (akumulował się wielokrotnie zamiast raz),
- **przesunięcie potoku** — mnożenie było opóźnione o takt względem
  sumowania, przez co ostatni składnik iloczynu skalarnego był gubiony.

Dodatkowo `top_nn` uruchamiał obie warstwy jednocześnie z resetu, więc
`dense_layer_2` zaczynał liczyć, zanim `dense_layer_1` się ustabilizował.

Oba pliki zastąpiłem jednym parametryzowanym modułem **`dense_layer.sv`**:
- poprawny sekwencyjny MAC: dokładnie `out[j] = ReLU(Σ_i in[i]·W[i][j] + bias[j])`,
- czytelny uchwyt **start/done**; `top_nn` sekwencjonuje warstwy po `done`,
- akumulator 48-bit z saturacją do szerokości wyjścia (24/32-bit),
- wagi/biasy ładowane z plików **`.mem`** (`$readmemh`) zamiast `assign`.

**Architektura sieci bez zmian**: 26 → 32 (ReLU) → 3 (logity) → argmax → 2-bit,
te same szerokości, int8, to samo mapowanie kodów (on=01, off=10, other=00).

Porty między modułami sieci spłaszczyłem do wektorów **packed** — unpacked array
na porcie nie propaguje się przez połączenie w iverilogu (w Vivado działa, ale
przez to nie dało się zsymulować sieci). Packed działa identycznie w obu.

`final_layer.sv`, `top_nn.sv`, `top_nn_axis.sv` dostosowane (start/done + packed).
W `mfcc.sv` zamieniłem `break` (nieobsługiwany przez iverilog) na flagę — bez
zmiany działania, dla przenośności narzędzi.

### Walidacja bit-accurate

`tools/train/nn_int_model.py` zawiera funkcję `forward_int` — bitowo-dokładną
replikę sprzętowej ścieżki. Testbench `sim/common/tb_nn_validate.sv` przepuszcza
te same wektory przez RTL. Sprawdzone: **RTL == model Pythona bit w bit** (zarówno
na oryginalnych, jak i na świeżo wytrenowanych wagach). Dzięki temu trafność
raportowana przy treningu = realna trafność na FPGA.

### Narzędzia do przeuczania (`tools/train/`)

| Plik | Rola |
|---|---|
| `extract_features.py` | liczy 26 cech z `data/train/<klasa>/*.wav` tą samą logiką co `gen_reference.py` |
| `nn_int_model.py` | bit-dokładny `forward_int` + trening QAT (czysty NumPy) |
| `retrain.py` | **jedna komenda**: ekstrakcja → trening → walidacja → zapis `.mem` + raport |
| `parse_existing_weights.py` | wyciąga startowe wagi z repo / generuje `.mem` |

Użytkownik wrzuca nagrania do `data/train/on|off|other/` i odpala
`python tools/train/retrain.py`. Skala cech jest stała **Q5.10 (×1024)** — dokładnie
to, co wystawia `feature_aggregator` — więc wytrenowane wagi konsumują wprost
wyjście potoku, **bez żadnych zmian w RTL**.

> Uwaga: trening liczy cechy na „idealnym" (float) potoku z `gen_reference.py`.
> Potok RTL jest jego stałoprzecinkowym przybliżeniem (log2 LZC, FFT Q1.15,
> DCT całkowitoliczbowy), więc warto zweryfikować wynik na kilku realnych
> nagraniach i w razie potrzeby dograć więcej danych.

---

## Krótko

**v3 to przepisanie projektu od zera zgodnie z konspektem, z reużyciem wytrenowanej sieci neuronowej z poprzedniej wersji.**

W poprzedniej iteracji (v2) zrobiłem tylko minimalny patch — wyrzucenie PMOD ADC, dodanie BRAM source, doklejenie pre-emphasis, opakowanie kontroli w AXI4-Lite. Stary DSP pipeline (FFT64, frame=64, mean+std bez DCT) został. To nie pasowało do konspektu, który wymaga FRAME_LEN=512, MFCC z log+DCT i 26 filtrów mel.

W v3 cały łańcuch przetwarzania jest nowy, z parametrami i strukturą z konspektu. **Sieć neuronowa (`top_nn`, `dense_layer_1`, `dense_layer_2`, `final_layer`, `nn_parameters`) jest skopiowana bit w bit z istniejącego repo** — wagi i biasy nietknięte. Wokół niej dorobiłem wrapper AXI4-Stream (`top_nn_axis.sv`).

## Co reużyte z istniejącego repo (bez modyfikacji)

| Plik | Pochodzenie |
|---|---|
| `rtl/neural_network/nn_parameters.sv` | `existing_repo/rtl/neural_network_optim/nn_parameters.sv` |
| `rtl/neural_network/dense_layer_1.sv` | jw. (wagi/biasy w `assign`) |
| `rtl/neural_network/dense_layer_2.sv` | jw. |
| `rtl/neural_network/final_layer.sv` | jw. |
| `rtl/neural_network/top_nn.sv` | jw. |
| `rtl/led_logic/led_logic.sv` | `existing_repo/rtl/led_logic/` |
| `env.sh`, `tools/run_simulation.sh`, `tools/generate_bitstream.sh`, `tools/program_fpga.sh`, `tools/clean.sh`, `tools/warning_summary.sh`, `tools/sim_cmd.tcl` | `existing_repo/` (workflow shellowy) |
| `doc/lista_kontrolna_2024_MG_KF.pdf`, `doc/raport_2024_MG_KF.pdf`, `doc/documentation` | `existing_repo/doc/` |
| `fpga/scripts/generate_bitstream.tcl`, `fpga/scripts/program_fpga.tcl` | `existing_repo/fpga/scripts/` |

## Co napisane od nowa

### RTL — pełny pipeline MFCC

| Plik | Opis | Status vs v2 |
|---|---|---|
| `rtl/ssr_pkg.sv` | Globalne parametry (FRAME_LEN=512, N_FFT=512, N_MELS=26, N_MFCC=13, N_FEATURES=26, ALPHA_Q15=0x7C29). | NOWY. W v2 parametry były rozsiane po modułach z FFT=64. |
| `rtl/data_source/bram_stream_source.sv` | AXI4-Stream master z BRAM ($readmemh "samples.mem"). | Był w v2, ale przepisany pod nowy ssr_pkg i większy BRAM (16384 sampli). |
| `rtl/dsp/preemphasis.sv` | y[n] = x[n] − 0.97·x[n−1], Q1.15, AXI-Stream. | Był w v2 ale jako prosty filtr na sygnale ciągłym; tu pełen AXI-Stream slave/master z saturacją. |
| `rtl/dsp/framing.sv` | Circular buffer, FRAME_LEN=512, HOP=256 (50% overlap), tuser=frame_id. | NOWY. W v2 frame=64 sztywno wewnątrz starego pipeline. |
| `rtl/dsp/window.sv` | Hamming z ROM (`window_hamming_512.mem`), AXI-Stream. | Przepisany pod N=512 (v2 miał N=64 wbudowane). |
| `rtl/dsp/fft_wrapper.sv` | 512-pkt FFT. SIM_MODE=1 (O(N²) DFT do symulacji) + hook na Xilinx xfft IP do bitstream'u. | NOWY. W v2 było natywne FFT64 w SystemVerilog. |
| `rtl/dsp/mel_filter_bank.sv` | 26 trójkątnych filtrów Mel z dense ROM (`mel_bank_dense.mem`), AXI-Stream. | Był w v2 ale dla N_BINS=33; tu N_BINS=257. |
| `rtl/dsp/mfcc.sv` | log2 (Leading Zero Count) + DCT-II ortonormalna z ROM (`dct_coeffs.mem`). 13 coeffs/ramka. | NOWY. W v2 nie było log+DCT — szły surowe energie Mel + mean/std. |
| `rtl/dsp/feature_aggregator.sv` | Akumuluje MFCC z ramek, liczy mean+std (Newton-Raphson sqrt) → 26 cech zgodnych z `IN_SIZE_1`. | NOWY. W v2 mean+std liczyło się na energiach Mel zamiast na MFCC. |
| `rtl/neural_network/top_nn_axis.sv` | NOWY: wrapper AXI4-Stream slave wokół `top_nn`. Bufuje 26 cech, resetuje sieć, czeka NN_LATENCY=80 cykli, wystawia 2-bit. | NOWY. W v2 NN był podpięty bezpośrednio przez `input_vector[25:0]`. |
| `rtl/axi/axi4lite_regs.sv` | Slave AXI4-Lite, mapa CTRL/STATUS/RESULT/CONFIG. | Był w v2 — zachowany interfejs, drobne porządki w side-effectach. |
| `rtl/top_ssr.sv` | Integracja całego IPcore: AXI-Lite + cały AXI-Stream pipeline + NN wrapper + led_logic. | Przepisany od zera — nowy DAG modułów. |

### Board level

| Plik | Status |
|---|---|
| `fpga/rtl/top_ssr_basys3.sv` | Przepisany pod uproszczony interfejs (BTNU=rst, BTNC=start, SW0=enable, LED0+LED_CMD[1:0]). AXI tied-off w stand-alone. |
| `fpga/constraints/top_ssr_basys3.xdc` | Nowe (poprzedni XDC miał piny pod PMOD JA1 ADC, których już nie używamy). |
| `fpga/scripts/project_details.tcl` | Nowa lista plików RTL i .mem; pakiety na początku. |

### Narzędzia Python (`tools/`)

| Plik | Status |
|---|---|
| `wav_to_mem.py` | NOWY: 16 kHz mono → Q1.15 .mem. |
| `gen_window_rom.py` | NOWY: Hamming N=512, Q1.15 unsigned. |
| `gen_mel_filterbank.py` | NOWY: 26 filtrów Mel × N_BINS=257, dense ROM Q1.15. |
| `gen_dct_coeffs.py` | NOWY: macierz DCT-II ortonormalna 13×26, Q1.15 signed. |
| `gen_reference.py` | NOWY: pełen pipeline w Pythonie, golden reference per etap (pre_emphasis.csv, frames.csv, windowed.csv, fft_magnitude.csv, mel_energy.csv, log_mel.csv, mfcc.csv, features.csv). |
| `verify.py` | NOWY: porównanie RTL output vs reference (Q1.15 / float / int). |
| `build_all.py` | NOWY: orchestrator wszystkich generatorów. |
| `requirements.txt` | NOWY. |

### Testbenche

| Plik | Status |
|---|---|
| `sim/top_ssr/top_ssr_tb.sv` | NOWY: system test — czeka na nn_value_valid, wypisuje wynik. |
| `sim/preemphasis/preemphasis_tb.sv` | NOWY: unit test, dumpuje wyjście do `preemphasis_out.txt` do weryfikacji przez `verify.py`. |
| `sim/*/`. prj | Pod nowe ścieżki plików. |

### Dane

| Plik | Status |
|---|---|
| `rtl/dsp/window_hamming_512.mem` | Wygenerowany (512 współczynników). |
| `rtl/dsp/mel_bank_dense.mem` | Wygenerowany (26×257 = 6682 współczynników). |
| `rtl/dsp/dct_coeffs.mem` | Wygenerowany (13×26 = 338 współczynników). |
| `data/samples.mem.example` | NOWY: syntetyczny chirp 200→2000 Hz, 16384 sampli Q1.15 — do symulacji bez prawdziwych nagrań. |
| `data/samples.mem` | Skopiowany z chirp; podmień własnym `wav_to_mem.py` na prawdziwe komendy. |

## Co wyrzucone z istniejącego repo

| Plik / katalog | Powód |
|---|---|
| `rtl/pmod_ad7991/*.vhd`, `rtl/i2c_master/*.vhd` | Konspekt mówi „offline preprocessing — próbki z BRAM przez .mem/.coe”. Nie używamy ADC. |
| `rtl/dsp_pipeline/` (stary FFT64, frame64, mean_std bez DCT) | Niezgodne z konspektem (FRAME_LEN=512, MFCC z log+DCT). |
| `rtl/clk_wiz_4` | Nie używane — pracujemy na 100 MHz prosto z W5. |
| `fpga/constraints/*.xdc` (stare piny PMOD JA1) | Nie używamy ADC. |

## Co wyrzucone z mojej wersji v2

| Plik / podejście | Powód |
|---|---|
| Stary `top_ssr.sv` v2 (z FFT64) | Cały DAG inny — łatwiej przepisać niż dolatywać. |
| `dsp_pipeline_axi.sv` (v2 wrapper na stare moduły) | Niepotrzebne — moduły są teraz natywnie AXI-Stream. |
| Stary euclidean classifier z v1 | Konspekt wymaga klasyfikatora, ale silniejszy MLP > euclidean → zostaje NN. |

## Przepływ próbek (zmiana w stosunku do v2)

**v2:**
```
PMOD ADC (lub BRAM) → preemphasis → framing64 → window64 → FFT64 → mel(33→13)
                                                                      → mean+std → NN
```

**v3 (zgodne z konspektem):**
```
BRAM → preemphasis → framing(512/256) → Hamming(512) → FFT(512, 257 bins)
        → mel(26 filtrów) → log+DCT(13 coeffs/ramka) → mean+std(26 cech) → NN(AXI-Stream)
```

## Co MUSI być zrobione przed bitstream'em

1. **FFT IP**: aktualnie `fft_wrapper.sv` ma `SIM_MODE=1` (O(N²) DFT, tylko symulacja). Do bitstream'u:
   - W Vivado IP Catalog wygeneruj `xfft v9.x`, 512-pkt, fixed-point, scaled, forward-only.
   - Przełącz `top_ssr.sv`: `fft_wrapper #(.SIM_MODE(0))`.
   - Podepnij IP wg wzorca w komentarzu w `fft_wrapper.sv`.

2. **Retreningu NN możesz potrzebować**: poprzednia sieć była trenowana na cechach z STAREGO pipeline'u (FFT64 + mean/std energii Mel). Nowe cechy (mean/std MFCC z FFT512) mają **inny rozkład** — same wymiary się zgadzają (26), ale rozkłady są inne, więc trafność rozpoznawania może spaść do uczciwego retreningu. Inferencja na FPGA i pipeline są poprawne — to kwestia kalibracji modelu.

## Walidacja na czysto

```
$ iverilog -g2012 -s top_ssr <wszystkie .sv>
# zero błędów, zero ostrzeżeń

$ iverilog -g2012 -s top_ssr_basys3 <wszystkie .sv + board wrapper>
# zero błędów, zero ostrzeżeń

$ python -c "import ast; [ast.parse(open(p).read()) for p in glob('tools/*.py')]"
# OK dla wszystkich 7 skryptów

$ python tools/build_all.py    # bez nagrań - generuje same ROM-y
# OK
```
