//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   dft
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   256-pkt DFT (real input) liczony sekwencyjnie.
                Dla kazdej ramki (FRAME_LEN probek Q1.15 po oknie):
                  re[k] = (sum_{n} win[n]*cos[k][n]) >>> 15   k=0..N_BINS-1
                  im[k] = (sum_{n} win[n]*sin[k][n]) >>> 15
                cos/sin z ROM (Q1.15), tablice N_BINS*N_FFT.

                Architektura: 1 MAC na re, 1 na im, akumulacja 256 cykli/bin.
                Najpierw buforuje cala ramke, potem liczy biny sekwencyjnie.
                Wystawia AXI-Stream: (re,im) per bin, tlast na ostatnim binie,
                tuser=frame_id.

                ROM-y: dft_cos_256.mem, dft_sin_256.mem (po N_BINS*N_FFT = 33024)
                indeks ROM = k*N_FFT + n.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module dft (
    input  logic clk,
    input  logic rst,

    // --- AXI-Stream slave (ramka po oknie) ---
    input  logic signed [SAMPLE_W-1:0]  s_tdata,
    input  logic                        s_tvalid,
    output logic                        s_tready,
    input  logic                        s_tlast,
    input  logic [$clog2(N_FRAMES)-1:0] s_tuser,

    // --- AXI-Stream master (re,im per bin) ---
    output logic signed [DFT_W-1:0]     m_tdata_re,
    output logic signed [DFT_W-1:0]     m_tdata_im,
    output logic                        m_tvalid,
    input  logic                        m_tready,
    output logic                        m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    // --- ROM cos/sin (Q1.15), N_BINS*N_FFT ---
    logic signed [TWIDDLE_W-1:0] cos_rom [N_BINS*N_FFT-1:0];
    logic signed [TWIDDLE_W-1:0] sin_rom [N_BINS*N_FFT-1:0];
    initial $readmemh("dft_cos_256.mem", cos_rom);
    initial $readmemh("dft_sin_256.mem", sin_rom);

    // --- bufor ramki ---
    logic signed [SAMPLE_W-1:0] frame_buf [FRAME_LEN-1:0];
    logic [$clog2(FRAME_LEN)-1:0] wr_idx;     // zapis ramki
    logic [$clog2(N_FRAMES)-1:0]  frame_id;

    // --- liczniki obliczen ---
    logic [$clog2(N_BINS)-1:0]  bin_idx;      // ktory bin (0..128)
    logic [$clog2(FRAME_LEN)-1:0] n_idx;      // ktora probka w MAC (0..255)

    // --- akumulatory (48-bit zapas) ---
    logic signed [47:0] acc_re, acc_im;

    typedef enum logic [1:0] {S_LOAD, S_MAC, S_OUT, S_NEXT} state_t;
    state_t state;

    integer i;

    // indeks do ROM: bin_idx*N_FFT + n_idx
    logic [$clog2(N_BINS*N_FFT)-1:0] rom_addr;
    assign rom_addr = bin_idx*N_FFT + n_idx;

    // produkty
    logic signed [2*SAMPLE_W-1:0] prod_re, prod_im;
    assign prod_re = frame_buf[n_idx] * cos_rom[rom_addr];
    assign prod_im = frame_buf[n_idx] * sin_rom[rom_addr];

    // przyjmujemy probki tylko w S_LOAD
    assign s_tready = (state == S_LOAD);

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= S_LOAD;
            wr_idx   <= '0;
            bin_idx  <= '0;
            n_idx    <= '0;
            acc_re   <= '0;
            acc_im   <= '0;
            frame_id <= '0;
            m_tvalid <= 1'b0;
            m_tlast  <= 1'b0;
            m_tdata_re <= '0;
            m_tdata_im <= '0;
            m_tuser  <= '0;
            for (i=0;i<FRAME_LEN;i++) frame_buf[i] <= '0;
        end else begin
            case (state)
                // --- ladowanie ramki do bufora ---
                S_LOAD: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    if (s_tvalid && s_tready) begin
                        frame_buf[wr_idx] <= s_tdata;
                        frame_id <= s_tuser;
                        if (s_tlast) begin
                            // cala ramka zaladowana, start MAC
                            wr_idx  <= '0;
                            bin_idx <= '0;
                            n_idx   <= '0;
                            acc_re  <= '0;
                            acc_im  <= '0;
                            state   <= S_MAC;
                        end else begin
                            wr_idx <= wr_idx + 1;
                        end
                    end
                end

                // --- MAC: akumuluj 256 produktow dla biezacego binu ---
                S_MAC: begin
                    acc_re <= acc_re + prod_re;
                    acc_im <= acc_im + prod_im;
                    if (n_idx == FRAME_LEN-1) begin
                        n_idx <= '0;
                        state <= S_OUT;
                    end else begin
                        n_idx <= n_idx + 1;
                    end
                end

                // --- wystaw wynik biezacego binu ---
                S_OUT: begin
                    m_tdata_re <= acc_re >>> Q15;   // Q1.15 skala
                    m_tdata_im <= acc_im >>> Q15;
                    m_tvalid   <= 1'b1;
                    m_tuser    <= frame_id;
                    m_tlast    <= (bin_idx == N_BINS-1);
                    if (m_tready) begin
                        state <= S_NEXT;
                    end
                end

                // --- przejdz do kolejnego binu lub kolejnej ramki ---
                S_NEXT: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    acc_re   <= '0;
                    acc_im   <= '0;
                    n_idx    <= '0;
                    if (bin_idx == N_BINS-1) begin
                        // wszystkie biny gotowe, czekaj na nowa ramke
                        bin_idx <= '0;
                        state   <= S_LOAD;
                    end else begin
                        bin_idx <= bin_idx + 1;
                        state   <= S_MAC;
                    end
                end

                default: state <= S_LOAD;
            endcase
        end
    end

endmodule : dft
