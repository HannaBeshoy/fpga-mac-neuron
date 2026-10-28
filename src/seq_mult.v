`timescale 1ns / 1ps
// ============================================================================
// seq_mult.v - constant-time shift-and-add multiplier (N x N -> 2N bits)
//
// Same datapath as the course multiplier (seq_mult_lab.v), but the add and
// the shift happen in the same clock: the adder adds the multiplicand when
// M = 1 and adds 0 when M = 0, and the result is shifted right at once.
// Every multiplication therefore takes the same time, whatever the operands
// (tb_mult measures 5 clocks from start to done for N = 4). The course
// version takes 5 clocks plus one per 1 bit in the multiplier, so its timing
// leaks information about the data.
//
// SM chart (3 states):
//   IDLE  st -> load, go to RUN
//   RUN   add-and-shift every clock; after the N-th, go to DONE
//   DONE  done = 1 for one clock, go to IDLE
// ============================================================================
module seq_mult #(parameter N = 4) (
    input              clk, rst,
    input              st,                 // start
    input      [N-1:0] mcand, mplier,      // multiplicand, multiplier
    output     [2*N-1:0] product,
    output             done                // one clock, product is valid
);
    localparam IDLE = 2'd0, RUN = 2'd1, DONE = 2'd2;

    reg [2*N:0] acc;                       // carry | upper N | multiplier
    reg [1:0]   state;
    reg [$clog2(N)-1:0] cnt;

    wire         m   = acc[0];
    wire         k   = (cnt == N - 1);
    wire [N:0]   sum = acc[2*N-1:N] + (m ? mcand : {N{1'b0}});   // add or add 0

    always @(posedge clk)
        if (rst) begin
            state <= IDLE;
            acc   <= 0;
            cnt   <= 0;
        end
        else
            case (state)
                IDLE: if (st) begin
                          acc   <= {{(N+1){1'b0}}, mplier};   // load
                          cnt   <= 0;
                          state <= RUN;
                      end
                RUN:  begin
                          acc   <= {1'b0, sum, acc[N-1:1]};   // add and shift
                          cnt   <= cnt + 1'b1;
                          if (k) state <= DONE;
                      end
                default: state <= IDLE;                       // DONE
            endcase

    assign done    = (state == DONE);
    assign product = acc[2*N-1:0];
endmodule
