/******************************************************************************
 * main.c  -  SSR na ZedBoard (Zynq PS + ARM Cortex-A9), 5 przyciskow
 *
 * Autorzy: Mateusz Gibas, Kacper Ferdek
 *
 * Dzialanie:
 *   - kazdy z 5 przyciskow odpala INNY plik audio (z audio_files.h),
 *   - po nacisnieciu procesor strumieniuje probki do rdzenia SSR (AXI4-Lite),
 *     rdzen liczy klasyfikacje, procesor odczytuje i wypisuje wynik na UART,
 *   - dioda LED jest sterowana sprzetowo przez rdzen (on->zapal, off->zgas).
 *
 *   Mapowanie przyciskow (zgodne z XDC):
 *     btn[0] BTNC -> plik 0 : ON  (good)
 *     btn[1] BTNU -> plik 1 : OFF (good)
 *     btn[2] BTND -> plik 2 : OTHER (good)
 *     btn[3] BTNL -> plik 3 : ON  (bad)
 *     btn[4] BTNR -> plik 4 : OTHER (bad)
 *   (W audio_files.h jest tez 6. plik OTHER(bad2) - niepodpiety pod przycisk.)
 *
 * Mapa rejestrow SSR (top_microblaze), offsety bajtowe od bazy:
 *   0x00 CTRL (W) bit0 soft_reset | 0x04 N_SAMPLES (W) | 0x08 SAMPLE (W)
 *   0x0C STATUS (R) bit0 ready, bit1 output_valid, bit2 busy | 0x10 RESULT (R) [1:0]
 ******************************************************************************/
#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "audio_files.h"

/* --- adres bazowy peryferium SSR (SPRAWDZ w Address Editor / xparameters.h) --- */
#ifndef SSR_BASE
  #ifdef XPAR_TOP_MICROBLAZE_0_S00_AXI_BASEADDR
    #define SSR_BASE  XPAR_TOP_MICROBLAZE_0_S00_AXI_BASEADDR
  #else
    #define SSR_BASE  0x43C00000   /* typowy adres na Zynq - SPRAWDZ */
  #endif
#endif

/* --- AXI GPIO z 5 przyciskami --- */
#ifndef BTN_GPIO_ID
  #ifdef XPAR_AXI_GPIO_0_DEVICE_ID
    #define BTN_GPIO_ID  XPAR_AXI_GPIO_0_DEVICE_ID
  #else
    #define BTN_GPIO_ID  0
  #endif
#endif
#define BTN_CHANNEL   1
#define N_BTN         5

#define REG_CTRL      0x00
#define REG_NSAMPLES  0x04
#define REG_SAMPLE    0x08
#define REG_STATUS    0x0C
#define REG_RESULT    0x10
#define CTRL_SOFT_RST (1u<<0)
#define ST_READY      (1u<<0)
#define ST_OVALID     (1u<<1)

static inline void ssr_w(u32 off, u32 v){ Xil_Out32(SSR_BASE+off, v); }
static inline u32  ssr_r(u32 off){ return Xil_In32(SSR_BASE+off); }

static XGpio btn_gpio;

/* Mapowanie: przycisk i -> indeks pliku w audio_files[] */
static const u32 btn_to_file[N_BTN] = { 0u, 1u, 2u, 3u, 4u };

/* Wyslij jeden plik audio do rdzenia i odczytaj wynik. */
static int process_file(const audio_file_t *f)
{
    xil_printf("\r\n[plik] %s  (%d probek)\r\n", f->name, (int)f->len);

    ssr_w(REG_CTRL, CTRL_SOFT_RST);
    for (volatile int d=0; d<2000; d++) {}

    ssr_w(REG_NSAMPLES, f->len);

    for (u32 i=0; i<f->len; i++) {
        u32 to = 2000000;
        while (!(ssr_r(REG_STATUS) & ST_READY) && --to) {}
        if (!to) { xil_printf("  BLAD: timeout przy probce %d\r\n", (int)i); return -1; }
        ssr_w(REG_SAMPLE, (u32)f->data[i]);
    }

    u32 to = 5000000;
    while (!(ssr_r(REG_STATUS) & ST_OVALID) && --to) {}
    if (!to) { xil_printf("  BLAD: timeout - brak wyniku\r\n"); return -1; }

    u32 res = ssr_r(REG_RESULT) & 0x3;
    const char *lab = (res==1) ? "ON" : (res==2) ? "OFF" : "OTHER";
    xil_printf("  -> wynik = %d (%s)\r\n", (int)res, lab);
    return (int)res;
}

static inline u32 btn_read(void){
    return XGpio_DiscreteRead(&btn_gpio, BTN_CHANNEL) & ((1u<<N_BTN)-1u);
}

int main(void)
{
    int st = XGpio_Initialize(&btn_gpio, BTN_GPIO_ID);
    if (st != XST_SUCCESS) xil_printf("BLAD inicjalizacji AXI GPIO\r\n");
    XGpio_SetDataDirection(&btn_gpio, BTN_CHANNEL, 0xFFFFFFFF); /* wejscia */

    xil_printf("\r\n=== SSR / ZedBoard - 5 przyciskow, 5 plikow ===\r\n");
    xil_printf("BTNC=ON(good) BTNU=OFF(good) BTND=OTHER(good) BTNL=ON(bad) BTNR=OTHER(bad)\r\n");

    u32 prev = btn_read();

    for (;;) {
        u32 now = btn_read();
        u32 pressed = now & ~prev;          /* bity, ktore wlasnie sie zapalily (zbocze) */

        if (pressed) {
            for (volatile int d=0; d<200000; d++) {}   /* debounce ~kilka ms */
            now = btn_read();
            pressed = now & ~prev;
            /* obsluz najnizszy nacisniety przycisk */
            for (int b=0; b<N_BTN; b++) {
                if (pressed & (1u<<b)) {
                    process_file(&audio_files[ btn_to_file[b] ]);
                    while (btn_read() & (1u<<b)) {}     /* czekaj na puszczenie */
                    break;
                }
            }
        }
        prev = btn_read();
        for (volatile int d=0; d<20000; d++) {}
    }
    return 0;
}
