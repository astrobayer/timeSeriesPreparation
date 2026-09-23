# HANDOVER — timeSeriesPreparation

**Revision 0.17 · 2026-09-23 · X-07 merged; the reference noise-model library blocked on sources**

This file is the single point of truth for this repository's **status,
obligations and repository-level decisions**. It points at, and never
restates:
- `docs/CONCEPT.md` — the design, with the design decisions in its section 11;
- `docs/GUIDE.md` — the order of work and every procedure.

---

## X-07 — merged 2026-09-23 (PR #44, `f7d3518`; issue #10 open for the library); scope frozen 2026-09-23

Tier B (no local MATLAB; the MATLAB verdict is CI's). Design: CONCEPT 10.1
row X-07, 6.1 rows 5-7, 5.2 (minimum-data gate), 8 (seed per stage,
block bootstrap, observability before the fit), Q12. Owner decisions of
2026-09-23 are recorded in the lsqvce section below: two PRs, gate 0.5,
Politis-White block length, and sources fetched by the session.

True after the merge:
- **`bootstrap`** (L2): moving-block bootstrap of a caller's statistic.
  Replicate r draws from substream r of an mrg32k3a stream seeded by
  **`internal.stageSeed`** (32-bit FNV-1a of the stage name plus a seed),
  so the numbers depend neither on worker count nor on stage order
  (CONCEPT 8). Percentile interval by the type-7 quantile.
- **`internal.blockLength`**: Politis & White (2004) with the Patton,
  Politis & White (2009) correction, the steps of Patton's reference code;
  NaN left out pairwise. bootstrap and crossval use the largest per-column
  value, rounded up.
- **`crossval`** (L2): hv-block cross-validation, contiguous folds and a
  buffer of Gap rows (default the block length); lossFcn sees the full
  grid with NaN outside each set.
- **`observability`** (L2): per axis, the Belsley condition number, the
  correlation of the estimates and the weighted, centred VIF of the design
  as given. The **minimum-data gate** refuses an axis keeping less weight
  than `Config.unc.minWeightFraction`: 0.5 for ACC1B, ACT1B, KBR1B and
  LRI1B, [] (must be given) for any other product.
- **`noise`** (L2, new unit, CONCEPT 0.16): ARMA(p,q) per axis by exact ML
  with gaps (tsFitArima) or through a 32-segment Welch PSD (psd2arma), the
  model's ACV (arma2acv) and Ljung-Box. The PSD route refuses gapped axes:
  psd2arma's log-LS gain on an unaveraged periodogram biases sigma2 by
  exp(-0.577) = 0.56. The order is the caller's (R5). The fit starts from
  a stage-seeded stream, reset per axis, and the caller's global stream
  is restored.
- **Q12**: `TestLsqvceAgreement` holds the four pairs together, with
  tolerances naming their terms (help of the test). The gate puts
  `deps/lsqvce` on the path; without it, 14 tests are incomplete.
- `Config.unc`: minWeightFraction, blockLength, nBoot 1000, level 0.6827,
  folds 5.

**Oracles and measurements (2026-09-23, NumPy):**
- Block length: `tests/oracles/block_length_pw.py` pins recombinator 0.0.6.1
  (a port of Patton's code) on six LCG-built series that MATLAB rebuilds bit
  for bit; a NumPy transcription of the MATLAB steps agrees to 5e-16. The
  port reads the no-window branch 0-based; two cases enter that branch and
  both readings give M = m_max there.
- Bootstrap: 200 AR(1) realisations (phi 0.5, N 4000) gave sigma/exact
  0.85-1.16; single-sample resampling 0.53-0.61.
- Q12: arma2acv vs armaACV to 8.6e-16 of r(0), 4.6e-13 for poles at 0.98;
  spec2acv vs psd2acv to 3.2e-16; Yule-Walker Toeplitz condition <= 410.

**Fault injection:**

| planted fault | caught by |
|---|---|
| block length: stationary constant D = 2 instead of 4/3 | 6 of 6 oracle cases |
| block length: rectangular instead of flat-top window | 6 of 6 |
| block length: mhat off by one | 4 of 6 |
| block length: K_N = 3 instead of 5 | 2 of 6 |
| Q12: AR(1) pole moved by 1e-7 | `plantedErrorExceedsTolerance` (in the suite) |
| gate: an axis at 0.4 against the 0.5 preset | `gateRefusesBelowPreset` (in the suite) |
| whiteness: AR(0) model of AR(1) data | `underfitFailsWhiteness` (in the suite) |

The first four ran on the NumPy transcription, the last three are tests
that run in CI.

**Blocked: the reference noise-model library** (ACC 1/f, KBR
CNR-limited, LRI design ASD; CONCEPT 6.1 row 5, W-12). The environment's
network policy refuses every source host (arXiv, Springer, NASA NTRS,
Copernicus, DLR, IOP; HTTP 403, 2026-09-23). Search summaries name, among
others, 80 nm/sqrt(Hz) sqrt(1 + (3 mHz/f)^2) sqrt(1 + (10 mHz/f)^2) for
the LRI and 1e-10 sqrt(1 + 5 mHz/f) m/s^2/sqrt(Hz) for the ACC. These are
SECONDARY and are not coded. The library needs the network hosts allowed
or the PDFs supplied (asked 2026-09-23). Issue #10 stays open for it.

**Prediction** (before any run): **489 + 0 + 0 = 489**. That is 421 plus
68: the new classes TestBlockLength 6, TestBootstrap 12, TestCrossval 9,
TestObservability 11, TestNoise 9, TestLsqvceAgreement 14; TestConfig +1;
TestHelpExamples 39 -> 45. Per tag: contract 152, reference 182, precision
13, robustness 100, metamorphic 28, vectorisation 11, speed 3. Without
lsqvce: 475 + 0 + 14.

**Verdict, MATLAB R2026a, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:**
- CI run 35905806199 on `8cdb086` (2026-09-23): **488 + 1 + 1**. The one
  failure was `TestBlockLength/batchEqualsColumns`, a bug in the test
  (`MATLAB:catenate:dimensionMismatch`: oracle cases 2 and 5 have 1000
  and 3000 samples). It was fixed in `726cdd7`.
- CI run 35909976645 on `726cdd7`: `audit` green; `matlab` green,
  **489 + 0 + 0 = 489**, every tag as predicted (contract 152, reference
  182, precision 13, robustness 100, metamorphic 28, vectorisation 11,
  speed 3). Q12 green against lsqvce; the PSD band of TestNoise held.
  Gate time 1012 s.

**Risk, stated:** nothing here ran in MATLAB before CI. The PSD-route
band of TestNoise (0.05 on phi, 15 % on sigma2) is an expectation, not a
measurement. References cited from memory are listed as debt.

**Debt.**
- Literature cited from memory, not re-read (network): Kuensch 1989,
  Lahiri 2003, Hyndman & Fan 1996, L'Ecuyer 1999, Politis 2003, Racine
  2000, Burman et al. 1994, Bergmeir et al. 2018, Belsley et al. 1980,
  Kutner et al. 2005, Box et al. 2015, Jones 1980, the FNV draft.
- The reference noise-model library (above).

---

## lsqvce in CI, before X-07 — merged 2026-09-23 (PR #43, `5afbd87`)

Tier B. Scope, frozen 2026-09-23. The owner decided X-07 comes in two PRs
(asked in session, 2026-09-23): this `.github/` PR, then all of X-07.

Owner decisions for X-07, the same day:
- **Minimum-data gate: 0.5** in every product preset (ACC, KBR, LRI),
  provisional until ORC-10.
- **Block length:** automatic, Politis & White (2004) with the Patton,
  Politis & White (2009) correction; an explicit option overrides it.
- **Reference noise-model library:** the session fetches the published
  sources, registers them, and pins every constant to a page; a constant
  without a source stays out.

True after the merge:
- `ci.yml` checks out **lsqvce `v6.1.3`** (an annotated tag, `b25bb11`)
  into `deps/lsqvce` when `REFERENCE_READ_TOKEN` is visible. This is the
  gracefoReading pattern and the token GUIDE §2 already names for lsqvce
  (tests only).
- Nothing uses it yet: the gate puts `deps/lsqvce` on the path in X-07,
  together with the Q12 agreement test, whose tests are incomplete (never
  passed) when lsqvce is absent.
- All five counterparts exist in `v6.1.3`: `+lsqvce/+kernel/armaACV`,
  `psd2acv`, `whitenessCorr`, `levinsonDurbin`, `whittle`.

**Checks:** the YAML parses and the steps are in order (checkout, probe,
gracefoReading, lsqvce, gate, report). The tag `v6.1.3` exists on the remote.
There is nothing to inject a fault into until X-07 adds the test that
uses the checkout. A checkout the token cannot reach fails the step, so it
cannot pass silently.

**Prediction** (before any run): **421 + 0 + 0 = 421**, unchanged.

**Verdict, CI run 35897320406 on `bbf56ff` (2026-09-23), MATLAB R2026a:**
- `audit` green.
- The step "Check out lsqvce (test-only dependency)" is green: the token
  reaches lsqvce.
- `matlab` green: **421 + 0 + 0 = 421**, as predicted. Gate time 1002 s.

---

## Release workflow — merged 2026-09-23 (PR #42, `298b7cd`)

Tier B. Scope, frozen 2026-09-23 (owner: "prepare the release workflow PR
after #41"): `.github/workflows/release.yml` and the records of `v0.1.0`.
No code, no test.

True after the merge:
- **`release.yml`**: on a merged PR, `ci-actions/matlab-release@v1.3.2` with
  `mode: file` reads `Contents.m`. If no tag names that version, it creates
  an annotated tag on the merge commit, reads it back and publishes the
  release (`--verify-tag`, so it can never make a lightweight one). Any
  other merge releases nothing. Checkout is pinned as in `ci.yml`.
- **`v0.1.0` recorded, not moved** (GUIDE §3 anomaly table):
  - The owner created it in the release UI after the session's push was
    refused (HTTP 403). It is **lightweight**, has generated notes, and
    sits on **`7fe24f3`** (the X-02 merge), not on `f969ecb` (the X-04
    merge).
  - So 0.1.0 contains X-06 and X-02 as well. The CHANGELOG now lists them
    under 0.1.0, with a note on the tag commit.
  - The session's unpushed local annotated tag on `f969ecb` was deleted;
    the remote tag is the only one.
- GUIDE rev 1.11: §3 says the workflow does the tag and the release where
  it exists; the hand steps stay as the fallback.

**Fault injection (2026-09-23)**: the decision script of `matlab-release`
(`release/nextversion.py`, ci-actions `v1.3.2`), run on this tree:

| input | decision |
|---|---|
| real tags, `Contents.m` 0.1.0 | `bump=none`: no release (this PR's own merge) |
| no tag `v0.1.0` (fault) | `bump=file`, `v0.1.0` |
| `Contents.m` at 0.2.0 (fault) | `bump=file`, `v0.2.0`, previous `v0.1.0` |

The YAML parses. The workflow runs only on `pull_request: closed`, so it
first runs at this PR's merge, and must print "No release from this merge."
The next PR records that run.

**First run, measured:** release run 35896679070 at the merge of #42
(2026-09-23 17:35 UTC). `matlab-release` decided `bump=none` and printed
"No release from this merge."; the tag step was skipped. No tag was made.

**Prediction** (before any run): **421 + 0 + 0 = 421**, unchanged from
the `.github/` profile switch, because no code or test changes.

**Verdict, CI run 35858904692 on `b8d99d7` (2026-09-23), MATLAB R2026a,
gracefoReading `v1.1.0`:**
- `audit` green.
- `matlab` green: **421 + 0 + 0 = 421**, every tag as predicted (contract
  129). Gate time 999 s.
- The release job has not run yet: it runs at the merge.

---

## `.github/` profile switch after X-02 — merged 2026-09-23 (PR #41, `7b94df4`)

Tier B. This PR finishes what X-02 left to `.github/`, a change that stands
alone. It touches only `.github/matlab-audit.json` and
`.github/matlab-docs.json`, plus the files generated from them.

True after the merge:
- **Audit**:
  - The profile `sigtools-imported` is gone. `+spectral` and `+tsmodels`
    are audited under `public` (the full CONCEPT 9.1 template).
  - `tests/sigtools` falls under `tests`.
  - A new profile `demos` asks for a help block with the provenance footer.
  - `public` has `"warnings": true`, so warning identifiers are checked
    (A5/A6) and catalogued. This closes the X-06 debt.
- **Docs**: the generator no longer excludes the subpackages. There are HTML
  pages for all 29 of their functions, and the catalogue has **94**
  identifiers (up from 28). **29 new help examples** run in
  `TestHelpExamples`.

**Fault injection (2026-09-23, ci-actions `v1.3.2`)**, each on a copy that
was restored afterwards:

| injected fault | finding |
|---|---|
| `arma2acv` without ACCURACY | A2 |
| a `tsPacf` warning raised under an undocumented identifier | A6 (and A5 for the orphaned documented one) |
| a demo footer at 0.0.9 | A3 |

The healthy tree is **clean**: 83 files. `matlab-docs --check`: 45 files,
**in sync**.

**Prediction** (before any run): **421 + 0 + 0 = 421**. That is X-02's 392
with TestHelpExamples going from 10 to 39 (+29, all contract): contract
129, reference 161, precision 10, robustness 87, metamorphic 25,
vectorisation 6, speed 3. Without gracefoReading: 413 + 0 + 8.

**Risk, stated:** the 29 sigtools EXAMPLEs run for the first time. Each must
run without a warning (`verifyWarningFree`). The agents wrote them without
MATLAB, so a red here is a help-text fix in this PR, not a numerical one.

**Verdict, CI run 35841401891 on `d53a040` (2026-09-23), MATLAB R2026a,
gracefoReading `v1.1.0`:**
- `audit` green.
- `matlab` green on the first run: **421 + 0 + 0 = 421**, every tag as
  predicted (contract 129).
- All 29 new sigtools EXAMPLEs ran warning-free; the risk did not occur.
- Gate time 1001 s.

---

## X-02 — merged 2026-09-23 (PR #40, issue #5); scope was frozen 2026-09-23

Tier B. Design: CONCEPT 10.1 row X-02, 12.5 and 12.9 (port first,
conventions after, gated by equality to the port). **Numbers unchanged** is
the gate (ORC-8). No release: the version stays 0.1.0.

Owner decisions of 2026-09-23 (asked in session):
- **Plotting split: clean break.** Compute functions never plot and lose
  their plot arguments. Plotting moves to sibling functions in the same
  subpackage. Demos and tests are updated in this PR.
- **One Lyapunov solver, per-caller parameters.** The five local copies
  (CONCEPT says four; `tsFitSarima` has a fifth) differ only in tolerance
  (1e-15 in `arma2acv`, 1e-14 elsewhere) and iteration cap (80 or 60). One
  `internal.dlyap(T, Q, Tol, MaxIter)` replaces them, and each caller passes
  its own values, so every number stays bit-identical. Harmonising the
  tolerances would be a later numerical WP.

True after the merge:
- `timeSeriesPreparation.internal.dlyap` replaces the five local copies.
- Plotting split:
  - `allanVariance` loses `doPlot`, and `plotAllanVariance` plots its
    result.
  - `psd2arma` loses `Plot`, and `plotPsd2armaFit` plots its `results`.
  - `tsCheckResiduals` no longer draws, and `plotResiduals` draws the
    four-panel figure from its output.
  - `powerSpectrum` computes what `plotPowerSpectrum` drew, and
    `plotPowerSpectrum` only plots.
- `arguments` blocks in every sigtools function, replacing `inputParser` and
  `nargin` checks. The defaults and the accepted domain stay as they were.
- Error identifiers are prefixed (`timeSeriesPreparation:<function>:<id>`),
  and every `error` raised has one.
- Help to the CONCEPT 9.1 template with footer, for all sigtools functions and
  the new ones; `Contents.m` of both subpackages.
- Tests:
  - `tests/sigtools` is updated for the identifiers and the split and tagged
    with the CONCEPT 9 categories; the `TestTagPolicy` exemption is removed.
  - **New gate `TestSigtoolsEquivalence` (ORC-8):** every function's outputs
    on a fixed battery equal those of the archived v1.3.1, run from the zip in
    a temporary folder, bit for bit (`isequaln`).
  - `TestSigtoolsImport` keeps only the archive-coverage check, because
    byte identity ends with the conventions.
- The demos are updated for the split.

Out of scope, each with its place:
- The audit profile `sigtools-imported` and the docs exclusion of `+spectral`
  and `+tsmodels` live in `.github/`, so they are switched in a separate PR
  right after this one (GUIDE §1). That PR also brings the generated HTML
  pages and help examples for the subpackages. Until then this PR's help
  blocks are checked locally against the `public` profile.
- Any numerical change: tolerances, algorithms, speed (X-16 for speed).

**How it was done.** I did the four plotting splits, `internal.dlyap`, the
equivalence gate, the demos and the test infrastructure myself. Four
parallel agents did the conventions pass:
- the spectral group;
- the tsmodels fitting group;
- the tsmodels utility group;
- the tagging of `tests/sigtools`.

I reviewed every non-comment line of their diffs. No computational line
changed. Options that became string arrays are only compared with
`strcmpi`, never returned, and option defaults keep their char class, so
the model structs stay identical.

**Interface changes, besides the plotting split** (all refuse earlier or
more precisely; none changes a number):
- inputParser gave way to arguments blocks, so a struct passed in place of
  name-value pairs is no longer expanded. No caller did that.
- `tsAutoArima` and `tsAutoSarima` forward only the options of their fit
  function, and an unknown option is refused at once. Before, every fit
  failed inside `try` and the call ended in `noFit`.
- The three `tsFit*` wrappers forward only the options they are given.
- `powerSpectrum` takes one series per call; several series are one struct
  array.

**Measured before the push (2026-09-23, ci-actions `v1.3.2`):**
- The Wilson-Hilferty chi-square quantile of `allanVariance` was checked
  against an exact quantile because its help needed a number. At 1 sigma
  it errs < 0.6 % for edf >= 3; at 95 % the lower quantile errs 16 % at
  edf 3, 4 % at edf 5 and 0.7 % at edf 10. This is now in its ACCURACY.
- `matlab-audit` with the repository profile: 83 files at 0.1.0,
  **clean**. With the strict profile the `.github/` PR will adopt
  (`sigtools-imported` dropped, subpackages under `public`, `tests/sigtools`
  under `tests`, a `demos` profile): **clean** but for its own catalogue
  path. `matlab-docs --check`: 16 files, **in sync** (+1 page and +1 help
  example, `internal.dlyap`).

**Prediction** (before any run): **392 + 0 + 0 = 392** with the
gracefoReading checkout (without it: 384 + 0 + 8).

| class | contract | reference | precision | robustness | metamorphic | vectorisation | speed | untagged | total |
|---|---|---|---|---|---|---|---|---|---|
| unchanged from X-06 | 40 | 42 | 7 | 52 | 10 | 5 | 3 | | 159 |
| tests/sigtools (tagged, count unchanged) | 48 | 79 | 3 | 34 | 15 | 1 | | | 180 |
| TestSigtoolsEquivalence (new) | 1 | 40 | | 1 | | | | | 42 |
| TestSigtoolsImport (5 -> 1) | 1 | | | | | | | | 1 |
| TestHelpExamples (+1, dlyap) | 10 | | | | | | | | 10 |
| **sum** | **100** | **161** | **10** | **87** | **25** | **6** | **3** | **0** | **392** |

(The first row is the X-06 total, 353, less the untagged sigtools 180,
TestSigtoolsImport 5 and TestHelpExamples 9 = 159.)

**Verdict, CI run 35836240391 on `0d9f62c` (2026-09-23), MATLAB R2026a,
gracefoReading `v1.1.0`:**
- `audit` green.
- `matlab` green on the first run: **392 + 0 + 0 = 392**, every tag as
  predicted.
- All 40 equivalence cases are bit-identical to the v1.3.1 archive (ORC-8
  met).
- Gate time 1017 s.

**Debt.**
- Tier A: there is no local MATLAB, and nothing here ran before CI. The
  converted functions' EXAMPLEs run only once the `.github/` PR includes
  the subpackages in the docs generator.
- **The `.github/` follow-up PR**, which stands alone: the audit profile
  switch described above; `"warnings": true`, so warning identifiers are
  audited (X-06 debt); and the docs generator for `+spectral` and
  `+tsmodels` (HTML pages, the catalogue with their identifiers, their help
  examples).
- The references the agents added from memory (e.g. Jones 1980, Monahan
  1984, Durbin 1960) need a spot check of volume and page.

---

## X-06 — merged 2026-09-23 (PR #39, issue #9); scope was frozen 2026-09-23

Tier B (no local MATLAB; the MATLAB verdict is CI's). Design: CONCEPT 5.2
(unit check), 6.1 row 3, 10.1 row X-06; v3 WP-02 item 3 and WP-11 item 1
(`docs/inputs/HANDOVER_AccelCal_v3.md`), v3 F2. No release (GUIDE §7: next
release is X-05, v0.2.0); the version stays 0.1.0.

True after the merge:
- `timeSeriesPreparation.align(obs, ref)`: the reference moved onto the
  observation epochs.
  - Interpolation (default pchip, the v2 choice: linear chords attenuate
    amplitude, which the scale absorbs) runs only inside contiguous stretches
    of the reference. A stretch ends at a NaN, at a removed sample (weight 0)
    and at a spacing wider than `MaxGap`. The default `MaxGap` is 1.5 times the
    median reference step, so every missing sample breaks a stretch. There is
    no extrapolation and no interpolation across a hole. This replaces v2's
    finiteness-mask trick, whose linear mask does not cover pchip's wider
    stencil once R2026a's `interp1` drops NaN points.
  - An epoch that coincides with a reference epoch takes its value bit for
    bit.
  - Validity is joint over columns, because weights are per row. Epochs that
    get no value are NaN and form the layer `alignGap`. The result keeps
    metadata and provenance (`Arc.derive`).
  - **Unit check (5.2):** columns are paired by position. Equal counts and
    equal units are required, compared after whitespace and `^` are removed
    (`m/s^2` = `m/s2`). A mismatch refuses, and so does a unit that is not
    stated (`""`, R5).
- `timeSeriesPreparation.checkAlignment(obs, ref)`: the lag diagnostic.
  - Both series go onto one uniform grid (1 s) by the same rules and are
    AC-coupled. The normalised cross-correlation is computed over ±`MaxLag`
    (60 s) only, and the peak is refined by a parabola.
  - The result is per column: lag, peak and a verdict. The verdicts are
    "aligned" (|lag| ≤ 1 s), "offset" (warns), "gross" (> MaxLag/2 or at the
    search edge; warns) and "undetermined" (warns).
  - It **never shifts** a series (v3 F2): the result is a report only.
- `Config.align`: the fields `method`, `maxGap`, `maxLag` and `threshold`,
  with the defaults above.

Out of scope: time-system conversion (v3 WP-02 items 1–2, `toGps` and leap
seconds; the arcs are GPS ns already), frame checks, consistency filtering
(the application's, with `crnApply`), `run`, and any automatic shift.

**Added during implementation** (within the frozen scope):
- `timeSeriesPreparation.internal.resampleOnto` holds the one resampling
  rule both functions share.
- `checkAlignment` in the layer map of `TestLayering` as L2, next to `align`
  (CONCEPT 6.1 row 3 names both).

**Measured before the push (2026-09-23, ci-actions `v1.3.2`, NumPy
prototype of both estimators):**
- pchip, 5 s → 1 s, on 1/rev + 2/rev (orbit 5640 s): error 3.8e-6 of the
  amplitude (linear 1.2e-5); the test requires 1e-5.
- Lag, one day at 1 s, 1/rev + 2/rev + 40 fixed tones (2–50 mHz):
  - 7.0 s is recovered to 1.1e-5 s, 7.3 s to 1.0e-3 s and 45 s to
    1.1e-5 s;
  - 7.0 s with gaps of 3000 s and 2000 s is recovered to 3.2e-5 s.

  The tests require 0.05 s, 0.01 s, 0.05 s and 0.05 s.
- **Limit found:** a lag beyond the window (90 s) is not always on the edge.
  With broadband tones a side lobe at 7.27 s wins, with peak 0.50 against
  0.9999 for a true lag; a smooth 1/rev signal peaks on the edge ("gross").
  This is documented in `checkAlignment` LIMITATIONS; a low peak is the sign.
- `matlab-audit`: 77 files at 0.1.0, **clean**; catalogue 28 identifiers
  (+5). `matlab-docs --check`: 15 files, **in sync** (+3 pages, +3 help
  examples).

**Prediction** (before any run): **353 + 0 + 0 = 353** with the
gracefoReading checkout (without it: 345 + 0 + 8).

| class | contract | reference | precision | robustness | metamorphic | vectorisation | speed | untagged | total |
|---|---|---|---|---|---|---|---|---|---|
| unchanged from X-04 | 31 | 39 | 5 | 37 | 6 | 3 | 1 | 180 | 302 |
| TestConfig (+2: align) | 6 | | | 3 | | | | | 9 |
| TestHelpExamples (+3) | 9 | | | | | | | | 9 |
| TestAlign (new) | 1 | 2 | 1 | 8 | 2 | 1 | 1 | | 16 |
| TestCheckAlignment (new) | 2 | 3 | 1 | 7 | 2 | 1 | 1 | | 17 |
| **sum** | **49** | **44** | **7** | **55** | **10** | **5** | **3** | **180** | **353** |

(The first row is the X-04 total, 315, less TestConfig 7 and
TestHelpExamples 6 = 302, whose new counts are listed separately.)

**CI run 35829306740 on `b9fc10b` (2026-09-23): 351 + 2 + 2 = 353**, all
other tags as predicted. `constantUndetermined` and
`disjointSpansUndetermined` both errored (counted failed and incomplete)
with `MATLAB:string:MissingNotSupported`: the undetermined warning built its
message with `string(NaN)`, which is `<missing>`, and `warning` refuses
it. Fixed by formatting the lag with `compose("%.4g", …)`. The two tests
were the fault injection that found it.

**Verdict, CI run 35831044729 on `d44d9b7` (2026-09-23), MATLAB R2026a,
gracefoReading `v1.1.0`:** `audit` green; `matlab` green, **353 + 0 + 0 =
353**, as predicted. Gate time 949 s.

**Debt.**
- Tier A: there is no local MATLAB, so the MATLAB verdict is CI's.
- **Warning identifiers are not audited.** The profile `public` in
  `.github/matlab-audit.json` has `"warnings": false`, so the three
  `checkAlignment` warnings are documented in its WARNINGS section but are
  neither checked (A5/A6) nor catalogued. Switching it on is a `.github/`
  change and stands alone (GUIDE §1).

---

## X-04 — merged 2026-09-23 (PR #38, issue #7), release 0.1.0; scope was frozen 2026-09-23

Tier B. R-1 (ATBD) read from the copy the owner supplied in this session
(SHA-256 `166778a94553f43ad9cd7f6be45528e7fb4e978e334a22f1a92bd565510b5a8d`,
54 pages), Appendix B, printed p. 39 = PDF p. 40, from the page image. The
exponent N_c stands on **each** passband term, as CONCEPT 8 records.

**One printing inconsistency, resolved by measurement.** F^Norm is printed as
Σ_i cos(2πf0 i/fs) Σ_k H_k cos(2πkn/N_f): the inner cosine carries n inside a
sum over i. Read as n → i, F^Norm makes the response at f0 exactly 1, and the
kernel reproduces every number CONCEPT 8 recorded from the 2026-09-19 reading:
DC gain 1 + 1.115e-7 (ACC), 1 + 1.10e-11 (KBR); the misplaced exponent gives
1.0004533. The derivative formulas (PDF p. 41) carry the same i/n swap in the
summation index and are read the same way.

True after the merge:
- `timeSeriesPreparation.crnKernel(preset)`: taps F_n and the derivative
  kernels of ATBD App. B, presets `"ACC"` (T_f 140.7 s, B 0.035 Hz) and `"KBR"`
  (70.7 s, 0.1 Hz), f_s 10 Hz, N_c 7, f0 0.37 mHz; explicit parameters by name.
  `"LRI"` refuses (V-2 LRI numbers open). No warning for GRACE-FO ACC (CONCEPT 8).
- `timeSeriesPreparation.crnApply(arc, kernel)`: convolution evaluated only at
  the output epochs (item 11), bit-identical to full rate then sampling and to
  chunked evaluation; NaN wherever the window is incomplete (edges, gaps, NaN
  or removed samples), recorded as layer `crnWindow`; derivative 0/1/2.
- `Arc.derive`: an arc on new epochs carrying the metadata and provenance.
- ORC-1: `tests/oracles/crn_atbd_asprinted.py` (NumPy, from the page) and the
  taps it generated, pinned in `TestCrnKernel`.
- CONCEPT 6.1 row 4 corrected (it still said "DC gain 1.0004533 kept", which
  section 8 voided at Rev 0.14).
- Release **0.1.0**: `Contents.m`, every footer, `CHANGELOG.md`.

Out of scope: LRI preset (V-2), the ACT1A → ACT1B frequency-response check
(X-12, needs L1A data), time-tag corrections, lifting a model to 10 Hz (the
application's), the release workflow (a `.github/` change stands alone).

**Measured before the push (2026-09-23, ci-actions `v1.3.2`, NumPy oracle):**
- ORC-1 oracle: ACC N_f 1407, N_B 5, DC gain − 1 = 1.115160e-07; KBR N_f 707,
  N_B 7, 1.101075e-11; power on the sum instead: 4.5328e-04 (ACC). Gain at f0
  1 to 2e-16; derivative kernels equal i2πf and (i2πf)² times the response to
  ≤ 1.8e-13 in the passband.
- `matlab-audit`: 72 files at 0.1.0, **clean**; `matlab-docs --check`: 12
  files, **in sync**.

**Prediction** (before any run): **315 + 0 + 0 = 315** with the
gracefoReading checkout (without it: 307 + 0 + 8, as before).

| class | contract | reference | precision | robustness | metamorphic | vectorisation | speed | untagged | total |
|---|---|---|---|---|---|---|---|---|---|
| unchanged from X-01 + X-03 | 19 | 33 | | 18 | 1 | | | 180 | 251 |
| TestArc (+2: derive) | 8 | | 1 | 11 | 1 | 1 | | | 22 |
| TestConfig (+2: crn preset) | 5 | | | 2 | | | | | 7 |
| TestHelpExamples (+2) | 6 | | | | | | | | 6 |
| TestCrnKernel (new) | 2 | 3 | 4 | 3 | 2 | | | | 14 |
| TestCrnApply (new) | 2 | 3 | | 5 | 2 | 2 | 1 | | 15 |
| **sum** | **42** | **39** | **5** | **39** | **6** | **3** | **1** | **180** | **315** |

(The first row is the X-01 + X-03 total, 280, less TestArc 20, TestConfig 5
and TestHelpExamples 4 = 251, whose new counts are listed separately.)

**Verdict, CI run 35824079077 on `046cfc8` (2026-09-23), MATLAB R2026a,
gracefoReading `v1.1.0`:** `audit` green; `matlab` green, **315 + 0 + 0 =
315** on the first run, every tag as predicted (precision 5, reference 39,
robustness 39, speed 1, vectorisation 3). The MATLAB kernel matched the NumPy
oracle within the stated bounds, and the output-epoch and piecewise
evaluations were bit-identical. Gate time 954 s.

**Debt.** Tier A (no local MATLAB). The tag `v0.1.0` and its GitHub release
are made after the merge (GUIDE §3); this repository has no release workflow
yet and a `.github/` change stands alone, so the tag is the owner's, or a
separate PR adopting ci-actions `matlab-release` (`mode: file`).

---

## X-01 + X-03 — merged 2026-09-23 (PR #37); scope was frozen 2026-09-22 (issues #4, #6), one batch PR

Owner decision 2026-09-22: X-01 and X-03 as **one batch PR**, one commit per
WP (GUIDE §1 standing rules). Tier B. Help footer wording set by the owner:
`… | Matthias Weigelt with the help of Claude Code (Anthropic)` (applied to
every footer, Q5).

**X-01 — sigtools v1.3.1 import, unchanged** (CONCEPT 3.2, 12.9). True after
the merge:
- `spectral/` (10) → `+timeSeriesPreparation/+spectral/`, `tsmodels/` (15) →
  `+timeSeriesPreparation/+tsmodels/`, `sigtoolsDemo` and the 6 demo scripts →
  `demos/`, the 15 class suites and the legacy `runAllTests` →
  `tests/sigtools/`.
- The **only** code change is the one a namespace forces: calls between
  sigtools functions, and from its tests and demos, are qualified
  (`timeSeriesPreparation.tsmodels.tsFitArima`). Numerics are byte-identical,
  which a `reference` test checks against the archived zip on every run:
  every imported file equals its original once the qualifiers are removed.
- The imported suite runs in the gate and is counted: 180 class-based tests
  plus the 29 legacy cases, one test each (209, as sigtools' HANDOFF states).
- Not imported, each replaced: `sigtools_setup` (by
  `setupTimeSeriesPreparation`, which now also adds `demos/`),
  `runSigtoolsTests` (by the gate), `Contents.m` (by one per subpackage),
  hand-made `doc/html` (by C-03 output at X-02). README and HANDOFF stay in the
  zip.
- Conventions stay as imported (help style, unprefixed identifiers, no
  `arguments` blocks, plotting inside functions): that is X-02. The audit
  gives the imported files their own profile, and the tag policy exempts
  `tests/sigtools/`, each with that reason, until X-02.

**X-03 — `Arc`, `Config` skeleton** (CONCEPT 5, 5.2). True after the merge:
- `timeSeriesPreparation.Arc(t, obs, aux)`: value class built from
  gracefoReading's triple by field names, calling no gracefoReading function;
  int64 gpsns time only (`Arc:timeFormat`); columns selected by name, never by
  position; `weights`, `layers` (true = remove), `filled`, append-only
  `provenance`.
- **Release in the metadata and the one-release rule (5.2):** the L1B release
  is read from each file name (header `product_version` as fallback), stored
  in `Arc.release` and in provenance; more than one release in an arc, or
  across a campaign (`Arc.requireOneRelease`), refuses unless asked for.
- `timeSeriesPreparation.Config`: the nine sections of CONCEPT 5, a schema
  per section (unknown field → error), `Config(arc)` records the product; no
  product preset yet (presets arrive with their stages, X-04 on).
- `contract` tests pin the `aux` fields `Arc` reads, on gracefoReading's real
  fixtures (`readL1b`, `readL1bMulti`, a classic binary file).

Out of scope: X-02 conventions, presets and product dictionaries (X-04,
X-10, X-13), campaign storage (X-15), any stage.

**Measured before the push (2026-09-22, ci-actions `v1.3.2`):**
- Import rewrite: 6 + 13 qualified calls in the package (the call graph of
  the 25 functions, read beforehand), 52 in demos, 296 in tests, plus one
  `evalc` string by hand. With the qualifiers and the `sigtools_setup` →
  `setupTimeSeriesPreparation` rename undone, **every imported file is
  byte-identical to the archive** (checked here with `cmp`; in CI by
  `TestSigtoolsImport`).
- `matlab-audit`: 68 files, **clean**; `matlab-docs --check`: 10 files,
  **in sync**.

**Prediction** (before any run; the 180 is sigtools' HANDOFF count, not
re-counted here): **280 + 0 + 0 = 280** with the gracefoReading checkout;
without it, TestArcContract's 7 and `gracefoReadingResolvesWhenCheckedOut`
are incomplete: 272 + 0 + 8.

| class | contract | reference | precision | robustness | metamorphic | vectorisation | untagged | total |
|---|---|---|---|---|---|---|---|---|
| sigtools suites (15, tests/sigtools, exempt) | | | | | | | 180 | 180 |
| TestSigtoolsLegacy | 1 | 29 | | | | | | 30 |
| TestSigtoolsImport | | 2 | | 3 | | | | 5 |
| TestSigtoolsDemos | 7 | | | | | | | 7 |
| TestArc | 7 | | 1 | 10 | 1 | 1 | | 20 |
| TestArcContract | 4 | 2 | | | 1 | | | 7 |
| TestConfig | 3 | | | 2 | | | | 5 |
| TestHelpExamples (generated) | 4 | | | | | | | 4 |
| TestCiGate | 1 | | | 2 | | | | 3 |
| TestLayering | 1 | | | 6 | | | | 7 |
| TestRequirePackage | 4 | | | 2 | | | | 6 |
| TestTagPolicy | 1 | | | 5 | | | | 6 |
| **sum** | **33** | **33** | **1** | **30** | **2** | **1** | **180** | **280** |

**First CI run, 35774284097 on `ba16a96`, MATLAB R2026a:** green, but
**273 + 0 + 7** against the predicted 280 + 0 + 0. All 7 of TestArcContract
were filtered by an assumption although gracefoReading resolved. Cause,
measured: the ACH1B fixture entered gracefoReading's `tests/realdata` after
`v1.1.0` (its PR #28, untagged), and CI checks out `v1.1.0`. Fix: the YAML
fixture is now `MAS1B_2020-01-01_C_04.txt` (present at `v1.1.0`), and a
missing fixture **fails** once gracefoReading resolves, instead of hiding
behind the assumption; MAS1B's prod_flag NaN compared with `isequaln`.
Every other class ran as predicted (sigtools' 180 confirmed; demos 7/7;
import identity 5/5; legacy 30/30). Gate time 953 s.

**Verdict, CI run 35777061630 on `0fda5fb`, MATLAB R2026a, gracefoReading
`v1.1.0`:** `audit` green; `matlab` green, **280 + 0 + 0 = 280**, every
class and every tag as predicted (TestArcContract 7/7 on MAS1B and classic
ACC1B). Gate time 960 s.

**Debt, with its reason.** Tier A (no local MATLAB in this session). The
imported files keep sigtools' conventions and are exempt from the help
template and the tag policy until X-02, by design (CONCEPT 12.9).

---

## X-00b — merged 2026-09-22 (PR #36, issue #3)

Tier B: no local MATLAB; the MATLAB suite runs in CI on the self-hosted runner.
Branch `claude/grace-timeseries-issues-28g3a4` (named by the session
environment, not by GUIDE step 2's pattern).

True after the merge:
- **Skeleton**: `+timeSeriesPreparation/Contents.m` at version **0.0.0**
  (unreleased; X-04 makes 0.1.0), `setupTimeSeriesPreparation.m`,
  `timeSeriesPreparationCiGate.m` (the gate command of GUIDE §2), `tests/`.
- **CI** `.github/workflows/ci.yml`: job `audit` (ci-actions `matlab-audit` and
  `matlab-docs` in check mode) and job `matlab` (`matlab-probe`, optional
  gracefoReading checkout, the gate), actions pinned to ci-actions `v1.3.2`.
- **Documentation pipeline**: `.github/matlab-audit.json`,
  `.github/matlab-docs.json` (adjusted from ci-actions' untested proposals),
  generated `html/`, `info.xml`, `docs/errorIdentifiers.md`,
  `tests/TestHelpExamples.m`.
- **Test tags**: the seven categories of CONCEPT 9 are the only allowed tags;
  every test carries at least one (`TestTagPolicy`, fault-injected).
- **Layering test**: CONCEPT 3.2 checked mechanically (`TestLayering`,
  fault-injected): calls go downward or sideways, never upward; L0 never calls
  gracefoReading; no package code calls lsqvce.
- **Optional gracefoReading**: `timeSeriesPreparation.internal.requirePackage`
  raises `timeSeriesPreparation:<fn>:depMissing` (CONCEPT 3.1); the layering
  test demands it in every file that references gracefoReading.

Out of scope: sigtools (X-01), any public function (X-03 on), the release
workflow (first release is X-04), lsqvce checkout (tests only, from X-07), the
data pool (first real-data test), required checks (O-2, owner).

**Measured before the push (2026-09-22, Python 3.11, ci-actions `v1.3.2`):**
- `matlab-audit`: 9 files at version 0.0.0, **clean**; `matlab-docs --check`:
  7 generated files, **in sync**.
- Adopted configuration fault-injected by hand, each restored afterwards: a
  missing ACCURACY fires A2, a footer at 0.0.1 fires A3, an undocumented
  raised identifier fires A6, a file without help fires A1, an edited EXAMPLE
  fires D1 (docs out of date).

**Prediction** (before any run): 22 + 0 + 0 = 22 with the gracefoReading
checkout; 21 + 0 + 1 = 22 without it (`gracefoReadingResolvesWhenCheckedOut`
incomplete).

| class | contract | robustness | total |
|---|---|---|---|
| TestCiGate | 1 | 2 | 3 |
| TestHelpExamples (generated) | 1 | 0 | 1 |
| TestLayering | 1 | 6 | 7 |
| TestRequirePackage | 4 | 2 | 6 |
| TestTagPolicy | 1 | 4 | 5 |
| **sum** | **8** | **14** | **22** |

**Measured in CI, run 35771631191 on `1be3033` (2026-09-22), MATLAB R2026a
Update 5, self-hosted Windows:** `audit` green; `matlab` green with
gracefoReading `v1.1.0` resolving from `deps/`: **22 + 0 + 0 = 22**
(contract 8, robustness 14), every class as predicted. The search database
was built by the generated `html/buildSearchDatabase.m`, and the
`TestHelpExamples` class that ci-actions generates ran in MATLAB for the first time.
This clears the ci-actions debts "neither `action.yml` loaded by a runner"
(for `matlab-audit`, `matlab-docs`) and "`TestHelpExamples` never executed".

**Debt, with its reason.**
- Tier A: no local MATLAB in this session; the MATLAB verdict is CI's (tier B).
- ~~Help footer wording~~ — settled by the owner 2026-09-22 (see X-01 + X-03).
- ci-actions `matlab-audit/examples/timeSeriesPreparation.json` and
  `matlab-docs/examples/timeSeriesPreparation.json` still hold the untested
  proposal; the measured configuration is `.github/*.json` here. Updating the
  examples is a ci-actions PR (one repository per PR).

---

## A. Status

**X-07 merged (PR #44, `f7d3518`; CI 489 + 0 + 0). Issue #10 stays open for the reference noise-model library, blocked on sources.**
lsqvce CI dependency merged (PR #43, `5afbd87`; CI 421 + 0 + 0).
Release workflow merged (PR #42, `298b7cd`); its first run
released nothing, as designed. `.github/` profile switch merged (PR #41,
`7b94df4`). X-02 merged (PR #40, `7fe24f3`). X-06 merged (PR #39,
`4f9e11e`). X-04 merged (PR #38, `f969ecb`, release 0.1.0). The tag `v0.1.0` is lightweight and sits on
`7fe24f3` (owner, release UI; GUIDE §3 anomaly table). X-01 + X-03 merged
(PR #37); X-00b (PR #36); X-00a (#2).

**Phase 0 complete (2026-09-19):**
- Stage A: repositories, settings and issues.
- Stage B: data D-1 … D-8 and D-10; D-9 pending.
- Stage C: references and V-items (CONCEPT 9.3).
- 0.4: lsqvce V-6 answered; `v6.1.0` tagged on `21e470d` and released.

C-01 and C-03 are merged in ci-actions (#6, closed 2026-09-20; tags up to
`v1.3.2`). Next: X-07 (#10); X-05
(#8) also waits on V-12 (defect catalogue, D-9).

**GUIDE A5 done:** one issue per WP, X-00b … X-18 = #3–#21 (map in GUIDE Appendix A).

| item | state |
|---|---|
| repository | private, `main`; auto-delete head branches on; MIT licence (owner, 2026-09-18) |
| ruleset `Main Protection` | no deletion, no force push; **no required checks yet** (see O-2) |
| ruleset `Tag protection` | `~ALL`, no deletion, no force push |
| content | `docs/CONCEPT.md` Rev 0.16, `docs/GUIDE.md` rev 1.11, `docs/inputs/` (4 files), this HANDOVER, README; code as below |
| code, `Contents.m`, CI, audit | X-00b: setup, gate, `ci.yml` (`audit`, `matlab`), shared audit and generator. X-01: `+spectral`, `+tsmodels`, `demos/`, `tests/sigtools/`. X-03: `Arc`, `Config`. X-04: `crnKernel`, `crnApply`, `Contents.m` 0.1.0 |
| `docs/GUIDE.md` | rev 1.11 (release workflow; `v0.1.0` anomaly) |
| `docs/CONCEPT.md` | Rev 0.16 (X-07: the L2 unit `noise`) |
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

**Verification available now (X-00b):** static audit and docs check (job
`audit`), MATLAB gate `timeSeriesPreparationCiGate` (job `matlab`).

---

## E. Obligations

| id | obligation | status | owner | re-entry |
|---|---|---|---|---|
| O-1 | X-00b: skeleton, CI, audit (C-01), documentation pipeline, test tags, layering test, references register | **closed 2026-09-22** (PR #36 merged, `2ecf543`) | — | — |
| O-2 | add the required checks `audit` and `matlab` to `Main Protection`; both contexts exist since run 35771631191 (2026-09-22) | open | owner | now |
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

1. A new unit must be added to the layer map in `tests/TestLayering.m`, or
   the layering test fails. sigtools lives in `+spectral`/`+tsmodels`
   **unchanged**: any edit there beyond a namespace qualifier fails
   `TestSigtoolsImport` until X-02 changes that test with the conventions.
2. `Main Protection` requires no checks until O-2 is done. The X-00a PR was the
   only merge meant to happen without CI.
3. Never unpack the zips in `docs/inputs/`.
