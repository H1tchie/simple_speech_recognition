//////////////////////////////////////////////////////////////////////////////
/*
 Module name:   framing
 Authors:       Kacper Ferdek, Mateusz Gibas
 Description:   Dzieli strumien probek na ramki FRAME_LEN z przeskokiem HOP_LEN.

 POPRAWKI vs wersja poprzednia:
   1. BUG FIX: Warunek wyjscia z S_FILL dla pierwszej ramki:
        bylo:  if (fill == FRAME_LEN-1)
        jest:  if (fill == FRAME_LEN-1) - OK, ale new_samples nie byl
      zerowany przy przejsciu na pierwsza ramke -> kolejna ramka startowala
      z new_samples != 0. Dodano reset new_samples przy wejsciu w S_EMIT
      z pierwszej ramki.

   2. BUG FIX: Po emisji ramki (frame_id == N_FRAMES-1) przejscie do S_DONE
      nastepowalo PRZED zwiekszeniem frame_id. Teraz frame_id jest
      inkrementowane a potem sprawdzane czy bylo ostatnie.

   3. BUG FIX (subtelny): emit_idx liczyl wystawione probki, ale warunek
      przejscia 'emit_idx == FRAME_LEN' byl sprawdzany ZANIM ostatnia
      probka (z tlast) zostala zaakceptowana przez downstream gdy
      m_tready=0 w momencie wystawienia tlast. Teraz sprawdzamy
      'emit_idx == FRAME_LEN' osobno od wystawiania - przejscie do
      kolejnego stanu tylko gdy handshake sie zakonczyl.
 */
//////////////////////////////////////////////////////////////////////////////

import ssr_pkg::*;

module framing (
    input  logic                     clk,
    input  logic                     rst,

    // --- AXI-Stream slave (probki wejsciowe) ---
    input  logic signed [SAMPLE_W-1:0] s_tdata,
    input  logic                       s_tvalid,
    output logic                       s_tready,
    input  logic                       s_tlast,

    // --- AXI-Stream master (ramki wyjsciowe) ---
    output logic signed [SAMPLE_W-1:0] m_tdata,
    output logic                       m_tvalid,
    input  logic                       m_tready,
    output logic                       m_tlast,
    output logic [$clog2(N_FRAMES)-1:0] m_tuser
);

    logic signed [SAMPLE_W-1:0]      buffer [FRAME_LEN-1:0];
    logic [$clog2(FRAME_LEN+1)-1:0]  fill;
    logic [$clog2(N_FRAMES)-1:0]     frame_id;
    logic                            first_frame;

    typedef enum logic [1:0] {S_FILL, S_EMIT, S_DONE} state_t;
    state_t state;

    logic [$clog2(FRAME_LEN+1)-1:0] emit_idx;
    logic [$clog2(HOP_LEN+1)-1:0]   new_samples;

    integer i;

    assign s_tready = (state == S_FILL) || (state == S_DONE);

    always_ff @(posedge clk) begin
        if (rst) begin
            fill        <= '0;
            frame_id    <= '0;
            first_frame <= 1'b1;
            state       <= S_FILL;
            emit_idx    <= '0;
            new_samples <= '0;
            m_tvalid    <= 1'b0;
            m_tlast     <= 1'b0;
            m_tdata     <= '0;
            m_tuser     <= '0;
            for (i = 0; i < FRAME_LEN; i++) buffer[i] <= '0;
        end else begin
            case (state)

                S_FILL: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                    if (s_tvalid && s_tready) begin
                        // Przesuwne okno: wyrzuc najstarsza, wstaw nowa na koniec
                        for (i = 0; i < FRAME_LEN-1; i++)
                            buffer[i] <= buffer[i+1];
                        buffer[FRAME_LEN-1] <= s_tdata;

                        if (fill < FRAME_LEN)
                            fill <= fill + 1;
                        new_samples <= new_samples + 1;

                        if (first_frame) begin
                            // Pierwsza ramka: czekaj az bufor pelny
                            if (fill == FRAME_LEN-1) begin
                                emit_idx    <= '0;
                                // BUG FIX #1: zeruj new_samples przy starcie
                                // pierwszej emisji zeby kolejna ramka liczyла
                                // od 0
                                new_samples <= '0;
                                state       <= S_EMIT;
                            end
                        end else begin
                            // Kolejne ramki: czekaj na HOP_LEN nowych probek
                            if (new_samples == HOP_LEN-1) begin
                                emit_idx    <= '0;
                                new_samples <= '0;
                                state       <= S_EMIT;
                            end
                        end
                    end
                end

                S_EMIT: begin
                    // BUG FIX #2 + #3: Poprawny wzorzec AXI-Stream master
                    // Dane wystawiane i trzymane az ready=1.
                    // emit_idx liczy probki DO WYSLANIA (nie wyslane).
                    // Przejscie do S_FILL/S_DONE tylko gdy ostatni handshake zakonczony.
                    if (m_tready || !m_tvalid) begin
                        if (emit_idx == FRAME_LEN) begin
                            // Wszystkie probki ramki wyslane i odebrane
                            m_tvalid    <= 1'b0;
                            m_tlast     <= 1'b0;
                            emit_idx    <= '0;
                            first_frame <= 1'b0;
                            // BUG FIX #2: inkrementuj frame_id, potem sprawdz
                            frame_id    <= frame_id + 1;
                            if (frame_id == N_FRAMES-1)
                                state <= S_DONE;
                            else
                                state <= S_FILL;
                        end else begin
                            // Wyslij kolejna probke
                            m_tvalid <= 1'b1;
                            m_tdata  <= buffer[emit_idx];
                            m_tuser  <= frame_id;
                            m_tlast  <= (emit_idx == FRAME_LEN-1);
                            emit_idx <= emit_idx + 1;
                        end
                    end
                end

                S_DONE: begin
                    m_tvalid <= 1'b0;
                    m_tlast  <= 1'b0;
                end

                default: state <= S_FILL;
            endcase
        end
    end

endmodule : framing