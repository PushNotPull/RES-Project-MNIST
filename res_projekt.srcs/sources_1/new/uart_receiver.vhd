-- uart_receiver.vhd
-- 115200 Baud, 8N1, 100 MHz Takt
-- Empfaengt 784 Bytes, schreibt ins BRAM, signalisiert done
-- Sendet 1 Byte Ergebnis zurueck (tx_data/tx_start von FSM)
--
-- FIX (13.07.2026): Die TX-State-Enum-Literale hiessen vorher
-- TX_IDLE/TX_START/TX_DATA/TX_STOP -- das kollidiert (case-insensitiv!)
-- mit den Ports tx_start/tx_data. Deshalb umbenannt zu ST_TX_*.
-- Ports (tx_data, tx_start) bleiben unveraendert, damit fsm_controller
-- und top.vhd nicht angepasst werden muessen.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_receiver is
    generic (
        CLK_FREQ  : integer := 100_000_000;
        BAUD_RATE : integer := 115_200;
        N_BYTES   : integer := 784
    );
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        rx       : in  std_logic;
        tx       : out std_logic;
        wr_en    : out std_logic;
        wr_addr  : out std_logic_vector(9 downto 0);
        wr_data  : out std_logic_vector(7 downto 0);
        done     : out std_logic;
        tx_data  : in  std_logic_vector(7 downto 0);
        tx_start : in  std_logic
    );
end uart_receiver;

architecture Behavioral of uart_receiver is
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;
    type rx_state_type is (RX_IDLE, RX_START, RX_DATA, RX_STOP);
    signal rx_state : rx_state_type := RX_IDLE;
    signal rx_clk_count : integer range 0 to CLKS_PER_BIT := 0;
    signal rx_bit_index : integer range 0 to 7 := 0;
    signal rx_byte      : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_byte_valid : std_logic := '0';
    signal byte_count : integer range 0 to N_BYTES := 0;
    signal done_reg   : std_logic := '0';

    -- umbenannt: ST_TX_* statt TX_* (Kollision mit Ports tx_start/tx_data vermeiden)
    type tx_state_type is (ST_TX_IDLE, ST_TX_START, ST_TX_DATA, ST_TX_STOP);
    signal tx_state     : tx_state_type := ST_TX_IDLE;
    signal tx_clk_count : integer range 0 to CLKS_PER_BIT := 0;
    signal tx_bit_index : integer range 0 to 7 := 0;
    signal tx_shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_reg       : std_logic := '1';
begin
    done <= done_reg;
    tx   <= tx_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                rx_state <= RX_IDLE; rx_clk_count <= 0;
                rx_bit_index <= 0; rx_byte_valid <= '0';
                byte_count <= 0; done_reg <= '0'; wr_en <= '0';
            else
                rx_byte_valid <= '0'; wr_en <= '0'; done_reg <= '0';
                case rx_state is
                    when RX_IDLE =>
                        if rx = '0' then rx_clk_count <= 0; rx_state <= RX_START; end if;
                    when RX_START =>
                        if rx_clk_count = CLKS_PER_BIT / 2 then
                            if rx = '0' then
                                rx_clk_count <= 0; rx_bit_index <= 0; rx_state <= RX_DATA;
                            else rx_state <= RX_IDLE; end if;
                        else rx_clk_count <= rx_clk_count + 1; end if;
                    when RX_DATA =>
                        if rx_clk_count = CLKS_PER_BIT - 1 then
                            rx_clk_count <= 0;
                            rx_byte(rx_bit_index) <= rx;
                            if rx_bit_index = 7 then rx_state <= RX_STOP;
                            else rx_bit_index <= rx_bit_index + 1; end if;
                        else rx_clk_count <= rx_clk_count + 1; end if;
                    when RX_STOP =>
                        if rx_clk_count = CLKS_PER_BIT - 1 then
                            rx_clk_count <= 0; rx_byte_valid <= '1'; rx_state <= RX_IDLE;
                        else rx_clk_count <= rx_clk_count + 1; end if;
                end case;
                if rx_byte_valid = '1' and byte_count < N_BYTES then
                    wr_en <= '1';
                    wr_addr <= std_logic_vector(to_unsigned(byte_count, 10));
                    wr_data <= rx_byte;
                    byte_count <= byte_count + 1;
                    if byte_count = N_BYTES - 1 then
                        done_reg <= '1'; byte_count <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tx_state <= ST_TX_IDLE; tx_reg <= '1'; tx_clk_count <= 0; tx_bit_index <= 0;
            else
                case tx_state is
                    when ST_TX_IDLE =>
                        tx_reg <= '1';
                        if tx_start = '1' then
                            tx_shift_reg <= tx_data; tx_clk_count <= 0; tx_state <= ST_TX_START;
                        end if;
                    when ST_TX_START =>
                        tx_reg <= '0';
                        if tx_clk_count = CLKS_PER_BIT - 1 then
                            tx_clk_count <= 0; tx_bit_index <= 0; tx_state <= ST_TX_DATA;
                        else tx_clk_count <= tx_clk_count + 1; end if;
                    when ST_TX_DATA =>
                        tx_reg <= tx_shift_reg(tx_bit_index);
                        if tx_clk_count = CLKS_PER_BIT - 1 then
                            tx_clk_count <= 0;
                            if tx_bit_index = 7 then tx_state <= ST_TX_STOP;
                            else tx_bit_index <= tx_bit_index + 1; end if;
                        else tx_clk_count <= tx_clk_count + 1; end if;
                    when ST_TX_STOP =>
                        tx_reg <= '1';
                        if tx_clk_count = CLKS_PER_BIT - 1 then
                            tx_clk_count <= 0; tx_state <= ST_TX_IDLE;
                        else tx_clk_count <= tx_clk_count + 1; end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;