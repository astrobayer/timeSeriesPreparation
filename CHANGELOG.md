# Changelog — timeSeriesPreparation

Semantic versioning (`ci-actions/VERSIONING.md`); `+timeSeriesPreparation/Contents.m`
is the single version source. Work packages are the rows of `docs/CONCEPT.md` 10.1.

## Unreleased

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

## 0.1.0 — 2026-09-23

First release (GUIDE section 7, Phase 2: X-04 → v0.1.0). Downstream may start
NonGravForces N-04 and rangingPreparation L-00 → L-01 → L-04.

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
