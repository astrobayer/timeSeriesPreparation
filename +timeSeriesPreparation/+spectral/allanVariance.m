function [tau, avar, adev, info] = allanVariance(x, fs, m, ciLevel)
%ALLANVARIANCE  Overlapping Allan variance and deviation, with confidence bounds and slopes.
%
%   SYNTAX
%     [tau, avar, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, fs)
%     [tau, avar, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, fs, m, ciLevel)
%
%   DESCRIPTION
%     Fully overlapping Allan variance of rate-type series (IEEE 1139;
%     Riley 2008), one column per channel, through the phase construction
%
%       theta(k) = sum_(j<k) x(j)/fs,   theta(1) = 0
%       sigma^2(tau) = sum_(i=1..K) (theta(i+2m) - 2 theta(i+m) + theta(i))^2
%                      / (2 tau^2 K),   K = N - 2m,  tau = m/fs.
%
%     Every cluster start is used, which gives far more confidence per tau
%     than non-overlapping blocks of the same record. The confidence bounds
%     use the chi-square construction edf*avar/chi2inv. The chi-square
%     quantiles come from the Wilson-Hilferty approximation through erfinv,
%     so no toolbox is needed. The equivalent degrees of freedom are the
%     noise-agnostic large-sample value edf = 3(N-1)/(2m) - 2(N-2)/N, which
%     is indicative only. The local log-log slope identifies the noise type:
%     white -1/2, flicker 0, random walk +1/2, ramp +1, quantisation -1.
%     The bias instability is 0.664 min(adev) (the IEEE convention).
%
%     Since X-02 the function computes only; plotAllanVariance draws the
%     result (owner decision 2026-09-23, clean break). The numbers are
%     v1.3.1's, unchanged.
%
%   INPUTS
%     x        (N,P) double   -   Rate-type series, one column per channel;
%                                 a row vector is one channel.
%     fs       (1,1) double   Hz  Sampling rate, > 0.
%     m        (K,1) double   -   Cluster factors, integers; tau = m/fs.
%                                 Entries with N - 2m < 1 are dropped. [] or
%                                 omitted: about 100 log-spaced integers from
%                                 1 to floor((N-8)/2).
%     ciLevel  (1,1) double   -   Confidence level of the bounds, in (0,1);
%                                 [] or omitted: 0.6827 (1 sigma).
%
%   OUTPUTS
%     tau   (K,1) double   s        Averaging times used, ascending.
%     avar  (K,P) double   unit^2   Overlapping Allan variance.
%     adev  (K,P) double   unit     Allan deviation, sqrt(avar).
%     info  (1,1) struct   -        Fields: edf (K,1); adevLow, adevHigh
%                                   (K,P), the bounds at ciLevel; slope
%                                   (K,P), d log10 adev / d log10 tau;
%                                   biasInstability (1,P), 0.664 min(adev);
%                                   biasInstabilityTau (1,P), s.
%
%   ACCURACY
%     The estimator is exact arithmetic on the phase sums. The bounds rest on
%     two approximations: the edf formula is noise-type agnostic (Riley 2008
%     gives noise-specific values), and the Wilson-Hilferty chi-square
%     quantile. At the default 1-sigma level that quantile errs by < 0.6 %
%     for edf >= 3. At 95 % its lower 2.5 % quantile errs by 16 % at edf 3,
%     4 % at edf 5 and 0.7 % at edf 10 (measured against an exact quantile,
%     2026-09-23), so the widest-tau bounds are rough. Unchanged from
%     sigtools v1.3.1, and TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none)
%     Inputs outside their domain are refused by the arguments block with a
%     MATLAB: identifier.
%
%   EXAMPLE
%     % White noise: the Allan deviation falls with slope -1/2.
%     x = randn(RandStream("twister", "Seed", 1), 10000, 1);
%     [tau, ~, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, 10);
%
%   LIMITATIONS
%     Rate-type (frequency) data only; phase data must be differenced first.
%     NaN is not handled: a NaN poisons every tau whose clusters touch it.
%
%   REFERENCES
%     IEEE Std 1139-2008. W. J. Riley (2008), Handbook of Frequency Stability
%     Analysis, NIST SP 1065. E. B. Wilson, M. M. Hilferty (1931), PNAS 17,
%     684-688.
%
%   See also timeSeriesPreparation.spectral.plotAllanVariance, timeSeriesPreparation.spectral.powerSpectrum, timeSeriesPreparation.spectral.spec2acv.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    x {mustBeNumeric}
    fs (1,1) double {mustBePositive}
    m {mustBeNumeric} = []
    ciLevel {mustBeScalarOrEmpty, mustBeNumeric} = []
