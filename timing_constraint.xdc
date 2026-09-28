create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

set_input_delay -clock [get_clocks *] 2.000 [get_ports {start done data_valid {data_in[0]} {data_in[1]} {data_in[2]} {data_in[3]} {data_in[4]} {data_in[5]} {data_in[6]} {data_in[7]} rst_n}]
set_output_delay -clock [get_clocks *] 2.000 [get_ports -filter { NAME =~  "*" && DIRECTION =~  "*OUT*" }]
