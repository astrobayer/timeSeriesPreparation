# Changelog — timeSeriesPreparation

Semantic versioning (`ci-actions/VERSIONING.md`); `+timeSeriesPreparation/Contents.m`
is the single version source. Work packages are the rows of `docs/CONCEPT.md` 10.1.

## Unreleased

- `.github/` profile switch (PR #41): `+spectral` and `+tsmodels` are audited
  under the public help template and documented; the error catalogue lists
  94 identifiers, warnings included; their 29 help examples run in the gate.
- Release workflow: a merge whose `Contents.m` names an untagged version gets
  an annotated tag on the merge commit and a GitHub release
  (`ci-actions/matlab-release`, `mode: file`).

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
