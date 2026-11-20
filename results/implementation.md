# Implementation in Vivado

The board design (`neuron_top`: sequential unsigned neuron, Clocking Wizard, display, buttons) was synthesised, placed and routed in **Vivado 2022.2** for the **xc7a100tcsg324-1** (Nexys 4 DDR, speed grade -1) on 20 November 2026. The full reports are in [vivado/](vivado/):

- `neuron_top_timing_summary_routed.rpt`: `report_timing_summary` after routing
- `neuron_top_utilization_placed.rpt`: `report_utilization` after placement

## Timing: met at 50 MHz

| | Value |
| --- | --- |
| System clock | 50 MHz (20 ns), from the Clocking Wizard (MMCM) |
| Worst setup slack (WNS) | **+14.094 ns** |
| Worst hold slack (WHS) | +0.048 ns |
| Failing endpoints (setup / hold / pulse width) | 0 / 0 / 0, of 324 |
| Result | All user specified timing constraints are met |

The slowest path uses 5.9 ns of the 20 ns period (20 − 14.094). At that delay the logic could run at about **169 MHz**, so the 50 MHz clock leaves more than three times the margin. This is an estimate from the slack: to confirm it, the design must be implemented again with a faster clock, because the placer works differently when the target is tighter.

The slowest path runs from the tick counter (`U_ticks/q_reg[9]`) through the "start a new run" tick (`sample_tick`, then `snap`, which fans out to 36 flip-flops) to the synchronous clear of the accumulator (`U_neuron/acc_reg[8]/R`): 5 LUT levels, 1.1 ns of logic and 4.0 ns of routing. Routing dominates (78%), as usual on an FPGA. The multiplier and the accumulator adder are not the limit.

## Resources after placement

| Resource | Used | Available | Yosys estimate (whole board design) |
| --- | ---: | ---: | --- |
| Slice LUTs | 100 | 63,400 (0.16%) | |
| Flip-flops | 153 | 126,800 (0.12%) | 150 |
| Latches | 0 | | 0 |
| CARRY4 | 12 | | |
| DSP48E1 | 0 | 240 | |
| Block RAM | 0 | 135 | |
| MMCM (Clocking Wizard) | 1 | 6 | |
| Global clock buffers (BUFG) | 2 | 32 | |
| I/O pins | 52 | 210 | |

Vivado's flip-flop count agrees with the open-source synthesis (153 against 150). No latches, no DSP blocks and no block RAM: the multiplier is the shift-and-add datapath, and the 8-word weight ROM fits in LUTs, as the [resource table](resources.md) predicts.

## Warnings in the report, and what they mean

- **19 inputs and 31 outputs have no input or output delay.** The inputs are the switches and buttons: a person changes them at any time, so they pass through two-flip-flop synchronizers instead of being timed against the clock. The outputs drive the LEDs and the 7-segment display, which are read by eye. Neither needs an I/O delay; a `set_false_path` on these ports would state that in the constraints and remove the warning.
- **The input clock is defined twice.** `constraints/nexys4ddr.xdc` creates `sys_clk_pin` on `clk` with `-add`, and the Clocking Wizard's own constraints create a second clock on the same pin. Vivado therefore analyses every path twice (`clk_out1_clk_wiz_0` and `clk_out1_clk_wiz_0_1`, with the same result) and also between the two copies. It does not change the result; dropping the `create_clock` line from the board XDC, which the Clocking Wizard already covers, would leave one clock.

## Not done yet

- Implementation of the variants in `src/variants/` (signed neuron, parallel neuron with DSP48E1 blocks, synchronous ROM).
- A timing simulation after place and route.
