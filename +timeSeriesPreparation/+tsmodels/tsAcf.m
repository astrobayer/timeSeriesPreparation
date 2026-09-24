function [rho, lags, conf, nPairs] = tsAcf(x, maxLag)
%TSACF  Sample autocorrelation function (gap-aware).
%
%   SYNTAX
%     [rho, lags, conf, nPairs] = timeSeriesPreparation.tsmodels.tsAcf(x)
%     [rho, lags, conf, nPairs] = timeSeriesPreparation.tsmodels.tsAcf(x, maxLag)
%
%   DESCRIPTION
%     The sample ACF is the first look at a series before an ARMA model is
%     identified: rho(k) = c(k)/c(0) at lags 0..maxLag, rho(1) = 1, with
%     the observed-sample mean removed.
%
%     A complete series gets the textbook biased estimator,
%     c(k) = sum x(t) x(t+k) / N. A series with NaN at missing epochs of an
%     otherwise regular grid is handled gap-aware: each lag k uses only the
%     pairs (t, t+k) in which both samples are observed, divided by their
%     count (a consistent moment estimator). A lag without any such pair is
%     NaN. conf is the approximate 95 % white-noise band 1.96/sqrt(n), with
%     n the lag-1 pair count (N for a complete series). Base MATLAB only.
%
%   INPUTS
%     x       (:,1) double   -   Series; NaN marks a missing sample, Inf is
%                                refused. A matrix is read as x(:).
%     maxLag  (1,1) double   -   Largest lag; [] or omitted:
%                                min(N - 1, 40). Rounded and capped at N - 1.
%
%   OUTPUTS
%     rho     (L+1,1) double   -   Sample ACF at lags 0..L, rho(1) = 1; NaN
%                                  at an unobservable lag.
%     lags    (L+1,1) double   -   Lags 0..L, in samples.
%     conf    (1,1) double     -   Half-width of the 95 % white-noise band.
%     nPairs  (L+1,1) double   -   Number of complete pairs per lag;
%                                  nPairs(1) is the number observed.
%
%   ACCURACY
%     Exact arithmetic of the estimator, no approximation beyond rounding.
%     The band is the large-sample normal approximation (Box, Jenkins,
%     Reinsel). Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence
%     holds it bit for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:tsAcf:badData - an observed sample is Inf.
%       A non-numeric or complex x, or a maxLag that is not a numeric
%       scalar or [], is refused by the arguments block with a MATLAB:
%       identifier.
%
%   EXAMPLE
%     % The ACF of an AR(1) series decays like 0.7^k.
%     x = filter(1, [1 -0.7], randn(RandStream("twister", "Seed", 1), 1000, 1));
%     [rho, lags, conf] = timeSeriesPreparation.tsmodels.tsAcf(x, 10);
%
%   LIMITATIONS
%     The gap-aware ACF is not guaranteed positive-definite; under heavy
%     gapping tsPacf can then exceed 1 in magnitude. A series whose
%     observed samples are all equal returns rho = ones and conf from the
%     number observed. Irregular sampling is not supported: NaN must mark
%     missing epochs of a regular grid.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley. sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.tsmodels.tsPacf, timeSeriesPreparation.tsmodels.tsLjungBox, timeSeriesPreparation.tsmodels.tsFitArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x {mustBeNumeric, mustBeReal}
        maxLag {mustBeScalarOrEmpty, mustBeNumeric} = []
    end

    x = x(:);
    N   = numel(x);
    obs = ~isnan(x);
    if any(~isfinite(x(obs)))
        error('timeSeriesPreparation:tsAcf:badData','Observed samples must be finite (Inf not allowed).');
    end
    if isempty(maxLag), maxLag = min(N-1, 40); end
    maxLag = min(round(maxLag), N-1);

    nObs = sum(obs);
    mu   = sum(x(obs)) / nObs;
    xc   = x - mu;
    xc(~obs) = NaN;                       % keep gaps as NaN for masking

    rho    = ones(maxLag+1, 1);
    nPairs = zeros(maxLag+1, 1);
    nPairs(1) = nObs;
    c0 = sum(xc(obs).^2) / nObs;
    if ~(c0 > 0)
        lags = (0:maxLag)'; conf = 1.96/sqrt(nObs); return;
    end

    hasGaps = nObs < N;
    for k = 1:maxLag
        a = xc(1:N-k); b = xc(k+1:N);
        both = ~isnan(a) & ~isnan(b);
        m = sum(both);
        nPairs(k+1) = m;
        if m == 0
            rho(k+1) = NaN;               % lag unobservable
        elseif hasGaps
            rho(k+1) = (sum(a(both).*b(both)) / m) / c0;   % pairwise (unbiased-count)
        else
            rho(k+1) = (a' * b) / N / c0;                  % biased denom (textbook)
        end
    end
    lags = (0:maxLag)';
    conf = 1.96 / sqrt(max(nPairs(2), 1));
end
