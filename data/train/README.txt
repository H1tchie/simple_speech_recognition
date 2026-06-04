Wrzuc tutaj swoje nagrania .wav (16 kHz, mono, pojedyncze slowo):

  data/train/on/      <- nagrania komendy "on"   (np. 30-50 plikow)
  data/train/off/     <- nagrania komendy "off"
  data/train/other/   <- inne dzwieki / cisza / mowa spoza komend

Potem z katalogu glownego projektu uruchom:

  python tools/train/retrain.py

Skrypt policzy cechy, przeuczy siec i zapisze wagi do
rtl/neural_network/dense*.mem. Architektura sieci sie nie zmienia.

Mapowanie klas -> wynik:
  on    -> kod 2'b01
  off   -> kod 2'b10
  other -> kod 2'b00
