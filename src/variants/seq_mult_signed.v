`timescale 1ns / 1ps
// ============================================================================
// seq_mult_signed.v - signed weight x unsigned input, still constant-time
//
// The weight is a two's-complement number (-8 .. 7 for N = 4), the input is
// unsigned (0 .. 15). The multiplier works on the magnitude of the weight
// with the same constant-time shift-and-add core as seq_mult.v, and the sign
// is put back at the end. The negation is always computed and a multiplexer
// picks the result, so a negative weight takes exactly as many clocks as a
// positive one: the timing still tells nothing about the data.
// ============================================================================
module seq_mult_signed #(parameter N = 4) (
    input                     clk, rst,
    input                     st,
    input  signed [N-1:0]     mcand,      // weight, two's complement
    input         [N-1:0]     mplier,     // input, unsigned
    output signed [2*N:0]     product,    // 2N+1 bits: sign + 2N magnitude
    output                    done
);
    wire           neg = mcand[N-1];
    wire [N-1:0]   mag = neg ? (~mcand + 1'b1) : mcand;   // |-8| = 8 fits in N bits
    wire [2*N-1:0] p;
    reg            neg_r;

    always @(posedge clk)
        if (rst)     neg_r <= 1'b0;
        else if (st) neg_r <= neg;        // remember the sign of this product

    seq_mult #(.N(N)) U_core (.clk(clk), .rst(rst), .st(st),
                              .mcand(mag), .mplier(mplier),
                              .product(p), .done(done));

    wire signed [2*N:0] pos = {1'b0, p};
    assign product = neg_r ? -pos : pos;
endmodule