end

if isvector(x)
    x = x(:);
end
[N, P] = size(x);

if isempty(m)
    maxM = max(1, floor((N - 8) / 2));
    m = unique(round(logspace(0, log10(maxM), 100)));
end
if isempty(ciLevel)
    ciLevel = 0.6827; % 1-sigma
end

m = m(:);
m = m(m >= 1 & (N - 2*m) >= 1);
tau = m / fs;
K   = numel(m);

avar = nan(K, P);
edf  = nan(K, 1);

theta = [zeros(1, P); cumsum(x, 1)] / fs; % (N+1) x P phase accumulation

for k = 1:K
    mk = m(k);
    nK = N - 2*mk;
    idx = (1:nK)';
    d = theta(idx + 2*mk, :) - 2*theta(idx + mk, :) + theta(idx, :);
    avar(k, :) = sum(d.^2, 1) / (2 * tau(k)^2 * nK);
    edf(k) = local_allan_edf(mk, N);
end

adev = sqrt(avar);

% --- confidence bounds via chi-square (Wilson-Hilferty approximation) ---
alpha    = 1 - ciLevel;
loQ      = local_chi2inv(alpha/2,   edf);
hiQ      = local_chi2inv(1-alpha/2, edf);
avarLow  = (edf .* avar) ./ hiQ;
avarHigh = (edf .* avar) ./ loQ;
adevLow  = sqrt(avarLow);
adevHigh = sqrt(avarHigh);

% --- local slope on log-log axes, per column ---
logTau = log10(tau);
slope  = zeros(K, P);
for p = 1:P
    slope(:, p) = gradient(log10(adev(:, p)), logTau);
end

% --- bias instability: flicker-floor minimum, IEEE-conventional 0.664 scale ---
[minAdev, iMin] = min(adev, [], 1);
biasInstability    = 0.664 * minAdev;
biasInstabilityTau = tau(iMin)';

info = struct( ...
    'edf', edf, ...
    'adevLow', adevLow, 'adevHigh', adevHigh, ...
    'slope', slope, ...
    'biasInstability', biasInstability, ...
    'biasInstabilityTau', biasInstabilityTau);

end

% ------------------------------------------------------------------------
function edf = local_allan_edf(m, N)
%LOCAL_ALLAN_EDF Approximate equivalent degrees of freedom for the
%   overlapping Allan variance estimator (large-sample approximation,
%   noise-type agnostic). Clamped to >= 1.
edf = (3*(N-1))/(2*m) - (2*(N-2))/N;
edf = max(edf, 1);
end

% ------------------------------------------------------------------------
function q = local_chi2inv(p, k)
%LOCAL_CHI2INV Wilson-Hilferty approximation of the chi-square inverse CDF.
%   Avoids a Statistics Toolbox dependency; uses erfinv (base MATLAB) to
%   get the standard-normal quantile, then the classical cube-root normal
%   approximation to the chi-square distribution with k degrees of freedom.
z = sqrt(2) * erfinv(2*p - 1);
q = k .* (1 - 2./(9*k) + z .* sqrt(2./(9*k))).^3;
q = max(q, eps);
end
