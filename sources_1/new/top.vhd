library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk     : in  std_logic;
        uart_rx : in  std_logic;
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(3 downto 0)
    );
end top;

architecture Behavioral of top is

    component mac_unit is
        generic (INPUT_SIZE : integer := 784);
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
    end component;

    component mac_unit_l2 is
        generic (INPUT_SIZE : integer := 64);
        port (
            clk         : in  std_logic;
            reset       : in  std_logic;
            enable      : in  std_logic;
            pixel_in    : in  std_logic_vector(31 downto 0);
            weight_data : in  std_logic_vector(7 downto 0);
            bias_in     : in  std_logic_vector(15 downto 0);
            addr_out    : out std_logic_vector(5 downto 0);
            result_out  : out std_logic_vector(31 downto 0);
            done        : out std_logic
        );
    end component;

    component fsm_controller is
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
    end component;

    component uart_receiver is
        port (
            clk       : in  std_logic;
            rx        : in  std_logic;

            wr_en     : out std_logic;
            wr_addr   : out std_logic_vector(9 downto 0);
            wr_data   : out std_logic_vector(7 downto 0);
            done      : out std_logic
        );
    end component;

    signal sys_reset : std_logic := '0';

    -- UART
    signal uart_done : std_logic;
    signal uart_wr_en   : std_logic;
    signal uart_wr_addr : std_logic_vector(9 downto 0);
    signal uart_wr_data : std_logic_vector(7 downto 0);

    signal l1_reset, l1_enable : std_logic;
    signal l2_reset, l2_enable : std_logic;
    signal pixel_addr           : std_logic_vector(9 downto 0);
    signal result_digit         : std_logic_vector(3 downto 0);
    signal result_valid         : std_logic;

    type input_bram_type is array(0 to 783) of std_logic_vector(7 downto 0);
    signal input_bram : input_bram_type := (others => (others => '0'));
    signal pixel_out  : std_logic_vector(7 downto 0);

    type weight_array    is array(0 to 63) of std_logic_vector(7 downto 0);
    type addr_array_l1   is array(0 to 63) of std_logic_vector(9 downto 0);
    type result_array_l1 is array(0 to 63) of std_logic_vector(31 downto 0);


    signal l1_weight_data : weight_array;
    signal l1_addr        : addr_array_l1;

    signal l1_result      : result_array_l1;

    signal l1_done        : std_logic_vector(63 downto 0);

    type bias_array_l1 is array(0 to 63) of std_logic_vector(15 downto 0);
    signal l1_bias : bias_array_l1;
    signal l1_results_packed : std_logic_vector(64*32-1 downto 0);

    signal relu_packed        : std_logic_vector(64*32-1 downto 0);

    type weight_array_l2   is array(0 to 9) of std_logic_vector(7 downto 0);
    type addr_array_l2     is array(0 to 9) of std_logic_vector(5 downto 0);
    type result_array_l2   is array(0 to 9) of std_logic_vector(31 downto 0);
    type bias_array_l2     is array(0 to 9) of std_logic_vector(15 downto 0);

    signal l2_weight_data : weight_array_l2;
    signal l2_addr        : addr_array_l2;
    signal l2_result      : result_array_l2;
    signal l2_bias        : bias_array_l2;

    signal l2_results_packed : std_logic_vector(10*32-1 downto 0);

    signal l2_input_pixel : std_logic_vector(31 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if uart_wr_en = '1' then
                input_bram(to_integer(unsigned(uart_wr_addr))) <= uart_wr_data;
            end if;

            pixel_out <= input_bram(to_integer(unsigned(pixel_addr)));
        end if;
    end process;

    uart_inst: uart_receiver
        port map (
            clk      => clk,
            rx       => uart_rx,
            wr_en    => uart_wr_en,
            wr_addr  => uart_wr_addr,
            wr_data  => uart_wr_data,
            done     => uart_done
        );

    fsm_inst: fsm_controller
        port map (
            clk          => clk,
            reset        => sys_reset,
            uart_done    => uart_done,
            l1_reset     => l1_reset,
            l1_enable    => l1_enable,
            l2_reset     => l2_reset,
            l2_enable    => l2_enable,
            pixel_addr   => pixel_addr,
            result_digit => result_digit,
            result_valid => result_valid,
            l1_results   => l1_results_packed,
            l2_results   => l2_results_packed,
            relu_out     => relu_packed
        );


    pack_l1: for i in 0 to 63 generate
        l1_results_packed(i*32+31 downto i*32) <= l1_result(i);
    end generate;

    l1_macs: for i in 0 to 63 generate
        mac_l1_inst: mac_unit
            generic map (INPUT_SIZE => 784)
            port map (
                clk         => clk,
                reset       => l1_reset,
                enable      => l1_enable,
                pixel_in    => pixel_out,           
                weight_data => l1_weight_data(i),   
                bias_in     => l1_bias(i),
                addr_out    => l1_addr(i),
                result_out  => l1_result(i),
                done        => l1_done(i)
            );

        weight_bram_l1: process(clk)

            type bram_type is array(0 to 783) of std_logic_vector(7 downto 0);

            variable bram_mem : bram_type := (others => x"00");
        begin
            if rising_edge(clk) then

                l1_weight_data(i) <= bram_mem(to_integer(unsigned(l1_addr(i))));
            end if;
        end process;
    end generate;

    l2_macs: for i in 0 to 9 generate
        mac_l2_inst: mac_unit_l2
            generic map (INPUT_SIZE => 64)
            port map (
                clk         => clk,
                reset       => l2_reset,
                enable      => l2_enable,
                pixel_in    => l2_input_pixel,
                weight_data => l2_weight_data(i),
                bias_in     => l2_bias(i),
                addr_out    => l2_addr(i),
                result_out  => l2_result(i),
                done        => open
            );
    end generate;

    pack_l2: for i in 0 to 9 generate
        l2_results_packed(i*32+31 downto i*32) <= l2_result(i);
    end generate;

    an <= "1110";
    with result_digit select
        seg <= "1000000" when x"0",  -- 0
               "1111001" when x"1",  -- 1
               "0100100" when x"2",  -- 2
               "0110000" when x"3",  -- 3
               "0011001" when x"4",  -- 4
               "0010010" when x"5",  -- 5
               "0000010" when x"6",  -- 6
               "1111000" when x"7",  -- 7
               "0000000" when x"8",  -- 8
               "0010000" when x"9",  -- 9
               "1111111" when others; -- aus

end Behavioral;