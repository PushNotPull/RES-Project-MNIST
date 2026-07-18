# generate_brams.tcl
# Fuehre dieses Skript in der Vivado Tcl Console aus:
# source /pfad/zu/generate_brams.tcl

set COE_DIR "/home/markus/Downloads/resprojekt/feils/coe_files"

# ── Layer 1: 64 BRAMs, je 784 x 8 Bit ────────────────────────────────────────
for {set i 0} {$i < 64} {incr i} {
    set name [format "weight_rom_l1_%02d" $i]
    set coe  [format "%s/weights_l1_neuron_%02d.coe" $COE_DIR $i]

    create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
              -version 8.4 -module_name $name

    set_property -dict [list \
        CONFIG.Memory_Type          {Single_Port_ROM} \
        CONFIG.Write_Width_A        {8}               \
        CONFIG.Write_Depth_A        {784}             \
        CONFIG.Read_Width_A         {8}               \
        CONFIG.Operating_Mode_A     {READ_FIRST}      \
        CONFIG.Enable_A             {Always_Enabled}  \
        CONFIG.Load_Init_File       {true}            \
        CONFIG.Coe_File             $coe              \
        CONFIG.Fill_Remaining_Memory_Locations {false}\
    ] [get_ips $name]

    generate_target all [get_ips $name]
    puts "Generiert: $name"
}

# ── Layer 1 Bias: 1 BRAM, 64 x 8 Bit ─────────────────────────────────────────
create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
          -version 8.4 -module_name bias_rom_l1

set_property -dict [list \
    CONFIG.Memory_Type          {Single_Port_ROM} \
    CONFIG.Write_Width_A        {8}               \
    CONFIG.Write_Depth_A        {64}              \
    CONFIG.Read_Width_A         {8}               \
    CONFIG.Operating_Mode_A     {READ_FIRST}      \
    CONFIG.Enable_A             {Always_Enabled}  \
    CONFIG.Load_Init_File       {true}            \
    CONFIG.Coe_File             "$COE_DIR/bias_l1.coe" \
    CONFIG.Fill_Remaining_Memory_Locations {false}\
] [get_ips bias_rom_l1]

generate_target all [get_ips bias_rom_l1]
puts "Generiert: bias_rom_l1"

# ── Layer 2: 10 BRAMs, je 64 x 8 Bit ─────────────────────────────────────────
for {set i 0} {$i < 10} {incr i} {
    set name [format "weight_rom_l2_%02d" $i]
    set coe  [format "%s/weights_l2_neuron_%02d.coe" $COE_DIR $i]

    create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
              -version 8.4 -module_name $name

    set_property -dict [list \
        CONFIG.Memory_Type          {Single_Port_ROM} \
        CONFIG.Write_Width_A        {8}               \
        CONFIG.Write_Depth_A        {64}              \
        CONFIG.Read_Width_A         {8}               \
        CONFIG.Operating_Mode_A     {READ_FIRST}      \
        CONFIG.Enable_A             {Always_Enabled}  \
        CONFIG.Load_Init_File       {true}            \
        CONFIG.Coe_File             $coe              \
        CONFIG.Fill_Remaining_Memory_Locations {false}\
    ] [get_ips $name]

    generate_target all [get_ips $name]
    puts "Generiert: $name"
}

# ── Layer 2 Bias: 1 BRAM, 10 x 8 Bit ─────────────────────────────────────────
create_ip -name blk_mem_gen -vendor xilinx.com -library ip \
          -version 8.4 -module_name bias_rom_l2

set_property -dict [list \
    CONFIG.Memory_Type          {Single_Port_ROM} \
    CONFIG.Write_Width_A        {8}               \
    CONFIG.Write_Depth_A        {10}              \
    CONFIG.Read_Width_A         {8}               \
    CONFIG.Operating_Mode_A     {READ_FIRST}      \
    CONFIG.Enable_A             {Always_Enabled}  \
    CONFIG.Load_Init_File       {true}            \
    CONFIG.Coe_File             "$COE_DIR/bias_l2.coe" \
    CONFIG.Fill_Remaining_Memory_Locations {false}\
] [get_ips bias_rom_l2]

generate_target all [get_ips bias_rom_l2]
puts "Generiert: bias_rom_l2"

puts ""
puts "Fertig! Alle 76 BRAMs generiert."
puts "Jetzt top.vhd anpassen um die IP-Instanzen einzubinden."
