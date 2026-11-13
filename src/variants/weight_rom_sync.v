`timescale 1ns / 1ps
// ============================================================================
// weight_rom_sync.v - weight ROM with a registered (synchronous) read
//
// A block RAM can only be read on a clock edge, so this is the form a ROM
// must have before synthesis may put it into a RAMB18E1/RAMB36E1 block
// (PLD Lecture 4). With 8 words the tool still builds it from LUTs; with
// DEPTH = 1024 it becomes block RAM: see results/resources.md.
// ============================================================================
module weight_rom_sync #(parameter DEPTH = 8, parameter MEMFILE = "weights.mem") (
    input                          clk,
    input      [$clog2(DEPTH)-1:0] addr,
    output reg [25:0]              data      // { threshold[9:0], w3, w2, w1, w0 }
);
    reg [25:0] rom [0:DEPTH-1];
    initial $readmemb(MEMFILE, rom);
    always @(posedge clk) data <= rom[addr];
endmodule
