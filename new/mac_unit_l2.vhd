-- mac_unit_l2.vhd
-- Layer-2 MAC-Einheit: 64 Eingaenge, Eingang ist 32-Bit signed
-- (ReLU-Outputs aus Layer 1)
--
-- FIX v2 (17.07.2026): Die BRAM-Adresse 0 liegt fuer ZWEI Takte an (einmal
-- waehrend Reset, einmal im ersten Enable-Takt bevor der Zaehler weiterlaeuft).
-- Dadurch erscheint Index 0 in pixel_in/weight_data zweimal, waehrend Index 63
-- nie erreicht wird (Zeitfenster von 64 Takten reicht dann nicht mehr).
--
-- Loesung: nicht mehr blind 64 Takte lang akkumulieren, sondern per
-- Adress-Vergleich (src_addr /= last_addr_used) jede Wiederholung erkennen
-- und ueberspringen. Das ist robust gegenueber der exakten Pipeline-Fuellzeit
-- und braucht keine manuelle Taktzaehlerei mehr.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac_unit_l2 is
    generic (
        INPUT_SIZE : integer := 64
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;
        enable      : in  std_logic;
        pixel_in    : in  std_logic_vector(31 downto 0);  -- ReLU-Output L1 (signed)
        weight_data : in  std_logic_vector(7 downto 0);   -- INT8 Gewicht
        bias_in     : in  std_logic_vector(15 downto 0);
        addr_out    : out std_logic_vector(5 downto 0);   -- 0..63
        result_out  : out std_logic_vector(31 downto 0);
        done        : out std_logic
    );
end mac_unit_l2;

architecture Behavioral of mac_unit_l2 is
    signal accumulator    : signed(31 downto 0) := (others => '0');
    signal counter        : integer range 0 to INPUT_SIZE-1 := 0;  -- Adresszaehler 0..63
    signal acc_count      : integer range 0 to INPUT_SIZE := 0;    -- Anzahl bereits verrechneter Terme
    signal done_reg       : std_logic := '0';
    signal last_addr_used : integer range -1 to INPUT_SIZE-1 := -1; -- -1 = noch keiner verrechnet
    signal src_addr       : integer range 0 to INPUT_SIZE-1 := 0;   -- Adresse, zu der pixel_in/weight_data
                                                                     -- GERADE gehoert (1 Takt verzoegert,
                                                                     -- wie die echte BRAM-Latenz)
begin
    addr_out <= std_logic_vector(to_unsigned(counter, 6));
    done <= done_reg;

    -- src_addr = Adresse von VOR einem Takt (das ist die Adresse, zu der die
    -- aktuell an pixel_in/weight_data anliegenden Daten gehoeren, weil das
    -- echte BRAM 1 Takt Latenz hat)
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                src_addr <= 0;
            else
                src_addr <= counter;
            end if;
        end if;
    end process;

    process(clk)
        variable pixel_signed  : signed(31 downto 0);
        variable weight_signed : signed(7 downto 0);
        variable product       : signed(39 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                accumulator    <= (others => '0');
                counter        <= 0;
                acc_count      <= 0;
                done_reg       <= '0';
                result_out     <= (others => '0');
                last_addr_used <= -1;

            elsif enable = '1' and done_reg = '0' then

                if acc_count < INPUT_SIZE then
                    -- Nur akkumulieren, wenn diese Adresse noch nicht verrechnet wurde.
                    -- Verhindert die Doppel-Zaehlung von Adresse 0 durch die BRAM-Fuellzeit.
                    if src_addr /= last_addr_used then
                        pixel_signed  := signed(pixel_in);
                        weight_signed := signed(weight_data);
                        product := pixel_signed * weight_signed;
                        accumulator <= accumulator + resize(product, 32);
                        acc_count <= acc_count + 1;
                        last_addr_used <= src_addr;
                    end if;

                    if counter < INPUT_SIZE - 1 then
                        counter <= counter + 1;
                    end if;
                else
                    result_out <= std_logic_vector(
                        accumulator + resize(signed(bias_in), 32)
                    );
                    done_reg <= '1';
                end if;

            end if;
        end if;
    end process;
end Behavioral;