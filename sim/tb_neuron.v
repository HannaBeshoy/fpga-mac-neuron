`timescale 1ns / 1ps
// ============================================================================
// tb_neuron.v - the neuron (controller + datapath + weight ROM) against an
// independent reference model
//
// The testbench reads weights.mem itself with $readmemb and computes
// y = w0*x0 + w1*x1 + w2*x2 + w3*x3 with *, so the shift-and-add hardware is
// checked against ordinary arithmetic. For each of the 8 weight sets it runs
// 4 corner cases (all inputs 0, all 15, one input 15, alternating) and 500
// random input vectors, and checks y, fire and the number of clocks.
// ============================================================================
module tb_neuron;
    reg clk = 1'b0, rst = 1'b1;
    always #5 clk = ~clk;

    reg  [2:0]  sel = 3'd0;
    reg  [15:0] x = 16'd0;
    reg         start = 1'b0;
    wire [15:0] w;
    wire [9:0]  th, y;
    wire        fire, busy, done;

    weight_rom #(.MEMFILE("weights.mem")) ROM (.addr(sel), .w(w), .th(th));
    neuron DUT (.clk(clk), .rst(rst), .start(start), .x(x), .w(w), .th(th),
                .y(y), .fire(fire), .busy(busy), .done(done));

    reg [25:0] model [0:7];                   // the reference copy of the ROM
    integer errors = 0, runs = 0, cycles, lat_min = 999, lat_max = 0, k, n;

    function [9:0] dot;                       // reference: plain multiplication
        input [15:0] wv, xv;
        integer j;
        begin
            dot = 0;
            for (j = 0; j < 4; j = j + 1)
                dot = dot + wv[4*j +: 4] * xv[4*j +: 4];
        end
    endfunction

    task run(input [2:0] s, input [15:0] xv);
        reg [9:0] want;
        reg       want_fire;
        begin
            sel = s; x = xv;
            want      = dot(model[s][15:0], xv);
            want_fire = (want >= model[s][25:16]);
            @(negedge clk) start = 1'b1;
            @(negedge clk) start = 1'b0;
            x = ~xv;                          // change the switches mid-run: must not matter
            cycles = 1;
            while (!done) begin @(negedge clk); cycles = cycles + 1; end
            @(negedge clk);                   // y and fire are loaded at this edge
            runs = runs + 1;
            if (cycles < lat_min) lat_min = cycles;
            if (cycles > lat_max) lat_max = cycles;
            if (y !== want || fire !== want_fire) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("ERROR set %0d x=%h: y=%0d fire=%b, expected y=%0d fire=%b",
                             s, xv, y, fire, want, want_fire);
            end
        end
    endtask

    initial begin
        $readmemb("weights.mem", model);
        repeat (2) @(negedge clk);
        rst = 1'b0;
        for (k = 0; k < 8; k = k + 1) begin
            run(k, 16'h0000);
            run(k, 16'hFFFF);
            run(k, 16'h000F);
            run(k, 16'hA5A5);
            for (n = 0; n < 500; n = n + 1)
                run(k, $random);
        end
        $display("set 3, x = FFFF: y = %0d (largest possible, 4 x 15 x 15 = 900)", dot(model[3][15:0], 16'hFFFF));
        $display("tb_neuron: %0d runs over 8 weight sets, %0d errors, %0d to %0d clocks per run",
                 runs, errors, lat_min, lat_max);
        if (lat_min != lat_max) begin
            errors = errors + 1;
            $display("ERROR: the run time depends on the data");
        end
        if (errors == 0) $display("PASS"); else $display("FAIL");
        $finish;
    end
endmodule
