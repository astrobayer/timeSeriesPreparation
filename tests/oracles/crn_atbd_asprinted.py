#!/usr/bin/env python3
"""ORC-1: the CRN-class digital filter of the GRACE L1B ATBD, as printed.

Source: Wu, Kruizinga, Bertiger (2006), Algorithm Theoretical Basis Document
for GRACE Level-1B Data Processing V1.2, JPL D-27672 (R-1 in
docs/references/REFERENCES.md), Appendix B, printed pp. 39-40 = PDF pp. 40-41,
transcribed from the page image of the copy with SHA-256
166778a94553f43ad9cd7f6be45528e7fb4e978e334a22f1a92bd565510b5a8d.

    Nf = fs*Tf (odd), NB = B*Tf, Nh = (Nf-1)/2
    H_k   = sum_{m=-NB..NB} ( sin[pi(k-m)/Nc] / sin[pi(k-m)/Nf] )^Nc
            -- the power N_c on EACH term (k = m: the limit Nf/Nc)
    F_n   = 1/FNorm * sum_{k=-Nh..Nh} H_k cos(2 pi k n / Nf),       |n| <= Nh
    FNorm = sum_{i=-Nh..Nh} cos(2 pi f0 i / fs) sum_k H_k cos(2 pi k i / Nf)
    dF_n  = 1/FNorm * sum_k -(2 pi k / Tf)   H_k sin(2 pi k n / Nf)
    ddF_n = 1/FNorm * sum_k -(2 pi k / Tf)^2 H_k cos(2 pi k n / Nf)

The page prints FNorm's inner cosine with n and the derivative sums over i;
both are read with the summation index of their sum (n -> i, i -> n). That
reading makes the response at f0 exactly 1 and reproduces the numbers CONCEPT 8
recorded on 2026-09-19: DC gain 1 + 1.115e-7 (ACC), 1 + 1.10e-11 (KBR).

This file is the oracle, not the implementation: it shares no code with
timeSeriesPreparation.crnKernel and uses NumPy's own sums. It writes
crn_atbd_asprinted.json, which TestCrnKernel pins. Regenerate only when the
reading of the page changes, and say why in the HANDOVER.

Usage:  python3 tests/oracles/crn_atbd_asprinted.py      (needs numpy)

Created: 2026-09-23
Author:  Matthias Weigelt with the help of Claude Code (Anthropic)
"""
import json
import os

import numpy as np

PRESETS = {  # ATBD App. B, PDF p. 40
    "ACC": dict(fs=10.0, Nc=7, Tf=140.7, B=0.035, f0=0.37e-3),
    "KBR": dict(fs=10.0, Nc=7, Tf=70.7, B=0.1, f0=0.37e-3),
}


def crn(fs, Nc, Tf, B, f0):
    Nf = int(round(fs * Tf))
    NB = int(round(B * Tf))
    assert Nf % 2 == 1, "Nf must be odd"
    Nh = (Nf - 1) // 2
    k = np.arange(-Nh, Nh + 1)
    H = np.zeros(Nf)
    for m in range(-NB, NB + 1):
        d = k - m
        den = np.sin(np.pi * d / Nf)
        den[d == 0] = 1.0
        term = np.sin(np.pi * d / Nc) / den
        term[d == 0] = Nf / Nc
        H += term ** Nc
    n = k
    A = 2.0 * np.pi * np.outer(n, k) / Nf
    G = np.cos(A) @ H
    FNorm = np.sum(np.cos(2.0 * np.pi * f0 * n / fs) * G)
    w = 2.0 * np.pi * k / Tf
    F = G / FNorm
    dF = (np.sin(A) @ (-w * H)) / FNorm
    ddF = (np.cos(A) @ (-(w ** 2) * H)) / FNorm
    return dict(Nf=Nf, NB=NB, Nh=Nh, FNorm=float(FNorm),
                dcGain=float(F.sum()), F=F.tolist(), dF=dF.tolist(),
                ddF=ddF.tolist())


def main():
    out = {"source": "GRACE L1B ATBD (JPL D-27672) App. B, PDF p. 40, as printed",
           "numpy": np.__version__}
    for name, p in PRESETS.items():
        out[name] = dict(parameters=p, **crn(**p))
        print(f"{name}: Nf={out[name]['Nf']} NB={out[name]['NB']} "
              f"dcGain-1={out[name]['dcGain'] - 1:.6e}")
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "crn_atbd_asprinted.json")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(out, fh, indent=1)
        fh.write("\n")


if __name__ == "__main__":
    main()
