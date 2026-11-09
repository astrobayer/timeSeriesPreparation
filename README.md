# timeSeriesPreparation

Physics-free preparation and analysis of GRACE and GRACE-FO time series in
MATLAB, shared by NonGravForces (accelerometer calibration) and
rangingPreparation (LRI/KBR):
- the `Arc` container;
- the exact CRN filter;
- masks from quality flags, thrusters and official event lists;
- quality control, alignment and gap handling;
- noise models (including sigtools v1.3.1);
- bootstrap and cross-validation;
- correlation analysis.

**Status: release 1.5.2 (the tests read the data pool as `DATAPOOL`, then `READING_DATA_POOL`).** Skeleton and CI (X-00b), sigtools v1.3.1
as `+spectral` / `+tsmodels` (X-01, conventions X-02), `Arc` and `Config`
(X-03), the exact ATBD CRN kernel and its output-epoch application (X-04),
masks and the residual quality control ported from NonGravForces (X-05),
alignment (X-06), bootstrap, cross-validation, observability and noise
models (X-07), gaps (X-08) and driver correlation (X-09). The defect
catalogue D-9 is tested on its real days. `run` chains the stages on one
arc as each one's input is given, and a real day against ITSG meets the
V-4 thresholds (X-10). Release 1.1.0 adds the stage cache (X-14), the
faster QC (X-16) and campaign mode: an Arc array through `run`, with
per-day files and a JSON manifest (X-15). Release 1.2.0 adds the QC
template bank (X-17) and the CF-1.12/ACDD-1.3 NetCDF export with PROV-O
provenance, DataCite fields in the manifest and a versioned Arc schema
(X-18). Release 1.3.0 adds `report` (figures, a self-contained HTML
page per day and a campaign index; X-11) and verifies the CRN preset against
GRACE-FO Level-1A: CRN(ACT1A) reproduces ACT1B to 2.5e-5 relative rms or
better per axis (X-12). Release 1.4.0 supports classic GRACE L1B (X-13):
units and `qualflg` meanings from the GRACE handbook (via gracefoReading),
the ACC1B fill-flag preset, and a classic A/B day through `run`.
Release 1.5.0 gives GRACE-FO's hybrid ACH1B the ACT1B preset, which its
header supports in full (X-19).
Release 1.5.1 holds the Q12 PSD → ACV agreement to the exact AR(1)
autocovariance, so it passes with lsqvce v7.0.1 (and v6.1.3).
Release 1.5.2 reads the data pool root of the real-data tests as `DATAPOOL`,
then `READING_DATA_POOL` (the owner's data pool rule).
Changes: `CHANGELOG.md`.

```matlab
setupTimeSeriesPreparation();              % toolbox and demos on the path; reports gracefoReading
[t, a, aux] = gracefoReading.readL1b(file, 'TimeFormat', "gpsns");
arc = timeSeriesPreparation.Arc(t, a, aux, Columns = ["lin_accl_x" "lin_accl_y" "lin_accl_z"]);
arc = timeSeriesPreparation.mask(arc, QualFlags = aux);  % header-defined qualflg layers, preset per product
k = timeSeriesPreparation.crnKernel("ACC");             % ATBD App. B, as printed
acc = timeSeriesPreparation.crnApply(arc10Hz, k, OutputEpochs = t1Hz);  % only at output epochs
mod = timeSeriesPreparation.align(acc, model);          % model onto the epochs, units checked
rep = timeSeriesPreparation.checkAlignment(acc, model); % lag over +/-60 s, reported, never shifted
res = timeSeriesPreparation.run(arc, Reference = model, QualFlags = aux);  % every stage whose input is given
spec = timeSeriesPreparation.spectral.powerSpectrum(1, arc.obs(:, 1));  % sigtools, 1 Hz
timeSeriesPreparation.spectral.plotPowerSpectrum(spec);
sigtoolsDemo                               % the sigtools demos
timeSeriesPreparationCiGate();             % the MATLAB gate, as CI runs it
```

| what | where |
|---|---|
| design and design decisions | [`docs/CONCEPT.md`](docs/CONCEPT.md) |
| order of work and every procedure | [`docs/GUIDE.md`](docs/GUIDE.md) |
| status, obligations, repository decisions | [`HANDOVER.md`](HANDOVER.md) |
| archived inputs (not authoritative) | [`docs/inputs/README.md`](docs/inputs/README.md) |
| error identifiers (generated) | [`docs/errorIdentifiers.md`](docs/errorIdentifiers.md) |
| reference pages (generated) | [`html/index.html`](html/index.html) |

Depends on gracefoReading (optional, for the L1B-specific functions;
1.3.0 or later for classic GRACE arcs, whose units and flag meanings it
supplies).
Licence: MIT.
