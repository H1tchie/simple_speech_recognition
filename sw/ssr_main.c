/*
 * ssr_main.c - przykladowy soft dla MicroBlaze sterujacy IPcore top_ssr.
 *
 * Rola procesora (konspekt sekcja 3.1): kontroler - start IPcore, czekanie
 * na 'done', odczyt wyniku klasyfikacji, zapalenie diody LED.
 * Klasyfikacja sama w sobie jest w RTL (siec neuronowa) - procesor tylko
 * startuje potok i odczytuje 2-bitowy kod komendy.
 *
 * Mapa rejestrow AXI4-Lite (rtl/axi/axi4lite_regs.sv):
 *   0x00 CTRL    [W]  bit0 = start, bit1 = soft_reset
 *   0x04 STATUS  [R]  bit0 = busy,  bit1 = done, bit2 = error
 *   0x08 RESULT  [R]  command_id[1:0]  (01=on, 10=off, 00=other)
 *   0x0C CONFIG  [RW] rezerwa
 */

#include "xil_io.h"
#include "xparameters.h"
#include "xil_printf.h"

/* Po dodaniu top_ssr jako IP w block design, baza pojawi sie w xparameters.h.
 * Nazwa makra zalezy od nazwy instancji IP - sprawdz w xparameters.h
 * (np. XPAR_TOP_SSR_0_S_AXI_BASEADDR). Tu zostaw placeholder: */
#ifndef SSR_BASEADDR
#define SSR_BASEADDR   0x44A00000u   /* <-- dopasuj do Address Editor w Vivado */
#endif

#define SSR_CTRL    (SSR_BASEADDR + 0x00)
#define SSR_STATUS  (SSR_BASEADDR + 0x04)
#define SSR_RESULT  (SSR_BASEADDR + 0x08)
#define SSR_CONFIG  (SSR_BASEADDR + 0x0C)

#define ST_BUSY  (1u << 0)
#define ST_DONE  (1u << 1)
#define ST_ERR   (1u << 2)

/* Opcjonalnie: AXI GPIO podpiete do diod LED (konspekt 4.9 - LED przez GPIO).
 * Odkomentuj i ustaw baze z xparameters.h, jesli dodasz blok AXI GPIO. */
/* #define LED_BASEADDR  XPAR_AXI_GPIO_0_BASEADDR
   #define GPIO_DATA     (LED_BASEADDR + 0x00) */

static const char *cmd_name(unsigned code)
{
    switch (code & 0x3u) {
        case 0x1: return "on";
        case 0x2: return "off";
        default:  return "other";   /* 0x0 */
    }
}

int main(void)
{
    xil_printf("\r\n[SSR] start kontrolera MicroBlaze\r\n");

    /* miekki reset IPcore */
    Xil_Out32(SSR_CTRL, 0x2u);
    Xil_Out32(SSR_CTRL, 0x0u);

    for (;;) {
        /* 1) wystartuj przetwarzanie (impuls start) */
        Xil_Out32(SSR_CTRL, 0x1u);

        /* 2) czekaj na done (polling STATUS.done) */
        u32 st;
        do { st = Xil_In32(SSR_STATUS); } while (!(st & ST_DONE));

        if (st & ST_ERR) {
            xil_printf("[SSR] blad IPcore (STATUS=0x%08x)\r\n", st);
        } else {
            /* 3) odczytaj wynik klasyfikacji */
            u32 code = Xil_In32(SSR_RESULT) & 0x3u;
            xil_printf("[SSR] komenda = %s (kod %u)\r\n", cmd_name(code), code);

            /* 4) zapal LED wg komendy (jesli masz AXI GPIO):
               Xil_Out32(GPIO_DATA, (code == 0x1) ? 0x1 : 0x0); */
        }

        /* prosty demo-loop: tu mozna czekac na przycisk / nowe probki */
        for (volatile int d = 0; d < 5000000; ++d) { }
    }
    return 0;
}
