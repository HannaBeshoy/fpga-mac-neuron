`timescale 1ns / 1ps
// ============================================================================
// tb_top.v - the whole board design, used like a person would use it
//
// The tick periods are made small with parameters (a digit per clock, a new
// run every 64 clocks) so the test is quick. The testbench sets switches,
// presses buttons (with bounce), and reads the results the way you would on
// the board: from the LEDs and by decoding the 7-segment display while it
// scans. Expected values come from its own copy of weights.mem.
// ============================================================================
module tb_top;
    reg         clk = 1'b0, cpu_resetn = 1'b0, btnu = 1'b0, btnd = 1'b0;
    reg  [15:0] sw = 16'd0;
    wire [15:0] led;
    wire [6:0]  a_to_g;
    wire [7:0]  an;
    wire        dp;

    neuron_top #(.SCAN_BIT(0), .SAMPLE_BITS(6), .MEMFILE("weights.mem")) DUT (
        .clk(clk), .cpu_resetn(cpu_resetn), .btnu(btnu), .btnd(btnd),
        .sw(sw), .led(led), .a_to_g(a_to_g), .an(an), .dp(dp));

    always #5 clk = ~clk;

    reg [25:0] model [0:7];
    integer errors = 0, checks = 0, k;

    function [3:0] seg2hex;                   // read a digit back from its segments
        input [6:0] s;
        case (s)
            7'b0000001: seg2hex = 4'h0;  7'b1001111: seg2hex = 4'h1;
            7'b0010010: seg2hex = 4'h2;  7'b0000110: seg2hex = 4'h3;
            7'b1001100: seg2hex = 4'h4;  7'b0100100: seg2hex = 4'h5;
            7'b0100000: seg2hex = 4'h6;  7'b0001111: seg2hex = 4'h7;
            7'b0000000: seg2hex = 4'h8;  7'b0000100: seg2hex = 4'h9;
            default:    seg2hex = 4'hF;
        endcase
    endfunction

    function [9:0] dot;
        input [15:0] wv, xv;
        integer j;
        begin
            dot = 0;
            for (j = 0; j < 4; j = j + 1) dot = dot + wv[4*j +: 4] * xv[4*j +: 4];
        end
    endfunction

    // press a button with a little bounce, hold it, release it
    task press(input up);
        integer b;
        begin
            for (b = 0; b < 6; b = b + 1) begin
                if (up) btnu = ~btnu; else btnd = ~btnd;
                repeat (3) @(posedge clk);
            end
            if (up) btnu = 1'b1; else btnd = 1'b1;
            repeat (400) @(posedge clk);
            if (up) btnu = 1'b0; else btnd = 1'b0;
            repeat (400) @(posedge clk);
        end
    endtask

    // read all 8 digits and both decimal points while the display scans
    task read_display(output [31:0] digits, output [7:0] points);
        integer n, d;
        begin
            for (n = 0; n < 16; n = n + 1) begin
                @(negedge clk);
                for (d = 0; d < 8; d = d + 1)
                    if (an == ~(8'd1 << d)) begin
                        digits[4*d +: 4] = seg2hex(a_to_g);
                        points[d] = ~dp;
                    end
            end
        end
    endtask

    // compare the board with the model for the current switches and set
    task check_board(input [2:0] set, input [8*24-1:0] what);
        reg [9:0]  y, th;
        reg        f;
        reg [31:0] shown, want_digits;
        reg [7:0]  pts;
        begin
            repeat (300) @(posedge clk);                    // a few runs
            y  = dot(model[set][15:0], sw);
            th = model[set][25:16];
            f  = (y >= th);
            want_digits = 0;
            want_digits[31:28] = set;
            want_digits[27:24] = (th / 100) % 10;
            want_digits[23:20] = (th / 10) % 10;
            want_digits[19:16] = th % 10;
            want_digits[15:12] = (y / 1000) % 10;
            want_digits[11:8]  = (y / 100) % 10;
            want_digits[7:4]   = (y / 10) % 10;
            want_digits[3:0]   = y % 10;
            read_display(shown, pts);
            checks = checks + 1;
            if (led[13:4] !== y || led[0] !== f || led[3:1] !== set ||
                shown !== want_digits || pts !== 8'b1001_0000) begin
                errors = errors + 1;
                $display("ERROR %0s: LEDs y=%0d fire=%b set=%0d, display %h, expected y=%0d fire=%b set=%0d display %h",
                         what, led[13:4], led[0], led[3:1], shown, y, f, set, want_digits);
            end
            else
                $display("ok  %0s: display %0d.%0d%0d%0d.%0d%0d%0d%0d  fire=%b", what,
                         shown[31:28], shown[27:24], shown[23:20], shown[19:16],
                         shown[15:12], shown[11:8], shown[7:4], shown[3:0], led[0]);
        end
    endtask

    initial begin
        $readmemb("weights.mem", model);
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);
        sw = 16'hF00F;                                     // x3 = 15, x0 = 15
        repeat (20) @(posedge clk);
        cpu_resetn = 1'b1;
        repeat (20) @(posedge clk);
        checks = checks + 1;
        if (!led[15]) begin errors = errors + 1; $display("ERROR: clock not locked"); end

        check_board(3'd0, "set 0, x3=x0=15");           // y = 30 = threshold: fires
        press(1'b1);
        check_board(3'd1, "BTNU: set 1");               // 8*15 + 1*15 = 135
        sw = 16'h0000;
        check_board(3'd1, "switches all 0");
        press(1'b0); press(1'b0);
        check_board(3'd7, "BTND twice: set 7 (wrap)");
        sw = 16'hFFFF;
        check_board(3'd7, "set 7, all 15: dead");
        press(1'b1);
        check_board(3'd0, "BTNU: back to set 0");
        for (k = 1; k < 7; k = k + 1) begin              // every other set, random inputs
            press(1'b1);
            sw = $random;
            check_board(k, "next set, random x");
        end

        $display("tb_top: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
