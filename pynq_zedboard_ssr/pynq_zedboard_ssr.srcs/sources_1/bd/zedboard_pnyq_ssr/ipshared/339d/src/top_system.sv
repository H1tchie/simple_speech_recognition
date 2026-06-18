//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   top_system
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Top-level laczacy tor DSP z siecia neuronowa.

                dsp_chain (audio -> 26 cech AXI-Stream)
                    |
                feature_buffer (zbiera 26 cech sekwencyjnych -> wektor rownolegly)
                    |
                top_nn (26 cech -> klasyfikacja: 0=other, 1=on, 2=off)

                Sekwencja dzialan:
                  1. Wejscie audio Q1.15 przez AXI-Stream (s_tdata/valid/ready/last)
                  2. dsp_chain przetwarza 16000 probek i wystawia 26 cech sekwencyjnie
                  3. feature_buffer zbiera cechy do wektora i resetuje top_nn
                  4. Po zebraniu 26 cech top_nn startuje i liczy wynik
                  5. output_value stabilizuje sie po ~60 cyklach od startu sieci
                  6. output_valid=1 sygnalizuje gotowy wynik

                Porty:
                  s_*     - wejscie audio AXI-Stream (Q1.15, 16-bit)
                  output_value  - wynik klasyfikacji (0=other, 1=on, 2=off)
                  output_valid  - 1 gdy wynik gotowy, 0 podczas przetwarzania
                  busy          - 1 gdy tor DSP lub siec pracuje
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;
import nn_parameters::*;

