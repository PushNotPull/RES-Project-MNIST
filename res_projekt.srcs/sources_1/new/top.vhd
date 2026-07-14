library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk      : in  std_logic;
        btnc     : in  std_logic;  -- Reset-Taster (Pin U18)
        uart_rx  : in  std_logic;
        uart_tx  : out std_logic;
        seg      : out std_logic_vector(6 downto 0);
        an       : out std_logic_vector(3 downto 0)
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
    end component;

    -- ===== Block-Memory-Generator IP Komponenten (von generate_brams.tcl erzeugt) =====
    -- Single Port ROM, Always Enabled -> nur clka/addra/douta, kein Enable-Pin

    component weight_rom_l1_00
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_01
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_02
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_03
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_04
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_05
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_06
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_07
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_08
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_09
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_10
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_11
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_12
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_13
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_14
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_15
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_16
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_17
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_18
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_19
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_20
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_21
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_22
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_23
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_24
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_25
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_26
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_27
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_28
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_29
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_30
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_31
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_32
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_33
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_34
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_35
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_36
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_37
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_38
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_39
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_40
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_41
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_42
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_43
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_44
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_45
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_46
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_47
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_48
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_49
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_50
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_51
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_52
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_53
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_54
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_55
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_56
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_57
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_58
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_59
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_60
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_61
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_62
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l1_63
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(9 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;

    component bias_rom_l1
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;

    component weight_rom_l2_00
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_01
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_02
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_03
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_04
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_05
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_06
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_07
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_08
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;
    component weight_rom_l2_09
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(5 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;

    component bias_rom_l2
        port (
            clka  : in  std_logic;
            addra : in  std_logic_vector(3 downto 0);
            douta : out std_logic_vector(7 downto 0)
        );
    end component;

    signal sys_reset : std_logic;

    -- UART
    signal uart_done    : std_logic;
    signal uart_wr_en   : std_logic;
    signal uart_wr_addr : std_logic_vector(9 downto 0);
    signal uart_wr_data : std_logic_vector(7 downto 0);
    signal uart_tx_data  : std_logic_vector(7 downto 0);
    signal uart_tx_start : std_logic;

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
    signal l1_bias_reg : bias_array_l1 := (others => (others => '0'));
    signal l1_results_packed : std_logic_vector(64*32-1 downto 0);

    signal relu_packed : std_logic_vector(64*32-1 downto 0);
    type relu_array_type is array(0 to 63) of std_logic_vector(31 downto 0);
    signal relu_array : relu_array_type;

    type weight_array_l2 is array(0 to 9) of std_logic_vector(7 downto 0);
    type addr_array_l2   is array(0 to 9) of std_logic_vector(5 downto 0);
    type result_array_l2 is array(0 to 9) of std_logic_vector(31 downto 0);
    type bias_array_l2   is array(0 to 9) of std_logic_vector(15 downto 0);

    signal l2_weight_data : weight_array_l2;
    signal l2_addr        : addr_array_l2;
    signal l2_result      : result_array_l2;
    signal l2_bias_reg    : bias_array_l2 := (others => (others => '0'));

    signal l2_results_packed : std_logic_vector(10*32-1 downto 0);
    signal l2_input_pixel    : std_logic_vector(31 downto 0);

    -- Bias-Lade-FSM: laedt einmalig nach Reset alle Bias-Werte seriell aus den
    -- gemeinsamen bias_rom_l1 / bias_rom_l2 ROMs in parallele Register.
    -- Noetig, weil ein Single-Port-ROM nur 1 Adresse/Takt liefert, aber alle
    -- MAC-Einheiten ihren Bias gleichzeitig brauchen.
    signal bias_idx      : integer range 0 to 63 := 0;
    signal bias_state    : integer range 0 to 2 := 0;  -- 0=L1 laedt, 1=L2 laedt, 2=fertig
    signal bias_idx_d    : integer range 0 to 63 := 0;
    signal bias_layer_d  : integer range 0 to 1 := 0;
    signal bias_valid_d  : std_logic := '0';
    signal bias_ready    : std_logic := '0';

    signal bias_l1_addr : std_logic_vector(5 downto 0);
    signal bias_l1_data : std_logic_vector(7 downto 0);
    signal bias_l2_addr : std_logic_vector(3 downto 0);
    signal bias_l2_data : std_logic_vector(7 downto 0);

begin

    sys_reset <= btnc;

    -- ================= Eingangsbild-Speicher (UART -> RAM) =================
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
            reset    => sys_reset,
            rx       => uart_rx,
            tx       => uart_tx,
            wr_en    => uart_wr_en,
            wr_addr  => uart_wr_addr,
            wr_data  => uart_wr_data,
            done     => uart_done,
            tx_data  => uart_tx_data,
            tx_start => uart_tx_start
        );

    -- Ergebnis nach der Erkennung einmalig per UART zurueckschicken
    uart_tx_data  <= "0000" & result_digit;
    uart_tx_start <= result_valid;

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

    unpack_relu: for i in 0 to 63 generate
        relu_array(i) <= relu_packed(i*32+31 downto i*32);
    end generate;

    -- Layer-2-Eingang: waehlt per gemeinsamem L2-Adresszaehler (l2_addr(0))
    -- den passenden ReLU-Wert aus (alle 10 L2-MACs zaehlen synchron gleich)
    l2_input_pixel <= relu_array(to_integer(unsigned(l2_addr(0))));

    -- ================= Layer 1: 64 MAC-Einheiten + Gewichts-ROMs =================
    l1_macs: for i in 0 to 63 generate
        mac_l1_inst: mac_unit
            generic map (INPUT_SIZE => 784)
            port map (
                clk         => clk,
                reset       => l1_reset,
                enable      => l1_enable,
                pixel_in    => pixel_out,
                weight_data => l1_weight_data(i),
                bias_in     => l1_bias_reg(i),
                addr_out    => l1_addr(i),
                result_out  => l1_result(i),
                done        => l1_done(i)
            );
    end generate;

    weight_rom_l1_00_inst : weight_rom_l1_00
        port map (
            clka  => clk,
            addra => l1_addr(0),
            douta => l1_weight_data(0)
        );
    weight_rom_l1_01_inst : weight_rom_l1_01
        port map (
            clka  => clk,
            addra => l1_addr(1),
            douta => l1_weight_data(1)
        );
    weight_rom_l1_02_inst : weight_rom_l1_02
        port map (
            clka  => clk,
            addra => l1_addr(2),
            douta => l1_weight_data(2)
        );
    weight_rom_l1_03_inst : weight_rom_l1_03
        port map (
            clka  => clk,
            addra => l1_addr(3),
            douta => l1_weight_data(3)
        );
    weight_rom_l1_04_inst : weight_rom_l1_04
        port map (
            clka  => clk,
            addra => l1_addr(4),
            douta => l1_weight_data(4)
        );
    weight_rom_l1_05_inst : weight_rom_l1_05
        port map (
            clka  => clk,
            addra => l1_addr(5),
            douta => l1_weight_data(5)
        );
    weight_rom_l1_06_inst : weight_rom_l1_06
        port map (
            clka  => clk,
            addra => l1_addr(6),
            douta => l1_weight_data(6)
        );
    weight_rom_l1_07_inst : weight_rom_l1_07
        port map (
            clka  => clk,
            addra => l1_addr(7),
            douta => l1_weight_data(7)
        );
    weight_rom_l1_08_inst : weight_rom_l1_08
        port map (
            clka  => clk,
            addra => l1_addr(8),
            douta => l1_weight_data(8)
        );
    weight_rom_l1_09_inst : weight_rom_l1_09
        port map (
            clka  => clk,
            addra => l1_addr(9),
            douta => l1_weight_data(9)
        );
    weight_rom_l1_10_inst : weight_rom_l1_10
        port map (
            clka  => clk,
            addra => l1_addr(10),
            douta => l1_weight_data(10)
        );
    weight_rom_l1_11_inst : weight_rom_l1_11
        port map (
            clka  => clk,
            addra => l1_addr(11),
            douta => l1_weight_data(11)
        );
    weight_rom_l1_12_inst : weight_rom_l1_12
        port map (
            clka  => clk,
            addra => l1_addr(12),
            douta => l1_weight_data(12)
        );
    weight_rom_l1_13_inst : weight_rom_l1_13
        port map (
            clka  => clk,
            addra => l1_addr(13),
            douta => l1_weight_data(13)
        );
    weight_rom_l1_14_inst : weight_rom_l1_14
        port map (
            clka  => clk,
            addra => l1_addr(14),
            douta => l1_weight_data(14)
        );
    weight_rom_l1_15_inst : weight_rom_l1_15
        port map (
            clka  => clk,
            addra => l1_addr(15),
            douta => l1_weight_data(15)
        );
    weight_rom_l1_16_inst : weight_rom_l1_16
        port map (
            clka  => clk,
            addra => l1_addr(16),
            douta => l1_weight_data(16)
        );
    weight_rom_l1_17_inst : weight_rom_l1_17
        port map (
            clka  => clk,
            addra => l1_addr(17),
            douta => l1_weight_data(17)
        );
    weight_rom_l1_18_inst : weight_rom_l1_18
        port map (
            clka  => clk,
            addra => l1_addr(18),
            douta => l1_weight_data(18)
        );
    weight_rom_l1_19_inst : weight_rom_l1_19
        port map (
            clka  => clk,
            addra => l1_addr(19),
            douta => l1_weight_data(19)
        );
    weight_rom_l1_20_inst : weight_rom_l1_20
        port map (
            clka  => clk,
            addra => l1_addr(20),
            douta => l1_weight_data(20)
        );
    weight_rom_l1_21_inst : weight_rom_l1_21
        port map (
            clka  => clk,
            addra => l1_addr(21),
            douta => l1_weight_data(21)
        );
    weight_rom_l1_22_inst : weight_rom_l1_22
        port map (
            clka  => clk,
            addra => l1_addr(22),
            douta => l1_weight_data(22)
        );
    weight_rom_l1_23_inst : weight_rom_l1_23
        port map (
            clka  => clk,
            addra => l1_addr(23),
            douta => l1_weight_data(23)
        );
    weight_rom_l1_24_inst : weight_rom_l1_24
        port map (
            clka  => clk,
            addra => l1_addr(24),
            douta => l1_weight_data(24)
        );
    weight_rom_l1_25_inst : weight_rom_l1_25
        port map (
            clka  => clk,
            addra => l1_addr(25),
            douta => l1_weight_data(25)
        );
    weight_rom_l1_26_inst : weight_rom_l1_26
        port map (
            clka  => clk,
            addra => l1_addr(26),
            douta => l1_weight_data(26)
        );
    weight_rom_l1_27_inst : weight_rom_l1_27
        port map (
            clka  => clk,
            addra => l1_addr(27),
            douta => l1_weight_data(27)
        );
    weight_rom_l1_28_inst : weight_rom_l1_28
        port map (
            clka  => clk,
            addra => l1_addr(28),
            douta => l1_weight_data(28)
        );
    weight_rom_l1_29_inst : weight_rom_l1_29
        port map (
            clka  => clk,
            addra => l1_addr(29),
            douta => l1_weight_data(29)
        );
    weight_rom_l1_30_inst : weight_rom_l1_30
        port map (
            clka  => clk,
            addra => l1_addr(30),
            douta => l1_weight_data(30)
        );
    weight_rom_l1_31_inst : weight_rom_l1_31
        port map (
            clka  => clk,
            addra => l1_addr(31),
            douta => l1_weight_data(31)
        );
    weight_rom_l1_32_inst : weight_rom_l1_32
        port map (
            clka  => clk,
            addra => l1_addr(32),
            douta => l1_weight_data(32)
        );
    weight_rom_l1_33_inst : weight_rom_l1_33
        port map (
            clka  => clk,
            addra => l1_addr(33),
            douta => l1_weight_data(33)
        );
    weight_rom_l1_34_inst : weight_rom_l1_34
        port map (
            clka  => clk,
            addra => l1_addr(34),
            douta => l1_weight_data(34)
        );
    weight_rom_l1_35_inst : weight_rom_l1_35
        port map (
            clka  => clk,
            addra => l1_addr(35),
            douta => l1_weight_data(35)
        );
    weight_rom_l1_36_inst : weight_rom_l1_36
        port map (
            clka  => clk,
            addra => l1_addr(36),
            douta => l1_weight_data(36)
        );
    weight_rom_l1_37_inst : weight_rom_l1_37
        port map (
            clka  => clk,
            addra => l1_addr(37),
            douta => l1_weight_data(37)
        );
    weight_rom_l1_38_inst : weight_rom_l1_38
        port map (
            clka  => clk,
            addra => l1_addr(38),
            douta => l1_weight_data(38)
        );
    weight_rom_l1_39_inst : weight_rom_l1_39
        port map (
            clka  => clk,
            addra => l1_addr(39),
            douta => l1_weight_data(39)
        );
    weight_rom_l1_40_inst : weight_rom_l1_40
        port map (
            clka  => clk,
            addra => l1_addr(40),
            douta => l1_weight_data(40)
        );
    weight_rom_l1_41_inst : weight_rom_l1_41
        port map (
            clka  => clk,
            addra => l1_addr(41),
            douta => l1_weight_data(41)
        );
    weight_rom_l1_42_inst : weight_rom_l1_42
        port map (
            clka  => clk,
            addra => l1_addr(42),
            douta => l1_weight_data(42)
        );
    weight_rom_l1_43_inst : weight_rom_l1_43
        port map (
            clka  => clk,
            addra => l1_addr(43),
            douta => l1_weight_data(43)
        );
    weight_rom_l1_44_inst : weight_rom_l1_44
        port map (
            clka  => clk,
            addra => l1_addr(44),
            douta => l1_weight_data(44)
        );
    weight_rom_l1_45_inst : weight_rom_l1_45
        port map (
            clka  => clk,
            addra => l1_addr(45),
            douta => l1_weight_data(45)
        );
    weight_rom_l1_46_inst : weight_rom_l1_46
        port map (
            clka  => clk,
            addra => l1_addr(46),
            douta => l1_weight_data(46)
        );
    weight_rom_l1_47_inst : weight_rom_l1_47
        port map (
            clka  => clk,
            addra => l1_addr(47),
            douta => l1_weight_data(47)
        );
    weight_rom_l1_48_inst : weight_rom_l1_48
        port map (
            clka  => clk,
            addra => l1_addr(48),
            douta => l1_weight_data(48)
        );
    weight_rom_l1_49_inst : weight_rom_l1_49
        port map (
            clka  => clk,
            addra => l1_addr(49),
            douta => l1_weight_data(49)
        );
    weight_rom_l1_50_inst : weight_rom_l1_50
        port map (
            clka  => clk,
            addra => l1_addr(50),
            douta => l1_weight_data(50)
        );
    weight_rom_l1_51_inst : weight_rom_l1_51
        port map (
            clka  => clk,
            addra => l1_addr(51),
            douta => l1_weight_data(51)
        );
    weight_rom_l1_52_inst : weight_rom_l1_52
        port map (
            clka  => clk,
            addra => l1_addr(52),
            douta => l1_weight_data(52)
        );
    weight_rom_l1_53_inst : weight_rom_l1_53
        port map (
            clka  => clk,
            addra => l1_addr(53),
            douta => l1_weight_data(53)
        );
    weight_rom_l1_54_inst : weight_rom_l1_54
        port map (
            clka  => clk,
            addra => l1_addr(54),
            douta => l1_weight_data(54)
        );
    weight_rom_l1_55_inst : weight_rom_l1_55
        port map (
            clka  => clk,
            addra => l1_addr(55),
            douta => l1_weight_data(55)
        );
    weight_rom_l1_56_inst : weight_rom_l1_56
        port map (
            clka  => clk,
            addra => l1_addr(56),
            douta => l1_weight_data(56)
        );
    weight_rom_l1_57_inst : weight_rom_l1_57
        port map (
            clka  => clk,
            addra => l1_addr(57),
            douta => l1_weight_data(57)
        );
    weight_rom_l1_58_inst : weight_rom_l1_58
        port map (
            clka  => clk,
            addra => l1_addr(58),
            douta => l1_weight_data(58)
        );
    weight_rom_l1_59_inst : weight_rom_l1_59
        port map (
            clka  => clk,
            addra => l1_addr(59),
            douta => l1_weight_data(59)
        );
    weight_rom_l1_60_inst : weight_rom_l1_60
        port map (
            clka  => clk,
            addra => l1_addr(60),
            douta => l1_weight_data(60)
        );
    weight_rom_l1_61_inst : weight_rom_l1_61
        port map (
            clka  => clk,
            addra => l1_addr(61),
            douta => l1_weight_data(61)
        );
    weight_rom_l1_62_inst : weight_rom_l1_62
        port map (
            clka  => clk,
            addra => l1_addr(62),
            douta => l1_weight_data(62)
        );
    weight_rom_l1_63_inst : weight_rom_l1_63
        port map (
            clka  => clk,
            addra => l1_addr(63),
            douta => l1_weight_data(63)
        );

    bias_rom_l1_inst : bias_rom_l1
        port map (
            clka  => clk,
            addra => bias_l1_addr,
            douta => bias_l1_data
        );

    -- ================= Layer 2: 10 MAC-Einheiten + Gewichts-ROMs =================
    l2_macs: for i in 0 to 9 generate
        mac_l2_inst: mac_unit_l2
            generic map (INPUT_SIZE => 64)
            port map (
                clk         => clk,
                reset       => l2_reset,
                enable      => l2_enable,
                pixel_in    => l2_input_pixel,
                weight_data => l2_weight_data(i),
                bias_in     => l2_bias_reg(i),
                addr_out    => l2_addr(i),
                result_out  => l2_result(i),
                done        => open
            );
    end generate;

    weight_rom_l2_00_inst : weight_rom_l2_00
        port map (
            clka  => clk,
            addra => l2_addr(0),
            douta => l2_weight_data(0)
        );
    weight_rom_l2_01_inst : weight_rom_l2_01
        port map (
            clka  => clk,
            addra => l2_addr(1),
            douta => l2_weight_data(1)
        );
    weight_rom_l2_02_inst : weight_rom_l2_02
        port map (
            clka  => clk,
            addra => l2_addr(2),
            douta => l2_weight_data(2)
        );
    weight_rom_l2_03_inst : weight_rom_l2_03
        port map (
            clka  => clk,
            addra => l2_addr(3),
            douta => l2_weight_data(3)
        );
    weight_rom_l2_04_inst : weight_rom_l2_04
        port map (
            clka  => clk,
            addra => l2_addr(4),
            douta => l2_weight_data(4)
        );
    weight_rom_l2_05_inst : weight_rom_l2_05
        port map (
            clka  => clk,
            addra => l2_addr(5),
            douta => l2_weight_data(5)
        );
    weight_rom_l2_06_inst : weight_rom_l2_06
        port map (
            clka  => clk,
            addra => l2_addr(6),
            douta => l2_weight_data(6)
        );
    weight_rom_l2_07_inst : weight_rom_l2_07
        port map (
            clka  => clk,
            addra => l2_addr(7),
            douta => l2_weight_data(7)
        );
    weight_rom_l2_08_inst : weight_rom_l2_08
        port map (
            clka  => clk,
            addra => l2_addr(8),
            douta => l2_weight_data(8)
        );
    weight_rom_l2_09_inst : weight_rom_l2_09
        port map (
            clka  => clk,
            addra => l2_addr(9),
            douta => l2_weight_data(9)
        );

    bias_rom_l2_inst : bias_rom_l2
        port map (
            clka  => clk,
            addra => bias_l2_addr,
            douta => bias_l2_data
        );

    pack_l2: for i in 0 to 9 generate
        l2_results_packed(i*32+31 downto i*32) <= l2_result(i);
    end generate;

    -- ================= Bias-Lade-FSM =================
    -- Laedt einmalig (ca. 76 Takte = < 1 us) nach Reset alle Bias-Werte seriell
    -- aus bias_rom_l1 (64 Werte) und bias_rom_l2 (10 Werte) in Register.
    -- WICHTIG: .coe-Werte werden hier als 8-Bit signed angenommen und auf
    -- 16 Bit vorzeichenrichtig erweitert (resize). Falls euer export_weights_v2.py
    -- die Bias-Werte mit mehr als 8 Bit quantisiert, muss Write_Width_A im
    -- Tcl-Skript UND diese resize-Breite angepasst werden!
    bias_l1_addr <= std_logic_vector(to_unsigned(bias_idx, 6));
    bias_l2_addr <= std_logic_vector(to_unsigned(bias_idx, 4));

    process(clk)
    begin
        if rising_edge(clk) then
            if sys_reset = '1' then
                bias_idx     <= 0;
                bias_state   <= 0;
                bias_idx_d   <= 0;
                bias_layer_d <= 0;
                bias_valid_d <= '0';
                bias_ready   <= '0';
            else
                -- Adresse in diesem Takt anlegen -> Datum ist naechsten Takt gueltig
                bias_idx_d   <= bias_idx;
                bias_layer_d <= bias_state;

                if bias_state = 0 or bias_state = 1 then
                    bias_valid_d <= '1';
                else
                    bias_valid_d <= '0';
                end if;

                case bias_state is
                    when 0 =>  -- L1: Adressen 0..63
                        if bias_idx = 63 then
                            bias_idx   <= 0;
                            bias_state <= 1;
                        else
                            bias_idx <= bias_idx + 1;
                        end if;
                    when 1 =>  -- L2: Adressen 0..9
                        if bias_idx = 9 then
                            bias_state <= 2;
                        else
                            bias_idx <= bias_idx + 1;
                        end if;
                    when others =>
                        bias_ready <= '1';
                end case;

                -- Daten abholen: gehoeren zur Adresse, die einen Takt vorher anlag
                if bias_valid_d = '1' then
                    if bias_layer_d = 0 then
                        l1_bias_reg(bias_idx_d) <= std_logic_vector(resize(signed(bias_l1_data), 16));
                    else
                        l2_bias_reg(bias_idx_d) <= std_logic_vector(resize(signed(bias_l2_data), 16));
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ================= 7-Segment-Anzeige =================
    an <= "1110";
    with result_digit select
        seg <= "1000000" when x"0",
               "1111001" when x"1",
               "0100100" when x"2",
               "0110000" when x"3",
               "0011001" when x"4",
               "0010010" when x"5",
               "0000010" when x"6",
               "1111000" when x"7",
               "0000000" when x"8",
               "0010000" when x"9",
               "1111111" when others;

end Behavioral;
