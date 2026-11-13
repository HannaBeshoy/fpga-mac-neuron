#!/usr/bin/env python3
"""Synthesises each variant for a Xilinx 7-series FPGA with Yosys and counts the
resources (PLD Lectures 4 and 7). Writes results/resources.md.

    apt install yosys      (or the OSS CAD Suite; any Yosys with ABC)
    python3 tools/resources.py

Yosys gives resource counts but no timing: the maximum clock frequency and the
post-implementation timing simulation need Vivado (docs/PROJECT_GUIDE.md).
"""
import re
import subprocess
import sys
from pathlib import Path

import shutil

YOSYS = shutil.which("yosys") or "yowasp-yosys"
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
V = SRC / "variants"

DESIGNS = [
    ("Course multiplier (data-dependent time)", "seq_mult_lab", {"N": 4}, [SRC / "seq_mult_lab.v"]),
    ("Constant-time multiplier", "seq_mult", {"N": 4}, [SRC / "seq_mult.v"]),
    ("Neuron, unsigned, sequential (on the board)", "neuron", {}, [SRC / "neuron.v", SRC / "seq_mult.v"]),
    ("Neuron, signed weights, sequential", "neuron_signed", {},
     [V / "neuron_signed.v", V / "seq_mult_signed.v", SRC / "seq_mult.v"]),
    ("Neuron, signed, 4 parallel multipliers, 4-bit", "neuron_parallel", {"W": 4}, [V / "neuron_parallel.v"]),
    ("Neuron, signed, 4 parallel multipliers, 16-bit", "neuron_parallel", {"W": 16}, [V / "neuron_parallel.v"]),
    ("Weight ROM, 8 words, asynchronous read", "weight_rom", {}, [SRC / "weight_rom.v"]),
    ("Weight ROM, 8 words, synchronous read", "weight_rom_sync", {"DEPTH": 8}, [V / "weight_rom_sync.v"]),
    ("Weight ROM, 1024 words, synchronous read", "weight_rom_sync", {"DEPTH": 1024}, [V / "weight_rom_sync.v"]),
]


def synth(top, params, files):
    script = "; ".join([f"read_verilog {f}" for f in files]
                       + [f"chparam -set {k} {v} {top}" for k, v in params.items()]
                       + [f"synth_xilinx -family xc7 -top {top} -flatten -noiopad", "stat"])
    out = subprocess.run([YOSYS, "-p", script],
                         cwd=SRC, capture_output=True, text=True)
    if out.returncode:
        sys.exit(out.stderr[-2000:])
    block = out.stdout.rsplit("Number of cells:", 1)[1]          # the last (flattened) summary
    cells = {name: int(n) for name, n in re.findall(r"^\s+(\$?[A-Za-z0-9_]+)\s+(\d+)\s*$", block, re.M)}
    lut = sum(n for c, n in cells.items() if re.fullmatch(r"LUT[1-6]", c))
    ff = sum(n for c, n in cells.items() if re.fullmatch(r"FD[RSCP]E", c))
    return lut, ff, cells.get("CARRY4", 0), cells.get("DSP48E1", 0), \
        sum(n for c, n in cells.items() if c.startswith("RAMB"))


def main():
    rows = ["| Design | LUTs | Flip-flops | CARRY4 | DSP48E1 | Block RAM |", "| --- | ---: | ---: | ---: | ---: | ---: |"]
    for label, top, params, files in DESIGNS:
        r = synth(top, params, files)
        rows.append(f"| {label} | " + " | ".join(str(v) for v in r) + " |")
        print(rows[-1])
    text = ("# Resources after synthesis\n\nYosys `synth_xilinx -family xc7` (Artix-7), cell counts from `stat`. "
            "Written by `tools/resources.py`.\n\n" + "\n".join(rows) + "\n")
    (ROOT / "results").mkdir(exist_ok=True)
    (ROOT / "results" / "resources.md").write_text(text)


if __name__ == "__main__":
    main()
