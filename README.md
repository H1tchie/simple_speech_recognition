# Simple-speech-recognisition
***Projekt na układy elektroniki cyfrowej 2***
## Omówienie projektu/Zasada działania
- do płytki basys3 jest podpięte adc, z którego są wyprowadzone dwa kabelki zlutowane z gniazdem typu jack, do którego podpięty jest mikrofon
- przełączenie switcha będzie skutkowało zbieraniem mowy
- po usłyszeniu prostej komendy będzie zapalana i gaszona dioda na płytce
### extra
- kontrola świateł w mieszkaniu wyświetlanym na ekranie za pomocą komend głosowych i przycisków służących wyborowi pokojów

## Praca z repozytorium
Projekt będzie podzielony na części dlatego na każdą z nich proponuje użyć innego brancha z masterem mergujemy po wykonaniu wszystkiego w danej części

- Najpierw pobieramy repozytorium:
```
git clone https://github.com/Ferdziu10/Simple-speech-recognisition
```
- Sprawdzamy listę istniejących branchy:
```
git branch
```
- Tworzymy branch na którym chcemy pracować (0_prep) :
```
git branch 0_prep
```
- Przełączamy się na niego i ładujemy zmiany
```
git checkout 0_preparation
git pull
```
- Po wszystkich dokonanych zmianach ładujemy pliki spowrotem 
```
git add .
git commit
git push
```

- oczywiście w dowolnym momencie możemy uruchomić `git status` aby dowiedzieć się czy przesyłamy to co chcemy

## Praca z projektem
- na początku:
```
. env.sh
```
- uruchomienie symulacji tekstowo
```
run_simulation -t <nazwa symulacji>
```
- uruchomienie symulacji graficznie
```
run_simulation -g -t <nazwa symulacji>
```
- generacja bitstreamu
```
generate_bitstream
```
- zaprogramowanie fpga wygenerowanym bitstreamem
```
program_fpga
```



Aby mel_filter_bank działał poprawnie należy do folderu Simple-speech-recognisition\fpga\build\ssr_project.gen\sources_1 dodac folder ip zawarty w folderu rtl/mel_filer lub wygenerowac ip core multiple o zadanych właściwościach (ostatecznie modul dziala tez z modulem multoiuplier takze nie trzeba nioc zmieniać) wiadomosc zostawaim dla potomnych
