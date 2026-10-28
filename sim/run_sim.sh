#!/bin/sh
# run_sim.sh - run every testbench with Icarus Verilog (free, Linux/macOS/Windows)
# In Vivado you can run the same testbenches in XSim instead (see README).
# -DSIMULATION replaces the Clocking Wizard IP with a pass-through clock.
set -e
cd "$(dirname "$0")"
mkdir -p out
cp ../src/weights.mem out/          # $readmemb looks for it in the run folder
cd out
SRC=../../src

echo "== multipliers: course version vs. constant-time"
iverilog -g2005 -Wall -s tb_mult -o tb_mult ../tb_mult.v $SRC/seq_mult_lab.v $SRC/seq_mult.v
vvp -n tb_mult

echo "== neuron: controller + datapath against a reference model"
iverilog -g2005 -Wall -s tb_neuron -o tb_neuron ../tb_neuron.v $SRC/neuron.v $SRC/seq_mult.v $SRC/weight_rom.v
vvp -n tb_neuron

echo "== whole board design"
iverilog -g2005 -Wall -DSIMULATION -s tb_top -o tb_top ../tb_top.v $SRC/*.v
vvp -n tb_top
