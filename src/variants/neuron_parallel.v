`timescale 1ns / 1ps
// ============================================================================
// neuron_parallel.v - the same neuron with hardware multipliers
//
// Four `*` operators compute the four products at once and an adder tree sums
// them: one clock per neuron instead of 25. This is the "area for speed"
// trade of PLD Lecture 4. Whether a `*` becomes a DSP48E1 block or LUTs is the
// synthesis tool's choice and depends on the operand width W: see the
// resource table in the README (results/resources.md).
// Signed weights, unsigned inputs, like neuron_signed.v.
// ============================================================================
module neuron_parallel #(parameter W = 4) (
    input                         clk, rst,
    input                         start,
    input      [4*W-1:0]          x,      // 4 unsigned inputs
    input      [4*W-1:0]          w,      // 4 signed weights
    input  signed [2*W+2:0]       th,
    output reg signed [2*W+2:0]   y,      // 2W+1 bits per product, +2 for the sum
    output reg                    fire,
    output reg                    done
);
    wire signed [2*W:0] p0, p1, p2, p3;
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : G_mul
            wire signed [W-1:0] wg = w[W*g +: W];
            wire signed [W:0]   xg = {1'b0, x[W*g +: W]};   // unsigned -> signed
            wire signed [2*W:0] pg = wg * xg;
        end
    endgenerate
    assign p0 = G_mul[0].pg;
    assign p1 = G_mul[1].pg;
    assign p2 = G_mul[2].pg;
    assign p3 = G_mul[3].pg;

    wire signed [2*W+2:0] sum = (p0 + p1) + (p2 + p3);     // adder tree

    always @(posedge clk)
        if (rst) begin
            y <= 0; fire <= 1'b0; done <= 1'b0;
        end
        else begin
            done <= start;
            if (start) begin
                y    <= sum;
                fire <= (sum >= th);
            end
        end
endmodule
