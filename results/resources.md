# Resources after synthesis

Yosys `synth_xilinx -family xc7` (Artix-7), cell counts from `stat`. Written by `tools/resources.py`.

| Design | LUTs | Flip-flops | CARRY4 | DSP48E1 | Block RAM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Course multiplier (data-dependent time) | 23 | 15 | 2 | 0 | 0 |
| Constant-time multiplier | 21 | 13 | 2 | 0 | 0 |
| Neuron, unsigned, sequential (on the board) | 82 | 80 | 6 | 0 | 0 |
| Neuron, signed weights, sequential | 64 | 81 | 10 | 0 | 0 |
| Neuron, signed, 4 parallel multipliers, 4-bit | 18 | 13 | 4 | 4 | 0 |
| Neuron, signed, 4 parallel multipliers, 16-bit | 58 | 37 | 12 | 4 | 0 |
| Weight ROM, 8 words, asynchronous read | 16 | 0 | 0 | 0 | 0 |
| Weight ROM, 8 words, synchronous read | 13 | 16 | 0 | 0 | 0 |
| Weight ROM, 1024 words, synchronous read | 0 | 0 | 0 | 0 | 1 |
