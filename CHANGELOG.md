# Changelog — timeSeriesPreparation

Semantic versioning (`ci-actions/VERSIONING.md`); `+timeSeriesPreparation/Contents.m`
is the single version source. Work packages are the rows of `docs/CONCEPT.md` 10.1.

## Unreleased

- **X-12** V-1 closed: `TestCrnVerification` rebuilds JPL's Level-1B chain
  from the GRACE-FO Level-1A files of C and D, 2020-01-02. The chain maps the
  ACT1A tags from OBC to receiver time (TIM1B) and on to GPS time (CLK1B),
  resamples them to 0.1 s and applies `crnApply` with `crnKernel("ACC")`.
  The result equals ACT1B to 2e-6 … 2.5e-5 relative rms per axis; the bar is
  2e-3. Tf 70.7 s (classic GRACE handbook) misses and is refuted. The
  Level-1A days live in the DATAPOOL, downloaded by the CI runner. Found:
  gracefoReading v1.1.0 cannot read CLK1B (`readL1b:noTime`), so the test
  parses it itself.

- **X-11** `report` draws four figures from a run result: series with
  layers, gaps and fills; the QC events; the residual PSD against the
  noise model and noiseReference; alignment and correlation. A panel
  whose stage did not run says why. With ExportTo it writes PNGs (200 dpi)
  and one self-contained HTML page (summary, skipped stages, events,
  provenance, embedded images). For a campaign result it writes one page
  per day and index.html. It is tested for its contract and for speed
  (under 10 s per figure); no pixel reference is kept.

## 1.2.0 — 2026-09-26

Exchange release (GUIDE section 7: X-17 → X-18 → v1.2.0).

- **X-18** CF/ACDD NetCDF export: `exportNetcdf` writes an arc, its
  residual and its QC events as NetCDF-4 with Conventions
  "CF-1.12, ACDD-1.3". Time is int64 GPS nanoseconds with
  `units_metadata = "leap_seconds: none"` (owner's choice; CF 1.13 has
  since withdrawn that attribute in favour of the calendar "tai"). Layers
  are CF flag bits and events are coded flags. The PROV-O graph of the
  arc's provenance is written as JSON-LD both in the file and in a
  `.prov.jsonld` sidecar (new `internal.provJsonLd`). `readNetcdf`
  returns the file bit for bit. `Config.export` holds the creator and the
  other dataset metadata; there is no default creator. `cfg.run.format`
  is "mat", "netcdf" or "both"; a campaign writing NetCDF without a
  creator refuses. The campaign summary gains `netcdf` and
  `netcdfSha256`, and the manifest (schema 2) gains a DataCite 4.7 block.
  Arc has `SchemaVersion` "2" with saveobj/loadobj: arcs saved by 1.1.0
  load unchanged and unknown versions refuse. Day files carry
  schemaVersion "2".
- **X-17** QC template bank: `qc.templateBank` holds the empirical
  thruster stacks of the GRACE-FO ACT1B residual (C and D, lags -60..60 s,
  two months of the DATAPOOL, scan PR #62); `qc.detectTemplates` finds
  them in a 3-axis residual with a matched filter and a robust score (8
  sigma), assigns THR1B firings within 5 s and returns one mask per
  class. `Config.qc.templates` (false) lets `run` add the stage
  "templates" after qc, the layer "tplThruster" and
  `diagnostics.templates`. Magnetorquer is left to N-11, the heater is
  deferred (no key series in L1B RL04), broad z-spikes are ignored.

## 1.1.0 — 2026-09-26

Campaign release (GUIDE section 7: X-14 → X-16 → X-15 → v1.1.0).

- **X-15** campaign mode of `run`: an Arc array runs every arc through the
  stages with seed cfg.run.seed + k - 1; a refusing arc keeps its
  MException and the campaign continues. Reference, Thrusters and (as
  cells) QualFlags, Eclipse, User and Design may be given per arc. The
  arcs must share one L1B release unless cfg.run.mixedRelease is set.
  cfg.run.parallel runs the arcs in `parfor` when a pool can be used
  (equal to serial). With cfg.run.outDir, each arc's result is a MAT v7.3
  day file `<mission>/<satellite>/<yyyy>/<yyyy-mm-dd>.mat` and
  `manifest.json` records the campaign (software, dates, config hash,
  per arc source files, content hash, file SHA-256, status); existing
  files are kept unless cfg.run.overwrite is set. New
  `internal.fileSha256`.
- **X-16** QC speed, pure MATLAB, numbers unchanged: `qc.hampel` computes
  the moving median and the exact window MAD vectorised (`movmedian`,
  window blocks) instead of a per-sample loop; `qc.detectJumps` caches
  each PELT candidate's cumulative sums and F(tau) beside it (no gathers
  per step); `qc.detectImpulses` and
  `qc.screen` build their event bookkeeping once. Every output equals the
  X-05 port bit for bit (TestQcEquivalence); speed tests pin the ratio
  against the port.
