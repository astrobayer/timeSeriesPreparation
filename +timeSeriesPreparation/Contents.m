% timeSeriesPreparation - physics-free preparation of GRACE and GRACE-FO time series
% Version 1.3.0  2026-09-27
%
%   Design: docs/CONCEPT.md. Order of work: docs/GUIDE.md.
%
%   Single point of access (L3)
%     run        - The instrument stages on one arc or a campaign, each run
%                  when its input is given.
%
%   Containers (L1)
%     Arc        - One instrument time series on int64 GPS-ns epochs, with
%                  weights, layers and provenance.
%     Config     - Instrument settings in ten sections.
%     crnKernel  - The CRN-class digital filter of the GRACE L1B ATBD, as printed.
%     noiseReference - Published noise ASDs of the GRACE-FO instruments (LRI,
%                  KBR, ACC).
%
%   Stages (L2)
%     mask            - Named removal layers from qualflg, SNR, THR1B,
%                       eclipse, official event lists and the caller.
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
%     regressDrivers  - Regression of per-revolution parameters on drivers,
%                       with a VIF gate and block-bootstrap sigmas.
%     partialCorrelation - Partial correlation of each pair of columns given
%                       all others, with block-bootstrap sigmas.
%     binnedMap       - Mean, standard deviation and count of a value in bins
%                       of two coordinates.
%     qc              - Residual quality control: outliers, impulses, jumps,
%                       event table (NonGravForces.qc 0.12.0, numbers
%                       unchanged), template bank and its matched filter
%                       (X-17; help timeSeriesPreparation.qc).
%     exportNetcdf    - One arc, its residual and QC events as a CF-1.12/
%                       ACDD-1.3 NetCDF-4 file with PROV-O provenance.
%     readNetcdf      - A file of exportNetcdf back as a struct.
%     report          - Figures and a self-contained HTML page of a run
%                       result; for a campaign, one page per day and an index.
%
%   Spectra and time-series models (L0, sigtools v1.3.1; conventions of X-02)
%     spectral   - help timeSeriesPreparation.spectral
%     tsmodels   - help timeSeriesPreparation.tsmodels
%
%   Internal
%     internal.blockLength     - Automatic block length for block resampling
%                                (Politis-White, Patton correction).
%     internal.contentHash     - SHA-256 of the content of values, the key of
%                                the stage cache.
%     internal.dlyap           - Stationary covariance P = T P T' + Q, the one
%                                Lyapunov solver of the toolbox.
%     internal.fileSha256      - SHA-256 of a file's bytes, the integrity
%                                record of a campaign's day files.
%     internal.provenance      - Metadata record of the qc units.
%     internal.provJsonLd      - W3C PROV-O graph of an arc's provenance, as
%                                JSON-LD.
%     internal.requirePackage  - Refuse at the point of use when an optional
%                                dependency is not on the path.
%     internal.resampleOnto    - Interpolate a series onto new epochs, never
%                                across a hole.
%     internal.stageCache      - A stage's outputs from the cache, or computed
%                                and stored.
%     internal.stageSeed       - RNG seed of a stage: its name hashed, plus the
%                                caller's seed.
%     internal.toolboxVersion  - The version stated in this file.
%
%   Demos: demos/sigtoolsDemo lists the sigtools demos.
