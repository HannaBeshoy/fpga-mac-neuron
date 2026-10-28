`timescale 1ns / 1ps
// ============================================================================
// seq_mult_lab.v - shift-and-add multiplier exactly as in the PLD course
// Lecture 9 (SM chart of the binary multiplier) and Lab 10, made N bits wide.
//
// Datapath (Lab 10 figure): a (2N+1)-bit accumulator ACC. Load puts the
// multiplier into the low N bits and clears the rest; Ad adds the
// multiplicand to ACC[2N-1:N] (carry into ACC[2N]); Sh shifts ACC right.
// After N shifts ACC[2N-1:0] holds the product.
//
// Controller (lecture SM chart, states 0..3):
//   0  idle:        St -> Load, go to 1
//   1  test M:      M=1 -> Ad, go to 2;  M=0 -> Sh, go to 3 if K else 1
//   2  shift:       Sh, go to 3 if K else 1
//   3  done:        Done, go to 0
// K = 1 during the last shift. A 1 in the multiplier costs two clocks (add,
// then shift) and a 0 costs one, so the time taken depends on the data.
// seq_mult.v is the constant-time version used in the neuron.
// ============================================================================
module seq_mult_lab #(parameter N = 4) (
    input              clk, rst,
    input              st,                 // start
    input      [N-1:0] mcand, mplier,      // multiplicand, multiplier
    output     [2*N-1:0] product,
    output reg         done                // one clock in state 3
);
    reg [2*N:0] acc;                       // ACC: carry | upper N | multiplier
    reg [1:0]   state, nextstate;
    reg [$clog2(N)-1:0] cnt;               // counts the shifts
    reg         load, sh, ad;

    wire m = acc[0];                       // M: lsb of the multiplier
    wire k = (cnt == N - 1);               // K: this is the last shift

    // controller: combinational part, one if per decision box
    always @(*) begin
        load = 1'b0; sh = 1'b0; ad = 1'b0; done = 1'b0;
        nextstate = state;
        case (state)
            2'd0: if (st) begin load = 1'b1; nextstate = 2'd1; end
            2'd1: if (m) begin
                      ad = 1'b1; nextstate = 2'd2;
                  end
                  else begin
                      sh = 1'b1; nextstate = k ? 2'd3 : 2'd1;
                  end
            2'd2: begin sh = 1'b1; nextstate = k ? 2'd3 : 2'd1; end
            2'd3: begin done = 1'b1; nextstate = 2'd0; end
        endcase
    end

    // state register
    always @(posedge clk)
        if (rst) state <= 2'd0;
        else     state <= nextstate;

    // datapath: accumulator and shift counter
    always @(posedge clk)
        if (rst) begin
            acc <= 0;
            cnt <= 0;
        end
        else if (load) begin
            acc <= {{(N+1){1'b0}}, mplier};
            cnt <= 0;
        end
        else if (ad)
            acc[2*N:N] <= acc[2*N-1:N] + mcand;
        else if (sh) begin
            acc <= acc >> 1;
            cnt <= cnt + 1'b1;
        end

    assign product = acc[2*N-1:0];
endmodule
