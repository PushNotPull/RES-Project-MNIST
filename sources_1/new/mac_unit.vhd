--pixel_in: 8 Bit unsigned (0-255)  -> greyvalue of pixel
--weight_data: 8 Bit signed (-127..127) -> quantizes weight from BRAM
--bias_in: 16 Bit signed -> quantized bias
--accumulator: 32 Bit signed (instead of 24/25) -> prevent overflow
--result_out: 32 Bit signed -> final result after bias
--addr_out: 10 Bit -> address for BRAM (0 - 783)

--sequence :
--1. reset='1'   -> accumulator=0, counter=0, done='0'
--2. enable='1'  -> starts calc
--3. after 784 runs: done='1', result_out = accumulator + bias
--4. done stays at '1' untill reset
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mac_unit is
    generic (
        INPUT_SIZE : integer := 784
    );
    port (
        clk         : in  std_logic;
        reset       : in  std_logic;                      
        enable      : in  std_logic;                      
        pixel_in    : in  std_logic_vector(7 downto 0);   
        weight_data : in  std_logic_vector(7 downto 0);
        bias_in     : in  std_logic_vector(15 downto 0);
        addr_out    : out std_logic_vector(9 downto 0);  
        result_out  : out std_logic_vector(31 downto 0);
        done        : out std_logic
    );
end mac_unit;

architecture Behavioral of mac_unit is
--accumulator: 32 Bit signed, no overflow with 784 * 255 * 127
    signal accumulator : signed(31 downto 0) := (others => '0');

    signal counter     : integer range 0 to INPUT_SIZE := 0;

    signal done_reg    : std_logic := '0';

begin

    addr_out <= std_logic_vector(to_unsigned(counter, 10));

    done <= done_reg;

    process(clk)
        variable pixel_signed  : signed(8 downto 0);
        variable weight_signed : signed(7 downto 0);
        variable product       : signed(16 downto 0);
    begin
        if rising_edge(clk) then

            if reset = '1' then

                accumulator <= (others => '0');
                counter     <= 0;
                done_reg    <= '0';
                result_out  <= (others => '0');

            elsif enable = '1' and done_reg = '0' then

                if counter < INPUT_SIZE then

                    pixel_signed  := signed('0' & pixel_in);
                    weight_signed := signed(weight_data);


                    product := pixel_signed * weight_signed;


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