## Clock constraint for project_reti_logiche
## 20 ns period (50 MHz), as specified by the Prova Finale di Reti Logiche 2024/25
create_clock -period 20.000 -name i_clk -waveform {0.000 10.000} [get_ports i_clk]
