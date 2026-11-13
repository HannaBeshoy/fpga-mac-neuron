`timescale 1ns / 1ps
// ============================================================================
// tb_vectors.v - self-checking testbench with test-vector files (PLD Lecture 6)
//
// Reads sim/vectors_unsigned.tv and sim/vectors_signed.tv (written by
// tools/gen_vectors.py, which computes the expected results on its own) and
// applies every vector to three implementations:
//   neuron           unsigned, sequential (the board design)
//   neuron_signed    signed weights, sequential, constant-time
//   neuron_parallel  signed weights, four multipliers, one clock
// It also checks that the two sequential neurons always take 25 clocks.
// ============================================================================
module tb_vectors;
    localparam NV = 1000;
    reg clk = 0, rst = 1;
    always #5 clk = ~clk;

    reg  [55:0] vu [0:NV-1];
    reg  [55:0] vs [0:NV-1];

    reg         start_u = 0, start_s = 0, start_p = 0;
    reg  [15:0] x, w;
    reg  [9:0]  th;
    wire [9:0]  y_u, y_s;
    wire        fire_u, fire_s, done_u, done_s, fire_p, done_p;
    wire signed [10:0] y_p;

    neuron          U_u (.clk(clk), .rst(rst), .start(start_u), .x(x), .w(w), .th(th),
                         .y(y_u), .fire(fire_u), .busy(), .done(done_u));
    neuron_signed   U_s (.clk(clk), .rst(rst), .start(start_s), .x(x), .w(w), .th(th),
                         .y(y_s), .fire(fire_s), .busy(), .done(done_s));
    neuron_parallel #(.W(4)) U_p (.clk(clk), .rst(rst), .start(start_p), .x(x), .w(w),
                         .th({th[9], th}), .y(y_p), .fire(fire_p), .done(done_p));

    integer i, errors = 0, checks = 0, clocks;

    task run_seq(input is_signed);
        begin
            @(negedge clk);
            if (is_signed) start_s = 1; else start_u = 1;
            @(negedge clk);
            start_s = 0; start_u = 0;
            clocks = 1;
            while (!(is_signed ? done_s : done_u)) begin @(negedge clk); clocks = clocks + 1; end
            @(negedge clk);
        end
    endtask

    task check(input [9:0] got_y, input got_fire, input [9:0] exp_y, input exp_fire, input [8*8:1] who);
        begin
            checks = checks + 1;
            if (got_y !== exp_y || got_fire !== exp_fire) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL %0s vector %0d: x=%h w=%h th=%h  y=%h fire=%b, expected y=%h fire=%b",
                             who, i, x, w, th, got_y, got_fire, exp_y, exp_fire);
            end
        end
    endtask

    initial begin
        $readmemh("vectors_unsigned.tv", vu);
        $readmemh("vectors_signed.tv", vs);
        repeat (3) @(negedge clk);
        rst = 0;

        for (i = 0; i < NV; i = i + 1) begin             // unsigned neuron
            {th, w, x} = vu[i][41:0];
            run_seq(1'b0);
            check(y_u, fire_u, vu[i][51:42], vu[i][52], "unsigned");
            if (clocks !== 25) begin errors = errors + 1; $display("FAIL unsigned vector %0d took %0d clocks", i, clocks); end
        end

        for (i = 0; i < NV; i = i + 1) begin             // signed neurons
            {th, w, x} = vs[i][41:0];
            run_seq(1'b1);
            check(y_s, fire_s, vs[i][51:42], vs[i][52], "signed");
            if (clocks !== 25) begin errors = errors + 1; $display("FAIL signed vector %0d took %0d clocks", i, clocks); end
            @(negedge clk); start_p = 1;
            @(negedge clk); start_p = 0;
            check(y_p[9:0], fire_p, vs[i][51:42], vs[i][52], "parallel");
        end

        if (errors == 0) $display("PASS: %0d checks on %0d vectors (unsigned, signed, parallel); every sequential run took 25 clocks", checks, 2 * NV);
        else             $display("FAILED: %0d errors in %0d checks", errors, checks);
        $finish;
    end
endmodule
