`timescale 1ns / 1ps
// ============================================================================
// bin2bcd.v - 10-bit binary -> 4 BCD digits, "double dabble" (shift and add 3)
// PLD Labs 6 and 7: a function with a for loop, written behaviorally.
//
// The binary number is shifted in one bit at a time, MSB first. Before each
// shift, every BCD digit that is 5 or more gets 3 added, so that the shift
// (a multiplication by 2) carries correctly into the next decimal digit.
// The loop is unrolled by synthesis into 10 rows of small adders: it is
// combinational logic, no clock involved.
// ============================================================================
module bin2bcd (
    input  [9:0]  bin,           // 0..1023
    output [15:0] bcd            // {thousands, hundreds, tens, ones}
);
    function [15:0] dabble;
        input [9:0] b;
        integer i;
        reg [25:0] s;            // {bcd[15:0], binary[9:0]}
        begin
            s = {16'd0, b};
            for (i = 0; i < 10; i = i + 1) begin
                if (s[13:10] >= 5) s[13:10] = s[13:10] + 4'd3;
                if (s[17:14] >= 5) s[17:14] = s[17:14] + 4'd3;
                if (s[21:18] >= 5) s[21:18] = s[21:18] + 4'd3;
                if (s[25:22] >= 5) s[25:22] = s[25:22] + 4'd3;
                s = s << 1;
            end
            dabble = s[25:10];
        end
    endfunction

    assign bcd = dabble(bin);
endmodule
