function [pacf, lags, conf] = tsPacf(x, maxLag, makePSD)
%TSPACF  Sample partial autocorrelation function (Durbin-Levinson, gap-aware).
%
%   SYNTAX
%     [pacf, lags, conf] = timeSeriesPreparation.tsmodels.tsPacf(x)
%     [pacf, lags, conf] = timeSeriesPreparation.tsmodels.tsPacf(x, maxLag)
%     [pacf, lags, conf] = timeSeriesPreparation.tsmodels.tsPacf(x, maxLag, makePSD)
%
%   DESCRIPTION
%     The PACF identifies the order of an autoregression: for an AR(p)
%     process it cuts off after lag p. It is computed by the Durbin-Levinson
%     recursion on the sample ACF of tsAcf, lags 1..maxLag.
%
%     With NaN gaps the ACF is estimated pairwise-complete (see tsAcf), and
%     such an ACF need not be positive-definite; the recursion can then
%     return |PACF| > 1, and a warning says so. makePSD = true first
%     projects the ACF onto the nearest positive-semidefinite
%     autocorrelation, by alternating projection (at most 100 sweeps, to
%     1e-10) between the PSD cone (eigenvalues clipped at 0) and unit-
%     diagonal Toeplitz matrices (diagonals averaged, rho(0) renormalised to
%     1). That guarantees |PACF| <= 1. conf is the 95 % white-noise band
%     1.96/sqrt(n) with n the smallest pair count over lags 1..maxLag. For
%     estimation with gaps prefer tsFitArima (exact missing-data ML); use
%     this PACF for identification. Base MATLAB only.
%
%   INPUTS
%     x        (:,1) double    -   Series; NaN marks a missing sample. A
%                                  matrix is read as x(:).
%     maxLag   (1,1) double    -   Largest lag; [] or omitted:
%                                  min(N - 1, 40). Rounded and capped at
%                                  N - 1.
%     makePSD  (1,1) logical   -   Project the ACF onto the nearest PSD
%                                  autocorrelation first; [] or omitted:
%                                  false.
%
%   OUTPUTS
%     pacf  (L,1) double   -   Sample PACF at lags 1..L.
%     lags  (L,1) double   -   Lags 1..L, in samples.
%     conf  (1,1) double   -   Half-width of the 95 % white-noise band.
%
%   ACCURACY
%     The recursion is exact up to rounding; a denominator below eps is
%     replaced by +/-eps. The PSD projection stops at a change below 1e-10
%     or after 100 sweeps. Unchanged from sigtools v1.3.1;
%     TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     Gaps:
%       timeSeriesPreparation:tsPacf:unobservableLag - a lag up to maxLag
%           has no complete pair.
%     Input:
%       A non-numeric or complex x, or a maxLag or makePSD that is not a
%       scalar or [], is refused by the arguments block with a MATLAB:
%       identifier.
%
%   WARNINGS
%     Gaps:
%       timeSeriesPreparation:tsPacf:nonPD - |PACF| > 1 at some lag: the
%           pairwise ACF is not positive-definite.
%
%   EXAMPLE
%     % The PACF of an AR(2) series cuts off after lag 2.
%     x = filter(1, [1 -0.5 0.3], randn(RandStream("twister", "Seed", 1), 2000, 1));
%     [pacf, lags, conf] = timeSeriesPreparation.tsmodels.tsPacf(x, 10);
%
%   LIMITATIONS
%     The projection is a heuristic nearest point, not a certified
%     Frobenius-nearest one, and costs an eigendecomposition of a
%     (maxLag+1)-square matrix per sweep. Without it, heavy gapping can
%     give |PACF| > 1.
%
%   REFERENCES
%     J. Durbin (1960), Rev. Int. Stat. Inst. 28(3), 233-244.
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley. sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.tsmodels.tsAcf, timeSeriesPreparation.tsmodels.tsFitArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x {mustBeNumeric, mustBeReal}
        maxLag {mustBeScalarOrEmpty, mustBeNumeric} = []
        makePSD {mustBeScalarOrEmpty, mustBeNumericOrLogical} = false
    end

    x = x(:);
    N = numel(x);
    if isempty(maxLag), maxLag = min(N-1, 40); end
    if isempty(makePSD), makePSD = false; end
    maxLag = min(round(maxLag), N-1);

    [r, ~, ~, nPairs] = timeSeriesPreparation.tsmodels.tsAcf(x, maxLag);
    r = r(2:end);                             % rho_1..rho_maxLag
    if any(isnan(r))
        error('timeSeriesPreparation:tsPacf:unobservableLag', ...
            'Some lags have no complete pairs; reduce MAXLAG or fill gaps.');
    end

    % Optional: project the (possibly non-PD, pairwise) ACF onto the nearest
    % valid positive-semidefinite autocorrelation before the recursion. Uses
    % alternating projection between the PSD cone and the unit-diagonal
    % Toeplitz set. Guarantees |PACF|<=1 and a well-posed Durbin-Levinson.
    if makePSD
        r = local_nearestPDacf([1; r(:)]);
        r = r(2:end);
    end

    pacf = zeros(maxLag, 1);
    phi  = zeros(maxLag, maxLag);
    if maxLag >= 1, phi(1,1) = r(1); pacf(1) = r(1); end
    for k = 2:maxLag
        den = 1 - phi(k-1, 1:k-1) * r(1:k-1);
        if abs(den) < eps, den = sign(den + eps)*eps; end
        phi(k,k) = (r(k) - phi(k-1, 1:k-1) * r(k-1:-1:1)) / den;
        phi(k, 1:k-1) = phi(k-1, 1:k-1) - phi(k,k) * phi(k-1, k-1:-1:1);
        pacf(k) = phi(k,k);
    end

    if any(abs(pacf) > 1)
        warning('timeSeriesPreparation:tsPacf:nonPD', ...
            ['Pairwise ACF is not positive-definite (|PACF|>1 at some lag); ', ...
             'interpret with caution or fill gaps before identification.']);
    end
    lags = (1:maxLag)';
    conf = 1.96 / sqrt(max(min(nPairs(2:end)), 1));
end

% ======================================================================
function r = local_nearestPDacf(r0)
% Nearest positive-semidefinite autocorrelation sequence to r0 (r0(1)=1)
% by alternating projection: (i) clip eigenvalues of the Toeplitz matrix
% to >= 0, (ii) restore Toeplitz structure by averaging each diagonal and
% renormalising r(1)=1. Base MATLAB.
    r0 = r0(:); n = numel(r0); r = r0 / r0(1);
    for it = 1:100
        R = toeplitz(r);
        [V, D] = eig(0.5*(R + R'));
        d = max(real(diag(D)), 0);
        Rp = V * diag(d) * V';
        new = zeros(n,1);
        for k = 0:n-1
            new(k+1) = mean(diag(Rp, k));
        end
        new = new / new(1);
        if max(abs(new - r)) < 1e-10, r = new; break; end
        r = new;
    end
end
