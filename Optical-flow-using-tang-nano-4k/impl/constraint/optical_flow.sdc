//============================================================================
// Timing Constraints for Optical Flow Co-Processor
// Target: Tang Nano 4K (GW1NSR-LV4CQN48PC6/I5)
//============================================================================

// Primary system clock: 27MHz on-board oscillator
create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {clk_27m}]

// DVP pixel clock from OV2640 (QVGA ~12MHz)
create_clock -name dvp_pclk -period 83.333 -waveform {0 41.667} [get_ports {dvp_pclk}]

// Clock domain crossing constraints
set_clock_groups -asynchronous -group {sys_clk} -group {dvp_pclk}

// False paths for CDC synchronizers (these are handled by multi-FF synchronizers)
// set_false_path -from [get_clocks dvp_pclk] -to [get_clocks sys_clk]
