-- fsm_controller.vhd
-- =============================================================================
-- Finite State Machine: steuert den gesamten Inferenz-Ablauf.
--
-- Zustaende:
--   IDLE       : Wartet auf Start-Signal vom UART-Modul
--   COMPUTE_L1 : Startet alle 64 MAC-Einheiten fuer Layer 1, zaehlt 786 Takte
--                (784 Pixel + 1 Takt BRAM-Latenz + 1 Takt Bias-Addition)
--   RELU       : Setzt negative L1-Ergebnisse auf 0 (1 Takt)
--   COMPUTE_L2 : Startet alle 10 MAC-Einheiten fuer Layer 2, zaehlt 66 Takte
--                (64 L1-Outputs + 1 Takt BRAM-Latenz + 1 Takt Bias)
--   ARGMAX     : Sucht den groessten L2-Output (10 Takte)
--   OUTPUT     : Gibt Ergebnis aus (1 Takt), dann zurueck zu IDLE
--
-- Warum braucht man eine FSM?
--   Layer 2 darf erst starten wenn Layer 1 fertig ist.
--   ARGMAX darf erst laufen wenn Layer 2 fertig ist.
--   Die FSM garantiert diese Reihenfolge.
--   Ohne FSM wuerden alle Teile gleichzeitig loslaufen -> falsche Ergebnisse.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm_controller is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        -- Vom UART-Modul: alle 784 Bytes empfangen
        uart_done    : in  std_logic;

        -- Steuersignale fuer MAC-Einheiten Layer 1 (64 Stueck)
        l1_reset     : out std_logic;
        l1_enable    : out std_logic;

        -- Steuersignale fuer MAC-Einheiten Layer 2 (10 Stueck)
        l2_reset     : out std_logic;
        l2_enable    : out std_logic;

        -- Pixel-Adresse ins Input-BRAM (welches Pixel ist gerade dran?)
        pixel_addr   : out std_logic_vector(9 downto 0);  -- 0 bis 783

        -- Ergebnis des Argmax (0 bis 9)
        result_digit : out std_logic_vector(3 downto 0);

        -- Zum 7-Segment: neues Ergebnis liegt an
        result_valid : out std_logic;

        -- L1-Ergebnisse (kommen von den 64 MAC-Einheiten)
        l1_results   : in  std_logic_vector(64*32-1 downto 0);  -- 64 * 32 Bit

        -- L2-Ergebnisse (kommen von den 10 MAC-Einheiten)
        l2_results   : in  std_logic_vector(10*32-1 downto 0);  -- 10 * 32 Bit

        -- ReLU-Outputs (gehen an Layer 2 als Eingabe)
        relu_out     : out std_logic_vector(64*32-1 downto 0)
    );
end fsm_controller;

architecture Behavioral of fsm_controller is

    -- Zustandstyp definieren
    type state_type is (
        IDLE,
        COMPUTE_L1,
        RELU,
        COMPUTE_L2,
        ARGMAX,
        OUTPUT
    );
    signal state : state_type := IDLE;

    -- Zaehler fuer die Takte in COMPUTE_L1 und COMPUTE_L2
    -- L1: 784 + 2 extra Takte = 786
    -- L2:  64 + 2 extra Takte =  66
    signal counter : integer range 0 to 800 := 0;

    -- Interner Pixel-Adress-Zaehler
    signal pixel_addr_reg : unsigned(9 downto 0) := (others => '0');

    -- ReLU-Ergebnisse intern halten
    type result_array_64 is array(0 to 63) of signed(31 downto 0);
    signal relu_results : result_array_64;

    -- Argmax-Hilfssignale
    signal best_score : signed(31 downto 0);
    signal best_index : integer range 0 to 9;
    signal argmax_counter : integer range 0 to 10 := 0;

