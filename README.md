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

**Status: design only — no code yet.**

| what | where |
|---|---|
| design and design decisions | [`docs/CONCEPT.md`](docs/CONCEPT.md) |
| order of work and every procedure | [`docs/GUIDE.md`](docs/GUIDE.md) |
| status, obligations, repository decisions | [`HANDOVER.md`](HANDOVER.md) |
| archived inputs (not authoritative) | [`docs/inputs/README.md`](docs/inputs/README.md) |

Depends on gracefoReading (optional, for the L1B-specific functions).
Licence: MIT.
