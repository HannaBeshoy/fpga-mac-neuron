`timescale 1ns / 1ps
// ============================================================================
// weight_rom.v - the neuron's weights and threshold, 8 sets (PLD Lab 5 ROM)
//
// Each 26-bit word is { threshold[9:0], w3[3:0], w2[3:0], w1[3:0], w0[3:0] }.
// The contents come from a text file read with $readmemb, so the weights can
// be changed without touching the Verilog. Asynchronous read: synthesis
// builds it from LUTs (distributed ROM).
// ============================================================================
module weight_rom #(parameter MEMFILE = "weights.mem") (
    input  [2:0]  addr,          // weight set 0..7
    output [15:0] w,             // {w3, w2, w1, w0}
    output [9:0]  th             // threshold
);
    reg [25:0] rom [0:7];

    initial $readmemb(MEMFILE, rom);

    assign {th, w} = rom[addr];
endmodule