- **X-14** stage cache of `run`: with `Config.run.cacheDir` set, crn, qc,
  noise and correlation keep their outputs under
  `<cacheDir>/<stage>/<key>.mat`. The key is the SHA-256 of the stage, the
  toolbox version, the inputs by content and the settings
  (`internal.contentHash`). `diagnostics.cache` and provenance report every
  hit, miss, rewrite or unsaved result. Stages with a function handle
  (bootstrap, crossval) are never cached. Off by default.

## 1.0.0 — 2026-09-25

First stable release (GUIDE section 7: X-10 → v1.0.0). The instrument level
is complete: every stage of CONCEPT 6.1 and the single point of access
`run`. NonGravForces N-02 and rangingPreparation L-03 can build on it.

- **X-10** integration tests (`TestIntegration`): ACT1B GRACE-C of
  2020-01-02 through `run` against ITSG nonConservativeForces, held to the
  V-4 thresholds (correlation >= 0.95 / 0.95 / 0.93; scales within 5 % of
  1.066 / 0.915 / 0.864) and to V-17 (band delay < 1 s on x and z); and a synthetic arc whose planted
  spikes, gap, noise level, bias and scale `run` recovers.
- V-17 (CONCEPT 9.3): ITSG `nonConservativeForces` is about 3 s late
  against JPL ACT1B and band-limited to about 10 mHz; the integration test
  moves the ITSG epochs and checks the band delay (x, z < 1 s). The scales
  are fitted in V-4's direction, ref = b + s * obs.
- CI: the `matlab` job's timeout is 60 min (O-6, PR #54).
- **X-05b** `qc`: help in this repository's template, errors raised with
  literal identifiers (catalogued once the `.github` follow-up lands),
  test tags spelled `vectorisation`; `internal.fail` removed. Numbers
  unchanged: `TestQcEquivalence` holds every output to the frozen X-05
  port, which `TestQcPort` holds to NonGravForces 0.12.0.