module top_system (
    input  logic clk,
    input  logic rst,

    // --- wejscie audio AXI-Stream Q1.15 ---
    input  logic signed [SAMPLE_W-1:0] s_tdata,
    input  logic                       s_tvalid,
    output logic                       s_tready,
    input  logic                       s_tlast,   // ostatnia probka nagrania

    // --- wyjscie klasyfikatora ---
    output logic [1:0]  output_value,  // 0=other, 1=on, 2=off
    output logic        output_valid,  // 1 = wynik gotowy
    output logic        busy           // 1 = trwa przetwarzanie
);

    // -----------------------------------------------------------------------
    // Magistrala DSP -> feature_buffer (AXI-Stream cech)
    // -----------------------------------------------------------------------
    logic signed [FEAT_W-1:0]          feat_tdata;
    logic                              feat_tvalid;
    logic                              feat_tready;
    logic                              feat_tlast;
    logic [$clog2(N_FEATURES)-1:0]     feat_tuser;   // feature_id 0..25

    // -----------------------------------------------------------------------
    // Bufor cech i sygnaly sterujace siecia
    // -----------------------------------------------------------------------
    logic signed [15:0] feature_vec [IN_SIZE_1-1:0];  // 26 cech dla top_nn
    logic               nn_rst;                        // reset sieci (aktywny wysoki)
    logic               nn_rst_r;                      // zarejestrowana kopia
    logic               features_ready;               // 1 po zebraniu 26 cech
    logic               nn_done;                      // done2 z top_nn (siec skonczyla)

    // -----------------------------------------------------------------------
    // Instancja dsp_chain
    // -----------------------------------------------------------------------
    dsp_chain u_dsp_chain (
        .clk,
        .rst,
        .s_tdata,
        .s_tvalid,
        .s_tready,
        .s_tlast,
        .m_tdata  (feat_tdata),
        .m_tvalid (feat_tvalid),
        .m_tready (feat_tready),
        .m_tlast  (feat_tlast),
        .m_tuser  (feat_tuser)
    );

    // -----------------------------------------------------------------------
    // Instancja top_nn
    // -----------------------------------------------------------------------
    top_nn u_top_nn (
        .clk,
        .rst        (nn_rst),
        .input_vector (feature_vec),
        .output_value (output_value),
        .done1_out  (),              // nieuzywane na tym poziomie
        .done2_out  (nn_done)
    );

    // -----------------------------------------------------------------------
    // feature_buffer: zbiera 26 cech z AXI-Stream do wektora rownolegego,
    // a nastepnie uruchamia siec przez zwolnienie resetu.
    //
    // Maszyna stanow:
    //   S_WAIT   - czeka na pierwsze m_tvalid z dsp_chain
    //   S_LOAD   - odbiera kolejne cechy (feat_tuser = 0..25)
    //   S_START  - jedna cykl: pulsuje reset sieci (nn_rst=1->0)
    //   S_RUN    - czeka az siec zakonczy obliczenia (nn_done=1)
    //   S_DONE   - wynik gotowy, czeka na kolejne nagranie (reset globainy)
    // -----------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_WAIT,
        S_LOAD,
        S_START,
        S_RUN,
        S_DONE
    } buf_state_t;

    buf_state_t buf_state;

    // Zawsze gotowi odbierac cechy gdy jestesmy w S_WAIT lub S_LOAD
    assign feat_tready = (buf_state == S_WAIT) || (buf_state == S_LOAD);

    always_ff @(posedge clk) begin
        if (rst) begin
            buf_state     <= S_WAIT;
            nn_rst        <= 1'b1;   // siec w resecie do czasu az beda cechy
            nn_rst_r      <= 1'b1;
            features_ready <= 1'b0;
            output_valid  <= 1'b0;
            for (int k = 0; k < IN_SIZE_1; k++)
                feature_vec[k] <= '0;
        end else begin
            nn_rst_r <= nn_rst;

            case (buf_state)

                // -----------------------------------------------------------
                // Czekaj na pierwszy beat z dsp_chain
                // -----------------------------------------------------------
                S_WAIT: begin
                    output_valid   <= 1'b0;
                    features_ready <= 1'b0;
                    nn_rst         <= 1'b1;   // siec stoi w resecie
                    if (feat_tvalid) begin
                        // Pierwsza cecha - zapisz i przejdz do ladowania
                        feature_vec[feat_tuser] <= feat_tdata;
                        buf_state <= S_LOAD;
                    end
                end

                // -----------------------------------------------------------
                // Laduj kolejne cechy do wektora
                // feat_tuser = indeks cechy (0..25), feat_tlast na idx=25
                // -----------------------------------------------------------
                S_LOAD: begin
                    if (feat_tvalid && feat_tready) begin
                        feature_vec[feat_tuser] <= feat_tdata;
                        if (feat_tlast) begin
                            // Wszystkie 26 cech zebrane - uruchom siec
                            features_ready <= 1'b1;
                            buf_state      <= S_START;
                        end
                    end
                end

                // -----------------------------------------------------------
                // START: jeden cykl zwolnienia resetu sieci.
                // top_nn wymaga aby rst opadlo i dane wejsciowe byly stabilne.
                // feature_vec jest juz kompletny z poprzedniego stanu.
                // -----------------------------------------------------------
                S_START: begin
                    nn_rst    <= 1'b0;   // zdejmij reset - siec startuje
                    buf_state <= S_RUN;
                end

                // -----------------------------------------------------------
                // RUN: czekaj az top_nn zakonczy obliczenia.
                // done2_out z top_nn idzie wysoko po ~60 cyklach
                // (26 cykli dense_layer_1 + 32 cykli dense_layer_2 + pipeline).
                // -----------------------------------------------------------
                S_RUN: begin
                    if (nn_done) begin
                        output_valid <= 1'b1;
                        buf_state    <= S_DONE;
                    end
                end

                // -----------------------------------------------------------
                // DONE: wynik stabilny, output_valid=1.
                // Czekamy na globalny reset (nowe nagranie).
                // -----------------------------------------------------------
                S_DONE: begin
                    output_valid <= 1'b1;
                    nn_rst       <= 1'b1;   // z powrotem reset zeby nie liczyla
                end

                default: buf_state <= S_WAIT;
            endcase
        end
    end

    // busy = 1 gdy cos sie dzieje (DSP przetwarza LUB siec liczy)
    assign busy = (buf_state != S_DONE) || !output_valid;

endmodule : top_system
