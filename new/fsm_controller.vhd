-- fsm_controller.vhd
-- =============================================================================
-- Finite State Machine: steuert den gesamten Inferenz-Ablauf.
--
-- Zustaende:
--   IDLE       : Wartet auf Start-Signal vom UART-Modul
--   COMPUTE_L1 : Startet alle 64 MAC-Einheiten fuer Layer 1. (787 Takte)
--   RELU       : Setzt negative L1-Ergebnisse auf 0 UND requantisiert
--                 (1 Takt) -- siehe FIX unten
--   COMPUTE_L2 : Startet alle 10 MAC-Einheiten fuer Layer 2. (66 Takte)
--   ARGMAX     : Sucht den groessten L2-Output (10 Takte)
--   OUTPUT     : Gibt Ergebnis aus (1 Takt), dann zurueck zu IDLE
--
-- FIX (19.07.2026): 32-BIT-OVERFLOW IN LAYER 2 BEHOBEN
-- ------------------------------------------------------------------------
-- Problem: Layer-1-Akkumulatoren (mac_unit) koennen bis zu
--   784 * 255 * 127 = 25.394.190
-- gross werden. Dieser Wert ging bisher UNVERAENDERT als "pixel_in" in
-- mac_unit_l2. Dort wird er mit einem int8-Gewicht (bis 127) multipliziert
-- und ueber 64 Terme aufaddiert. Der 32-Bit-Akkumulator in mac_unit_l2
-- (max. ca. 2.147.483.647) lief dabei ueber:
--   25.394.190 * 127 * 64  ~  206 Milliarden  >>  2^31
-- Das "resize(product, 32)" in mac_unit_l2 hat diese Werte stillschweigend
-- abgeschnitten -> Layer 2 hat mit Datenmuell gerechnet, unabhaengig vom
-- Eingabebild. Das ist mit hoher Wahrscheinlichkeit die Hauptursache fuer
-- die schlechte / fast zufaellige Erkennung.
--
-- Loesung: ReLU-Output wird um SHIFT_L2 = 7 Bit nach rechts geschoben
-- (entspricht Division durch 128), bevor er als relu_out an Layer 2 geht.
--   25.394.190 >> 7 = 198.392  (max. moeglicher Wert nach Shift)
--   198.392 * 127 * 64 = 1.612.530.176  <  2^31 = 2.147.483.648
-- -> passt mit ca. 25% Headroom fuer den Bias in den 32-Bit-Akkumulator.
--
-- WICHTIG: export_weights_v2.py simuliert diesen Shift jetzt exakt genauso
-- (SHIFT_L2 = 7) in seinem INT8-Selbsttest, damit Python-Simulation und
-- FPGA wieder dieselbe Rechnung durchfuehren.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm_controller is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;
        uart_done    : in  std_logic;

        l1_reset     : out std_logic;
        l1_enable    : out std_logic;
        l2_reset     : out std_logic;
        l2_enable    : out std_logic;

        pixel_addr   : out std_logic_vector(9 downto 0);
        result_digit : out std_logic_vector(3 downto 0);
        result_valid : out std_logic;

        l1_results   : in  std_logic_vector(64*32-1 downto 0);
        l2_results   : in  std_logic_vector(10*32-1 downto 0);
        relu_out     : out std_logic_vector(64*32-1 downto 0)
    );
end fsm_controller;

architecture Behavioral of fsm_controller is

    -- FIX: Requantisierungs-Shift zwischen Layer 1 und Layer 2.
    -- Muss mit dem Selbsttest in export_weights_v2.py uebereinstimmen!
    constant SHIFT_L2 : integer := 7;

    type state_type is (
        IDLE,
        COMPUTE_L1,
        RELU,
        COMPUTE_L2,
        ARGMAX,
        OUTPUT
    );
    signal state : state_type := IDLE;

    signal counter : integer range 0 to 800 := 0;
    signal pixel_addr_reg : unsigned(9 downto 0) := (others => '0');

    type result_array_64 is array(0 to 63) of signed(31 downto 0);
    signal relu_results : result_array_64;

    signal best_score : signed(31 downto 0);
    signal best_index : integer range 0 to 9;
    signal argmax_counter : integer range 0 to 10 := 0;

begin

    pixel_addr <= std_logic_vector(pixel_addr_reg);

    relu_pack: for i in 0 to 63 generate
        relu_out(i*32+31 downto i*32) <=
            std_logic_vector(relu_results(i));
    end generate;

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
                l1_reset     <= '0';
                l2_reset     <= '0';
                result_valid <= '0';

                case state is

                    when IDLE =>
                        l1_enable      <= '0';
                        l2_enable      <= '0';
                        pixel_addr_reg <= (others => '0');

                        if uart_done = '1' then
                            l1_reset <= '1';
                            counter  <= 0;
                            state    <= COMPUTE_L1;
                        end if;

                    when COMPUTE_L1 =>
                        l1_enable <= '1';

                        if counter < 786 then
                            if counter > 0 then
                                pixel_addr_reg <= pixel_addr_reg + 1;
                            end if;
                            counter <= counter + 1;
                        else
                            l1_enable <= '0';
                            state     <= RELU;
                        end if;

                    when RELU =>
                        -- ReLU + Requantisierung (FIX): negative Werte -> 0,
                        -- positive Werte um SHIFT_L2 Bit nach rechts schieben,
                        -- damit Layer 2 nicht ueberlaeuft.
                        for i in 0 to 63 loop
                            l1_val := signed(l1_results(i*32+31 downto i*32));
                            if l1_val < 0 then
                                relu_results(i) <= (others => '0');
                            else
                                relu_results(i) <= shift_right(l1_val, SHIFT_L2);
                            end if;
                        end loop;

                        l2_reset <= '1';
                        counter  <= 0;
                        state    <= COMPUTE_L2;

                    when COMPUTE_L2 =>
                        l2_enable <= '1';

                        if counter < 66 then
                            counter <= counter + 1;
                        else
                            l2_enable <= '0';
                            best_score    <= signed(l2_results(31 downto 0));
                            best_index    <= 0;
                            argmax_counter <= 1;
                            state         <= ARGMAX;
                        end if;

                    when ARGMAX =>
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

                    when OUTPUT =>
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
