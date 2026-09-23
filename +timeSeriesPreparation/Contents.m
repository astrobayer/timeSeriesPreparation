% timeSeriesPreparation - physics-free preparation of GRACE and GRACE-FO time series
% Version 0.1.0  2026-09-23
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
%     align           - Move a reference series onto the epochs of an
%                       observation, units checked.
%     checkAlignment  - Report a time lag between observation and reference;
%                       never shift.
%     crnApply        - Apply a CRN kernel to an arc, evaluated only at the
%                       output epochs.
%
%   Spectra and time-series models (L0, sigtools v1.3.1; conventions of X-02)
%     spectral   - help timeSeriesPreparation.spectral
%     tsmodels   - help timeSeriesPreparation.tsmodels
%
%   Internal
%     internal.dlyap           - Stationary covariance P = T P T' + Q, the one
%                                Lyapunov solver of the toolbox.
%     internal.requirePackage  - Refuse at the point of use when an optional
%                                dependency is not on the path.
%     internal.resampleOnto    - Interpolate a series onto new epochs, never
%                                across a hole.
%     internal.toolboxVersion  - The version stated in this file.
%
%   Demos: demos/sigtoolsDemo lists the sigtools demos.
