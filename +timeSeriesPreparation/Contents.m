% timeSeriesPreparation - physics-free preparation of GRACE and GRACE-FO time series
% Version 0.0.0  2026-09-22
%
%   Design: docs/CONCEPT.md. Order of work: docs/GUIDE.md.
%
%   Containers (L1)
%     Arc        - One instrument time series on int64 GPS-ns epochs, with
%                  weights, layers and provenance.
%     Config     - Instrument settings in nine sections.
%     crnKernel  - The CRN-class digital filter of the GRACE L1B ATBD, as printed.
%
%   Stages (L2)
%     crnApply   - Apply a CRN kernel to an arc, evaluated only at the output
%                  epochs.
%
%   Spectra and time-series models (L0, sigtools v1.3.1, imported at X-01)
%     spectral   - help timeSeriesPreparation.spectral
%     tsmodels   - help timeSeriesPreparation.tsmodels
%
%   Internal
%     internal.requirePackage  - Refuse at the point of use when an optional
%                                dependency is not on the path.
%     internal.toolboxVersion  - The version stated in this file.
%
%   Demos: demos/sigtoolsDemo lists the sigtools demos.
