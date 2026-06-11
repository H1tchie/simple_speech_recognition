/******************************************************************************
 * main.c  -  Aplikacja MicroBlaze dla projektu SSR (wersja bez ADC)
 *
 * Autorzy: Mateusz Gibas, Kacper Ferdek
 *
 * Co robi:
 *   1. Trzyma plik audio w pamieci procesora jako tablica audio_samples[]
 *      (12-bitowe probki "ADC", wygenerowane z pliku WAV - patrz gen_audio_header.py).
 *   2. Resetuje rdzen SSR (peryferium AXI4-Lite ssr_axi_lite).
 *   3. Strumieniuje probki jedna po drugiej, zapisujac rejestr SAMPLE
 *      (kazdy zapis = jeden takt sample_valid w sprzecie).
 *   4. Zatrzaskuje wynik (CTRL.latch), czeka na STATUS.valid i odczytuje RESULT.
 *   5. Wypisuje wynik przez UART i ustawia/gasi diode (CTRL.but_enable).
 *
 * Mapa rejestrow peryferium (offsety bajtowe od bazy):
 *   0x00 SAMPLE (W) : [11:0] probka,  kazdy zapis -> sample_valid
 *   0x04 CTRL   (W) : bit0 soft_reset, bit1 latch, bit2 but_enable
 *   0x08 STATUS (R) : bit0 result_valid
 *   0x0C RESULT (R) : [1:0] wynik (0=other, 1=on, 2=off)
 ******************************************************************************/
#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "audio_samples.h"   /* definiuje: audio_samples[] oraz AUDIO_LEN */

/* Baza peryferium - nazwa z xparameters.h. Jezeli kreator nada inna nazwe,
 * podmien ponizsza definicje (np. XPAR_SSR_AXI_LITE_0_BASEADDR). */
#ifndef SSR_BASE
  #ifdef XPAR_SSR_AXI_LITE_0_S00_AXI_BASEADDR
    #define SSR_BASE  XPAR_SSR_AXI_LITE_0_S00_AXI_BASEADDR
  #elif defined(XPAR_SSR_AXI_LITE_0_BASEADDR)
    #define SSR_BASE  XPAR_SSR_AXI_LITE_0_BASEADDR
  #else
    #define SSR_BASE  0x44A00000  /* typowy adres - SPRAWDZ w Address Editor */
  #endif
#endif

#define REG_SAMPLE  0x00
#define REG_CTRL    0x04
#define REG_STATUS  0x08
#define REG_RESULT  0x0C

/* Bity CTRL */
#define CTRL_SOFT_RESET  (1u << 0)
#define CTRL_LATCH       (1u << 1)
#define CTRL_BUT_EN      (1u << 2)

static inline void ssr_write(u32 off, u32 val) { Xil_Out32(SSR_BASE + off, val); }
static inline u32  ssr_read (u32 off)          { return Xil_In32(SSR_BASE + off); }

int main(void)
{
    xil_printf("\r\n=== SSR / MicroBlaze - rozpoznawanie mowy z pliku w pamieci ===\r\n");
    xil_printf("Liczba probek audio: %d\r\n", (int)AUDIO_LEN);

    /* 1. Miekki reset rdzenia (czysci potok DSP, NN i flage wyniku) */
    ssr_write(REG_CTRL, CTRL_SOFT_RESET);

    /* maly odstep, aby reset zostal rozciagniety w sprzecie */
    for (volatile int d = 0; d < 1000; d++) { }

    /* 2. Strumieniowanie probek. Kazdy zapis SAMPLE generuje jeden impuls
     *    sample_valid -> modul framing_axi pobiera dokladnie jedna probke. */
    for (u32 i = 0; i < AUDIO_LEN; i++) {
        ssr_write(REG_SAMPLE, (u32)(audio_samples[i] & 0x0FFF));
    }

    /* 3. Zatrzasniecie wyniku i wlaczenie sterowania dioda (but_enable=1). */
    ssr_write(REG_CTRL, CTRL_LATCH | CTRL_BUT_EN);

    /* 4. Czekamy az wynik bedzie gotowy. */
    u32 timeout = 1000000;
    while (((ssr_read(REG_STATUS) & 0x1) == 0) && timeout--) { }

    if ((ssr_read(REG_STATUS) & 0x1) == 0) {
        xil_printf("BLAD: wynik nie zostal zatrzasniety (timeout).\r\n");
        return -1;
    }

    /* 5. Odczyt i interpretacja wyniku. */
    u32 res = ssr_read(REG_RESULT) & 0x3;
    const char *label;
    switch (res) {
        case 1:  label = "ON  (zapalenie diody)";   break;
        case 2:  label = "OFF (zgaszenie diody)";   break;
        default: label = "OTHER (komenda inna)";    break;
    }
    xil_printf("Wynik klasyfikacji: %d -> %s\r\n", (int)res, label);

    xil_printf("=== Koniec ===\r\n");
    return 0;
}
