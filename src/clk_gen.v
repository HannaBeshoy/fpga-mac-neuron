`timescale 1ns / 1ps
// ============================================================================
// clk_gen.v - 50 MHz system clock from the board's 100 MHz (PLD Lab 8)
//
// In Vivado this instantiates clk_wiz_0, a Clocking Wizard IP core with one
// 50 MHz output (see README, "Clocking Wizard"). The wizard configures an
// MMCM clock manager and reports `locked` once the output is stable; the
// design is held in reset until then.
// For Icarus Verilog, run with -DSIMULATION: the clock is passed through and
// `locked` is 1, because the Xilinx IP model is not available there.
// ============================================================================
module clk_gen (
    input  clk_in,          // 100 MHz, pin E3
    input  reset,           // active high
    output clk_out,         // 50 MHz system clock
    output locked
);
`ifdef SIMULATION
    assign clk_out = clk_in;
    assign locked  = ~reset;
`else
    clk_wiz_0 U_wiz (
        .clk_in1  (clk_in),
        .clk_out1 (clk_out),
        .reset    (reset),
        .locked   (locked));
`endif
endmodule
