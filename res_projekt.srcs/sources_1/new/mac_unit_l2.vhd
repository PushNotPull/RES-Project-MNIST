-- mac_unit_l2.vhd
-- Layer-2 MAC-Einheit: 64 Eingaenge, Eingang ist 32-Bit signed
-- (das sind die ReLU-Outputs aus Layer 1, kein 8-Bit Pixel mehr)
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
    signal accumulator : signed(31 downto 0) := (others => '0');
    signal counter     : integer range 0 to INPUT_SIZE := 0;
    signal done_reg    : std_logic := '0';
begin
    addr_out <= std_logic_vector(to_unsigned(counter, 6));
    done <= done_reg;

    process(clk)
        variable pixel_signed  : signed(31 downto 0);
        variable weight_signed : signed(7 downto 0);
        variable product       : signed(39 downto 0);  -- 32-bit * 8-bit = bis zu 40 Bit
    begin
        if rising_edge(clk) then
            if reset = '1' then
                accumulator <= (others => '0');
                counter     <= 0;
                done_reg    <= '0';
                result_out  <= (others => '0');
            elsif enable = '1' and done_reg = '0' then
                if counter < INPUT_SIZE then
                    pixel_signed  := signed(pixel_in);
                    weight_signed := signed(weight_data);
                    product := pixel_signed * weight_signed;
                    -- Achtung: hier wird von 40 Bit auf 32 Bit resized (siehe Hinweis im Chat)
                    accumulator <= accumulator + resize(product, 32);
                    counter <= counter + 1;
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
