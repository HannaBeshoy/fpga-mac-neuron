`timescale 1ns / 1ps
// ============================================================================
// neuron_signed.v - the neuron with signed weights (two's complement)
//
// y = w0*x0 + w1*x1 + w2*x2 + w3*x3 with weights -8 .. 7 and inputs 0 .. 15,
// so an input can also inhibit the neuron. fire = (y >= threshold), signed.
// Same ASM chart and the same 25 clocks per run as neuron.v; only the
// datapath changes: a signed multiplier, a signed accumulator (the sum lies
// in -480 .. 420, which fits 10 bits) and a signed comparison.
// Simulated only; the board design (neuron_top.v) still uses neuron.v.
// ============================================================================
module neuron_signed (
    input            clk, rst,
    input            start,          // one-clock pulse
    input      [15:0] x,             // {x3, x2, x1, x0}, 4 bits each
    input      [15:0] w,             // {w3, w2, w1, w0}, each two's complement (-8 .. 7)
    input  signed [9:0] th,          // threshold, two's complement
    output reg signed [9:0] y,       // last result (-480 .. 420)
    output reg        fire,          // y >= threshold
    output            busy,
    output            done           // one clock when y and fire are new
);
    localparam IDLE = 2'd0, MSTART = 2'd1, MWAIT = 2'd2, DONE = 2'd3;

    reg  [1:0]  state, nextstate;
    reg  [15:0] xr, wr;
    reg  signed [9:0] thr, acc;
    reg  [1:0]  i;
    reg         snap, clr, add, inc;        // Mealy (conditional) outputs
    wire        mst  = (state == MSTART);   // Moore outputs
    wire        ld_y = (state == DONE);
    wire        mdone;
    wire signed [8:0] product;

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
    wire signed [3:0] wi = wr[4*i +: 4];
    wire [3:0] xi = xr[4*i +: 4];

    seq_mult_signed #(.N(4)) U_mult (.clk(clk), .rst(rst), .st(mst),
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
