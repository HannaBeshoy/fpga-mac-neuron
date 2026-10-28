`timescale 1ns / 1ps
// ============================================================================
// display8.v - scans the 8-digit 7-segment display (from the Digital Design
// project's display_mux.v): a 3-to-8 decoder with one-cold outputs drives
// the anodes, an 8-to-1 multiplexer picks the digit value, hex7seg draws it.
// Field layout K.TTT.YYYY: weight set, threshold, neuron output y.
// The decimal points after digit 7 and digit 4 separate the fields.
// ============================================================================
module display8 (
    input      [2:0]  scan,             // active digit
    input      [31:0] digits,           // {d7, d6, ..., d0}, 4 bits each
    output reg [7:0]  an,               // anodes, active low
    output     [6:0]  a_to_g,           // segments, active low
    output            dp                // decimal point, active low
);
    always @(*) begin
        an = 8'hFF;
        an[scan] = 1'b0;                // one-cold: only the active digit is low
    end

    wire [3:0] value = digits[4*scan +: 4];

    hex7seg U_seg (.x(value), .a_to_g(a_to_g));

    assign dp = ~((scan == 3'd7) | (scan == 3'd4));
endmodule
