`timescale 1ns / 1ps
// ============================================================================
// hex7seg.v - hexadecimal to 7-segment decoder
// Digital Design Lab 3_3 (unchanged). Lecture: BCD-to-7-segment decoder.
//
// The Nexys 4 DDR segments are active LOW: 0 lights a segment.
// a_to_g[6] = segment a, a_to_g[5] = b, ... a_to_g[0] = segment g
// ============================================================================
module hex7seg (
    input      [3:0] x,
    output reg [6:0] a_to_g
);
    always @(*)
        case (x)
            4'h0: a_to_g = 7'b0000001;
            4'h1: a_to_g = 7'b1001111;
            4'h2: a_to_g = 7'b0010010;
            4'h3: a_to_g = 7'b0000110;
            4'h4: a_to_g = 7'b1001100;
            4'h5: a_to_g = 7'b0100100;
            4'h6: a_to_g = 7'b0100000;
            4'h7: a_to_g = 7'b0001111;
            4'h8: a_to_g = 7'b0000000;
            4'h9: a_to_g = 7'b0000100;
            4'hA: a_to_g = 7'b0001000;
            4'hB: a_to_g = 7'b1100000;
            4'hC: a_to_g = 7'b0110001;
            4'hD: a_to_g = 7'b1000010;
            4'hE: a_to_g = 7'b0110000;
            4'hF: a_to_g = 7'b0111000;
            default: a_to_g = 7'b0000001;
        endcase
endmodule
