`timescale 1ns / 1ps
// ============================================================================
// neuron.v - one artificial neuron: y = w0*x0 + w1*x1 + w2*x2 + w3*x3,
// fire = (y >= threshold). Controller + datapath, designed with an ASM chart
// (PLD Lecture 9, Lab 10). See docs/asm_chart.svg.
//
// Datapath
//   xr, wr, thr   input, weight and threshold registers (a snapshot at start,
//                 so moving a switch mid-calculation cannot mix two inputs)
//   i             index of the product being computed (0..3)
//   2 multiplexers choose w[i] and x[i] for the multiplier
//   seq_mult      constant-time 4 x 4 shift-and-add multiplier (8-bit product)
//   acc           10-bit accumulator (largest sum 4 x 15 x 15 = 900)
//   y, fire       result registers, updated in DONE
//
// ASM chart (Moore outputs in the state boxes, Mealy outputs in the
// conditional output boxes):
//   IDLE   / idle          start ?  -> snap, clr  -> MSTART
//   MSTART / mst                                 -> MWAIT
//   MWAIT                  mdone ?  -> add ; last ? -> DONE
//                                              : inc  -> MSTART
//   DONE   / ld_y                                -> IDLE
// Every run takes the same number of clocks (tb_neuron measures 25 from start
// to done), whatever the inputs and weights, because seq_mult is constant-time.
// ============================================================================
module neuron (
    input            clk, rst,
    input            start,          // one-clock pulse
    input      [15:0] x,             // {x3, x2, x1, x0}, 4 bits each
    input      [15:0] w,             // {w3, w2, w1, w0}, from the weight ROM
    input      [9:0]  th,            // threshold, from the weight ROM
    output reg [9:0]  y,             // last result
    output reg        fire,          // y >= threshold
    output            busy,
    output            done           // one clock when y and fire are new
);
    localparam IDLE = 2'd0, MSTART = 2'd1, MWAIT = 2'd2, DONE = 2'd3;

    reg  [1:0]  state, nextstate;
    reg  [15:0] xr, wr;
    reg  [9:0]  thr, acc;
    reg  [1:0]  i;
    reg         snap, clr, add, inc;        // Mealy (conditional) outputs
    wire        mst  = (state == MSTART);   // Moore outputs
    wire        ld_y = (state == DONE);
    wire        mdone;
    wire [7:0]  product;

    // ---------------------------------------------------- controller (ASM)
    always @(*) begin
        snap = 1'b0; clr = 1'b0; add = 1'b0; inc = 1'b0;
        nextstate = state;
        case (state)
            IDLE:   if (start) begin
                        snap = 1'b1; clr = 1'b1;
                        nextstate = MSTART;
                    end
            MSTART: nextstate = MWAIT;
            MWAIT:  if (mdone) begin
                        add = 1'b1;
                        if (i == 2'd3) nextstate = DONE;
                        else begin
                            inc = 1'b1;
                            nextstate = MSTART;
                        end
                    end
            DONE:   nextstate = IDLE;
        endcase
    end

    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= nextstate;

    assign busy = (state != IDLE);
    assign done = ld_y;

    // ----------------------------------------------------------- datapath
    // multiplexers: the i-th weight and input (4 bits each)
    wire [3:0] wi = wr[4*i +: 4];
    wire [3:0] xi = xr[4*i +: 4];

    seq_mult #(.N(4)) U_mult (.clk(clk), .rst(rst), .st(mst),
                              .mcand(wi), .mplier(xi),
                              .product(product), .done(mdone));

    always @(posedge clk)
        if (rst) begin
            xr <= 0; wr <= 0; thr <= 0; acc <= 0; i <= 0;
            y  <= 0; fire <= 1'b0;
        end
        else begin
            if (snap) begin xr <= x; wr <= w; thr <= th; end
            if (clr)       acc <= 0;
            else if (add)  acc <= acc + product;
            if (clr)       i <= 0;
            else if (inc)  i <= i + 1'b1;
            if (ld_y) begin
                y    <= acc;
                fire <= (acc >= thr);
            end
        end
endmodule
