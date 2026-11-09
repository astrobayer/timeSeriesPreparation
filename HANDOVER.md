# HANDOVER — timeSeriesPreparation

**Revision 0.45 · 2026-11-09 · the repository owns its test-data list, `tests/data/SOURCES.json`, checked by `TestDataSources`; release 1.6.0 (PR open)**

This file is the single point of truth for this repository's **status,
obligations and repository-level decisions**. It points at, and never
restates:
- `docs/CONCEPT.md` — the design, with the design decisions in its section 11;
- `docs/GUIDE.md` — the order of work and every procedure.

---

## Test-data list in the repository, and release 1.6.0 — 2026-11-09 (PR open); scope frozen 2026-11-09

**Owner, 2026-11-09 (through the toolboxInstaller session):** the
repository owns its test-data list. Until now toolboxInstaller's
registry (`registry/timeSeriesPreparation.json`, `tests.data.sources`)
named the third-party files the real-data tests read from the pool, and
nothing tied that list to the tests. The installer will read it from
this repository.

**Scope (frozen):**
- `tests/data/SOURCES.json` (new; `tests/data/samples/` stays as it is):
  `{"schema": 1, "sources": [...]}`, the registry's array copied
  verbatim with Python `json.load` / `json.dump(ensure_ascii=False,
  indent=2)`, UTF-8, LF. 15 sources, 26 files, paths relative to the
  DATAPOOL root.
