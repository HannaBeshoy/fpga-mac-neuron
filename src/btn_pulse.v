`timescale 1ns / 1ps
// ============================================================================
// btn_pulse.v - push-button conditioning: one clean pulse per press
//
// A mechanical button bounces for a few milliseconds and is not synchronized
// to the clock. Three small steps, all built from D flip-flops (Lab 7):
//   1. two flip-flops in a row synchronize the button to clk
//   2. the synchronized level is sampled only on sample_tick (~10 ms apart),
//      so the bounce is never seen as two presses
//   3. a flip-flop holding the previous level plus an AND gate turn the
//      rising edge into a pulse that is exactly one clock long
// level is the debounced button state (used for STOP, which acts while held).
// ============================================================================
module btn_pulse (
    input      clk, rst,
    input      sample_tick,   // ~95 Hz enable from clkdiv
    input      btn,           // raw push-button, 1 = pressed
    output reg level,         // debounced level
    output     pulse          // high for one clock on each press
);
    reg sync0, sync1, level_d;

    // 1. synchronizer
    always @(posedge clk) begin
        sync0 <= btn;
        sync1 <= sync0;
    end

    // 2. slow sampling = debouncing
    always @(posedge clk)
        if (rst)              level <= 1'b0;
        else if (sample_tick) level <= sync1;

    // 3. rising-edge detector
    always @(posedge clk)
        if (rst) level_d <= 1'b0;
        else     level_d <= level;

    assign pulse = level & ~level_d;
endmodule
