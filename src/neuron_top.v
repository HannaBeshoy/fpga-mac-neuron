`timescale 1ns / 1ps
// ============================================================================
// neuron_top.v - MAC neuron accelerator on the Digilent Nexys 4 DDR
// (Artix-7 XC7A100T), Programmable Logic Devices course project, Vivado.
//
// One artificial neuron:  y = w0*x0 + w1*x1 + w2*x2 + w3*x3,  fire = y >= T
//   inputs  x0..x3   4 bits each, from the switches
//   weights w0..w3   4 bits each, and threshold T, from a ROM of 8 weight sets
// A new result is computed every 10.5 ms, so the display follows the switches.
//
// Board I/O
//   SW3..SW0 = x0   SW7..SW4 = x1   SW11..SW8 = x2   SW15..SW12 = x3
//   BTNU next weight set   BTND previous weight set   CPU RESET reset
//   Display  K.TTT.YYYY   K = weight set, TTT = threshold, YYYY = y
//   LED0 fire   LED3..LED1 weight set   LED13..LED4 y in binary
//   LED14 heartbeat   LED15 clock locked (Clocking Wizard)
// ============================================================================
module neuron_top #(
    parameter SCAN_BIT    = 16,           // simulation makes these small
    parameter SAMPLE_BITS = 19,
    parameter MEMFILE     = "weights.mem"
)(
    input         clk,                    // 100 MHz oscillator
    input         cpu_resetn,             // CPU RESET button, active low
    input         btnu, btnd,
    input  [15:0] sw,
    output [15:0] led,
    output [6:0]  a_to_g,
    output [7:0]  an,
    output        dp
);
    // ------------------------------------------------ clock and reset
    wire sysclk, locked;
    clk_gen U_clk (.clk_in(clk), .reset(~cpu_resetn), .clk_out(sysclk), .locked(locked));

    reg rst_s0, rst;                      // reset synchronizer, held until locked
    always @(posedge sysclk) begin
        rst_s0 <= ~cpu_resetn | ~locked;
        rst    <= rst_s0;
    end

    // --------------------------------------------------------- ticks
    wire [2:0] scan;
    wire       sample_tick, heartbeat;
    ticks #(.SCAN_BIT(SCAN_BIT), .SAMPLE_BITS(SAMPLE_BITS))
        U_ticks (.clk(sysclk), .rst(rst), .scan(scan),
                 .sample_tick(sample_tick), .heartbeat(heartbeat));

    // ------------------------------------------------ inputs: switches, buttons
    reg [15:0] sw_s0, x;                  // 2-flip-flop synchronizer
    always @(posedge sysclk) begin
        sw_s0 <= sw;
        x     <= sw_s0;
    end

    wire up_p, down_p;
    btn_pulse U_up   (.clk(sysclk), .rst(rst), .sample_tick(sample_tick),
                      .btn(btnu), .level(), .pulse(up_p));
    btn_pulse U_down (.clk(sysclk), .rst(rst), .sample_tick(sample_tick),
                      .btn(btnd), .level(), .pulse(down_p));

    reg [2:0] sel;                        // weight set, wraps 7 <-> 0
    always @(posedge sysclk)
        if (rst)         sel <= 3'd0;
        else if (up_p)   sel <= sel + 1'b1;
        else if (down_p) sel <= sel - 1'b1;

    // ---------------------------------------------- weight ROM and neuron
    wire [15:0] w;
    wire [9:0]  th, y;
    wire        fire, busy, done;

    weight_rom #(.MEMFILE(MEMFILE)) U_rom (.addr(sel), .w(w), .th(th));

    neuron U_neuron (.clk(sysclk), .rst(rst), .start(sample_tick & ~busy),
                     .x(x), .w(w), .th(th),
                     .y(y), .fire(fire), .busy(busy), .done(done));

    // -------------------------------------------------------- display
    wire [15:0] y_bcd, th_bcd;
    bin2bcd U_ybcd  (.bin(y),  .bcd(y_bcd));
    bin2bcd U_thbcd (.bin(th), .bcd(th_bcd));

    display8 U_disp (.scan(scan),
                     .digits({1'b0, sel, th_bcd[11:0], y_bcd}),
                     .an(an), .a_to_g(a_to_g), .dp(dp));

    // ----------------------------------------------------------- LEDs
    assign led[0]    = fire;
    assign led[3:1]  = sel;
    assign led[13:4] = y;
    assign led[14]   = heartbeat;
    assign led[15]   = locked;
endmodule
