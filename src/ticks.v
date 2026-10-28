`timescale 1ns / 1ps
// ============================================================================
// ticks.v - free-running counter that makes enable ticks (no derived clocks)
//
// At the 50 MHz system clock, with the default parameters:
//   scan        q[18:16]: the display moves to the next digit every 1.31 ms
//   sample_tick one clock every 2^19 clocks = 10.5 ms (buttons, new run)
//   heartbeat   q[25], about 0.75 Hz, blinks LED14
// The PLD Lab 8 pulse generator does the same job with a compare (== N-1);
// here the period is a power of two, so the tick is "low bits all zero".
// ============================================================================
module ticks #(
    parameter SCAN_BIT    = 16,
    parameter SAMPLE_BITS = 19
)(
    input        clk, rst,
    output [2:0] scan,
    output       sample_tick,
    output       heartbeat
);
    reg [25:0] q;

    always @(posedge clk)
        if (rst) q <= 26'd0;
        else     q <= q + 1'b1;

    assign scan        = q[SCAN_BIT+2:SCAN_BIT];
    assign sample_tick = (q[SAMPLE_BITS-1:0] == 0);
    assign heartbeat   = q[25];
endmodule
