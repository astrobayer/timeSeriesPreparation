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
%     noiseReference - Published noise ASDs of the GRACE-FO instruments (LRI,
%                  KBR, ACC).
%
%   Stages (L2)
%     align           - Move a reference series onto the epochs of an
%                       observation, units checked.
%     checkAlignment  - Report a time lag between observation and reference;
%                       never shift.
%     crnApply        - Apply a CRN kernel to an arc, evaluated only at the
%                       output epochs.
%     noise           - Residual noise model per axis: ARMA by exact ML with
%                       gaps, or PSD -> ARMA.
%     fill            - Report the gaps of an arc, or fill the short ones by
%                       covariance collocation.
%     observability   - Identifiability metrics of a design before the fit,
%                       and the minimum-data gate.
%     bootstrap       - Moving-block bootstrap of a statistic, one RNG
%                       substream per replicate.
%     crossval        - Blocked cross-validation with a buffer, for serially
%                       correlated rows.
%     drivers         - Supplied driver series on the epochs of an arc, names
%                       and units checked.
%     correlate       - Lagged correlation of pre-whitened residuals and
%                       drivers, with effective sample size and CIs.
%
%   Spectra and time-series models (L0, sigtools v1.3.1; conventions of X-02)
%     spectral   - help timeSeriesPreparation.spectral
%     tsmodels   - help timeSeriesPreparation.tsmodels
%
%   Internal
%     internal.blockLength     - Automatic block length for block resampling
%                                (Politis-White, Patton correction).
%     internal.dlyap           - Stationary covariance P = T P T' + Q, the one
%                                Lyapunov solver of the toolbox.
%     internal.requirePackage  - Refuse at the point of use when an optional
%                                dependency is not on the path.
%     internal.resampleOnto    - Interpolate a series onto new epochs, never
%                                across a hole.
%     internal.stageSeed       - RNG seed of a stage: its name hashed, plus the
%                                caller's seed.
%     internal.toolboxVersion  - The version stated in this file.
%
%   Demos: demos/sigtoolsDemo lists the sigtools demos.
