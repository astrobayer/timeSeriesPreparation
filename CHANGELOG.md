# Changelog — timeSeriesPreparation

Semantic versioning (`ci-actions/VERSIONING.md`); `+timeSeriesPreparation/Contents.m`
is the single version source. Work packages are the rows of `docs/CONCEPT.md` 10.1.

## Unreleased

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