begin

    -- Pixel-Adresse nach aussen geben
    pixel_addr <= std_logic_vector(pixel_addr_reg);

    -- ReLU-Outputs zusammenpacken fuer Layer 2
    relu_pack: for i in 0 to 63 generate
        relu_out(i*32+31 downto i*32) <=
            std_logic_vector(relu_results(i));
    end generate;

    -- ─────────────────────────────────────────────────────────
    -- Hauptprozess: FSM
    -- ─────────────────────────────────────────────────────────
    process(clk)
        variable l1_val  : signed(31 downto 0);
        variable l2_val  : signed(31 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then
                state         <= IDLE;
                l1_reset      <= '1';
                l1_enable     <= '0';
                l2_reset      <= '1';
                l2_enable     <= '0';
                result_valid  <= '0';
                counter       <= 0;
                pixel_addr_reg <= (others => '0');

            else
                -- Default: kein Reset, kein neues Ergebnis
                l1_reset     <= '0';
                l2_reset     <= '0';
                result_valid <= '0';

                case state is

                    -- ──────────────────────────────────────────
                    when IDLE =>
                    -- Wartet bis UART alle 784 Bytes empfangen hat.
                    -- uart_done wird vom UART-Modul fuer einen Takt auf '1' gesetzt.
                        l1_enable      <= '0';
                        l2_enable      <= '0';
                        pixel_addr_reg <= (others => '0');

                        if uart_done = '1' then
                            -- Layer 1 MAC-Einheiten resetten und gleich starten
                            l1_reset <= '1';
                            counter  <= 0;
                            state    <= COMPUTE_L1;
                        end if;

                    -- ──────────────────────────────────────────
                    when COMPUTE_L1 =>
                    -- Alle 64 MAC-Einheiten laufen parallel.
                    -- In jedem Takt: Pixel-Adresse erhoehen, MACs lesen
                    -- Gewicht aus BRAM (1 Takt Latenz), multiplizieren, addieren.
                    -- Wir laufen 786 Takte: 1 (BRAM warmup) + 784 + 1 (Bias).
                        l1_enable <= '1';

                        if counter < 785 then
                            pixel_addr_reg <= pixel_addr_reg + 1;
                            counter        <= counter + 1;
                        else
                            -- Layer 1 fertig
                            l1_enable <= '0';
                            state     <= RELU;
                        end if;

                    -- ──────────────────────────────────────────
                    when RELU =>
                    -- Alle 64 L1-Ergebnisse gleichzeitig durch ReLU.
                    -- Negative Werte -> 0, positive bleiben.
                    -- Dauert genau einen Takt.
                        for i in 0 to 63 loop
                            l1_val := signed(l1_results(i*32+31 downto i*32));
                            if l1_val < 0 then
                                relu_results(i) <= (others => '0');
                            else
                                relu_results(i) <= l1_val;
                            end if;
                        end loop;

                        -- Layer 2 vorbereiten
                        l2_reset <= '1';
                        counter  <= 0;
                        state    <= COMPUTE_L2;

                    -- ──────────────────────────────────────────
                    when COMPUTE_L2 =>
                    -- 10 MAC-Einheiten laufen parallel.
                    -- Eingaben sind jetzt die 64 ReLU-Outputs (nicht mehr Pixel).
                    -- Laeuft 66 Takte: 1 + 64 + 1.
                        l2_enable <= '1';

                        if counter < 65 then
                            counter <= counter + 1;
                        else
                            l2_enable <= '0';
                            -- Argmax starten
                            best_score    <= signed(l2_results(31 downto 0));
                            best_index    <= 0;
                            argmax_counter <= 1;
                            state         <= ARGMAX;
                        end if;

                    -- ──────────────────────────────────────────
                    when ARGMAX =>
                    -- Geht alle 10 L2-Scores durch, merkt sich den groessten.
                    -- Laeuft 9 Takte (Vergleiche fuer Index 1 bis 9).
                    -- Kein Multiplizierer noetig, nur Vergleiche.
                        if argmax_counter < 10 then
                            l2_val := signed(
                                l2_results(argmax_counter*32+31 downto argmax_counter*32)
                            );
                            if l2_val > best_score then
                                best_score <= l2_val;
                                best_index <= argmax_counter;
                            end if;
                            argmax_counter <= argmax_counter + 1;
                        else
                            state <= OUTPUT;
                        end if;

                    -- ──────────────────────────────────────────
                    when OUTPUT =>
                    -- Ergebnis ausgeben und zurueck zu IDLE.
                        result_digit <= std_logic_vector(
                            to_unsigned(best_index, 4)
                        );
                        result_valid <= '1';
                        state        <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
