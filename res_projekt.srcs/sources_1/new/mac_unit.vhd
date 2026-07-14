-- mac_unit.vhd
-- =============================================================================
-- Eine einzelne MAC-Einheit fuer ein Neuron.
-- 
-- Was diese Einheit tut:
--   In jedem Takt (wenn enable='1') liest sie ein Pixel und ein Gewicht,
--   multipliziert beide, und addiert das Produkt auf den Akkumulator.
--   Nach INPUT_SIZE Takten (784) ist die Berechnung fertig.
--   Das Gewicht kommt aus einem externen BRAM (weight_data).
--   Das Pixel kommt vom gemeinsamen Pixel-Bus (pixel_in).
--
-- Signalbreiten:
--   pixel_in:   8 Bit unsigned (0-255)  -> Grauwert des Pixels
--   weight_data: 8 Bit signed (-127..127) -> quantisiertes Gewicht aus BRAM
--   bias_in:    16 Bit signed           -> quantisierter Bias
--   accumulator: 32 Bit signed          -> laeuft nicht ueber
--     Beweis: max = 784 * (255 * 127) + 32767 = 25.390.000 + 32767 < 2^31
--   result_out: 32 Bit signed           -> finales Ergebnis nach Bias
--   addr_out:   10 Bit                  -> Adresse fuer das BRAM (0 bis 783)
--
-- Sequenz:
--   1. reset='1'   -> Akkumulator=0, Zaehler=0, done='0'
--   2. enable='1'  -> startet die Berechnung
--   3. Nach 784 Takten: done='1', result_out = Akkumulator + Bias
--   4. done bleibt '1' bis naechstes reset
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac_unit is
    generic (
        INPUT_SIZE : integer := 784   -- Anzahl Pixel / Gewichte (28*28)
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;                      -- synchroner Reset
        enable      : in  std_logic;                      -- startet Berechnung

        -- Pixel-Eingang (gemeinsamer Bus fuer alle MAC-Einheiten)
        pixel_in    : in  std_logic_vector(7 downto 0);   -- uint8, 0-255

        -- Gewicht aus BRAM (jede MAC-Einheit hat ihr eigenes BRAM)
        weight_data : in  std_logic_vector(7 downto 0);   -- int8, -127..127

        -- Bias (direkt verdrahtet, kein BRAM noetig wegen nur 64 Werte)
        bias_in     : in  std_logic_vector(15 downto 0);  -- int16

        -- BRAM-Adresse (diese Einheit steuert ihr eigenes BRAM)
        addr_out    : out std_logic_vector(9 downto 0);   -- 10 Bit fuer bis zu 1024

        -- Ergebnis
        result_out  : out std_logic_vector(31 downto 0);  -- int32
        done        : out std_logic
    );
end mac_unit;

architecture Behavioral of mac_unit is

    -- Akkumulator: 32 Bit signed, kein Ueberlauf bei 784 * 255 * 127
    signal accumulator : signed(31 downto 0) := (others => '0');

    -- Zaehler: zaehlt von 0 bis INPUT_SIZE-1
    signal counter     : integer range 0 to INPUT_SIZE := 0;

    -- Internes done-Flag
    signal done_reg    : std_logic := '0';

begin

    -- BRAM-Adresse = aktueller Zaehlerstand
    -- Wichtig: BRAM hat 1 Takt Latenz bei synchronem Lesen.
    -- Deshalb zaehlen wir schon ab 0, und das Gewicht kommt einen Takt spaeter.
    -- Die FSM muss das beruecksichtigen (einen Extra-Takt am Anfang).
    addr_out <= std_logic_vector(to_unsigned(counter, 10));

    done <= done_reg;

    process(clk)
        variable pixel_signed  : signed(8 downto 0);   -- 9 Bit: uint8 als signed (kein Vorzeichenproblem)
        variable weight_signed : signed(7 downto 0);   -- 8 Bit: int8
        variable product       : signed(16 downto 0);  -- 17 Bit: 9*8 Bit Produkt
    begin
        if rising_edge(clk) then

            if reset = '1' then
                -- Alles zuruecksetzen
                accumulator <= (others => '0');
                counter     <= 0;
                done_reg    <= '0';
                result_out  <= (others => '0');

            elsif enable = '1' and done_reg = '0' then

                if counter < INPUT_SIZE then
                    -- Pixel ist unsigned (0-255), aber signed-Arithmetik noetig.
                    -- Loesung: Pixel in 9-Bit signed konvertieren (immer positiv).
                    pixel_signed  := signed('0' & pixel_in);   -- '0' vorne: positiv
                    weight_signed := signed(weight_data);       -- int8 direkt

                    -- Produkt: 9 Bit * 8 Bit = 17 Bit
                    product := pixel_signed * weight_signed;

                    -- Auf 32-Bit Akkumulator addieren (sign-extend)
                    accumulator <= accumulator + resize(product, 32);

                    counter <= counter + 1;

                else
                    -- Alle 784 Pixel verarbeitet -> Bias addieren, fertig
                    result_out <= std_logic_vector(
                        accumulator + resize(signed(bias_in), 32)
                    );
                    done_reg <= '1';
                end if;

            end if;
        end if;
    end process;

end Behavioral;
