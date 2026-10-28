`timescale 1ns / 1ps
// ============================================================================
// tb_mult.v - both multipliers on every input pair, plus their timing
//
//  1. The course multiplier (seq_mult_lab, N = 3) on all 64 pairs, including
//     the three cases in the Lab 10 sample waveform.
//  2. Both multipliers with N = 4 on all 256 pairs. The expected product is
//     computed with *, independently of the shift-and-add hardware.
//  3. The clocks from start to done are measured for every pair. The course
//     version's time depends on how many 1 bits the multiplier has; the
//     constant-time version must take the same time for every pair.
// Uses tasks for the repeated stimulus (PLD Lab 6).
// ============================================================================
module tb_mult;
    reg clk = 1'b0, rst = 1'b1;
    always #5 clk = ~clk;

    reg  [2:0] a3, b3;   reg st3 = 1'b0;   wire [5:0] p3;  wire d3;
    reg  [3:0] a4, b4;   reg stl = 1'b0, stc = 1'b0;
    wire [7:0] pl, pc;   wire dl, dc;

    seq_mult_lab #(.N(3)) LAB3 (.clk(clk), .rst(rst), .st(st3), .mcand(a3), .mplier(b3), .product(p3), .done(d3));
    seq_mult_lab #(.N(4)) LAB4 (.clk(clk), .rst(rst), .st(stl), .mcand(a4), .mplier(b4), .product(pl), .done(dl));
    seq_mult     #(.N(4)) CT4  (.clk(clk), .rst(rst), .st(stc), .mcand(a4), .mplier(b4), .product(pc), .done(dc));

    integer errors = 0, checks = 0, cycles, i, j, ones;
    integer lab_min [0:4], lab_max [0:4];        // clocks, by number of 1s in the multiplier
    integer ct_min = 999, ct_max = 0;

    // start a multiplier and count the clocks until its done pulse
    task run3(input [2:0] a, input [2:0] b, output integer n);
        begin
            a3 = a; b3 = b; n = 0;
            @(negedge clk) st3 = 1'b1;
            @(negedge clk) st3 = 1'b0; n = 1;
            while (!d3) begin @(negedge clk); n = n + 1; end
            @(negedge clk);                           // back to idle
        end
    endtask

    task run4(input [3:0] a, input [3:0] b, input which, output integer n);   // which: 0 lab, 1 constant-time
        begin
            a4 = a; b4 = b; n = 0;
            @(negedge clk) if (which) stc = 1'b1; else stl = 1'b1;
            @(negedge clk) begin stc = 1'b0; stl = 1'b0; end
            n = 1;
            while (!(which ? dc : dl)) begin @(negedge clk); n = n + 1; end
            @(negedge clk);
        end
    endtask

    task check(input [7:0] got, input [7:0] want, input [8*12-1:0] who);
        begin
            checks = checks + 1;
            if (got !== want) begin
                errors = errors + 1;
                if (errors <= 10) $display("ERROR %0s: %0d x %0d gave %0d, expected %0d", who, a4, b4, got, want);
            end
        end
    endtask

    initial begin
        for (i = 0; i <= 4; i = i + 1) begin lab_min[i] = 999; lab_max[i] = 0; end
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // 1. N = 3, the Lab 10 sample waveform first
        run3(3'b111, 3'b101, cycles); checks = checks + 1; if (p3 !== 6'b100011) errors = errors + 1;
        run3(3'b100, 3'b001, cycles); checks = checks + 1; if (p3 !== 6'b000100) errors = errors + 1;
        run3(3'b111, 3'b100, cycles); checks = checks + 1; if (p3 !== 6'b011100) errors = errors + 1;
        $display("Lab 10 sample: 111 x 101 = 100011, 100 x 001 = 000100, 111 x 100 = 011100 checked");
        for (i = 0; i < 8; i = i + 1)
            for (j = 0; j < 8; j = j + 1) begin
                run3(i, j, cycles);
                checks = checks + 1;
                if (p3 !== i * j) begin
                    errors = errors + 1;
                    if (errors <= 10) $display("ERROR lab N=3: %0d x %0d gave %0d", i, j, p3);
                end
            end

        // 2. and 3. N = 4, both versions, all 256 pairs, with timing
        for (i = 0; i < 16; i = i + 1)
            for (j = 0; j < 16; j = j + 1) begin
                ones = j[0] + j[1] + j[2] + j[3];
                run4(i, j, 1'b0, cycles);
                check(pl, i * j, "course");
                if (cycles < lab_min[ones]) lab_min[ones] = cycles;
                if (cycles > lab_max[ones]) lab_max[ones] = cycles;
                run4(i, j, 1'b1, cycles);
                check(pc, i * j, "const-time");
                if (cycles < ct_min) ct_min = cycles;
                if (cycles > ct_max) ct_max = cycles;
            end

        $display("course multiplier, N = 4: clocks from start to done");
        for (i = 0; i <= 4; i = i + 1)
            $display("  multiplier with %0d one-bits: %0d to %0d clocks", i, lab_min[i], lab_max[i]);
        $display("constant-time multiplier, N = 4: %0d to %0d clocks for every pair", ct_min, ct_max);
        if (ct_min != ct_max) begin
            errors = errors + 1;
            $display("ERROR: the constant-time multiplier's timing depends on the data");
        end

        $display("tb_mult: %0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