- `tests/TestDataSources.m` (new, 9 tests): contract - the file parses at
  schema 1; every entry carries id, url, files, MB, licence, licenceText,
  description (unique ids, https, MB > 0, sha256 64 hex where present,
  relative paths); every listed file sits in a layout the pool tests look
  in (`GRACEFO\L1A|L1B\RL04\<yyyy>\<date>\`, `GRACE\L1B\JPL\RL02\<yyyy>\`,
  `GRACEFO-1|2\`); every listed file's product and date are named by a
  test that reads the pool; every day a pool test names with literal
  product, date and satellite (`readDay` / `dayFile`) is listed.
  Robustness - each of the four findings fires on a planted manifest or
  test text.
- Documentation: GUIDE rev 1.13 (section 5), README status.
- `.github/workflows/ci.yml`: **comments only** - the header and the job
  `env` comment name `DATAPOOL` first and `READING_DATA_POOL` as the
  fallback the workflow passes. No variable, step or pin changes. In its
  own commit; the owner asked for one PR per repository, so GUIDE
  section 1's "workflow changes stand alone" is departed from for a
  comment-only edit, as 1.5.1 did for a pin.
- Release 1.6.0 (MINOR: the repository now supplies the installer's
  test-data list; no toolbox function changes): `chore: version 1.5.2 ->
  1.6.0` as its own commit over every literal, CHANGELOG section, README
  status.
- Not in scope: toolboxInstaller (it switches to reading the file);
  deriving pool names that the tests compute in loops (`TestCrnVerification`'s
  `poolFile`, the `cases` table of DC-3, the satellite loops of
  `TestIntegration`) - they are covered by the product-and-date direction
  only.

**Prediction** (before any run): **737 total** (728 + 9). Tags: contract
230 (225 + 5), robustness 144 (140 + 4), reference 263,
precision 23, metamorphic 44, vectorisation 21, speed 12. Without a pool
variable exactly the 14 pool tests incomplete, **723 + 0 + 14**; with
`DATAPOOL=E:\DATAPOOL`, **737 + 0 + 0**. `TestDataSources` reads no pool
and downloads nothing, so it is 9/9 in both.

**Fault injection** (local, not committed): the four robustness tests plant
each finding (duplicate id, missing url, absolute path, malformed sha256;
a file without its day folder; an unread KBR1B day; an unlisted literal
THR1B day) and the healthy case. On copies of `tests/` with the real list
mutated (`matlab -batch`, R2026a): healthy 9/9; THR1B 2020-01-04 dropped
fails exactly `everyLiteralPoolDayIsListed`; the ITSG file moved out of
`GRACEFO-1\` fails exactly `everyFileSitsWhereThePoolTestsLook`;
**TIM1B C/D of 2020-01-02 dropped is NOT caught** (9/9) - TIM1B is named
only through `poolFile`'s computed arguments. That is the limitation the
scope names, measured.

**Tier A verdict (2026-11-09, R2026a, matthiaspc, worktree
`_wt/timeSeriesPreparation-sources` at `e3c3dd8`,
`matlab -batch "timeSeriesPreparationCiGate(Coverage=false, SearchDatabase=false)"`
with deps at CI's pins: gracefoReading v1.3.0, lsqvce v7.0.1, exported to
`deps/`; `DATAPOOL=E:\DATAPOOL`, `READING_DATA_POOL` unset): 737 + 0 + 0 =
737**, as predicted; contract 230, metamorphic 44, precision 23, reference
263, robustness 144, speed 12, vectorisation 21, every tag as predicted;
1721 s. **Not measured:** the no-pool environment (predicted 723 + 0 + 14;
`TestDataSources` reads no pool) and the CI tier. Static audit (ci-actions
v1.3.2) clean at 1.6.0 (146 files), docs in sync (76 generated files).

## Data pool rule, and release 1.5.2 — 2026-11-08 (PR open); scope frozen 2026-11-08

**Owner, 2026-11-08:** "All data go always to the data pool. Only model
code or libraries go to the toolbox." The contract is toolboxInstaller
`docs/DATA_POOL.md`: pool root = an explicit option, then
`getenv("DATAPOOL")` (the installer's `startup.m` sets it), then
`getenv("READING_DATA_POOL")` (the older name, still honoured, never
required). **This toolbox downloads nothing**, so only the tests read the
pool, and the installer's missing `READING_DATA_POOL` for this package
(Q12 record, "not in scope") is answered by `DATAPOOL`.

**Scope (frozen):**
- `tests/dataPoolRoot.m` (new helper, not a test): `DATAPOOL`, else
  `READING_DATA_POOL`; the first variable that is set decides; with
  neither, `assumeNotEmpty` (incomplete, never passed), the message names
  both variables and the WP. It replaces the five `getenv("READING_DATA_POOL")`
  reads of `TestCrnVerification` (X-12), `TestDefectCatalogue` (D-9),
  `TestIntegration` (V-4 real day, X-13 classic days) and `TestTemplates`
  (X-17). The layout below the root is unchanged.
- GUIDE rev 1.12 (section 2 table, section 5) and `docs/references/REFERENCES.md`.
- Release 1.5.2 (PATCH: tests and documentation only): `chore: version
  1.5.1 -> 1.5.2` as its own commit over every literal (217 files: 1.5.1's
  216 and the helper), CHANGELOG section, README status.
- Not in scope: `.github/workflows/ci.yml` (it passes
  `READING_DATA_POOL`, a valid fallback; its comment still names only that
  variable).

**Prediction** (before any run): **728 total** (no test added or removed;
the helper is a function file, not a test class), every tag total as at
1.5.1. Without a pool variable exactly the 14 pool tests incomplete,
714 + 0 + 14; `DATAPOOL` and `READING_DATA_POOL` set to the same pool give
the same verdict.

**Tier A verdict (2026-11-08, R2026a, worktree `_wt/timeSeriesPreparation-datapool`
at `6f7bbce`, `timeSeriesPreparationCiGate(Coverage=false, SearchDatabase=false)`
with deps at CI's pins: gracefoReading v1.3.0, lsqvce v7.0.1, exported to
`deps/`):**
- neither variable: **714 + 0 + 14 = 728**, the 14 incomplete each with
  "Neither DATAPOOL nor READING_DATA_POOL is set" (D-9 x8, X-12 x3, V-4,
  X-13, X-17); contract 225, metamorphic 44, precision 23, speed 12,
  vectorisation 21 full, reference 250 of 263, robustness 139 of 140;
- `DATAPOOL=E:\DATAPOOL`: **728 + 0 + 0 = 728**, every tag full. **This
  host's pool changed again since 1.5.1** (2026-11-07: no `GRACEFO` folder,
  714 + 11 + 14): it now holds every day the suite reads;
- only `READING_DATA_POOL=E:\DATAPOOL` (the fallback): **728 + 0 + 0 = 728, the same as with DATAPOOL**.

The total is as predicted in all three. Static audit (ci-actions v1.3.2)
clean at 1.5.2 (145 files), docs in sync (76 generated files).

## Q12 against lsqvce v7.0.1, and release 1.5.1 — 2026-11-07 (PR open); scope frozen 2026-11-07

**Found** by running the suite through toolboxInstaller (2026-11-07),
which installs lsqvce's newest release, v7.0.1, where CI pinned v6.1.3:
`TestLsqvceAgreement/psdToAcvAgrees` failed for both spectra, by up to
1.1e-4 (6.6e-6 of r(0)) at lag 49, growing like lag^2. **Cause, read
in lsqvce:** since v6.6.2 (WP-111, "the PSD law's ACV without a lag
period") `lsqvce.kernel.psd2acv` integrates the piecewise-linear
interpolant of S exactly against the cosine, where the test assumed the
trapezoid on both sides. Measured against the exact autocovariance of
the AR(1) law the spectrum is built from, r(k) = phi^k / (1 - phi^2):
`spec2acv` is within 5.7e-14 (ar09) and 2.1e-16 (ar097) of r(0);
`psd2acv` v7.0.1 within 2.4e-6 and 6.6e-6. So at these lags the newer
lsqvce kernel is the less accurate one; that is lsqvce's trade (no
periodic wrap at long lags), recorded here, not changed here.

**Scope (frozen):**
- `psdToAcvAgrees`: each kernel against the exact r(k), `spec2acv` to
  1e-12 r(0), `psd2acv` to the bound (df^2/12) * integral |S''| df
  (from |S - S_lin| <= (df^2/8)|S''| per segment, averaged: df^2/12),
  computed in the test from the grid, plus 1e-12 r(0); the two to the
  sum. The class help states each tolerance and the measured values.
- CI: the test-only lsqvce pin v6.1.3 → v7.0.1 (`.github/workflows/ci.yml`).
- Release 1.5.1 (PATCH: a test fix and a dependency pin; no toolbox
  function changes): `chore: version 1.5.0 -> 1.5.1` as its own commit over
  every literal (216 files, as 1.5.0's), CHANGELOG section, README status.
- Not in scope: whether lsqvce should keep the short-lag accuracy it gave
  up in WP-111 (lsqvce's decision); the installer's missing
  `READING_DATA_POOL` for this package's tests (toolboxInstaller's registry).

**Prediction** (before any run): **728 + 0 + 0 = 728** on CI, unchanged
(no test added or removed); every tag as at 1.5.0: contract 225,
reference 263, precision 23, robustness 140, metamorphic 44,
vectorisation 21, speed 12.

**Fault injection** (local, not committed): with the bound halved,
exactly `psdToAcvAgrees(ar09)` and `(ar097)` fail; restored, the class is
14/14 with lsqvce v7.0.1 and 14/14 with v6.1.3 (`matlab -batch`, R2026a).

**Tier A verdict (2026-11-07, R2026a, `607ad26` + records,
`matlab -batch timeSeriesPreparationCiGate` with deps at CI's pins:
gracefoReading v1.3.0, lsqvce v7.0.1; `READING_DATA_POOL=E:\DATAPOOL`):
714 + 11 + 14 = 728** (the 11 failed are among the 14 incomplete: an
`assertNotEmpty` on a pool file). The total is as predicted; contract 225,
metamorphic 44, precision 23, speed 12, vectorisation 21 are full, reference
250 of 263, robustness 139 of 140. **`TestLsqvceAgreement` is 14/14 with
v7.0.1**, the failure this change is for. **Every non-pass is a DATAPOOL
file this host does not hold now:** `TestCrnVerification` x3 (no
Level-1A), `TestDefectCatalogue` dc1-dc8 (ACT1B, KBR1B, THR1B days of
2020 under `GRACEFO\L1B\RL04`), `TestIntegration` x2, `TestTemplates/
realThrusterDay`. **This host's pool changed since 1.5.0:** at X-19 it held
GRACE-FO L1B RL04 (5 failed + 8 incomplete); on 2026-11-07 `E:\DATAPOOL`
has no `GRACEFO` folder at all. Recorded as a tier debt for the CI runner,
which has the pool. Static audit (ci-actions v1.3.2) clean at 1.5.1, docs
in sync.

## X-19 — Config preset for the hybrid ACH1B, and release 1.5.0 — merged 2026-10-20 (PR #74, `977d10d`; issue #73 closed; v1.5.0 tagged by the workflow); scope was frozen 2026-10-20

Issue #73. Found by NonGravForces N-10b (NonGravForces PR #104), which
compares GRACE-D calibrations on ACT1B and ACH1B over 26 days of 2020-01
and, to prepare both alike, labels its ACH1B arcs "ACT1B" (a documented
workaround in its `tools/regressionBaseline.m`). `Config(arc)` gives
ACH1B no preset: no crn preset, no minimum-data gate, no mask bits.

**What the header says** (RL04, `ACH1B_2020-01-01_D_04.txt`, the real
120-record extract in gracefoReading `tests/realdata`, present at the
CI pin v1.3.0; byte-identical, CR aside, to NonGravForces'
`data/samples/acx` copy): the same nine data columns as ACT1B, with the
same names, units and column comments; the eight `qualflg` meanings
**word for word ACT1B's** (bits 5-7 the fill flags by distance from the
CRN centre, 3/4 the CLK1B extrapolation); `acl_*_res` "Residual of
lin_accl_* from non-CRN-filtered value", i.e. CRN-filtered at 1 Hz; summary
"1-Hz linear accelerations dervied [sic] from a hybrid transplant in SRF". The
only difference in the variable block: ACT1B's angular columns say
"0 for ACT1B". So every part of the ACT1B preset rests on a header fact
ACH1B shares, and all three parts are mapped.

**Scope (frozen):**
- `Config`: ACH1B takes ACT1B's preset - `crn.preset` "ACC",
  `unc.minWeightFraction` 0.5, `mask.removeBits` [5 6 7]. Help of
  `Config` (and of `mask`, `observability` where they list the presets).
- `TestConfig`: the preset tables gain ACH1B rows, and a new test reads
  the real ACH1B and ACT1B extracts through `gracefoReading.readL1b` and
  asserts the header facts the preset rests on (product, column names,
  units, the eight bit meanings equal ACT1B's, the CRN residual comment)
  and the preset of `Config` on the real arc.
- CONCEPT: row X-19 in 10.1, V-16 and 6.1 row 1 name ACH1B.
- Release 1.5.0 (MINOR: a preset for one more product; every caller keeps
  working, the only default that moves is ACH1B's): `chore: version 1.4.0
  -> 1.5.0` as its own commit over every literal, as in 1.4.0; CHANGELOG
  section, README status.
- Not in scope: `report`'s noiseReference overlay for ACH1B (it names
  ACT1B/ACC1B only; ACH1B is a hybrid of measurement and models, so its
  noise is not the instrument's without a measurement); removing the
  workaround in NonGravForces (its own later step).

**Prediction** (before any run): **728 + 0 + 0 = 728**, one more than
1.4.0 (the new TestConfig test, tagged reference). Per tag: contract
225, reference 263, precision 23, robustness 140, metamorphic 44,
vectorisation 21, speed 12.

**Fault injection** (local, not committed): ACH1B taken out of the mask
case fails `TestConfig/ach1bPresetFromHeader` and
`TestConfig/maskDefaultsAndPresets`; restored, TestConfig is 15/15.

**Tier A verdict (2026-10-20, R2026a, `ef4e6b4`,
`matlab -batch timeSeriesPreparationCiGate` with deps at CI's pins:
gracefoReading v1.3.0, lsqvce v6.1.3; `READING_DATA_POOL=E:\DATAPOOL`):
720 + 5 + 8 = 728** (the 5 failed are among the 8 incomplete). The total
and every tag total are as predicted: contract 225/225, reference 256 of
263, robustness 139 of 140, precision 23, metamorphic 44, vectorisation 21,
speed 12. **Every non-pass is a DATAPOOL file this host does not hold**,
none touches `Config`: `TestCrnVerification` x3 (no Level-1A),
`TestDefectCatalogue` dc3/dc4/dc5 (no KBR1B of 2020-07),
`TestIntegration/realDayAgainstItsg` (no ITSG under GRACEFO-1) and
`classicDaysEndToEnd` (no classic RL02). The host's pool holds GRACE-FO
L1B RL04 only. Recorded as a tier debt: the CI runner, which has the
pool, gives the full verdict. Static audit (ci-actions v1.3.2) clean at
1.5.0, docs in sync.

**CI verdict (07c33c2, run 39412337364, matlab job 118592910534): 728 + 0
+ 0 = 728, green.** Every tag as predicted: contract 225, reference 263,
precision 23, robustness 140, metamorphic 44, vectorisation 21, speed 12.
The runner's pool completes all eight tests this host could not, which
clears the Tier A debt above. The gate reports `timeSeriesPreparation
v1.5.0`; audit was green. The matlab job took 38.0 min. The first run
(39409967168, on `ef4e6b4`) was cancelled in the queue, superseded when the record
commit was pushed.

**Merged** 2026-10-20 by the owner (PR #74, merge commit `977d10d`). The
release workflow (run 39422071366) tagged `v1.5.0`, annotated, on
`977d10d` and published the release.

**Next:** NonGravForces can drop the "ACT1B" label on its ACH1B arcs
(`tools/regressionBaseline.m`) and raise its timeSeriesPreparation
minimum to 1.5. That is its own step, in that repository.

## Release 1.4.0 — X-13; scope frozen 2026-09-28

Owner decision 2026-09-28 ("Release 1.4.0"), after PR #71 merged. MINOR:
classic GRACE arcs now carry units and flag meanings and get the ACC1B
fill-flag preset (X-13). Every GRACE-FO caller keeps working unchanged.
The only default that changes is classic ACC1B `mask.removeBits`, from
none to [5 6 7]. Before 1.3.0 of gracefoReading a classic arc had no
units, so `align` refused it anyway.

**Scope (frozen), as release 1.3.0 (PR #68):**
- `chore: version 1.3.0 -> 1.4.0`, its own commit (GUIDE 3): Contents.m,
  every help footer (version only; date and time move only where content
  changes), `docs/errorIdentifiers.md` and the generated html
  (regenerated), TestHelpExamples' header.
- CHANGELOG: "Unreleased" becomes "1.4.0 — 2026-09-28"; README status, and
  README's dependency line names gracefoReading >= 1.3.0 for classic arcs.
- Not changed: every literal naming another repository's version
  (gracefoReading 1.3.0, the CI pin `v1.3.0`, ci-actions tags) and literals
  naming the release in which something happened (Arc schema "2 since
  release 1.2.0", the example provenance record with version "1.2.0").
- The release workflow tags `v1.4.0` on the merge commit and publishes the
  release.

**Prediction** (before any run): **727 + 0 + 0 = 727**, unchanged. Per
tag: contract 225, reference 262, precision 23, robustness 140,
metamorphic 44, vectorisation 21, speed 12. The two version-dependent
checks (TestArc, TestCampaign) compare with `internal.toolboxVersion()`.

**CI verdict (bde3e1c, run 36385566964, matlab job 108810101306): 727 + 0
+ 0 = 727, green.** Per tag as predicted: contract 225, reference 262,
precision 23, robustness 140, metamorphic 44, vectorisation 21, speed 12.
The gate reports `timeSeriesPreparation v1.4.0`, and no line of the log
names this toolbox at 1.3.0 (the only `v1.3.0` is the gracefoReading
pin). The classic days log as on PR #71. The suite took 37.0 min, and
audit was green.

## X-13 — classic GRACE: masks, presets, a classic day end to end — merged 2026-09-28 (PR #71, `beaafa5`; issue #16 closed); scope was frozen 2026-09-27

Tier B. CONCEPT row X-13, V-8, issue #16, with the owner's decisions of
2026-09-27 (interview after v1.3.0).

**Found before the freeze (measured, with the fix placed where it belongs):**
- Classic headers carry neither units nor qualflg meanings, so with
  gracefoReading v1.2.0 a classic arc had no units: `align` refused it
  (`unitUnknown`), `mask` refused classic THR1B (on_time not in
  milliseconds) and every classic bit read "(not documented)". Owner:
  the reader supplies them, from JPL D-22027 v1.3 chapter 6 —
  **gracefoReading v1.3.0** (its PR #32, CI 162 + 0 + 1, tagged
  2026-09-27). CI moves to it in PR #70 (workflow only; CI 726 + 0 + 0,
  merged `71e7ce4`).
- The handbook's editing guidance matches the GRACE-FO presets: ACC1B
  4.3.2 names bits 5/6/7 (filled data), KBR1B 4.1.2 bit 0 (phase break);
  its bit tables (6.2, 6.7) equal the RL04 headers' for ACT1B and KBR1B.
- **The CRN span of classic ACC1B stays open.** Owner: fetch classic
  ACC1A. Scan PR #69 (closed unmerged, two rounds): ISDC's `grace/`
  holds DOCUMENTS, GravIS, IONOSPHERE, Level-1B, Level-2, ORBIT and
  SOFTWARE; every `grace/Level-1A/…` path answers 403, while GRACE-FO's
  Level-1A is served. PO.DAAC needs an Earthdata login the runner does
  not have. V-1's classic half waits for another ACC1A source.

**Owner decisions (2026-09-27):**
- units and meanings from the reader (gracefoReading 1.3.0), not a second
  table here;
- classic presets = the GRACE-FO ones (ACC1B removes bits 5 6 7; KBR1B
  0 6 7 with SNR fraction 0.5, as now); the handbook's absolute KBR SNR
  (> 450 in 0.1 dB-Hz) is recorded, not used;
- integration: one real ACC1B day for A and B end to end; no mission-
  aware strings and no classic template bank in this WP.

**Scope (frozen):**
- `Config`: ACC1B of mission GRACE gets `mask.removeBits = [5 6 7]`
  (D-22027 4.3.2). GRACE-FO ACC1B keeps none: its bits were never
  measured here. KBR1B is unchanged (both missions).
- `TestIntegration/classicDaysEndToEnd` (reference; ORC-9, real classic
  files): ACC1B and THR1B of 2008-07-02, A and B, from
  `DATAPOOL\GRACE\L1B\JPL\RL02\2008\2008-07-02\`, through `run` with
  QualFlags and Thrusters. Asserted: mission GRACE, release 02, units
  m/s2; stages mask (and fill), align/qc skipped for want of a
  reference; the qualflg layers equal the bits decoded independently by
  `decodeQualFlags` and carry the handbook meanings; a THR1B layer with
  firings; the epochs and observations are unchanged where kept.
- `TestArcContract/arcFromClassicBinary`: the classic arc's units are
  the handbook's (m/s2, rad/s2).
- `TestCrnVerification` reads CLK1B through `gracefoReading.readL1b`
  (v1.2.0 reads it) instead of its local parser; the numbers are the same.
- `TestConfig`: the classic ACC1B preset and the GRACE-FO ACC1B without
  one, as rows of the existing preset table.
- CONCEPT: X-13 row, V-8 closed, V-1's classic half open with the reason;
  help (`Config`, `mask`), CHANGELOG Unreleased.

Out of scope (owner): exportNetcdf's keyword "GRACE-FO" and run's DataCite
resourceType for classic arcs; `report`'s reference ASD (noiseReference
covers GRACE-FO only, and `report` draws it for classic ACC1B/KBR1B too);
the classic THR1B template bank. Recorded as debt below.

**Tests (predicted):** TestIntegration +1 (reference). Every other change
adds rows or assertions to existing tests.
**Prediction: 727 + 0 + 0 = 727.** Per tag: contract 225, reference 262,
precision 23, robustness 140, metamorphic 44, vectorisation 21, speed 12.

**Verdict, CI run 36349933110 on `5fc32e1` (PR #71, 2026-09-27), MATLAB
R2026a, gracefoReading v1.3.0: 727 + 0 + 0 = 727**, the prediction met in
total and on every tag (contract 225, reference 262, precision 23,
robustness 140, metamorphic 44, vectorisation 21, speed 12).
- Classic days, measured: A 86 400 epochs, 28 144 removed (thr 28 144,
  608 firings); B 86 400 epochs, 43 683 removed (thr 43 683, 1 262
  firings). **No record of either day sets bit 5, 6 or 7**, so on real
  data the qualflg layers are all false and only the fault injection
  below shows that the preset reaches them. A classic day with filled
  data would test it on real records; none is in the pool's test days.
- Fault injection (commit on PR #71, reverted after): classic ACC1B
  `removeBits = [5 6]`. Predicted 725 + 2 + 0 (contract 224 + 1:
  `TestConfig/maskDefaultsAndPresets`; reference 261 + 1:
  `TestIntegration/classicDaysEndToEnd`, which finds no layer
  `qualflg_b7`). The `TestArcContract` units assertion is not injected:
  its fault is gracefoReading < 1.3.0, a workflow change that may not
  share this PR (`.github/` stands alone); v1.2.0 returned no classic
  units, which is what the assertion guards against.
- **Fault run, CI job 108719939160 on `9db6803`: 725 + 2 + 1 = 727.**
  Exactly the two predicted tests fail, and nothing else:
  `TestConfig/maskDefaultsAndPresets` ("ACC1B": actual [5 6], expected
  [5 6 7]) and `TestIntegration/classicDaysEndToEnd` (`MATLAB:
  nonExistentField`, "Unrecognized field name qualflg_b7"). The one
  incomplete was mispredicted: MATLAB counts a test that errors as both
  failed and incomplete (reference 261 + 1 + 1). For a fault that errors,
  predict it that way. Reverted in `07baae5`.
- **Final verdict, CI run 36356980231 on `07baae5` (job 108726558153):
  727 + 0 + 0 = 727**, every tag as predicted; the classic days log the
  same numbers as on `5fc32e1`. X-13 is green and waits for the owner's
  merge.

## Release 1.3.0 — X-11 + X-12 — merged 2026-09-27 (PR #68, `bc3415a`; v1.3.0 tagged by the workflow); scope was frozen 2026-09-27

Owner decision 2026-09-27 ("Release 1.3.0"), after PR #67 merged. MINOR:
`report` (X-11) is new capability that leaves every caller working; X-12
adds a test and documentation only.

**Scope (frozen):**
- `chore: version 1.2.0 -> 1.3.0`, its own commit (GUIDE 3): Contents.m,
  every help footer (version only; the date and time move only where
  content changes), `docs/errorIdentifiers.md` and the generated html
  (regenerated), TestHelpExamples' header.
- CHANGELOG: "Unreleased" becomes "1.3.0 — 2026-09-27"; README status.
- Not changed: literals that name the release in which something happened
  (`Arc` schema "2 since release 1.2.0", the example provenance record
  with version "1.2.0").
- The release workflow tags `v1.3.0` on the merge commit and publishes the
  release.

**Prediction** (before any run): **726 + 0 + 0 = 726**, unchanged. Per
tag: contract 225, reference 261, precision 23, robustness 140,
metamorphic 44, vectorisation 21, speed 12. The two version-dependent
checks (TestArc, TestCampaign) compare with `internal.toolboxVersion()`.

**CI verdict (2c72abd, matlab job 108620473944): 726 + 0 + 0 = 726,
green.** Per tag as predicted: contract 225, reference 261, precision 23,
robustness 140, metamorphic 44, vectorisation 21, speed 12. The gate
reports `timeSeriesPreparation v1.3.0`; no line of the log names 1.2.0.
The suite took 37.0 min and audit was green.

## X-12 — V-1: GRACE-FO CRN frequency response on ACT1A → ACT1B — merged 2026-09-27 (PR #67, `0fa7b4b`; issue #15 closed); scope was frozen 2026-09-27

Tier B. CONCEPT row X-12 and V-1, issue #15, with the owner's decisions of
2026-09-27, the uploaded GRACE L1B handbook (R-4, JPL D-22027 v1.3) and the
throwaway scan PR #66 (closed unmerged; three rounds, jobs 108572446547,
108579518163, 108583599314).

**Data.** The CI runner downloads the Level-1A days from ISDC
(`grace-fo/Level-1A/JPL/INSTRUMENT/RL04/<yyyy>/`) and keeps them in the
DATAPOOL under `GRACEFO\L1A\RL04\<yyyy>\<day>\` (owner decision). 2020-01-02
(`gracefo_1A_2020-01-02_RL04.ascii.noLRI.tgz`, 423 MB, 66 files) is there.
gracefoReading v1.1.0 reads ACC1A and ACT1A (864 078 × 28 at 10 Hz). Their
time tags are **OBC time** (`time_ref` R).

**Scan findings:**
- CRN(ACT1A) against ACT1B at the ACT1B epochs, C and D, 2020-01-02; the
  time mapping is OBC → receiver (TIM1B) → GPS (CLK1B,
  GPS = rcv_time + eps_time):

  | Tf | raw tags: rel rms per axis | TIM1B + CLK1B |
  |---|---|---|
  | **140.7 s** (ATBD, the preset) | 4e-5 … 3e-4, lag −0.01 s | **2e-6 … 2.5e-5**, lag 0.00 s |
  | 70.7 s (R-4 p. 20) | 3.7e-3 … 3.6e-2 | 3.7e-3 … 3.6e-2 |

  So the full frequency response of `crnKernel("ACC")` is confirmed for
  GRACE-FO. The 70.7 s ACC span of the classic handbook does not hold for
  GRACE-FO ACT; whether it holds for classic GRACE ACC1B is open (X-13).
- The axis pairing is ACT1B x ← ACT1A z, y ← x, z ← y on both satellites.
  The GPS − OBC correction is about −11 ms; receiver − OBC is at the
  1e-7 s level.
- ACC1A (untransformed) matches only partly (r 0.98 / 0.68): ACT1B comes
  from ACT1A, as V-5 says.
- gracefoReading v1.1.0 defects, filed as astrobayer/gracefoReading#29
  (G-side, not this repository):
  - CLK1B refuses (`readL1b:noTime`, `rcv_time` not recognised);
  - TIM1B_D has 31 of 10 800 records with rcvtime 0;
  - CLK1B_D has records with eps_time ≈ 0 (max −1.9e-7 s).
  The test parses CLK1B itself and drops TIM1B records with a zero time.

**Owner decisions (2026-09-27):**
- bar: relative rms ≤ **2e-3** per axis (about 2 × the worst scan value
  with raw tags);
- fault injection: the 70.7 s span must be at least 10 × worse on every
  axis;
- exact mapping TIM1B + CLK1B;
- data: C and D, 2020-01-02.

**Scope (frozen):**
- `tests/TestCrnVerification.m` builds JPL's chain, as R-4 §3.3
  describes it, from the DATAPOOL files:
  1. ACT1A tags OBC → receiver: linear interpolation in the TIM1B records
     (obctime → rcvtime); records with a zero time are dropped.
  2. Receiver → GPS: + eps_time from CLK1B, linear in receiver time;
     CLK1B is parsed locally.
  3. Resampled to the 0.1 s grid by linear interpolation, as an Arc (NaN
     where the neighbouring samples are more than 0.15 s apart).
  4. `crnApply(arc, crnKernel("ACC"), OutputEpochs = ACT1B epochs)`.
  5. Per axis, with the pairing above: rel = rms(d) / rms(b − mean b),
     d = (b − mean b) − (a − mean a), over the epochs where the output is
     finite.
- It skips cleanly (assumption) without READING_DATA_POOL or the L1A day.
- `crnKernel`'s help and CONCEPT V-1 and section 8: the frequency response
  is confirmed (numbers above); V-1 is closed.
- R-4's 70.7 s is recorded in CONCEPT V-1 as refuted for GRACE-FO ACT and
  open for classic GRACE.

Out of scope:
- a production function for the OBC → GPS mapping; the chain lives in the
  test until an application needs Level-1A;
- LRI (V-2);
- fixing gracefoReading (another repository).

**Tests (predicted):**
- TestCrnVerification (3):
  - reference 2: frequencyResponseC, frequencyResponseD;
  - robustness 1: wrongSpanRefuted (70.7 s, both satellites).

**Prediction** (before any run): **726 + 0 + 0 = 726**, that is 723 + 3.
Per tag: contract 225, reference 261, precision 23, robustness 140,
metamorphic 44, vectorisation 21, speed 12.

**CI verdict (6d8e792, matlab job 108586877483): 726 + 0 + 0 = 726,
green.** Per tag as predicted: contract 225, reference 261, precision 23,
robustness 140, metamorphic 44, vectorisation 21, speed 12.
TestCrnVerification passed 3/3 in 189 s (both satellites, both spans; it
prints no values on success) with no warning. The whole suite took 37.1 min
(testing time, +3.5 min from this class) and audit was green.

## X-11 — report — merged 2026-09-27 (PR #65, `7c3c222`; issue #14 closed); scope was frozen 2026-09-26

Tier B. CONCEPT row X-11 (v3 WP-20, the instrument part), with the owner's
decisions of 2026-09-26 (interview while PR #64 awaited its merge).

**Scope (frozen):**
- `report(res, Visible = "on", ExportTo = "")` (L2; it reads a run
  result and never calls run). It returns out with:
  - figures: a struct of four figure handles.
  - notes: a struct of four strings, "" or why the panel is empty,
    taken from diagnostics.skipped.
  - files: the paths written.
  - html: the page path, or "".
- The four figures:
  - series: per axis, the observation and the reference (mean
    removed) and the residual, plus a timeline of every layer, the
    gaps and the filled samples.
  - events: flags.events by class and axis, coloured by source.
  - noise: per axis, the residual PSD (spectral.powerSpectrum) against
    the fitted model's PSD (spectral.arma2psd), plus noiseReference's
    ASD squared when the product has one (ACT1B/ACC1B -> "ACC", KBR1B,
    LRI1B).
  - alignment: checkAlignment's r(lag) per axis with the refined lag,
    and correlate's r(lag) with its interval per axis and driver when
    that stage ran.
- With ExportTo: series.png, events.png, noise.png and alignment.png at
  200 dpi (exportgraphics), and report.html, one self-contained page.
  The page holds the summary table, the skipped stages, the flags, the
  events (up to 200 rows), the provenance and the config hash, with the
  PNGs embedded as data URIs.
- A campaign result: ExportTo is required. Each day that ran is
  reported into ExportTo/<yyyy-mm-dd>/ with Visible off, and its
  figures are closed after export. index.html holds the summary table
  (status, identifier, weight fraction, events, files, SHA-256), with
  links to the days.
- No pixel reference is kept (owner decision; renderers differ between
  MATLAB updates), so there is no precision test.
- The version stays 1.2.0; CHANGELOG "Unreleased" lists report. The next
  release is the owner's call.

**Tests: TestReport (6).**
- contract 4:
  - figureHandles: four figures, Visible off.
  - exportWritesFiles: four PNGs and report.html, whose four data URIs
    and doctype are checked.
  - stageNotRunNoted: a bare run notes why noise and alignment are
    empty.
  - campaignIndex: index.html and one report.html per day, linked.
- robustness 1: refusals: a struct that is no run result
  (`report:inputResult`); a campaign without ExportTo
  (`report:exportToRequired`).
- speed 1: speedPerFigure: a six-hour three-axis run with the noise
  stage; report with export takes under 10 s per figure. The bar of 0 s
  must fail (fault injection).
- TestHelpExamples +1 (report; contract).

**Prediction** (before any run): **723 + 0 + 0 = 723**, that is 716 + 6
+ 1. Per tag: contract 225, reference 259, precision 23, robustness 139,
metamorphic 44, vectorisation 21, speed 12.

**CI verdict (e4d8802, matlab job 108488884689): 723 + 0 + 0 = 723,
green.** Per tag as predicted: contract 225, reference 259, precision 23,
robustness 139, metamorphic 44, vectorisation 21, speed 12. TestReport
passed 6/6 in 47 s, speedPerFigure included; the report example ran
without a warning. The whole suite took 33.6 min and audit was green.

## X-18 — CF/ACDD NetCDF export, PROV-O, Arc schema version → release 1.2.0 — merged 2026-09-26 (PR #64, `5cba363`; issue #21 closed; v1.2.0 tagged by the workflow); scope was frozen 2026-09-26

Tier B. CONCEPT row X-18 and 5.2 with the owner's decisions of 2026-09-26
(interview after PR #63). Standards, current on 2026-09-26: CF 1.12 for
the time coordinate (owner's choice, see below), ACDD 1.3, W3C PROV-O
(2013) serialised as JSON-LD, DataCite Metadata Schema 4.7 (2026-03-03).

**Finding before the freeze:** CF 1.13 (17 Dec 2025, Appendix M) withdrew
the `units_metadata = "leap_seconds: …"` values that CF 1.12 introduced,
in favour of the calendars `utc` and `tai`; GPS time would then be
calendar `tai` with reference 2000-01-01 12:00:19. Put to the owner:
**keep CF-1.12 with `leap_seconds: none`.** The file says
`Conventions = "CF-1.12, ACDD-1.3"`, so a reader knows which rules apply.

**Scope (frozen):**
- `exportNetcdf(file, arc, Residual = s, Events = T, Metadata = m,
  Overwrite = false)` (new, L2): one NetCDF-4 file (deflate 4, shuffle),
  CF-1.12 + ACDD-1.3:
  - `time` (int64, GPS ns): units "nanoseconds since 2000-01-01
    12:00:00", calendar "standard", units_metadata "leap_seconds: none",
    standard_name "time", axis "T". Values equal `arc.t` bit for bit.
  - one double variable per observation column, named as `arc.names`,
    with its units and _FillValue NaN; `weights` (units "1"); `filled`
    (byte, flag_values 0 1); `layers` (uint32, one bit per layer,
    flag_masks and flag_meanings = the layer names; more than 32 layers
    refuse).
  - with Residual (an Arc on arc.t): `residual_<name>` per column.
  - with Events (qc.eventTable): dimension `event`; `event_start`,
    `event_end` (int64 GPS ns, as time); `event_class`, `event_axis`,
    `event_source` (byte codes, flag_values and flag_meanings);
    `event_amplitude`, `event_sigma`, `event_confidence` (double).
  - global attributes: ACDD 1.3 (title, summary, id, history, source,
    platform, instrument, processing_level, product_version,
    date_created, creator_*, institution, publisher_name, license,
    time_coverage_*), `schema_version` "1" and `prov_jsonld`, the PROV-O
    graph; the same graph goes to the sidecar `<name>.prov.jsonld`.
  - metadata m: creator (required; empty refuses), creatorOrcid,
    creatorEmail, institution, publisher, license ("CC-BY-4.0"), title,
    project.
- `readNetcdf(file)` (new, L2): the file back as a struct (t, obs, names,
  units, weights, filled, layers, residual, events, attributes); the
  round trip is bit-exact.
- `internal.provJsonLd(provenance, ...)` (new, L0): PROV-O JSON-LD of an
  Arc's provenance: the input L1B files as prov:Entity, every stage as a
  prov:Activity (startedAtTime, used, wasAssociatedWith the
  timeSeriesPreparation prov:SoftwareAgent), the creator as prov:Person
  (ORCID as @id when given), the file as the generated entity.
- `Config.export` (new section, creator etc. as above, empty by default)
  and `cfg.run.format` ("mat" default, "netcdf", "both"). A campaign with
  "netcdf" or "both" and no creator refuses before any arc runs
  (`run:exportMetadata`). It writes `<yyyy-mm-dd>.nc` and
  `<yyyy-mm-dd>.prov.jsonld` beside the MAT file. The summary gains the
  columns netcdf and netcdfSha256. The manifest gains per arc netcdf,
  netcdfSha256, prov and provSha256, and a `datacite` block (DataCite 4.7
  mandatory properties: creators, titles, publisher, publicationYear,
  resourceType "Dataset", plus version, rights and formats).
- Arc schema version: the constant `Arc.SchemaVersion` = "2". saveobj
  stores a struct with schemaVersion. loadobj restores it, accepts an Arc
  object saved by 1.1.0 or earlier (schema "1", no saveobj then), and
  refuses an unknown version (`Arc:schemaVersion`). The campaign's day
  file schemaVersion becomes "2".
- Release 1.2.0: Contents.m, every help footer, CHANGELOG.

Out of scope: CF DSG encoding of the events (they are a plain table on
dimension `event`); reading NetCDF back into an Arc object (readNetcdf
returns a struct); DOI registration.

**Tests (predicted):**
- TestExport (11):
  - contract 3: fileLayout, timeCoordinate, provenanceGraph.
  - reference 4: arcRoundTrip, residualAndEventsRoundTrip,
    campaignNetcdf, campaignBoth.
  - robustness 4: refusals, campaignRefusesWithoutCreator,
    existingFileKept, nanSurvives.
- TestArcSchema (4):
  - contract: schemaVersionConstant.
  - reference: saveLoadRoundTrip.
  - robustness: loadobjAcceptsV1Object, loadobjRefusesUnknownVersion.
- TestHelpExamples +3 (exportNetcdf, readNetcdf, internal.provJsonLd;
  contract).
- TestConfig, TestCampaign and TestLayering follow: ten sections, the
  summary columns, schemaVersion "2", and the two new L2 units.

**Prediction** (before any run): **716 + 0 + 0 = 716**. That is 698 plus
11, 4 and 3. Per tag: contract 220, reference 259, precision 23,
robustness 138, metamorphic 44, vectorisation 21, speed 11.

**CI round 1 (d448919, matlab job 108468198898): 715 + 1 + 0 = 716.**
The count per tag was as predicted. One pin was missed:
TestConfig/toStructCarriesEverything lists the fields of toStruct, and
"export" was missing from it. Fix: add "export" to that list. The
prediction is unchanged: 716 + 0 + 0.

**CI verdict (7bee802, matlab job 108475902234): 716 + 0 + 0 = 716,
green.** Per tag as predicted: contract 220, reference 259, precision 23,
robustness 138, metamorphic 44, vectorisation 21, speed 11. TestExport
passed 11/11 and TestArcSchema 4/4. TestCampaign passed on a real pool
(Processes, 8 workers) with saveobj/loadobj in the transfer. The whole
suite ran in 33.5 min and the audit was green. The release workflow tags
1.2.0 on merge.

## X-17 — QC template bank — merged 2026-09-26 (PR #63, `db47634`; issue #20 closed); scope was frozen 2026-09-26

Tier B. CONCEPT 6.1 row 2 and row X-17, with the owner's decisions of
2026-09-26 and the throwaway scan PR #62 (closed unmerged; three runs, the
last two complete: jobs 108411906583 and 108423640544).

**Scan findings (ACT1B residual to a 301-s moving median; 2020-01 and
2020-07; GRACE-FO C and D):**
- **Thruster:** THR1B records with an on-time give a stable stack.
  - N: C 14 146 + 12 971, D 12 084 + 12 467.
  - Peak at the record: y −1.16e-8 (C) / −1.47e-8 (D) m/s², z
    +2.1e-9 / +2.2e-9 m/s², x 0 (C) / 1e-10 (D); main lobe about ±15 s with
    CRN sidelobes.
  - The two months agree to 6 % of the peak (largest difference 9e-10 on y).
- **Magnetorquer:** MAG1B `torque1A`…`torque3B` vary continuously; their
  only large steps are around the D outage 2020-01-19…22. No switching
  spikes. **Owner: left to N-11 as a regressor.**
- **Heater:** no heater column in THR1B, MAG1B, AHK1B or IHK1B; IHK1B's 39
  sensors are named only 01…39 (one sample per 120 s). No key series, no
  shape. **Owner: deferred;** the sensor map of IHK1B would unblock it.
- **z-spikes:** after excluding ±70 s around THR1B records, y has no
  candidates; z has ~60 per day and satellite, broad (~30 s) plateaus of
  about +3e-9 m/s², up to 136 σ (C 2020-01-21 25375 s). Not the sharp 10 Hz
  twang. **Owner: ignored.**
- **x axis:** 34–58 % of the ACT1B x residual is exactly 0 on every day of
  both satellites; x is unusable for spike detection.

**Scope (frozen):**
- `qc.templateBank`: the bank as data with provenance: class "thruster",
  per satellite C and D, the 121 x 3 stack (lags −60…60 s, m/s²), the
  event-weighted mean of the two months, with its event counts.
- `qc.detectTemplates(r, Epoch = t, Satellite = s)`: the residual is
  high-passed as in the scan (minus its 301-s moving median); a 3-axis
  matched filter with the unit-norm template; score = filter output over
  its robust sigma; peaks of |score| above Threshold (8) at least 121 s
  apart, largest first, claim their neighbourhood and the positive ones
  become qc.eventTable rows (found while building: a negated median
  template has positive autocorrelation sidelobes of 15 to 26 sigma, so a
  negative peak must block them) of class "impulse", amplitude = size relative to the
  median event times the template's largest sample (m/s², the
  eventTable's unit of the data), sigma from the robust sigma. A THR1B prior within
  PriorWindow_s (5 s) makes the source "THR1B" with confidence 1. One mask
  per class over the template's support (|template| >= 5 % of its peak).
- `Config.qc.templates` (false = off, R5). With true, a Reference and
  three axes of a satellite in the bank, `run` calls detectTemplates on
  the qc residual after qc, with the THR1B firings of Thrusters as priors,
  and adds one layer per class ("tplThruster"); `diagnostics.templates`
  holds its info ([] otherwise).
- TestQcEquivalence's unit list admits the two new +qc units (they are
  not part of the frozen port).

**Tests: TestTemplates (9).**
- contract 3: bankShape, outputSchema, runLayerOnlyWhenAsked.
- reference 3:
  - plantedRecoveredC and plantedRecoveredD: three templates (scale 0.5,
    1, 2) in white noise are found at their samples, each scale within
    5 sigma;
  - realThrusterDay: DC-8 (ACT1B + THR1B D 2020-01-04): detections exist
    and more than half of them lie within 5 s of a THR1B firing.
- robustness 3:
  - refusals (unknown satellite, wrong shape, threshold <= 0);
  - noiseOnly: one day of white noise with a NaN run gives no detection;
  - wrongSign: a negated template is not detected (fault injection).
- TestHelpExamples +2 (templateBank, detectTemplates; contract).

**Prediction** (before any run): **698 + 0 + 0 = 698**. That is 687 plus
TestTemplates 9 and TestHelpExamples 2.
Per tag: contract 213, reference 254, precision 23, robustness 132,
metamorphic 44, vectorisation 21, speed 11.

**CI verdict (317398d, matlab job 108448432540): 698 + 0 + 0 = 698,
green.** Per tag as predicted: contract 213, reference 254, precision 23,
robustness 132, metamorphic 44, vectorisation 21, speed 11. TestTemplates
9/9 in 9.3 s, realThrusterDay (DC-8) included: more than half of the
detections on GRACE-FO D 2020-01-04 lie within 5 s of a THR1B firing.
Whole suite 32 min. audit green.

## X-15 — campaign mode of `run`, per-day storage, manifest → release 1.1.0 — merged 2026-09-26 (PR #61, `a82c710`; issue #18 closed; v1.1.0 released by the workflow); scope was frozen 2026-09-26

Tier B. CONCEPT 6.6 and 5.2 with the owner's decisions of 2026-09-26.
Needs X-14 (merged), X-16 (merged) and G-03 (gracefoReading #18, closed
2026-09-22 by gracefoReading PR #26, release 1.1.0).
- **Entry point:** `run(arcs, ...)` with an Arc array of two or more arcs
  is a campaign; one arc is the single run, unchanged. An empty array
  refuses (`run:inputCount`).
- **Per-arc inputs:** Reference and Thrusters may be an Arc array with one
  arc per campaign arc; QualFlags, Eclipse, User and Design may be a cell
  with one entry per arc. Any other value is shared by every arc. A wrong
  count refuses the campaign before any arc runs (`run:inputCount`), as
  does an Arc array for Reference in a single run.
- **Seeds:** arc k runs with cfg.run.seed + k - 1, so it equals
  `run(arcs(k), ..., Config = set(cfg, "run", "seed", seed + k - 1))`.
  Without a Config, arc k takes Config(arcs(k)).
- **Errors:** a stage that refuses on one arc stops that arc only; its
  MException is kept and the campaign continues (CONCEPT 6.6).
- **Release rule (5.2):** the arcs must share one L1B release
  (`Arc.requireOneRelease`, `Arc:mixedRelease`) unless
  cfg.run.mixedRelease is true.
- **Parallel (owner):** serial by default; cfg.run.parallel = true uses
  `parfor` over the arcs when `canUseParallelPool` is true, else it runs
  serially. The per-arc seeds make both equal. res.parallel says which
  ran.
- **Per-day storage (owner):** only when cfg.run.outDir is set ("" = in
  memory, R5). One MAT v7.3 file per arc,
  `outDir/<mission>/<satellite>/<yyyy>/<yyyy-mm-dd>.mat` (GPS date of the
  first epoch), holding `result` and `schemaVersion` ("1"). An existing
  day file is not overwritten unless cfg.run.overwrite is true: that arc's
  status is "unsaved" with `run:fileExists`.
- **Manifest (owner):** `outDir/manifest.json` (jsonencode): schemaVersion,
  title, software name and version, created (UTC), first and last day,
  config hash (internal.contentHash of toStruct(cfg)), seed, parallel; per
  arc: index, day, mission, satellite, product, release, source files,
  content hash, file (relative), SHA-256 of the file, status, identifier,
  message. An existing manifest refuses the campaign before any arc runs
  (`run:fileExists`) unless cfg.run.overwrite is true.
- **New L0 helper:** `internal.fileSha256`, the plain SHA-256 of a file's
  bytes, pinned to FIPS 180-4 (abc, empty).
- **Result of a campaign:** struct with results (N x 1 cell of single-run
  results, [] where an arc failed), summary (table: index, day, mission,
  satellite, status ok/error/unsaved, identifier, message, file, sha256),
  errors (N x 1 cell of MException or []), manifest (struct or []),
  parallel (logical).
- **Config.run** gains parallel (false), outDir (""), overwrite (false),
  mixedRelease (false).
- **Release 1.1.0** in this PR (GUIDE section 7): Contents.m, every
  footer, CHANGELOG.

**Tests.**
- TestCampaign (new, 10):
  - contract 3: campaignResultFields, inMemoryByDefault,
    pairedInputsCounted;
  - reference 3: eachArcEqualsSingleRun, filesAndManifest,
    fileSha256Pinned;
  - robustness 4: failingArcIsCaptured, existingFilesNotOverwritten,
    mixedReleaseRefuses, parallelEqualsSerial.
- TestHelpExamples +1 (internal.fileSha256; contract).
- TestRun's refusal test and TestConfig's run pin change, count unchanged.
- Fault injection: a changed byte changes fileSha256; a failing arc, an
  existing file and a mixed release each fire.

**Prediction** (before any run): **687 + 0 + 0 = 687**. That is 676 plus
TestCampaign 10 and TestHelpExamples 1.
Per tag: contract 208, reference 251, precision 23, robustness 129,
metamorphic 44, vectorisation 21, speed 11.

**CI round 1 (c470185): 686 + 1 + 0.** A real pool ran ('Processes', 8
workers). TestCampaign/parallelEqualsSerial failed on all three arcs: each
result carries its Config, and cfg.run.parallel is true in the parallel
campaign and false in the serial one. Fix: the test sets that one field
equal before comparing and names the first differing field on failure.
Prediction unchanged: 687 + 0 + 0.

**CI verdict (1f0f45a, matlab job 108392406734): 687 + 0 + 0
= 687, green.** Per tag as predicted: contract 208, reference 251,
precision 23, robustness 129, metamorphic 44, vectorisation 21, speed 11.
parallelEqualsSerial ran on a real pool ('Processes', 8 workers): the
parallel results equal the serial ones bit for bit. Whole suite 34 min.
audit green. Release 1.1.0 is tagged by the release workflow on merge.

## X-16 — QC speed — merged 2026-09-26 (PR #60, `ca5230f`; issue #19 closed); scope was frozen 2026-09-26

Tier B. CONCEPT row X-16 with the owner's decisions of 2026-09-26:
- **Pure MATLAB.** No C layer, no MEX: one code path on every platform.
- **Scope: the whole of `qc.screen`** (widened from the two named units):
  - `hampel`: the per-sample loop becomes vectorised windows. A full,
    finite window (odd count) takes its median from `movmedian` (the middle
    element, no arithmetic) and its MAD from one `median` over W x n window
    blocks of at most 2^16 elements (cache-sized; 2^22 in round 1). Edge
    windows and windows with NaN take
    `median(..., "omitnan")`; `movsum` counts the finite samples.
  - `detectJumps`: PELT's admissible candidates carry their cumulative
    sums and F(tau) in arrays beside them, and the too-recent ones wait in
    a queue (round 2; round 1 had a preallocated buffer only). No gathers
    per step; same candidates, same order, same arithmetic.
  - `detectImpulses`: the greedy suppression collects the peak indices and
    builds the event columns once, instead of appending datetimes.
  - `screen`: each impulse's first sample is found by one `ismember` over
    all events, instead of a full `epoch ==` scan per event.
  - `residuals` and `eventTable` stay as they are (no hot spot). The
    matched filter of `detectImpulses` keeps its loop: `conv` or `filter`
    would sum in another order and change the last bits.
- **Equality gate:** `isequaln` with the frozen port (TestQcEquivalence)
  over all outputs, bit for bit. No tolerance.
- **Speed, as a ratio against the port** (owner decision), timed in the
  same test on one day, 86400 x 3 at 1 Hz, best of three runs each (a
  separate warm-up call was dropped in round 2 to fit the 60-min job):
  - `hampel` at least 5 times faster (owner decision 2026-09-26, after
    CI measured 6.42 and 7.57 against the first bar of 10);
  - `detectJumps` not slower (owner decision);
  - `screen` at least 2 times faster (my proposal: hampel dominates the
    port's screen; the owner may raise it).
  - My estimate before any run (2026-09-26): hampel reaches about 3–4
    times, not 10. The owner kept 10 (decision 2026-09-26). If CI measures
    less, I keep optimising in MATLAB; if that fails, the bar or a MEX
    layer goes back to the owner. The bar is not lowered by me.

**Tests.**
- TestQcEquivalence +4 cases (reference):
  - hampelInfShortNaN: Inf and -Inf samples, a series shorter than the
    window, a column with fewer than three finite samples;
  - hampelBlocks: 5000 samples, so the 2^16-element blocks (1074 windows)
    split, with a NaN run across a block boundary and a partial last block;
  - detectJumpsLong: 20000 samples, eight jumps, so the candidate buffer
    grows and prunes;
  - screenManyImpulses: forty pulses on three axes, so the event lookup
    runs for many events.
- TestQcEquivalence +3 speed tests (speed): hampelFivefold (hampelTenfold
  until round 3),
  detectJumpsNotSlower, screenTwofold.
- Fault injection:
  - speed: each speed test first applies its ratio check to the port
    against itself (its slowest run over its fastest), with the bar 10,
    and requires the check to fail; only then does it
    check the new unit;
  - equality: the existing oneUlpIsDetected.

**Prediction** (before any run): **676 + 0 + 0 = 676**. That is 669 plus
TestQcEquivalence +4 (reference) and +3 (speed).
Per tag: contract 204, reference 248, precision 23, robustness 125,
metamorphic 44, vectorisation 21, speed 11.

**CI round 1 (4aed563): cancelled at the 60-min job limit**, in
tsmodelsTest, after TestQcEquivalence (41.5 min). Every equivalence case
passed (no other verification failed); two speed tests missed:
- hampel: port 1.129 s, unit 0.176 s, ratio 6.42 < 10;
- screen: port 191.105 s, unit 159.622 s, ratio 1.20 < 2;
- detectJumps: passed (not slower).

Finding: screen on one day is dominated by PELT, not hampel. With two
jumps in 86400 samples PELT prunes little, so its candidate list grows
and the cost is quadratic (about 60 s per axis with the port). Round 2
(bars unchanged): PELT without gathers per step (above), hampel in
cache-sized blocks, the speed tests without the extra warm-up and
fault-injection runs. Prediction unchanged: 676 + 0 + 0.

**CI round 2 (34d18e8): 675 + 1 + 0**, whole suite in 33 min
(TestQcEquivalence 12 min 50 s). Per tag as predicted except speed
10 + 1. The one failure: hampel: port 1.122 s, unit 0.148 s, ratio
7.57 < 10. screen and detectJumps passed (their ratios print only on
failure). Every equivalence case passed.

**Owner decision 2026-09-26:** after two pure-MATLAB rounds (6.42, 7.57),
the hampel bar is 5, about 2/3 of the measured 7.57, instead of a MEX
layer. Round 3 changes only the bar and the test's name (hampelFivefold).
Prediction: 676 + 0 + 0, per tag as above.

**CI verdict (70d9a91, run 36227961222): 676 + 0 + 0 = 676, green.** Per
tag as predicted: contract 204, reference 248, precision 23, robustness
125, metamorphic 44, vectorisation 21, speed 11. Whole suite 34 min
(TestQcEquivalence 13 min). audit green. The speed tests print their
ratios only on failure; the last measured are round 2's (hampel 7.57).

## X-14 — stage cache — merged 2026-09-26 (PR #59, `a264793`; issue #17 closed); scope was frozen 2026-09-25

Tier B. CONCEPT 6.6 with the owner's decisions of 2026-09-25:
- **Cached stages:** the expensive ones, crn, qc, noise and correlation.
  mask, align, gate and fill always compute; hashing them would cost
  more than it saves.
- **Stages with a function handle** (bootstrap, crossval) are never
  cached. What a handle computes cannot be hashed.
- **Reporting:**
  - diagnostics.cache is a table of stage, key, status and reason. The
    status is off, hit, miss, rewritten, unsaved or not cached.
  - The run entry of provenance carries that table.
  - No warnings.
- **Files and eviction:** one MAT file per key,
  `cacheDir/<stage>/<key>.mat`. There is no eviction. An unreadable file
  is recomputed and overwritten (status "rewritten").

**Scope (frozen):**
- `Config.run.cacheDir`, default "" = off (R5).
- `internal.contentHash`: the SHA-256 of a canonical byte stream.
  - Supported types: numeric, logical, char, string, struct, cell,
    table, datetime.
  - A function handle or an object (Arc included) refuses: contentHash
    is L0 (CONCEPT 3.2). `run` hashes an Arc as a struct of its content,
    without provenance.
  - Pinned against a Python rebuild of the stream.
- `internal.stageCache`: load, or compute and store; it returns a status.
- `run`: the four stages go through the cache. The key is contentHash(
  stage, toolbox version, the stage's inputs, the stage's settings).
  diagnostics gains the field `cache`, and TestRun's pin is extended by
  it.

**Measured before the push (2026-09-25):** audit clean (131 files, 159
identifiers); docs in sync (69).

**Prediction** (before any run): **669 + 0 + 0 = 669**. That is 659 plus:
- TestStageCache +8: contract 2, reference 3, robustness 3;
- TestHelpExamples +2 (contentHash, stageCache; contract).

Per tag: contract 204, reference 244, precision 23, robustness 125,
metamorphic 44, vectorisation 21, speed 8.

**CI round 1 (2fbc37b): 668 + 1 + 0.** TestLayering/repositoryPackageIsLayered
found "+internal/contentHash.m: upward call from L0 'internal' to L1 'Arc'".
Fix: the Arc branch moves from contentHash to `run` (arcContent); the
provenance check moves from contentHashPinned (now: contentHash refuses an
Arc) to changedInputOrSettingMisses (an arc with added provenance hits).
Prediction unchanged: 669 + 0 + 0.

**CI verdict (ae56ee0, run 36195219643): 669 + 0 + 0 = 669, green.**
Per tag as predicted: contract 204, reference 244, precision 23,
robustness 125, metamorphic 44, vectorisation 21, speed 8. audit green.

**Risks, stated:**
- MAT round trips of Arc objects and tables are used for the first time.
  A hit must be isequaln to the computation, and the test checks this.
- `mkdir` on a path that is a file may warn instead of erroring. Either
  way, save fails and the status is "unsaved".

---

## X-10 PR-2 — integration tests and release 1.0.0; scope frozen 2026-09-25

Tier B. The second of X-10's two PRs. It adds no code, only the
integration tests (owner decisions 2026-09-24; scale tolerance
2026-09-25) and the version bump to 1.0.0 (GUIDE section 7).

**Scope (frozen):**
- `TestIntegration/realDayAgainstItsg`:
  - Inputs: ACT1B C 2020-01-02 (DATAPOOL, RL04) and its qualflg, against
    ITSG `GRACEFO-1_nonConservativeForces_2020-01-02` (DATAPOOL
    `GRACEFO-1`, read with gracefoReading `readItsgProduct`), through
    `run` with the ACT1B preset. The file holds 8 641 epochs (both
    midnights); 8 640 lie on the ACT1B day.
  - The ITSG epochs are moved 3 s earlier (V-17, owner decision
    2026-09-25). At the shifted ITSG epochs, each axis is fitted as
    ref = b + s * obs (V-4's direction).
  - Required:
    - the band delay (2.5–10 mHz) is below 1 s on x and z;
    - correlation >= 0.95 / 0.95 / 0.93;
    - each scale is within 5 % of 1.066 / 0.915 / 0.864.
    - run's full-band lags are logged, not asserted.
- **Scale direction.** First read wrong (from a 600 s sample): I took obs
  = b + s * ref. CI showed V-4's direction, ref = b + s * obs (see the
  second run below). The direction was fixed; the tolerance was not
  touched.
- `TestIntegration/syntheticTruthRecovered`:
  - Arc: six hours at 1 Hz, planted b and s, white noise 1e-10, three
    5e-9 spikes, a 30 s gap.
  - Required: the spikes are masked; the gap is reported on each axis;
    no lag; the noise sigma2 is within 5 %; the fit recovers s to 5e-4
    and b to 5e-12.
- Version 1.0.0: `Contents.m` and every footer, CHANGELOG 1.0.0, README
  status. The release workflow tags `v1.0.0` on the merge.

**Measured before the push (2026-09-25):** audit clean (128 files); docs
in sync (67).

**Prediction** (before any run): **659 + 0 + 0 = 659**. That is PR-1's
657 plus TestIntegration's 2 (reference). Per tag: contract 200,
reference 241, precision 23, robustness 122, metamorphic 44,
vectorisation 21, speed 8.

**First CI run (run 36124312901 on `b830265`): 658 + 1 + 1.** The only
red was the test's own premise: it asserted 8 640 ITSG epochs, and the
file holds 8 641, both midnights (00:00 and 24:00). V-4's 8 640 are the
epochs on the ACT1B day. The assertion now counts those. The thresholds
did not run and are unchanged. Everything else was as predicted
(synthetic test green; contract 200, reference 240 + 1 + 1, the rest
equal).

**Second run (run on `0d0f7ad`): 658 + 1 + 0.** Correlation passed.
- Scales: the fit ran in the wrong direction. V-4 fitted ref = b + s * obs;
  the other direction gave 0.906 / 1.032 / 1.058, which equals r^2 / s of
  V-4's values (the two slopes of one data set multiply to r^2). Fixed.
- Lag: checkAlignment gave −14.97 / +3.02 / +3.05 s. The owner said it is a
  time offset and asked for the cause before 1.0.

**V-17 investigation (2026-09-25; three temporary diagnostics in CI, runs
36160272643, 36162760916, 36166998289, since removed):**
- The lag depends on the band, so it is not a pure clock offset.
  - Full band: −15 / +3 / +3 s.
  - High-pass 610 s: −3.1 / −5.1 / −3.9 s (ITSG late).
  - The same band with ITSG taken as a 10 s trailing mean: +1.8 / −0.1 /
    +1.1 s.
- Cross-spectral phase over 2.5–10 mHz, weighted by coherence, ITSG late
  by: x 3.1 / 5.4 / 2.6 s, z 3.0 / 3.0 / 1.3 s (C 01-02, C 01-03, D
  01-02); y undetermined (0.8 / −2.3 / −2.0 s). Coherence is below 0.3
  above about 15 mHz. Below 2 mHz the phase is not a delay, and that range
  sets the full-band lag, with the opposite sign.
- Sources read (owner's copies): the ITSG README (2025-10-16) says only
  GPS time and 10 s sampling. P-2 App. A: TU Graz's ACT1B is timed like
  JPL's (CLK1B, zero-phase CRN). The delay therefore comes from the
  undocumented step that makes the 10 s product.
- **Owner decisions:**
  - V-17 recorded and closed (CONCEPT 0.24, 9.3).
  - The test moves the ITSG epochs 3 s earlier.
  - Timing is checked by the band delay (|tau| < 1 s on x and z; y
    logged). run's full-band lags are logged, not asserted.
- **Correction recorded:** my first proposal claimed that the 3 s shift
  brings the full-band y/z lag to about 0. It brings it to about +6 s,
  because the two measures have opposite signs. The owner decided again
  with this corrected.

Prediction unchanged: **659 + 0 + 0**.

**Verdict, CI run 36176429460 on `e1e4d5b` (2026-09-25), MATLAB R2026a:**
- `audit` green.
- `matlab` green: **659 + 0 + 0 = 659**, every tag as predicted
  (contract 200, reference 241, precision 23, robustness 122, metamorphic
  44, vectorisation 21, speed 8). Gate time 1229 s.
- Real day, after the V-17 shift:
  - band delay +0.45 / +1.37 / +0.63 s; x and z are asserted, y is
    logged;
  - run's full-band lags −11.97 / +6.02 / +6.05 s, logged, as corrected;
  - correlation and scales (V-4's direction) passed.
- Synthetic arc: green.

**Risks, stated:**
- The band delay after the shift is predicted from the diagnostic (x
  3.07 − 3, z 2.99 − 3 s on C 01-02, from 3 bins). The test fits every
  bin of 2.5–10 mHz with coherence > 0.5, so it can differ by a few
  tenths of a second.
- First read of the ITSG day in CI. If the file is missing below
  `GRACEFO-1`, the assertion names the folder.
- `qc.screen` on a full day (86 400 x 3) runs for the first time in this
  repository; the gate time will show its cost.

---

## X-10 PR-1 — `run` and the full `Config`; scope frozen 2026-09-25

Tier B. The first of X-10's two PRs (owner decisions 2026-09-24): `run`
for one arc, every Config section with its fields, and the contract test
of the result fields. PR-2 adds the integration tests (ACT1B C 2020-01-02
against ITSG, V-4 thresholds; a synthetic arc with planted truth) and
releases 1.0.0.

**Scope (frozen):**
- `run(arc, ...)`, L3. Each stage runs when its input is given, and a
  skipped stage is listed with its reason in `diagnostics.skipped`:
  - mask always (sources QualFlags, Thrusters, Eclipse, Events, Soe, User);
  - crn when a Reference is given and `cfg.run.filterReference` is true;
  - align and checkAlignment when a Reference is given;
  - qc (`qc.screen`, layer `qc`) when a Reference is given and the arc
    has 1 or 3 columns;
  - noise when `cfg.noise.order` is given, on the residual (with a
    Reference) or on the arc;
  - gate when a Design is given; bootstrap / crossval when a Statistic /
    Loss is given;
  - fill always ("none" reports); collocation only without a Reference
    (with one the model is the residual's, which is fill's deferred
    method "reference");
  - correlation when Drivers, the noise model and `cfg.drivers.maxLag`
    exist.
- **Execution order.** crn → align → qc run in data order: the CRN
  filter needs the reference on its raw grid, and QC needs it on the
  observation epochs. The other stages keep their 6.1 order. This is
  recorded in CONCEPT 0.23, 6.1. **Owner confirmed the order on
  2026-09-25.**
- **Result fields** exactly `arc`, `reference`, `diagnostics`,
  `correlation`, `flags`, `config`, `provenance` (CONCEPT 4), pinned by
  `TestRun`. The pin is fault-injected: a result with a field added or
  removed must fail it.
- Epochs reach `qc.screen` as UTC: GPS minus the leap seconds of the date,
  counted in `UTCLeapSeconds`. A spike planted at 00:05:00 UTC on
  2020-01-02 (GPS 00:05:18) must carry that time in its event.
- `Config`: `qc` (the eight options of qc.screen, with its defaults),
  `noise` (order [] because R5 gives it no default; method "exact",
  maxLag 100, lags 20, welchAverages 32, noise's defaults) and `run`
  (filterReference [] = not stated; seed 0). No product preset changes.
- Not in scope: campaign mode (an arc array refuses with
  `run:campaignDeferred`), the stage cache (X-14), the report (X-11), and
  qc priors from run.

**Measured before the push (2026-09-25, ci-actions `v1.3.2`):** audit
clean (127 files, 158 identifiers); docs in sync (67).

**Prediction** (before any run): **657 + 0 + 0 = 657**. That is 643 plus:
- TestRun +12: contract 5, reference 5, robustness 2;
- TestConfig +1 (`qcNoiseRunDefaultsAndSet`, contract);
- TestHelpExamples +1 (`run`, contract).

Per tag: contract 200, reference 239, precision 23, robustness 122,
metamorphic 44, vectorisation 21, speed 8.

**Risks, stated:**
- MATLAB is not available in this session, so the new code first runs in
  CI. A red is a wiring or test fault, fixed in this PR. The stages
  themselves are unchanged.
- The UTC conversion relies on converting a `UTCLeapSeconds` datetime to
  `UTC`; `qcSpikeEventInUtc` pins the result.

**Verdict, CI run 36111847556 on `9774c55` (2026-09-25), MATLAB R2026a:**
- `audit` green.
- `matlab` green on the first run: **657 + 0 + 0 = 657**, every tag as
  predicted (contract 200, reference 239, precision 23, robustness 122,
  metamorphic 44, vectorisation 21, speed 8). Gate time 1192 s.
- TestRun 12/12, including the UTC epoch of the planted spike and the
  CRN-filtered reference. The UTCLeapSeconds conversion works.
- One expected warning in TestRun: in `qcSpikeEventInUtc` the planted
  1e-6 spike pulls checkAlignment's x lag to -1.59 s ("offset"). That is
  the diagnostic doing its job on a deliberately disturbed arc, and
  nothing is shifted.

---

## X-05b `.github/` follow-up — `qc` under the public template; 2026-09-24

A `.github/` change, so it stands alone: `.github/matlab-audit.json`,
`.github/matlab-docs.json` and the files generated from them, as PR #41
did after X-02.

True after the merge:
- The audit profile `qc-ported` is gone. `+timeSeriesPreparation/+qc/*.m`
  is audited under `public` (the full template, identifiers and warnings),
  and `tests/qc/*.m` under `tests`.
- The generator documents `+qc`. There are 6 new pages, and the
  catalogue lists **157** identifiers (20 of them `qc`).
  **6 new help examples** run in `TestHelpExamples`.

**Fault injection (2026-09-24, ci-actions `v1.3.2`)**, each on a copy:

| injected fault | finding |
|---|---|
| `hampel` raises an undocumented `…:inputWindowX` | A6 |
| `screen`'s help without SYNTAX | A2 |

The healthy tree is **clean**: 125 files. `matlab-docs --check`: 66 files,
**in sync**.

**Prediction** (before any run): **643 + 0 + 0 = 643**. That is X-05b's
637 with TestHelpExamples growing from 54 to 60 (+6, contract): contract
193, reference 234, precision 23, robustness 120, metamorphic 44,
vectorisation 21, speed 8.

**CI verdict** (run 36102900717, head `ee9f31b`, 2026-09-25): **643 + 0 + 0
= 643**, as predicted. Per tag: contract 193, reference 234, precision 23,
robustness 120, metamorphic 44, vectorisation 21, speed 8. Audit green.

**Risk, stated:** the six `qc` EXAMPLEs run for the first time, each
warning-free. A red here is a help-text fix in this PR, never a numerical
one.

---

## X-05b — `qc` conventions, numbers unchanged (owner decision 2026-09-24); scope frozen 2026-09-24

Tier B. The ported `+qc` is brought to this repository's conventions
before release 1.0 (CONCEPT 12.9: conventions change in a separate WP,
gated by equality to the port). Two PRs: this code PR, then a `.github/`
PR that removes the audit profile `qc-ported` and the docs exclusion,
with the regenerated catalogue and help examples (as PR #41 after X-02).

**Owner decisions 2026-09-24 (X-10 interview):**
- **X-05b before X-10**, so 1.0 has one convention throughout.
- **X-10 in two PRs**:
  - PR-1: `run` for a single arc, the full Config presets, and a contract
    test pinning the result fields.
  - PR-2: the integration tests and release 1.0.0.
- **`run` is input-driven.** Every stage whose inputs exist runs, in
  CONCEPT 6.1 order. A stage without its input is skipped and listed in
  `diagnostics.skipped`; nothing is assumed.
- **Integration day: ACT1B C 2020-01-02 against ITSG
  nonConservativeForces**, the day V-4 measured. The thresholds come from
  V-4: correlation ≥ 0.95 / 0.95 / 0.93 (measured 0.984 / 0.973 / 0.955),
  the lag below 1 s, and the scales within the V-4 range. A synthetic arc
  with planted truth is added.

True after the merge (code PR):
- The six `+qc` units have the template help (SYNTAX … REFERENCES, footer)
  and self-contained EXAMPLEs. Their errors are raised with literal
  identifiers, `error("timeSeriesPreparation:<unit>:<mnemonic>", …)`, so
  the audit can catalogue them.
- `internal.fail` is removed, since nothing calls it any more.
  `internal.provenance` stays.
- The frozen port is `tests/qc/frozen/*.m.txt`, the PR-B files with
  `qcPort.` names.
  - `TestQcPort` holds the six units to NonGravForces `3cc0123` by
    SHA-256.
  - **`TestQcEquivalence`** loads the frozen port as package `qcPort` and
    requires every output of 15 cases to be isequaln, with the provenance
    records removed (they carry a creation time). The refusals must raise
    the same identifiers.
  - Fault injection: a one-ulp change must fire.
- In `tests/qc` only the help headers changed (DESCRIPTION, COVERAGE,
  footer) and the tag spelling `vectorization` → `vectorisation`.
  `TestTagPolicy` exempts no folder any more.

**Measured before the push (2026-09-24, ci-actions `v1.3.2`):**
- The code lines of the six units differ from the frozen port only in the
  34 error calls and the dropped `unit =` lines (diff, 0 unexplained).
- Under the current configuration: audit clean (125 files), docs in sync
  (60).
- Under the `.github` configuration the follow-up PR will carry (on a
  copy): audit clean, **20** `qc` identifiers catalogued (157 in total),
  docs in sync (66), and 6 new help examples.

**Prediction** (before any run): **637 + 0 + 0 = 637**. That is 622 (after
O-6) with these changes:
- TestQcEquivalence +17 (reference 15, contract 1, robustness 1).
- TestQcPort 5 → 4: the screen-test hash is gone (reference −1).
- TestHelpExamples 55 → 54: `internal.fail` is gone (contract −1).
- The five `vectorization` tests move to `vectorisation`.

Per tag: contract 187, reference 234, precision 23, robustness 120,
metamorphic 44, vectorisation 21, speed 8.

**Risk:** the equivalence cases run for the first time. A red case is a
test bug or a conversion slip, fixed in this PR; the numbers are never
touched.

**Verdict, CI run 36055437030 on `160f0ea` (2026-09-24), MATLAB R2026a:**
- `audit` green.
- `matlab` green on the first run: **637 + 0 + 0 = 637**, every tag as
  predicted (contract 187, reference 234, precision 23, robustness 120,
  metamorphic 44, vectorisation 21, speed 8; no `vectorization` any
  more).
- TestQcEquivalence 17/17: the converted `qc` equals the frozen port in
  all 15 cases. TestQcPort 4/4.
- Gate time 1199 s.

---

## O-6 — `matlab` job timeout 30 → 60 min (`.github/` only) — merged 2026-09-24 (PR #54, `7c7fb7b`)

A `.github/` change, so it stands alone: `.github/workflows/ci.yml` and this
file. The gate grew from 953 s (X-01) to 1541 s (X-05 PR-C, 622 tests, the
D-9 DATAPOOL reads); with setup the job took 27 min 7 s of its 30. The new
limit is 60 min. It still ends a hung run within the hour, and it leaves
room for the WPs that add real-data tests (X-10 on).

No check is added, so nothing is fault-injected.
**Prediction:** 622 + 0 + 0, unchanged.

**Verdict, CI run 36047997902 on `1f99fd2` (2026-09-24), MATLAB R2026a:**
`audit` green; `matlab` green, **622 + 0 + 0 = 622** as predicted, every
tag unchanged. Gate time 1171 s; job 20 min 47 s of the new 60.

---

## X-05 PR-C — `mask`, D-9 tests, release 0.2.0 — merged 2026-09-24 (PR #53, `f448f78`; issue #8 closed; v0.2.0 released by the workflow); scope was frozen 2026-09-24 (X-05 PR-A)

Tier B. Scope: X-05 PR-A below.

**Owner decisions 2026-09-24 (third round):**
- **qualflg: the header decides.** `decodeQualFlags` supplies each bit's
  meaning from the file header. The presets remove the L1B fill flags
  (ACT1B 5–7, KBR1B and LRI1B 6–7) and the phase break (KBR1B and LRI1B
  bit 0); every other bit is reported and removes nothing. CONCEPT's "ACC
  large-range mode, bit 4 (R-2 p. 32)" is corrected: in the GRACE-FO
  ACT1B RL04 header, bit 4 is the CLK1B clock-offset extrapolation.
- **SNR layer.** A sample is removed where an SNR column falls below a
  fraction of its median: `Config.mask.snrFraction`, 0.5 for KBR1B and
  LRI1B, provisional.
- **Event lists.** Callers state their windows; a TN-01 helper is built
  in. TN-01 MANV rows become [epoch, epoch + values(1) s]. The duration
  reading was measured: the first GRACE-C row, 127 s, equals TN-01a's
  "06:19:26 to 06:21:33" on 2018-05-24. TN-01a prose is never parsed.
- **THR1B margin.** Half the CRN fit interval (70.35 s ACC, 35.35 s KBR).
  Eclipse transitions use the same margin. LRI has no CRN preset, so its
  margins must be given (`mask:marginMissing`).

True after the merge:
- **`mask(arc, ...)`** (L2) adds one named layer per source:
  - `qualflg_b<k>`, `snr`, `thr`, `eclipse`, `events`, `crnEdge` (off by
    default) and `user`;
  - `info` returns the qualflg report, the SNR thresholds, the firing and
    transition counts, and the calibration windows (`info.windows`).
- `Config.mask`: `removeBits`, `snrFraction`, `thrMargin`,
  `eclipseMargin`, `crnEdge`, with the presets above.
- `TestMask`: every count is written out from the definition. The TN-01
  window is checked on gracefoReading's fixture.
- `TestDefectCatalogue` covers DC-1 … DC-8 on their real days in the
  DATAPOOL. Each test first checks the recorded numbers, then the verdict.
  The three synthetic classes behave as follows:
  - a duplicated epoch is refused by `Arc`;
  - an LRI1B phase break is removed;
  - a 10-sigma level jump is reported by `qc.screen`, never masked.
- Release **0.2.0**: `Contents.m`, every footer, README, CHANGELOG. The
  release workflow tags the merge commit.
- CONCEPT Rev 0.21: 6.1 row 1 as above; V-12 answered.

**Measured before the push (2026-09-24, ci-actions `v1.3.2`):**
- `matlab-audit`: 125 files at 0.2.0, **clean**.
- `matlab-docs --check`: 61 files, **in sync**; the mask EXAMPLE is new.

**Fault injection:**
- The refusals each fire on a planted defect: wrong size, THR1B on-times
  in seconds, eclipse value 2, a window ending before it starts, LRI1B
  with no margin, and mask run twice.
- DC-6 and DC-7 hold the negative: a reported bit must not remove.
- DC-4 holds 2020-07-12 as a dip that must stay.

**Prediction** (before any run): **622 + 0 + 0 = 622**. That is 598 (PR-B)
plus:
- TestMask 11 (contract 3, reference 5, metamorphic 2, robustness 1).
- TestDefectCatalogue 11 (reference 8, robustness 3).
- TestConfig +1 (contract).
- TestHelpExamples 54 -> 55 (contract).

Per tag: contract 187, reference 220, precision 23, robustness 119,
metamorphic 44, vectorisation 16, vectorization 5, speed 8.
- Without READING_DATA_POOL the eight DC tests are incomplete: 614 + 0 + 8.
- Without gracefoReading as well, the qualflg and TN-01 tests of TestMask
  and the synthetic LRI test are also incomplete.

**Risks, stated:**
- The DC tests read the DATAPOOL for the first time from the `matlab`
  job.
- DC-8 builds an `Arc` from a real THR1B day, which needs strictly
  increasing epochs. That holds on gracefoReading's THR1B fixture (471 of
  471), but 2020-01-04 D has not been checked.
- A red here is a test or `mask` fix in this PR. The recorded D-9 numbers
  change only on evidence.

**Debt:** Tier A (no local MATLAB).

**Verdict, CI run 36033100696 on `a2dcbff` (2026-09-24), MATLAB R2026a
Update 5, gracefoReading `v1.1.0`, lsqvce `v6.1.3`, READING_DATA_POOL set:**
- `audit` green.
- `matlab` green on the first run: **622 + 0 + 0 = 622**, every tag as
  predicted (contract 187, reference 220, precision 23, robustness 119,
  metamorphic 44, vectorisation 16, vectorization 5, speed 8).
- TestMask 11/11 and TestDefectCatalogue 11/11. The DC tests ran on the
  real days, with nothing incomplete.
- DC-5 logged its phase breaks: 2020-07-01 at 13590 s and 2020-07-09 at
  82645 s, now in the D-9 table.
- No new warning in the gate step. Gate time 1541 s.

**Finding: the `matlab` job ran 27 min 7 s against its 30-min
`timeout-minutes`.** The gate grew from 1159 s (PR-A) to 1541 s, and the
DATAPOOL reads add to it. The next WP's tests may cross the limit. Raising
it is a `.github/` change and stands alone (O-6).

---

## X-05 PR-B — `qc` port, unchanged (issue #8) — merged 2026-09-24 (PR #52, `b5633c0`); scope was frozen 2026-09-24 (X-05 PR-A)

Tier B. Scope, decisions and pin: X-05 PR-A below.

True after the merge:
- `+timeSeriesPreparation/+qc/`: `residuals`, `hampel`, `detectImpulses`,
  `detectJumps`, `eventTable`, `screen`, from NonGravForces `3cc0123`. Four
  text substitutions are the only change: `NonGravForces.qc.` →
  `timeSeriesPreparation.qc.`, `NonGravForces.fail(` →
  `timeSeriesPreparation.internal.fail(`, `NonGravForces.provenance(` →
  `timeSeriesPreparation.internal.provenance(`, `NonGravForces:` →
  `timeSeriesPreparation:`. None of the replacements occurs in the
  originals, so the map inverts; references to NonGravForces' readers in
  the help text stay as written.
- `internal.fail` (same classes, hint marker and throwAsCaller) and
  `internal.provenance` (same fields). `dependencies` is empty, because
  the qc units call no toolbox.
  - **Finding in NonGravForces:** its FNV-1a `localHash` multiplies in
    double. The product reaches 2^56, beyond the 53-bit mantissa, so the
    hash is not the FNV-1a of its text. Here it is exact
    (`internal.stageSeed`), so the two hashes can differ. It affects no
    qc number; to be reported to NonGravForces.
- Tests: `tests/qc/` holds `NgfTestCase`, `tNgfQc` and `tNgfQcScreen`.
  Their oracles are byte copies in `tests/tools/pyxcheck/`, and the 600-s
  ACT1B sample is in `tests/data/samples/`. These paths keep the originals'
  `fileparts(fileparts(mfilename))` lines valid.
  - `tNgfQcScreen` reads THR1B from gracefoReading's `tests/realdata`
    (byte-identical to NonGravForces' copy; `TestQcPort` checks it) and
    ACT1B with `gracefoReading.readL1b`. The two static readers rebuild
    `io.readTHR1B` (UTC = GPS − 18 s) and `io.readACC1B` for the fields
    the tests use.
- `TestQcPort`: every ported file, after the map is undone, has the
  SHA-256 of its original. `tNgfQcScreen` additionally has its reader
  block removed and its two lines restored. The copies are byte-equal. CR
  is dropped first, because the originals hold LF only.
- `TestTagPolicy` exempts `tests/qc` for its spelling "vectorization". The
  gate counts that tag under its own name until a conventions WP.

**Measured before the push (2026-09-24, ci-actions `v1.3.2`):**
- The same round trip in Python matches all 14 files and the screen test.
- `matlab-audit`: 122 files, **clean**. Catalogue: 133 identifiers,
  including `fail`'s 2.
- `matlab-docs --check`: 60 files, **in sync**. Two new help examples:
  `internal.fail` and `internal.provenance`.

**Fault injection:** `TestQcPort/changedCharacterBreaksEquality` turns
`1.4826` into `1.5826` in `hampel` and requires the hash to break, while
the unmodified file still matches.

**Prediction** (before any run): **598 + 0 + 0 = 598**. That is 553 plus:
- tNgfQc 10 (contract 2, reference 1, precision 1, vectorization 1,
  robustness 2, metamorphic 2, speed 1).
- tNgfQcScreen 28 (4 in each of the seven categories).
- TestQcPort 5 (reference 4, robustness 1).
- TestHelpExamples 52 -> 54 (contract).

Per tag: contract 182, reference 207, precision 23, robustness 115,
metamorphic 42, vectorisation 16, **vectorization 5**, speed 8. Without
gracefoReading, the three THR1B/ACT1B-dependent tests are incomplete: 595 +
0 + 3.

**Risks, stated:**
- The seven speed bounds were measured on the owner's host. If a bound
  fails on the runner, the failure is recorded, never widened.
- The rebuilt readers run for the first time. A red in `detectImpulsesReference` or
  `screenReference` is a reader fix in this PR, not a qc change.

**Debt:** Tier A (no local MATLAB). The six units are outside the
identifier catalogue and the generated docs until a conventions WP (audit
profile `qc-ported`).

**Verdict, CI run 36017541577 on `4f1abf0` (2026-09-24), MATLAB R2026a
Update 5, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:** `audit` green;
`matlab` green on the first run, **598 + 0 + 0 = 598**, every tag as
predicted (contract 182, reference 207, precision 23, robustness 115,
metamorphic 42, vectorisation 16, vectorization 5, speed 8). tNgfQc 10/10,
tNgfQcScreen 28/28 (the seven speed bounds held on the runner), TestQcPort
5/5. No new warning in the gate step. Gate time 1387 s.

---

## X-05 PR-A — DATAPOOL for the `matlab` job, D-9 catalogue, X-05 scope (issue #8) — merged 2026-09-24 (PR #51, `dcc185a`); scope was frozen 2026-09-24

Tier B. A `.github/` change, so it stands alone: it touches only
`.github/workflows/ci.yml`, `.github/matlab-audit.json`,
`.github/matlab-docs.json` and this file.

**Owner decisions 2026-09-24:**
- D-9 is recorded from **two scanned months**, 2020-01 (throwaway PR #49)
  and 2020-07 (throwaway PR #50, which also fetched 2020-07 into the
  DATAPOOL). Both PRs were closed unmerged.
- The three classes with **no real instance** in either month are covered
  by **synthetic tests only**, and each test says so.
- X-05 is cut into **three PRs**:
  - **PR-A** (this one): `.github/` and HANDOVER.
  - **PR-B**: the `qc` port, unchanged, with its tests.
  - **PR-C**: `mask`, the D-9 tests and release 0.2.0.
- **Port helpers.** `NonGravForces.fail` becomes an internal `fail` with
  the prefix `timeSeriesPreparation:`, so the identifiers read
  `timeSeriesPreparation:<unit>:<mnemonic>`. `NonGravForces.provenance`
  becomes a local record with the same fields; its FNV-1a option hash is
  unchanged.
- **Test inputs.** THR1B comes from gracefoReading `v1.1.0`
  `tests/realdata/THR1B_2020-01-01_C_04.txt` (read with
  `gracefoReading.readL1b`). The 600-s ACT1B sample is copied from
  NonGravForces `data/samples/` with its SHA-256. The tests change only in
  the reader call; every bound stays.

True after the merge:
- The `matlab` job's environment carries
  `READING_DATA_POOL: ${{ vars.READING_DATA_POOL }}`, the DATAPOOL root
  (HANDOVER F, 2026-09-19). Nothing reads it yet. PR-C's D-9 tests will,
  and a test that finds it empty is counted incomplete, never passed.
- **Audit profile `qc-ported`** for `+timeSeriesPreparation/+qc/*.m` and
  `tests/qc/*.m`: only a help block is required, as `sigtools-imported`
  did for X-01. The reason is stated in the profile. The ported help keeps
  NonGravForces' style, identifiers are raised through `fail` (not visible
  to the static check), and the ported tests keep their own layout. A
  conventions WP lifts it. Until then the six `qc` units are **not in the
  identifier catalogue**, which is debt.
- **Docs:** `+timeSeriesPreparation/+qc/*.m` is excluded from the generator
  until then. The ported EXAMPLEs call NonGravForces' readers and cannot run
  here.
- The D-9 catalogue below. GUIDE D-9 names this file as the place to
  record it.

**Fault injection (2026-09-24, ci-actions `v1.3.2`)**, on a copy of the
tree with PR-B's ported files in place:

| tree | finding |
|---|---|
| PR-B files, old configuration | A0 on all 9 ported files; docs D1 on 6 pages + TestHelpExamples |
| PR-B files, this configuration | audit **clean** (118 files); docs **in sync** (58) |
| the same, `hampel.m` without its help block | A1 |
| this repository as it is (no `+qc` yet) | audit **clean** (109); docs **in sync** (58) |

### D-9 — the defect catalogue (V-12, CONCEPT ORC-11)

GRACE-FO L1B RL04, below `<DATAPOOL>\GRACEFO\L1B\RL04\<yyyy>\<yyyy-mm-dd>\`.
Times are seconds of the GPS day of the named file. Found by the throwaway
scans (`tools/scanDefectCandidates.m`, never merged), each reading every
day with `gracefoReading.readL1b` (`v1.1.0`). The qualflg meanings are the
ones the file headers themselves print (2020-07 headers).

| id | class | file (day) | epoch range | expected verdict |
|---|---|---|---|---|
| DC-1 | satellite outage (GRACE-D AOCS safe mode, TN-01a) | ACT1B D 2020-01-18 … 2020-01-22 | last sample 01-18 18229 s; 01-19, 01-20, 01-21 files hold no data (`gracefoReading:readL1b:noData`); first sample 01-22 43385 s. KBR1B/LRI1B return 2020-01-24 at 36770 s / 57564 s | masked by the TN-01a event layer (01-18 05:05 … 01-22 12:05, D-4) and reported as one gap; never filled |
| DC-2 | gap across the day boundary | KBR1B Y 2020-01-14 → 2020-01-15 | last sample 01-14 82235 s; first sample 01-15 4675 s | one gap spanning both files; longer than the 21-s L1B fill limit, so the arc splits there |
| DC-3 | gaps inside a day | KBR1B Y 2020-01-08; KBR1B Y 2020-07-09 | 01-08: starts 70170 s (+740 s), 78290 s (+610), 79215 s (+75), 82025 s (+100); 07-09: 81680 s (+965) | four (one) gap segments; each longer than 21 s, so none is an L1B fill |
| DC-4 | KBR SNR drop | KBR1B Y 2020-01-14, `K_B_SNR` | minimum 288 at 82150 s (median of the day 774), just before DC-2's gap | flagged by the SNR layer (PR-C sets the threshold); smaller dips 2020-07-12 (723 at 61455 s) and 2020-07-17 (732 at 19145 s) stay unflagged |
| DC-5 | KBR phase break (qualflg bit 0) | KBR1B Y 2020-07-01; KBR1B Y 2020-07-09 | one flagged sample each day: 07-01 at 13590 s, 07-09 at 82645 s (logged by `TestDefectCatalogue`, CI run 36033100696) | masked by the qualflg layer (bit 0) |
| DC-6 | ACT1B clock-offset extrapolation (qualflg bits 3/4) | ACT1B C 2020-01-08; ACT1B C 2020-07-16 | 01-08: bits 3/4 on ~16 200 samples; 07-16: bit 3 on 10 750 samples | a qualflg layer, **reported, not masked by default**: the header reads "extrapolated CLK1B clock offset, > 5 s (bit 3) / ≤ 5 s (bit 4) from the CRN centre" — a time-tag quality statement, not a data defect. (Corrects this session's first reading, "large-range mode", which was wrong.) |
| DC-7 | KBR time-tag bias correction (qualflg bit 5) | KBR1B Y 2020-01-09 | all 17 182 samples | informational layer, **not masked**: the header reads "data corrected for time-tag bias in K or Ka phase" |
| DC-8 | thruster-heavy day | THR1B D 2020-01-04 (with ACT1B D 2020-01-04) | 727 THR1B records against ~440 on a typical day | THR1B windows layer; `qc` impulses assigned to THR1B with confidence 1 |

**No real instance in 2020-01 or 2020-07 — synthetic tests only** (owner,
2026-09-24):
- **Duplicate epochs at the day boundary.** Every file runs 0 … 86399 s
  (ACT1B) with no repeated epoch.
- **LRI phase jump.** LRI1B qualflg bit 0 is never set in either month.
- **Clear ACT1B bias jump.** The largest step of 10-min block medians
  after a 3-h moving median, over the robust scale of all steps, is 7.7
  (2020-07-20 at 85199 s) and 7.4 (2020-07-26): no isolated jump stands
  out.

A later month, or classic GRACE after G-02, may supply them. They then
enter this table and the synthetic test stays.

**Measured:** 2020-07 fetch (PR #50, same D-2 script): 93 archives, 0
failed, 2 821 extracted, **2 728 of 2 728** source MD5 verified, 0
conflicts; manifest `GRACEFO\L1B\RL04\2020\SHA256SUMS_2020-07.txt` (2 914
entries), 11 min. The 2020-07 scan: 124 rows (31 days × ACT1B C, ACT1B D,
KBR1B, LRI1B), no read error.

### X-05 scope (all three PRs)

- **PR-B, `qc` port.** NonGravForces `3cc0123` (0.12.0, the pin in CONCEPT
  2), `+NonGravForces/+qc/`: `residuals`, `hampel`, `detectImpulses`,
  `detectJumps`, `eventTable`, `screen` → `+timeSeriesPreparation/+qc/`.
  With them come `tests/tNgfQc.m` and `tests/tNgfQcScreen.m` and the
  oracles they read (`tools/pyxcheck/hampel_*`, `pelt_*`). The `v0.12.0`
  tag differs from `3cc0123` only in five help lines of `screen.m`. The
  only code changes are the ones the namespace forces, and a `reference`
  test checks that every ported file equals its original once they are
  mapped back. Conventions, speed (X-16) and templates (X-17) come later.
- **PR-C, `mask` and D-9.** `mask` (CONCEPT 6.1, row 1): qualflg layers
  via `gracefoReading.decodeQualFlags`, the L1B fill flags, THR1B windows,
  CRN edges, a user layer and the official event lists
  (`gracefoReading.readEventList`, G-05). One test per DC row above on the
  real day, plus the three synthetic classes. Release **0.2.0**.

**Prediction for PR-A** (before any run): **553 + 0 + 0 = 553**, unchanged
from X-09 PR 2 (no test is added; the new variable is not read yet).

**Verdict, CI run 36010094684 on `06b20dd` (2026-09-24), MATLAB R2026a
Update 5, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:** `audit` green;
`matlab` green, **553 + 0 + 0 = 553** as predicted, every tag unchanged
(contract 174, reference 198, precision 18, robustness 108, metamorphic
36, vectorisation 16, speed 3). No new warning in the gate step. Gate time
1159 s.

---

## X-09 PR 2 — regression with VIF gate, partial correlation, binned maps — merged 2026-09-24 (PR #48, `ffe0164`; issue #12 closed); scope was frozen 2026-09-24

Tier B. Design: CONCEPT 7 (the remaining three methods) and 8 (demean
regressors; block bootstrap for sigmas).

**Owner decisions 2026-09-24 (second round):**
- The VIF gate is **10, a Config default**. It is provisional until real
  data refine it, like the 0.5 gate.
- Coefficient sigmas come from the **block bootstrap**.
- Binned maps give **mean, sd and count** per bin. The bin edges are the
  caller's, and empty bins are NaN.
- The methods are **three L2 functions**. CONCEPT 3.2 and the layering map
  gain `regressDrivers`, `partialCorrelation` and `binnedMap`.

True after the merge:
- **`regressDrivers(P, Z, ...)`** (L2): P (R,J) holds the gated
  per-revolution parameters and Z (R,K) the drivers. Rows are in time
  order.
  - Per parameter j, the fit is OLS on the rows complete in P(:,j) and Z,
    with the regressors demeaned (CONCEPT 8). coef(1,j) is the intercept,
    which is the mean of P(:,j).
  - The VIF gate uses diag(inv(corrcoef(Z))) on the rows complete in Z. A
    driver above MaxVif (default 10) refuses with `regressDrivers:collinear`.
  - sigma and ci come from `bootstrap` over the rows [P(:,j) Z]: automatic
    block length, seed from the stage name.
  - Outputs: coef, sigma, ci, vif, r2, nRows, blockLength and names.
  - Errors: `sizeMismatch`, `collinear`, `tooFewRows` (fewer than K + 2
    rows).
- **`partialCorrelation(X, ...)`** (L2): partial correlation of each pair
  of columns given all the others, from the inverse correlation matrix:
  -P_ij / sqrt(P_ii P_jj), on the complete rows. Sigma and ci come from the
  block bootstrap. Errors: `tooFewVariables` (V < 2), `collinear`,
  `tooFewRows`.
- **`binnedMap(value, a, b, edgesA, edgesB)`** (L2): per bin of (a, b),
  the mean, the sd (n − 1; NaN below 2 samples) and the count. It uses
  `discretize` rules: bins are right-open except the last. NaN samples and
  samples outside the edges are ignored, and empty bins are NaN. Errors:
  `sizeMismatch`, `badEdges`.
- `Config.drivers` gains `maxVif` (10).
- Records: CONCEPT 3.2 (three new L2 units), 7 and history; TestLayering;
  Contents, CHANGELOG, generated docs.

**Tests planned:**
- References: `backslash` on [ones, demeaned Z]; VIF 1/(1 − r²) for
  constructed regressors; the 3-variable partial-correlation formula; an
  explicit loop for `binnedMap`.
- Precision: partial correlation equals the correlation of the residuals
  after regressing each variable on the rest.
- Measured band (NumPy, 2026-09-24): over 100 realisations of 600 rows
  with white errors, the bootstrap slope sigma was 0.86–1.21 of the OLS
  sigma; the test holds 0.75–1.35. The intercept's bootstrap sigma ran up
  to 1.36 of the OLS value, because each replicate re-centres Z, so no test
  compares it with OLS.

**Amendment:** the singularity threshold is rcond < 1e-12, not eps. With
eps, an exactly dependent column can slip through on rounding (rcond
around 1e-16). Both `regressDrivers` and `partialCorrelation` use 1e-12.

**Fault injection:**
- The references are backslash, the 3-variable formula, the residual
  correlation and an explicit loop, all written in the tests.
- Dropping the demeaning changes coef(1) away from mean(P).
- The VIF gate refuses at 50 against 10 and passes at MaxVif 100.

**Prediction** (before any run): **554 + 0 + 0 = 554**. (Corrected below:
553.) That is 534 plus:
- TestRegressDrivers 7 (reference 3, contract 1, metamorphic 1,
  vectorisation 1, robustness 1).
- TestPartialCorrelation 5 (reference 1, precision 1, contract 1,
  metamorphic 1, robustness 1).
- TestBinnedMap 4 (reference 1, contract 1, metamorphic 1, robustness 1).
- TestConfig +1 (contract).
- TestHelpExamples 49 -> 52 (contract).

Per tag: contract 175, reference 198, precision 18, robustness 108,
metamorphic 36, vectorisation 16, speed 3.

**Verdict, first run:** CI run 35980346146 on `2958261` (2026-09-24):
`audit` green; `matlab` **552 + 1 + 0 = 553**.
- **The failure was a bug in the test.**
  `TestRegressDrivers/refusalsAndGate` planted too few rows on the u, v
  pair with rho 0.99. The VIF gate (50 > 10) runs first, so it raised
  `collinear` instead of `tooFewRows`. The fix passes MaxVif = 100 in that
  call, so the row check is what fires. The function is unchanged.
- **The prediction was wrong by one.** TestConfig gained no test: its
  drivers test was extended, not added. The correct prediction is **553
  + 0 + 0**: contract 174, reference 198, precision 18, robustness 108,
  metamorphic 36, vectorisation 16, speed 3. Every other tag matched.

**Verdict, MATLAB R2026a, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:**
CI run 35982964249 on `336f36c` (2026-09-24): `audit` green; `matlab`
green, **553 + 0 + 0 = 553**, every tag as corrected (contract 174,
reference 198, precision 18, robustness 108, metamorphic 36,
vectorisation 16, speed 3). No warnings from the new functions appear in
the part of the log that was read. Gate time 1028 s.

**Cited from memory, not re-read** (debt): Kutner et al. 2005 sect. 10.5,
Kuensch 1989 and Whittaker 1990.

---

## X-09 PR 1 — `drivers` and lagged `correlate` — merged 2026-09-24 (PR #47, `8182010`); scope was frozen 2026-09-24

Tier B. Design: CONCEPT 7, 6.1 row 9, 10.1 row X-09 (needs X-07, merged).

**Owner decisions 2026-09-24:**
- **Two PRs.**
  - PR 1: `drivers`, lagged correlation of pre-whitened series, the
    effective sample size and block-bootstrap CIs.
  - PR 2: regression with the VIF gate, partial correlation, and binned
    (β′, u) maps.
- **`drivers` aligns and validates supplied series and computes no
  physics.** β′, u, eclipse, space weather, THR1B counts and SNR come from
  other toolboxes (CONCEPT 7). There is no per-revolution averaging.
- **Pre-whitening with a caller-supplied noise model.** `correlate` hides
  no fit.

True after the merge:
- **`drivers`** (L2): `drv = drivers(arc, series, Method = "pchip", MaxGap = [])`.
  - `series` is a (1,K) struct with fields `name`, `t` (int64 GPS ns,
    increasing), `value` (double, NaN missing) and `unit`. A unit is
    required (R5).
  - Each driver goes onto `arc.t` by align's rule
    (`internal.resampleOnto`). It is exact at coinciding epochs, never
    interpolated across a hole, and never extrapolated.
  - It returns a struct: `t`, `names`, `units`, `values` (N,K), `gap`
    (N,K), `method`, and `maxGap` (1,K).
  - Errors: `drivers:badSeries`, `drivers:duplicateName`,
    `drivers:unitUnknown`.
- **`correlate`** (L2), lagged correlation:
  `res = correlate(arc, drv, model, maxLag, AcfLags, BootLags = 0, NBoot, BlockLength, Seed, Stage = "correlate", Level)`.
  - **Pre-whitening follows Box and Jenkins.** Axis m and every driver are
    filtered by the inverse of axis m's ARMA model (a/b, `noise`'s
    output), each after removing its own mean. Each finite segment is
    filtered from rest, and its first p samples are dropped. For AR models
    that is exact; for MA terms the start-up transient decays like
    theta^k. With the residual white, the null variance of r is 1/n
    whatever the driver's own autocorrelation (Bartlett), so one model per
    axis is enough.
  - r(l, m, k) is the Pearson correlation over the complete pairs
    (x'_t, d'_(t-l)), for l = -maxLag..maxLag samples. A positive lag
    means the driver leads.
  - nEff(m, k) = n / (1 + 2 sum_k rho_x'(k) rho_d'(k)), using the
    gap-aware `tsmodels.tsAcf` of the whitened series up to AcfLags.
  - The CI at every lag is Fisher z with nEff.
  - At BootLags, a moving-block bootstrap of the pair rows is run through
    `bootstrap` (automatic block length, seed from Stage).
  - maxLag has no default (R5).
  - Errors: `correlate:epochMismatch`, `correlate:modelMismatch`,
    `correlate:irregularGrid`, `correlate:tooFewPairs` (and
    `correlate:badBootLag`, see the amendment).
- `Config.drivers`: method ("pchip"), maxGap ([]) and maxLag ([], no
  default).
- Records: CONCEPT 7 (the pre-whitening rule and the lag convention),
  Contents, CHANGELOG, generated docs.

**Tests planned:**
- Reference: a white model reduces `correlate` to corrcoef of the shifted
  vectors. A white transfer x_t = e_t + beta d_(t-l0) peaks at l0 with rho
  = beta sd / sqrt(beta^2 sd^2 + se^2).
- Precision: AR(1) pre-whitening returns the innovations exactly.
- Metamorphic: two independent AR(0.95) series stay within the null band
  after pre-whitening. They far exceed it before.
- `drivers` equals `align` on a same-unit driver, bitwise.
- Contract, vectorisation and robustness as usual.

**Measured before coding (NumPy, 2026-09-24):**
- AR(1) pre-whitening returns the innovations to 4e-16.
- x_t = e_t + 0.5 d_(t-7), n = 4000: the peak lands at +7 in every
  realisation. The scatter of r - 0.447 is 0.0122 (theory 0.0126), and the
  worst of 300 is 0.038. Tests hold it to 0.065.
- Two independent AR(0.95) series, n = 3000, lags -50..50. Before
  pre-whitening, nEff/n is 0.039–0.069; after, 0.986–1.010. After
  pre-whitening, max |r| sqrt(n) is at most 4.18 over 200 realisations.
  Tests hold these to < 0.1, 0.95–1.05 and 5.5.
- Lag-0 block-bootstrap sigma over (1 - r^2)/sqrt(n): 0.90–1.10 over 100
  realisations. Tests hold it to 0.75–1.3.
- Raw max |r| can be as small as 0.028, so no test asserts that the raw
  correlation exceeds the band.

**Amendment:** a new error, `correlate:badBootLag`, for a BootLags entry
beyond maxLag. It replaces silent clamping.

**Fault injection:**
- The reference tests compute r independently with corrcoef, and the
  pre-whitened reference with a direct `filter`.
- Filtering only the residual (not the driver), or the wrong lag sign,
  moves the transfer peak to -7 or changes r by O(0.1).
- Each identifier's test plants its own trigger.

**Prediction** (before any run): **534 + 0 + 0 = 534**. That is 515 plus:
- TestDrivers 7 (reference 1, precision 1, contract 2, metamorphic 1,
  vectorisation 1, robustness 1).
- TestCorrelate 9 (reference 3, precision 1, contract 2, metamorphic 1,
  vectorisation 1, robustness 1).
- TestConfig +1 (contract).
- TestHelpExamples 47 -> 49 (contract).

Per tag: contract 168, reference 193, precision 17, robustness 105,
metamorphic 33, vectorisation 15, speed 3.

**Verdict, MATLAB R2026a, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:**
CI run 35972395466 on `4587a5d` (2026-09-24): `audit` green; `matlab`
green, **534 + 0 + 0 = 534**, every tag as predicted (contract 168,
reference 193, precision 17, robustness 105, metamorphic 33,
vectorisation 15, speed 3). TestDrivers 7 and TestCorrelate 9 all pass;
no warning from `drivers`, `correlate`, `bootstrap` or `tsAcf`. Gate
time 1034 s.

**Cited from memory, not re-read** (debt): Box et al. 2015 ch. 12,
Bartlett 1946 and Fisher 1921, all named in `correlate`'s help.

---

## X-08 — `fill` — merged 2026-09-24 (PR #46, `a08cfc0`; issue #11 closed); scope was frozen 2026-09-24

Tier B (no local MATLAB; the MATLAB verdict is CI's). Design: CONCEPT
6.5, 3.2 (no least-squares estimator; `fill` takes a covariance model),
10.1 row X-08, Q3 (default `none`). Needs X-07 (merged) and V-7.

**V-7 answered from the code (2026-09-24).** The sigtools gap-aware
Kalman filter only filters and forecasts. `tsFitSarima`/`tsFitArima` run
the missing-data filter to get the likelihood, where "the Kalman filter only
predicts at a gap". `tsForecast` "runs the missing-data Kalman filter to the
end of the history" and then projects forward. No routine runs a backward
(smoothing) pass. So `fill` supplies the interpolation itself.

**Owner decisions 2026-09-24:**
- **Covariance collocation**, not an RTS smoother. This takes any
  autocovariance, including one from lsqvce (CONCEPT 3.2).
- **`reference` is deferred** until after X-09 (drivers). In X-08 it
  refuses with its own identifier.

True after the merge:
- **`fill`** (L2): `[arc, info] = fill(arc, Method = "none" | "collocation",
  Model = <struct>, MaxGap = <s>, Window = <samples>)`.
  - A missing sample is NaN, weight 0 or already filled; each axis is
    treated separately. The grid must be uniform (as for `noise`).
  - `none` (default) changes nothing and only reports the gaps.
  - `collocation` predicts each interior gap of at most `MaxGap` seconds.
    It uses x_g = mu + C_go C_oo^-1 (x_o - mu), where the observed samples
    are those within `Window` samples on either side of the gap. The
    covariance is Toeplitz from `Model.acv`; the window rule is in the
    amendment below. `info.sigma` is the prediction standard
    deviation, sqrt(diag(C_gg - C_go C_oo^-1 C_og)).
  - Not filled, but reported: runs at the arc edges (extrapolation) and
    runs longer than `MaxGap`.
  - `Model` is `noise`'s output or any struct with `acv` (L+1, M), `dt`
    (s) and `mu` (1, M).
  - The arc keeps its epochs. Filled values enter `obs`, and the row is
    flagged in `arc.filled` (N x 1, CONCEPT 5). A row is flagged when any
    of its axes was filled, so every fit weighs the whole row 0.
- `Arc`: a new method writes the filled values and the flag, and appends
  the `fill` provenance entry. This is the only way a stage can change
  `obs` on the same epochs.
- `Config.fill`: `method` ("none"), `maxGap` ([] s, no default, Q3),
  `window` ([] = the model's largest lag).
- Errors:
  - `fill:maxGapMissing`, `fill:modelMissing`, `fill:modelMismatch`
    (dt or column count);
  - `fill:irregularGrid`, `fill:notPositiveDefinite` (a truncated ACV that
    is not a covariance);
  - `fill:referenceDeferred`.
- Records: CONCEPT (V-7 closed, 6.5, the X-08 row), Contents, CHANGELOG,
  generated docs, TestLayering (L2 gains `fill`).

**Tests planned (TestFill):**
- Reference: an AR(1) one-sample gap gives
  phi/(1 + phi^2) (x_(t-1) + x_(t+1)), with variance sigma2/(1 + phi^2).
- Reference: an AR(1) bridge of k samples against the closed form. An AR(p)
  gap with Window >= p equals the full-record conditional expectation to
  rounding, because the AR precision matrix is banded (Markov).
- Precision: an ARMA(1,1) window converges to the full conditional
  expectation. The tolerance comes from a NumPy run.
- Contract: gap report, edges, MaxGap, flags, provenance, Config.
- Metamorphic: filling twice gives the same result; scaling x scales the
  fill.
- Vectorisation: a batched call equals per-axis calls.
- Robustness: every error above.

**Amendment, measured before coding (2026-09-24).** The frozen text
zero-padded the autocovariance beyond its largest lag L. NumPy showed that
this padding biases the fill: 2e-9 for an AR(1) with L = 50 against the
closed form. It can also make C_oo indefinite. The window W is therefore
capped at floor((L - k + 1) / 2) for a gap of k samples. Every lag inside
the window is then at most L, and the matrix is the model's own. A gap the
model cannot bridge (W < 1) is reported as `beyondModel` instead of being
filled. `info.gaps.width` records the W that was used. With this rule,
NumPy gives (2026-09-24):
- AR(1) one-sample and bridge closed forms: 6e-16.
- AR(2) window against the whole record: 1.1e-15 over 50 realisations,
  also with a second gap inside the window.
- ARMA(1,1), worst over 200 realisations: 1.4e-3, 1.4e-6, 1.1e-12 and
  4.7e-15 sigma for L = 40, 60, 100 and 140.

`fill:notPositiveDefinite` stays; it now fires only for an ACV that is not
an autocovariance.

**Fault injection:**
- Each identifier's test plants its own trigger.
- The reference tests are closed forms written from gamma_k, not from
  `fill`. Dropping the Cholesky solve or mis-indexing the Toeplitz lag
  moves the AR(1) value by O(1).
- Zero-padding beyond L instead of capping W fails
  `ar1OneSampleClosedForm` by 2e-9 against 1e-12 (NumPy).

**Prediction** (before any run): **515 + 0 + 0 = 515**. That is 499 plus:
- TestFill: 12 (reference 3, precision 1, contract 4, metamorphic 2,
  vectorisation 1, robustness 1).
- TestArc +2 (contract, robustness).
- TestConfig +1 (contract).
- TestHelpExamples 46 -> 47 (contract).

Per tag: contract 161, reference 189, precision 15, robustness 103,
metamorphic 31, vectorisation 13, speed 3.

**Verdict, MATLAB R2026a, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:**
CI run 35960930225 on `cbac23e` (2026-09-24): `audit` green; `matlab`
green, **515 + 0 + 0 = 515**, every tag as predicted (contract 161,
reference 189, precision 15, robustness 103, metamorphic 31,
vectorisation 13, speed 3). TestFill 12 of 12; no warning from `fill`.
Gate time 1015 s.

**Cited from memory, not re-read** (debt, as for X-07): Moritz 1980
(collocation) and Brockwell & Davis 1991 (best linear prediction), both
named in `fill`'s help.

---

## X-07, the reference noise-model library — merged 2026-09-24 (PR #45, `fae4071`; issue #10 closed); scope was frozen 2026-09-23

Tier B. The owner supplied the sources on 2026-09-23. These are arXiv
copies of P-11, P-9 and P-13, and the ESSD paper P-21. Every constant below
was read from the rendered page image, not from the text layer, which
garbles the formulas.

True after the merge:
- **`noiseReference`** (L1, beside `crnKernel`; CONCEPT 0.17) gives
  one-sided ASDs:

  | model | ASD | stated band | status | source |
  |---|---|---|---|---|
  | `LRI` | 80 nm/sqrt(Hz) sqrt(1+(3 mHz/f)^2) sqrt(1+(10 mHz/f)^2) | 2–100 mHz | requirement | P-13 p. 4 |
  | `LRI-laser` | 5e-9 sqrt(1+(0.0182 Hz/f)^2) m/sqrt(Hz), 238 km | none stated; 1e-4–1e-1 Hz as plotted in its Fig. 12 | simulation model | P-21 Eq. 21 p. 841 |
  | `KBR` | 1e-6 sqrt(1+(0.0018 Hz/f)^4) m/sqrt(Hz), 238 km | 1e-5–1e-1 Hz | simulation model (after Kim 2000) | P-21 Eq. 15 p. 839 |
  | `ACC` x, z | 1e-10 sqrt(1+0.005 Hz/f) m s^-2/sqrt(Hz) | 1e-5–1e-1 Hz | simulation model (after Kim 2000) | P-21 Eq. 9 p. 838 |
  | `ACC` y | 1e-9 sqrt(1+0.1 Hz/f) m s^-2/sqrt(Hz) | 1e-5–1e-1 Hz | simulation model | P-21 Eq. 9 p. 838 |

  `Derivative` 1 or 2 multiplies by (2 pi f)^n. `info.inBand` marks the
  stated band.
- For scale, measured values: the in-orbit LRI is about 1 nm/sqrt(Hz)
  above 100 mHz (P-13, abstract), and the KBR white noise is about
  0.6 um/sqrt(Hz) (P-9 sect. 6.3). Both are below the model and the
  requirement.
- REFERENCES: P-21 added. P-9, P-11 and P-13 carry the SHA-256 of the
  copies that were read. The PDFs are not committed; the owner places them
  in the DATAPOOL.

**Not found in the supplied sources:** a KBR "CNR-limited" formula as
such. P-21 Eq. 15 is the system-plus-oscillator model, and P-9 gives a
measured level. The LRI entry is the requirement; P-21 Eq. 21 gives the
laser-frequency part.

**Fault injection:** the reference tests pin each formula at its corner
frequency against a value written from the page. Changing any printed
constant (for example 3 mHz to 2 mHz, or the KBR exponent 4 to 2) moves the
corner value by more than 1e-15 relative, so the test fails. A Python
evaluation of the printed formulas matches the expected values to 0 and
the slopes to 1.4e-4 (2026-09-23).

**Prediction** (before any run): **499 + 0 + 0 = 499**. That is 489
plus TestNoiseReference 9 plus TestHelpExamples 45 -> 46. Per tag:
contract 154, reference 186, precision 14, robustness 101, metamorphic 29,
vectorisation 12, speed 3.

**Verdict, MATLAB R2026a, gracefoReading `v1.1.0`, lsqvce `v6.1.3`:**
CI run 35913104426 on `e275611` (2026-09-23): `audit` green; `matlab`
green, **499 + 0 + 0 = 499**, every tag as predicted (contract 154,
reference 186, precision 14, robustness 101, metamorphic 29,
vectorisation 12, speed 3). TestNoiseReference 9 of 9. Gate time 1003 s.

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
- Classic GRACE metadata (X-13, owner 2026-09-27: out of that WP):
  `exportNetcdf` writes the keyword "GRACE-FO" and `run`'s DataCite block
  "Prepared GRACE-FO instrument time series" for classic arcs too, and
  `report` draws GRACE-FO's reference ASD (noiseReference) for classic
  ACC1B and KBR1B. Each is one mission-aware string or guard.
- V-1's classic half (the CRN span of classic ACC1B, 70.7 s per D-22027
  or 140.7 s as for GRACE-FO): no public classic ACC1A on ISDC (scan PR
  #69); waits for another source.

---

## A. Status

**Release 1.5.0 merged** (X-19, PR #74, `977d10d`; CI 728 + 0 + 0; **release v1.5.0**; issue #73 closed). Release 1.4.0 merged (PR #72, `ad2c445`; CI 727 + 0 + 0; **release v1.4.0**). X-13 merged (PR #71, `beaafa5`; CI 727 + 0 + 0; fault injection 725 + 2 + 1 as intended; issue #16 closed). CI pin gracefoReading v1.3.0 merged (PR #70, `71e7ce4`; CI 726 + 0 + 0). Release 1.3.0 merged (PR #68, `bc3415a`; CI 726 + 0 + 0; **release v1.3.0**). X-12 merged (PR #67, `0fa7b4b`; CI 726 + 0 + 0; issue #15 closed). X-11 merged (PR #65, `7c3c222`; CI 723 + 0 + 0; issue #14 closed). X-18 merged (PR #64, `5cba363`; CI 716 + 0 + 0; **release v1.2.0**; issue #21 closed). X-17 merged (PR #63, `db47634`; CI 698 + 0 + 0; issue #20 closed). X-15 merged (PR #61, `a82c710`; CI 687 + 0 + 0; **release v1.1.0**; issue #18 closed). X-16 merged (PR #60, `ca5230f`; CI 676 + 0 + 0; issue #19 closed). X-14 merged (PR #59, `a264793`; CI 669 + 0 + 0; issue #17 closed). X-10 merged (PR #58, `3bc1f4c`; **release v1.0.0**; issue #13 closed).

**Earlier:** X-05b merged.
O-6 merged (PR #54, `7c7fb7b`; CI 622 + 0 + 0).
X-05 PR-C merged (PR #53, `f448f78`; CI 622 + 0 + 0); **release v0.2.0** tagged on the merge by the release workflow; issue #8 closed.
X-05 PR-B merged (PR #52, `b5633c0`; CI 598 + 0 + 0).
X-05 PR-A merged (PR #51, `dcc185a`; CI 553 + 0 + 0).
X-09 PR 2 merged (PR #48, `ffe0164`; CI 553 + 0 + 0; issue #12 closed).
X-09 PR 1 merged (PR #47, `8182010`; CI 534 + 0 + 0).
X-08 merged (PR #46, `a08cfc0`; CI 515 + 0 + 0).
X-07 library merged (PR #45, `fae4071`; CI 499 + 0 + 0).
X-07 merged (PR #44, `f7d3518`; CI 489 + 0 + 0).
lsqvce CI dependency merged (PR #43, `5afbd87`; CI 421 + 0 + 0).
Release workflow merged (PR #42, `298b7cd`); its first run
released nothing, as designed. `.github/` profile switch merged (PR #41,
`7b94df4`). X-02 merged (PR #40, `7fe24f3`). X-06 merged (PR #39,
`4f9e11e`). X-04 merged (PR #38, `f969ecb`, release 0.1.0). The tag `v0.1.0` is lightweight and sits on
`7fe24f3` (owner, release UI; GUIDE §3 anomaly table). X-01 + X-03 merged
(PR #37); X-00b (PR #36); X-00a (#2).

**Phase 0 complete (2026-09-19):**
- Stage A: repositories, settings and issues.
- Stage B: data D-1 … D-10 (D-9 recorded 2026-09-24).
- Stage C: references and V-items (CONCEPT 9.3).
- 0.4: lsqvce V-6 answered; `v6.1.0` tagged on `21e470d` and released.

C-01 and C-03 are merged in ci-actions (#6, closed 2026-09-20; tags up to
`v1.3.2`). Next: X-05 (#8) in three PRs
(PR-A `.github/`, PR-B `qc` port, PR-C `mask` + D-9 + release 0.2.0); V-12
is answered by D-9.

**GUIDE A5 done:** one issue per WP, X-00b … X-18 = #3–#21 (map in GUIDE Appendix A).

| item | state |
|---|---|
| repository | private, `main`; auto-delete head branches on; MIT licence (owner, 2026-09-18) |
| ruleset `Main Protection` | no deletion, no force push; **no required checks yet** (see O-2) |
| ruleset `Tag protection` | `~ALL`, no deletion, no force push |
| content | `docs/CONCEPT.md` Rev 0.17, `docs/GUIDE.md` rev 1.11, `docs/inputs/` (4 files), this HANDOVER, README; code as below |
| code, `Contents.m`, CI, audit | X-00b: setup, gate, `ci.yml` (`audit`, `matlab`), shared audit and generator. X-01: `+spectral`, `+tsmodels`, `demos/`, `tests/sigtools/`. X-03: `Arc`, `Config`. X-04: `crnKernel`, `crnApply`, `Contents.m` 0.1.0 |
| `docs/GUIDE.md` | rev 1.11 (release workflow; `v0.1.0` anomaly) |
| `docs/CONCEPT.md` | Rev 0.20 (X-09: `drivers`, `correlate`, `regressDrivers`, `partialCorrelation`, `binnedMap`; 3.2, 7) |
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
| D-9 | **recorded 2026-09-24**: 8 classes from 2020-01 and 2020-07, 3 classes synthetic only (see X-05 PR-A) | scans on throwaway PRs #49, #50; 2020-07 fetched with the D-2 script, `GRACEFO\L1B\RL04\2020\SHA256SUMS_2020-07.txt` (2 914) |
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
| O-6 | raise the `matlab` job's `timeout-minutes` (30) before the gate outgrows it: 27 min 7 s at X-05 PR-C (run 36033100696). A `.github/` change, its own PR | **closed 2026-09-24**: 30 → 60 min (PR #54) | Session, owner merges | before the next WP that adds real-data tests |
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
