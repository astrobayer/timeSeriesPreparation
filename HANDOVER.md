# HANDOVER — timeSeriesPreparation

**Revision 0.6 · 2026-09-19 · no code yet**

This file is the single point of truth for this repository's **status,
obligations and repository-level decisions**. It points at, and never
restates:
- `docs/CONCEPT.md` — the design, with the design decisions in its section 11;
- `docs/GUIDE.md` — the order of work and every procedure.

---

## A. Status

**Documents only.** X-00a merged (#2, `f26df8d`).

**GUIDE A5 done:** one issue per WP, X-00b … X-18 = #3–#21 (map in GUIDE Appendix A).

| item | state |
|---|---|
| repository | private, `main`; auto-delete head branches on; MIT licence (owner, 2026-09-18) |
| ruleset `Main Protection` | no deletion, no force push; **no required checks yet** (see O-2) |
| ruleset `Tag protection` | `~ALL`, no deletion, no force push |
| content | `docs/CONCEPT.md` Rev 0.13, `docs/GUIDE.md` rev 1.3, `docs/inputs/` (4 files), this HANDOVER, README |
| code, `Contents.m`, CI, audit | none (X-00b) |
| `docs/GUIDE.md` | rev 1.6 (Stage C done) |
| `docs/CONCEPT.md` | Rev 0.14 (verification results 9.3; CRN correction) |
| `docs/references/REFERENCES.md` | the register: R-1 … R-13 (documents in the DATAPOOL), P-1 … P-20 (papers) |

**The move, measured.** SHA-256 of all six files at the copy commit was
identical to gracefoReading branch `claude/preproc-concept` at `4c08cb7`.
After the copy, only location text changed:
- `CONCEPT.md`: the hosting paragraph, one note in section 12, history row 0.12;
- `GUIDE.md`: the X-00a PR named by role, rev 1.2;
- `inputs/README.md`: the gate-safety paragraph.

The four input files are unchanged, and their SHA-256 match
`docs/inputs/README.md`.

**Data (GUIDE Stage B), measured on the runner 2026-09-19.**

| id | state | evidence |
|---|---|---|
| D-1 | **complete** for 2020-01-01 (and 2025-01-01), all products of the three daily archives; no ACC1B exists in RL04 | inventory run 35464353649 (PR #24) |
| D-2 | **complete**: 2020-01, 31 days × 3 archives = 93; 2 791 files extracted; **2 698 of 2 698** source MD5 verified; 0 mismatches, 0 conflicts | fetch run 35464757435 (PR #25), 12 min; `GRACEFO\L1B\RL04\2020\SHA256SUMS_2020-01.txt` (2 884 entries) |
| D-3 | **complete as published**: 4 products × 2 satellites × **28** days, plus 2 READMEs. No products for **2020-01-19 … 21**: TN-01a explains it (next row) | same run; `ITSG\SHA256SUMS_2020-01.txt` (226) |
| D-4 | **complete**: TN-01 SOE, TN-01a SCE, TN-01b KBR/GPS statistics, server version 2026-09-08, in `GRACEFO\DOCUMENTS\TECHNICAL_NOTES\2026-09-08\` | fetch run 35466032781 (PR #27) |
| D-5 | present in NonGravForces' `data\` (space weather and CERES, 2019-09 … 2020-03) | inventory |
| D-6 | **complete** for AEI: LRI1B and RTC1B v52, 2020 Q1 (Jan 31, Feb 29, Mar 31 days), release notes, Misfeldt et al. 2023; CC BY 3.0. SYSU/HUST not planned (owner named AEI) | same run; `GRACEFO\L1B\AEI_v52\SHA256SUMS_2020-Q1.txt` (186) |
| D-7 | **complete**: the owner names ITSG attitude as D-7; it arrived with D-3 | — |
| D-8 | **complete** for 2008-07 (before April 2011), 2012-01 (thermal control off), 2017-01 (GRACE-B transplant): RL02 daily archives (full product set, 93 days, 5 190 files) and RL03 monthly archives (KBR1B and SCA1B only), plus the GRACE-B transplant archive (ACT1B B, 2016-11-13 … 2017-06-29, 169 files). Classic `.dat` records are **binary** (ASCII header `FILE FORMAT … : 0`) | fetch run 35466840120 (PR #29); `GRACE\L1B\JPL\RL03\SHA256SUMS_2026-09-19_222059.txt` (6 014); findings posted on gracefoReading#17 (G-02) |
| D-9 | can start now (D-2 exists) | — |
| D-10 | **complete**: ZARM Bremen (Wöske et al. 2024): all ACC calibration files, i.e. GRACE A/B 2002–2016 (constant and monthly scale, 3-hourly bias, monthly scale factors) and GRACE-C 2018–2023. For the reference months also ZARM's GRACE-D transplant 2020-01 (24 days) and modelled radiation accelerations (GRACE-A 2008-07 and 2012-01; C 2020-01, 31 days; D 2020-01, 26 days; none published for 2017). **Convention ACC_cal = s·(ACC + b)**: their bias converts to this design's b = s·b_ZARM. No GRACE-D calibration series (D is a transplant) | fetch run 35467369081 (PR #30); `ZARM\SHA256SUMS_2026-09-19.txt` (95) |

**Stage C (references), 2026-09-19.**
- 220 ISDC documents were mirrored into the DATAPOOL by fetch run 35467953474
  (PR #31), with manifest `GRACEFO\DOCUMENTS\SHA256SUMS_documents_2026-09-19.txt`.
- Verification items were closed from the documents and from real files
  (CONCEPT 9.3).

**Finding: the v2 CRN oracle is wrong.**
- The ATBD formula, read from the page image (R-1, PDF p. 40), raises **each**
  passband term to the power N_c. The v2 port raised the **sum**.
- **Real data decide it:** GRACE-C 2020-01-02, mean(ACT1B_y) / mean(ACT1A_x)
  over 01:00–23:00 = **1.000000064**. The ATBD form predicts 1 + 1.1e-7; the
  v2 port predicts 1.0004533.
- Section 8 of the concept and ORC-1/ORC-2 are corrected. The v2 "+453 ppm" is
  void, and every v2 number computed with that kernel is re-derived before use.

**Finding from TN-01a (2026-09-19): GRACE-D safe mode inside the reference month.**
- 2020-01-17: GRACE-D IPU reboot (spontaneous) at about 07:43.
- 2020-01-18: KBR and LRI link lost after GRACE-D switched to AOCS safe mode at 05:05.
- 2020-01-19: GRACE-C IPU reboot (commanded).
- 2020-01-21: GRACE-D IPU, MWA, LRI and star cameras off since 18 January.
- 2020-01-22: back to nominal mode at 12:05.

This explains the ITSG gap. It is the first real entry for the defect catalogue
(V-12), and it bears on the regression baseline 2020-01 (ORC-10), see O-5.

**Verification available now:** none automated. X-00b brings the gate and
the audit.

---

## E. Obligations

| id | obligation | status | owner | re-entry |
|---|---|---|---|---|
| O-1 | X-00b: skeleton, CI, audit (C-01), documentation pipeline, test tags, layering test, references register | open | session | ci-actions#2 (C-01) released |
| O-2 | add the required checks `audit` and `matlab` to `Main Protection` once X-00b's first CI run has created them | open | owner | X-00b's first run |
| O-4 | GUIDE A3 steps 6 and 7: gracefoReading #15 merged (`de87fbf`, merge commit, see F), NonGravForces #57 merged (`10c8504`) | **closed 2026-09-18** | owner | — |
| O-5 | Regression month (CONCEPT ORC-10): keep 2020-01 and mask GRACE-D's safe mode 2020-01-18 05:05 … 2020-01-22 12:05 from the baseline (proposal; it then also tests event masking), or choose another month | open | owner | before N-10 |

---

## F. Repository decisions

Design decisions live in `docs/CONCEPT.md` section 11 only.

| date | decision | reason |
|---|---|---|
| 2026-09-19 | Reference documents live in the DATAPOOL next to the data (register in `docs/references/`), not in the repository | one pattern for everything downloaded; binaries stay out of git. GUIDE Stage C amended |
| 2026-09-19 | `READING_DATA_POOL` (organisation) is the DATAPOOL root; fixtures live below it in `RawData\tests\realdata`; new data follow the owner's existing layout | owner; one variable, one meaning. gracefoReading's repository-level value keeps the old meaning until G-07 (gracefoReading#23) |
| 2026-09-19 | D-2 and D-3 fetched by a runner workflow on a throwaway PR (#25), never merged | owner-approved; anonymous sources; no overwrite, source MD5 verified |
| 2026-09-18 | **Correction, measured:** gracefoReading #15 was merged with a merge commit (`de87fbf`), not squashed as planned, and its branch deleted; the concept drafts and the two input zips (~2.7 MB) are in gracefoReading's `main` history. Accepted; the concept's pre-move history is reachable there up to `4c08cb7` | rewriting gracefoReading's `main` is forbidden by its ruleset and not needed; the tree is as intended (gracefoReading#22 corrects its own record) |
| 2026-09-18 | GUIDE A5: issues #3–#21 opened for X-00b … X-18 | the standard loop closes each through its PR |
| 2026-09-18 | Concept, guide and inputs moved here from gracefoReading as X-00a; their earlier history is in gracefoReading's `main` history up to `4c08cb7` | CONCEPT Q14 item 5: the design lives where its code will, and the input zips never enter the reader's history |

---

## G. What a next session would be wrong for not reading

1. There is no code. The next WP here is X-00b, and it waits for C-01
   (ci-actions#2).
2. `Main Protection` requires no checks until O-2 is done. The X-00a PR was the
   only merge meant to happen without CI.
3. Never unpack the zips in `docs/inputs/`.