- `.github/` follow-up of X-05b (PR #56): `+qc` audited under the public
  template and documented; the catalogue lists 157 identifiers.
- **X-10** `run`: the instrument stages on one arc. Each stage runs when
  its input is given (a reference, mask sources, a noise order, a design,
  a statistic, drivers) and is otherwise listed with its reason in
  `diagnostics.skipped`; the result has exactly the fields `arc`,
  `reference`, `diagnostics`, `correlation`, `flags`, `config`,
  `provenance`. Each stage's result equals its direct call.
- **X-10** `Config`: every section has its fields; `qc` (qc.screen's
  options), `noise` (order, no default; method, maxLag, lags,
  welchAverages) and `run` (filterReference, not stated by default; seed).

## 0.2.0 — 2026-09-24

Second release (GUIDE section 7, Phase 2: X-05 → v0.2.0). Besides X-05 it
carries X-06, X-02, X-07, X-08 and X-09, merged after 0.1.0.


- `.github/` profile switch (PR #41): `+spectral` and `+tsmodels` are audited
  under the public help template and documented; the error catalogue lists
  94 identifiers, warnings included; their 29 help examples run in the gate.
- Release workflow: a merge whose `Contents.m` names an untagged version gets
  an annotated tag on the merge commit and a GitHub release
  (`ci-actions/matlab-release`, `mode: file`).
- CI checks out lsqvce `v6.1.3` as a test-only dependency (PR #43).
- **X-07** `bootstrap`: moving-block bootstrap of any statistic; one RNG
  substream per replicate, the seed derived from the stage name (FNV-1a),
  so results do not depend on worker count or stage order; automatic block
  length by Politis & White (2004) with the Patton et al. (2009)
  correction, pinned against Patton's reference code.
- **X-07** `crossval`: blocked (hv-block) cross-validation with a buffer of
  the automatic block length; rows outside each set are NaN.
- **X-07** `observability`: condition number, estimate correlations and VIF
  of a design before the fit; the minimum-data gate refuses an axis below
  `Config.unc.minWeightFraction` (0.5 in the ACC, KBR and LRI presets).
- **X-07** `noise`: ARMA(p,q) per axis by exact ML with gaps or through the
  Welch PSD, its autocovariance and a Ljung-Box check.
- **X-07** Q12: `TestLsqvceAgreement` holds `arma2acv`, `spec2acv`,
  `tsLjungBox` and `tsFitAR` to lsqvce's `armaACV`, `psd2acv`,
  `whitenessCorr`, `levinsonDurbin` and `whittle`.
- `Config.unc` (minWeightFraction, blockLength, nBoot, level, folds).
- **X-07** `noiseReference`: the reference noise-model library. It gives the
  LRI ranging requirement (Abich et al. 2019) and the KBR, LRI-laser and
  accelerometer ASD models of Darbeheshti et al. (2017), each read from the
  source page, with derivatives for rate and acceleration.
- **X-08** `fill`: reports the gaps of each axis (method `none`, the
  default) or fills interior gaps up to `MaxGap` by covariance collocation
  on the noise model's autocovariance (`collocation`), with the prediction
  sigma. The window is capped at the model's largest lag. Filled rows are
  flagged in `Arc.filled` through the new `Arc.fillSamples`. V-7 closed:
  the sigtools Kalman filter has no smoother. `reference` follows X-09.
- `Config.fill` (method, maxGap, window).
- **X-09** `drivers`: supplied driver series (β′, u, eclipse, space weather,
  THR1B counts, SNR) onto the arc's epochs by align's rule, names and units
  checked; no physics.
- **X-09** `correlate`: lagged correlation of Box–Jenkins pre-whitened
  residuals and drivers (the caller's ARMA model), Bartlett effective sample
  size, Fisher-z intervals at every lag and block-bootstrap intervals at
  chosen lags.
- `Config.drivers` (method, maxGap, maxLag).
- **X-09** `regressDrivers`: OLS of per-revolution parameters on demeaned
  drivers with a VIF gate (`Config.drivers.maxVif`, 10) and block-bootstrap
  sigmas.
- **X-09** `partialCorrelation`: partial correlations from the inverse
  correlation matrix, block-bootstrap sigmas.
- **X-09** `binnedMap`: mean, sd and count per bin of two coordinates, e.g.
  a residual over (β′, u).
- **X-05** CI: the `matlab` job receives `READING_DATA_POOL` for the D-9
  real-day tests; audit profile `qc-ported` (PR #51).
- **X-05** `qc`: NonGravForces.qc 0.12.0 (`3cc0123`) ported unchanged but for
  the namespace — `residuals`, `hampel`, `detectImpulses`, `detectJumps`,
  `eventTable`, `screen` — with its two test classes as the gate
  (`tests/qc`). Errors are now `timeSeriesPreparation:<unit>:<mnemonic>`
  through `internal.fail`; `internal.provenance` keeps the record's fields.
  `TestQcPort` holds every ported file to the SHA-256 of its original.
- **X-05** `mask`: one named removal layer per source — qualflg bits with
  the file header's meanings (presets remove the L1B fill flags and the
  KBR1B/LRI1B phase break; ACT1B clock-offset extrapolation and KBR1B
  time-tag bias correction are reported only), SNR below 0.5 of its median
  (KBR1B, LRI1B), THR1B firings and eclipse transitions ± half the CRN fit
  interval, TN-01 manoeuvre windows and caller-stated TN-01a windows, CRN
  edges at gaps (off by default), a user layer. `Config.mask` holds the
  presets.
- **X-05** D-9: `TestDefectCatalogue` checks the eight defect classes on
  their real days of 2020-01 and 2020-07 (DATAPOOL) and the three without
  a real instance synthetically.

## 0.1.0 — 2026-09-23

First release (GUIDE section 7, Phase 2: X-04 → v0.1.0). Downstream may start
NonGravForces N-04 and rangingPreparation L-00 → L-01 → L-04.

The tag `v0.1.0` sits on `7fe24f3`, the X-02 merge, not on the X-04 merge
`f969ecb`: it was created in the release UI after X-06 and X-02 had merged.
So 0.1.0 contains them too, and they are listed here. Tags are never moved
(GUIDE section 3).

- **X-06** `align`: the reference moved onto the observation epochs. Values
  at coinciding epochs are copied bit for bit, and pchip interpolation runs
  inside contiguous stretches only, so no hole is bridged and nothing is
  extrapolated; uncovered epochs become NaN and form the layer `alignGap`.
  Units are checked (CONCEPT 5.2): a mismatch or an unstated unit refuses.
- **X-06** `checkAlignment`: the normalised cross-correlation lag over
  ±60 s, refined below the grid step, with the verdict "aligned" (≤ 1 s),
  "offset", "gross" or "undetermined" and a warning for the last three.
  It never shifts a series (v3 F2).
- **X-06** `Config.align` (`method`, `maxGap`, `maxLag`, `threshold`);
  `internal.resampleOnto`, the resampling rule both functions share.
- **X-02** sigtools conventions, numbers unchanged (bit for bit against the
  v1.3.1 archive, `TestSigtoolsEquivalence`): `arguments` blocks, prefixed
  error identifiers, template help, tagged tests, one Lyapunov solver
  `internal.dlyap`. **Breaking:** the plotting is split out of the compute
  functions:
  - `plotPowerSpectrum` becomes `powerSpectrum` (one series per call, peaks
    in the result) plus a drawing-only `plotPowerSpectrum(spec)`;
  - `allanVariance` loses `doPlot` and gains `plotAllanVariance`;
  - `psd2arma` loses `Display` and gains `plotPsd2armaFit`;
  - `tsCheckResiduals` no longer draws; `plotResiduals` does.
- **X-04** `crnKernel`: the CRN-class digital filter of the GRACE L1B ATBD
  (JPL D-27672, App. B) as printed — the power N_c on each passband term,
  normalised at f0, DC gain 1 + 1.1e-7 (ACC) — with derivative kernels;
  presets `"ACC"` and `"KBR"`, `"LRI"` refused until V-2. Pinned against an
  independent NumPy transcription of the page (ORC-1).
- **X-04** `crnApply`: the convolution evaluated only at the output epochs,
  bit-identical to full rate and to piecewise evaluation; NaN and layer
  `crnWindow` wherever the window is incomplete.
- **X-03** `Arc` (int64 GPS-ns container, layers, provenance, one-release
  rule), `Arc.derive`; `Config` with nine strict sections, `crn.preset`.
- **X-01** sigtools v1.3.1 as `+spectral` and `+tsmodels`, unchanged but for
  namespace qualifiers (checked against the archive on every run); demos.
- **X-00b** skeleton, CI (`audit`, `matlab`), shared audit and documentation
  generator, test-tag policy, layering test, optional gracefoReading.
