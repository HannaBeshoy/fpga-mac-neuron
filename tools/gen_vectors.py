#!/usr/bin/env python3
"""Writes the test-vector files read by sim/tb_vectors.v (PLD Lecture 6:
self-checking testbench with a test-vector file).

    python3 tools/gen_vectors.py          # writes sim/vectors_unsigned.tv and sim/vectors_signed.tv

Each line is one test, 14 hex digits = 56 bits:
    x[15:0]  w[15:0]  th[9:0]  y[9:0]  fire  (3 unused bits at the top)
The expected y and fire are computed here, independently of the Verilog.
"""
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def nibbles(v):
    return [(v >> (4 * i)) & 0xF for i in range(4)]


def signed4(n):
    return n - 16 if n >= 8 else n


def expected(x, w, th, signed):
    xs, ws = nibbles(x), nibbles(w)
    if signed:
        y = sum(signed4(wi) * xi for wi, xi in zip(ws, xs))
        t = th - 1024 if th >= 512 else th
        return y & 0x3FF, int(y >= t)
    y = sum(wi * xi for wi, xi in zip(ws, xs))
    return y, int(y >= th)


def cases(signed, n_random, seed):
    r = random.Random(seed)
    out = [(0x0000, 0x0000, 0), (0xFFFF, 0xFFFF, 0), (0xFFFF, 0x1111, 30), (0xFFFF, 0x1111, 61),
           (0x000F, 0x0001, 15), (0x000F, 0x0001, 16), (0xFFFF, 0x7777, 420), (0xFFFF, 0x8888, 0x220),
           (0xFFFF, 0x8888, 0x221), (0x1234, 0x8421, 100), (0xF0F0, 0x7878, 0x3FF)]
    for i in range(4):                       # one input and one weight at a time
        for v in (1, 7, 8, 15):
            out.append((v << (4 * i), 0xFFFF, 1))
            out.append((0xFFFF, v << (4 * i), 1))
    while len(out) < n_random:
        th = r.randrange(1024) if signed else r.randrange(901)
        out.append((r.randrange(1 << 16), r.randrange(1 << 16), th))
    return out


def write(name, signed, seed):
    lines = []
    for x, w, th in cases(signed, 1000, seed):
        y, fire = expected(x, w, th, signed)
        word = (fire << 52) | (y << 42) | (th << 32) | (w << 16) | x
        lines.append(f"{word:014x}")
    (ROOT / "sim" / name).write_text("\n".join(lines) + "\n")
    print(f"sim/{name}: {len(lines)} vectors")


if __name__ == "__main__":
    write("vectors_unsigned.tv", False, 1)
    write("vectors_signed.tv", True, 2)
