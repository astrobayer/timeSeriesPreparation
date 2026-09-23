# Changelog — timeSeriesPreparation

Semantic versioning (`ci-actions/VERSIONING.md`); `+timeSeriesPreparation/Contents.m`
is the single version source. Work packages are the rows of `docs/CONCEPT.md` 10.1.

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
