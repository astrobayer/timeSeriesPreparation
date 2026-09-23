#!/usr/bin/env python3
"""Oracle for timeSeriesPreparation.internal.blockLength (Politis-White with
the Patton-Politis-White 2009 correction).

The reference is recombinator 0.0.6.1, a line-by-line Python port of Andrew
Patton's MATLAB opt_block_length_REV_dec07; its circular-block value b_star_cb
is the number pinned. That port has one indexing slip: in the branch where no
window of K_N insignificant autocorrelations exists it takes the 0-based index
of the last significant lag, where Patton's MATLAB `find` gives the lag. The
cases "ar095" and "periodic" enter that branch; there both readings give
M = m_max, so the pinned value is the same (a NumPy transcription with the lag
reading agreed to 5e-16 on all six cases, 2026-09-23).

The series are generated so that NumPy and MATLAB produce the same doubles:
an integer LCG u_k = (1664525 u_(k-1) + 1013904223) mod 2^32, e_k = u_k/2^32 -
0.5 (exact), then x_1 = e_1, x_k = phi x_(k-1) + e_k in plain IEEE double. A
"period" adds amp * (-1)^floor(k/period) (exact). TestBlockLength rebuilds
them from the parameters in block_length_pw.json.

Usage:  python3 tests/oracles/block_length_pw.py   (needs numpy, recombinator)

Created: 2026-09-23
Author:  Matthias Weigelt with the help of Claude Code (Anthropic)
"""
import json
import os

import numpy as np
from recombinator.optimal_block_length import optimal_block_length

CASES = [
    dict(name="white", seed=1, n=500, phi=0.0, period=0, amp=0.0),
    dict(name="ar05", seed=2, n=1000, phi=0.5, period=0, amp=0.0),
    dict(name="ar09", seed=3, n=2000, phi=0.9, period=0, amp=0.0),
    dict(name="ar095", seed=4, n=5000, phi=0.95, period=0, amp=0.0),
    dict(name="negative", seed=5, n=3000, phi=-0.6, period=0, amp=0.0),
    dict(name="periodic", seed=6, n=1000, phi=0.0, period=37, amp=2.0),
]


def series(c):
    u = c["seed"]
    x = np.empty(c["n"])
    prev = 0.0
    for k in range(c["n"]):
        u = (1664525 * u + 1013904223) % 2**32
        e = u / 2**32 - 0.5
        prev = e if k == 0 else c["phi"] * prev + e
        x[k] = prev
    if c["period"]:
        k = np.arange(1, c["n"] + 1)
        x = x + c["amp"] * (-1.0) ** np.floor(k / c["period"])
    return x


def main():
    out = []
    for c in CASES:
        x = series(c)
        b = float(optimal_block_length(x)[0].b_star_cb)
        out.append(dict(c, b=b, first=float(x[0]), last=float(x[-1])))
        print(f"{c['name']:9s} n={c['n']:5d} b={b:.12g}")
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "block_length_pw.json")
    with open(path, "w") as fh:
        json.dump(dict(source="recombinator 0.0.6.1 optimal_block_length, b_star_cb",
                       cases=out), fh, indent=1)


if __name__ == "__main__":
    main()
