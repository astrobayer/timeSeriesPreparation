# HANDOVER — timeSeriesPreparation

**Revision 0.1 · 2026-09-18 · no code yet**

This file is the single point of truth for this repository's **status,
obligations and repository-level decisions**. It points at, and never
restates:
- `docs/CONCEPT.md` — the design, with the design decisions in its section 11;
- `docs/GUIDE.md` — the order of work and every procedure.

---

## A. Status

**Documents only.** X-00a (issue #1) delivered on its branch; merge pending.

| item | state |
|---|---|
| repository | private, `main`; auto-delete head branches on; MIT licence (owner, 2026-09-18) |
| ruleset `Main Protection` | no deletion, no force push; **no required checks yet** (see O-2) |
| ruleset `Tag protection` | `~ALL`, no deletion, no force push |
| content | `docs/CONCEPT.md` Rev 0.12, `docs/GUIDE.md` rev 1.2, `docs/inputs/` (4 files), this HANDOVER, README |
| code, `Contents.m`, CI, audit | none (X-00b) |

**The move, measured.** SHA-256 of all six files at the copy commit was
identical to gracefoReading branch `claude/preproc-concept` at `4c08cb7`.
After the copy, only location text changed:
- `CONCEPT.md`: the hosting paragraph, one note in section 12, history row 0.12;
- `GUIDE.md`: the X-00a PR named by role, rev 1.2;
- `inputs/README.md`: the gate-safety paragraph.

The four input files are unchanged, and their SHA-256 match
`docs/inputs/README.md`.

**Verification available now:** none automated. X-00b brings the gate and
the audit.

---

## E. Obligations

| id | obligation | status | owner | re-entry |
|---|---|---|---|---|
| O-1 | X-00b: skeleton, CI, audit (C-01), documentation pipeline, test tags, layering test, references register | open | session | ci-actions#2 (C-01) released |
| O-2 | add the required checks `audit` and `matlab` to `Main Protection` once X-00b's first CI run has created them | open | owner | X-00b's first run |
| O-3 | GUIDE A5: one issue per WP, X-00b … X-18 | open | session | now |
| O-4 | GUIDE A3 steps 6 and 7: reduce gracefoReading #15 to a pointer plus the G-01…G-06 records; update the concept path in NonGravForces #57 | open | session | this PR merged |

---

## F. Repository decisions

Design decisions live in `docs/CONCEPT.md` section 11 only.

| date | decision | reason |
|---|---|---|
| 2026-09-18 | Concept, guide and inputs moved here from gracefoReading as X-00a; their earlier history stays in gracefoReading branch `claude/preproc-concept` | CONCEPT Q14 item 5: the design lives where its code will, and the input zips never enter the reader's history |

---

## G. What a next session would be wrong for not reading

1. There is no code. The next WP here is X-00b, and it waits for C-01
   (ci-actions#2).
2. `Main Protection` requires no checks until O-2 is done. The X-00a PR was the
   only merge meant to happen without CI.
3. Never unpack the zips in `docs/inputs/`.
