function res = correlate(arc, drv, model, maxLag, options)
%CORRELATE  Lagged correlation of pre-whitened residuals and drivers, with effective sample size and CIs.
%
%   SYNTAX
%     res = timeSeriesPreparation.correlate(arc, drv, model, maxLag)
%     res = timeSeriesPreparation.correlate(arc, drv, model, maxLag, AcfLags = [], BootLags = 0, NBoot = 1000, BlockLength = [], Seed = 0, Stage = "correlate", Level = 0.6827)
%
%   DESCRIPTION
%     The lagged correlation of CONCEPT 7, respecting autocorrelation.
%       - Pre-whitening (Box and Jenkins): axis m and every driver are
%         filtered by the inverse of axis m's ARMA model, e_t =
%         (a(B)/b(B)) (x_t - mu), a and b from noise (owner decision
%         2026-09-24: the model is the caller's, no fit here). The axis
%         loses model.mu(m), each driver its own mean first. Each finite
%         stretch is filtered from rest and its first p samples are
%         dropped (NaN): exact for AR models; with MA terms the start-up
%         transient decays like theta^k. Rows with weight 0 or filled are
%         missing (CONCEPT 5).
%       - r(l) = corr(x'_t, d'_(t-l)), the Pearson correlation over the
%         complete pairs, for l = -maxLag..maxLag samples; a positive l
%         means the driver leads the residual by l samples.
%       - Effective sample size (Bartlett) per axis and driver:
%         nEff = n / (1 + 2 sum_(k=1..AcfLags) rho_x'(k) rho_d'(k)), n the
%         lag-0 pairs and rho the gap-aware tsmodels.tsAcf of the whitened
%         series. With the residual white, rho_x'(k) is near 0 and nEff
%         near n whatever the driver's own memory; that is why one model
%         per axis suffices. Unwhitened AR(0.95) pairs have nEff about 5 %
%         of n (NumPy, 2026-09-24).
%       - ci: the Fisher-z interval tanh(atanh(r) -+ z/sqrt(nEff - 3)) at
%         Level, at every lag.
%       - At BootLags: a moving-block bootstrap of the pair rows (bootstrap,
%         automatic block length unless BlockLength, seed from Stage and
%         Seed), its sigma and percentile interval.
%     maxLag has no default (R5).
%
%   INPUTS
%     arc     (1,1) Arc      -   Residuals on a uniform grid, M axes.
%     drv     (1,1) struct   -   drivers(arc, ...) output on arc.t, K
%                                drivers.
%     model   (1,1) struct   -   Per-axis ARMA model, noise's output:
%                                fields a (M, p+1), b (M, q+1), mu (1, M),
%                                a(:,1) = b(:,1) = 1.
%     maxLag  (1,1) double   -   Largest lag in samples, integer >= 0.
%
%   OPTIONS
%     AcfLags      (1,1) double   [maxLag]   Lags of the nEff sum; 0 =
%                                            nEff = n.
%     BootLags     (1,:) double   [0]        Lags bootstrapped, |l| <=
%                                            maxLag; [] = none.
%     NBoot        (1,1) double   [1000]     Bootstrap replicates.
%     BlockLength  (1,1) double   [auto]     Block length in rows; [] =
%                                            Politis-White.
%     Seed         (1,1) double   [0]        Caller's seed, integer >= 0.
%     Stage        (1,1) string   ["correlate"]  Stage name of the seed.
%     Level        (1,1) double   [0.6827]   Two-sided level of ci and of
%                                            the bootstrap interval.
%
%   OUTPUTS
%     res  (1,1) struct   -   Fields: axes (1,M), drivers (1,K) string;
%                             lags (2L+1,1) samples; lagSeconds (2L+1,1)
%                             s; r, n (2L+1,M,K); nEff (M,K); ci
%                             (2,2L+1,M,K); level; boot, a struct with
%                             lags (B,1), sigma (B,M,K), ci (2,B,M,K),
%                             blockLength (B,M,K); order (M,2) [p q].
%
%   ACCURACY
%     r is exact arithmetic on the pairs. With a white model it equals
%     corrcoef of the shifted vectors; AR(1) pre-whitening returns the
%     innovations to 4e-16 (NumPy). The Fisher interval assumes
%     near-normal pairs; the bootstrap sigma of a lag-0 correlation lay
%     within 0.90-1.10 of (1 - r^2)/sqrt(n) over 100 NumPy realisations
%     (2026-09-24).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:correlate:irregularGrid - the epochs are not
%           uniformly spaced.
%       timeSeriesPreparation:correlate:epochMismatch - drv is not drivers'
%           output on arc.t.
%       timeSeriesPreparation:correlate:modelMismatch - model lacks a, b
%           or mu, or its rows differ from the arc's axes, or a(:,1) or
%           b(:,1) is not 1.
%       timeSeriesPreparation:correlate:badBootLag - a BootLags entry
%           exceeds maxLag.
%       timeSeriesPreparation:correlate:tooFewPairs - an axis and a driver
%           share fewer than 10 whitened samples at lag 0.
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%
%   EXAMPLE
%     % A driver acting 5 s late on a white residual: the peak sits at +5.
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     rs = RandStream("twister", "Seed", 9);
%     d = randn(rs, 2005, 1);
%     t = int64(0:1999)' * int64(1e9);
%     arc = timeSeriesPreparation.Arc(t, randn(rs, 2000, 1) + 0.5 * d(1:2000), aux);
%     drv = timeSeriesPreparation.drivers(arc, struct("name", "d", "t", t, "value", d(6:2005), "unit", "1"));
%     white = struct("a", 1, "b", 1, "mu", 0);
%     res = timeSeriesPreparation.correlate(arc, drv, white, 10, BootLags = [], AcfLags = 5);
%
%   LIMITATIONS
%     Linear, pairwise and stationary. The interval at each lag ignores the
%     search over 2 maxLag + 1 lags; pick the lag of interest beforehand
%     or correct the level. Correlation is not attribution: partial
%     correlation and regression are X-09's second part.
%
%   REFERENCES
%     Box, G. E. P., Jenkins, G. M., Reinsel, G. C., Ljung, G. M. (2015).
%     Time Series Analysis: Forecasting and Control, 5th ed. Wiley, ch. 12
%     (pre-whitening, the cross-correlation check). Bartlett, M. S. (1946).
%     On the theoretical specification and sampling properties of
%     autocorrelated time-series. J. R. Stat. Soc. Suppl. 8, 27-41.
%     Fisher, R. A. (1921). Metron 1, 3-32 (the z transform).
%     docs/CONCEPT.md section 7.
%
%   See also timeSeriesPreparation.drivers, timeSeriesPreparation.noise, timeSeriesPreparation.bootstrap, timeSeriesPreparation.tsmodels.tsAcf.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-24 10:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        drv (1,1) struct
        model (1,1) struct
        maxLag (1,1) double {mustBeInteger, mustBeNonnegative}
        options.AcfLags double {mustBeScalarOrEmpty, mustBeInteger, mustBeNonnegative} = []
        options.BootLags double {mustBeInteger} = 0
        options.NBoot (1,1) double {mustBeInteger, mustBePositive} = 1000
        options.BlockLength double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Stage (1,1) string = "correlate"
        options.Level (1,1) double {mustBeGreaterThan(options.Level, 0), mustBeLessThan(options.Level, 1)} = 0.6827
    end

    N = numel(arc.t);
    M = size(arc.obs, 2);
    step = diff(arc.t);
    if N < 2 || any(step ~= step(1))
        error("timeSeriesPreparation:correlate:irregularGrid", ...
            "correlate needs uniformly spaced epochs; resample with align first.");
    end
    dt = double(step(1)) / 1e9;
    if ~all(isfield(drv, ["t" "names" "values"])) || ~isequal(drv.t, arc.t) ...
            || size(drv.values, 1) ~= N || size(drv.values, 2) ~= numel(drv.names)
        error("timeSeriesPreparation:correlate:epochMismatch", ...
            "drv must be the output of drivers(arc, ...) on the arc's epochs.");
    end
    checkModel(model, M);
    bootLags = reshape(options.BootLags, [], 1);
    if any(abs(bootLags) > maxLag)
        error("timeSeriesPreparation:correlate:badBootLag", ...
            "BootLags must lie within -maxLag..maxLag (%d).", maxLag);
    end
    acfLags = options.AcfLags;
    if isempty(acfLags)
        acfLags = maxLag;
    end

    K = numel(drv.names);
    lags = (-maxLag:maxLag)';
    nL = numel(lags);
    B = numel(bootLags);
    X = arc.obs;
    X(arc.weights == 0 | arc.filled, :) = NaN;
    D = drv.values - mean(drv.values, 1, "omitnan");
    z = sqrt(2) * erfinv(options.Level);

    res = struct("axes", arc.names, "drivers", drv.names, "lags", lags, ...
        "lagSeconds", lags * dt, "r", NaN(nL, M, K), "n", zeros(nL, M, K), ...
        "nEff", NaN(M, K), "ci", NaN(2, nL, M, K), "level", options.Level, ...
        "boot", struct("lags", bootLags, "sigma", NaN(B, M, K), ...
            "ci", NaN(2, B, M, K), "blockLength", NaN(B, M, K)), ...
        "order", [repmat(size(model.a, 2) - 1, M, 1), repmat(size(model.b, 2) - 1, M, 1)]);
    for m = 1:M
        a = model.a(m, :);
        b = model.b(m, :);
        xw = whiten(X(:, m) - model.mu(m), a, b);
        Dw = zeros(N, K);
        for k = 1:K
            Dw(:, k) = whiten(D(:, k), a, b);
        end
        rhoX = [];
        for k = 1:K
            dw = Dw(:, k);
            for i = 1:nL
                [xa, da] = pairsAt(xw, dw, lags(i));
                [res.r(i, m, k), res.n(i, m, k)] = pearson(xa, da);
            end
            n0 = res.n(lags == 0, m, k);
            if n0 < 10
                error("timeSeriesPreparation:correlate:tooFewPairs", ...
                    "Axis %s and driver %s share %d whitened samples at lag 0; at least 10 are needed.", ...
                    arc.names(m), drv.names(k), n0);
            end
            if isempty(rhoX)
                rhoX = acfOf(xw, acfLags);
            end
            rhoD = acfOf(dw, acfLags);
            res.nEff(m, k) = n0 / (1 + 2 * sum(rhoX(2:end) .* rhoD(2:end), "omitnan"));
            half = z / sqrt(max(res.nEff(m, k) - 3, 0));
            zr = atanh(res.r(:, m, k));
            res.ci(:, :, m, k) = tanh([zr - half, zr + half]');
            for j = 1:B
                [xa, da] = pairsAt(xw, dw, bootLags(j));
                [~, info] = timeSeriesPreparation.bootstrap([xa, da], @pearsonRows, ...
                    NBoot = options.NBoot, BlockLength = options.BlockLength, ...
                    Seed = options.Seed, Stage = options.Stage, Level = options.Level);
                res.boot.sigma(j, m, k) = info.sigma;
                res.boot.ci(:, j, m, k) = info.ci;
                res.boot.blockLength(j, m, k) = info.blockLength;
            end
        end
    end
end

% ------------------------------------------------------------------------

function checkModel(model, M)
% noise's a, b, mu for M axes, monic.
    ok = all(isfield(model, ["a" "b" "mu"]));
    if ok
        ok = isa(model.a, "double") && isa(model.b, "double") && ismatrix(model.a) ...
            && ismatrix(model.b) && size(model.a, 1) == M && size(model.b, 1) == M ...
            && ~isempty(model.a) && ~isempty(model.b) && all(model.a(:, 1) == 1) ...
            && all(model.b(:, 1) == 1) && all(isfinite([model.a(:); model.b(:)])) ...
            && isnumeric(model.mu) && numel(model.mu) == M && all(isfinite(model.mu));
    end
    if ~ok
        error("timeSeriesPreparation:correlate:modelMismatch", ...
            "model needs a (%d x p+1) and b (%d x q+1) with leading 1, and mu (1 x %d), as noise returns.", ...
            M, M, M);
    end
end

function y = whiten(x, a, b)
% Inverse ARMA filter per finite stretch, from rest; the first p samples NaN.
    p = numel(a) - 1;
    y = NaN(size(x));
    d = diff([false; isfinite(x); false]);
    first = find(d == 1);
    last = find(d == -1) - 1;
    for s = 1:numel(first)
        rows = first(s):last(s);
        seg = filter(a, b, x(rows));
        seg(1:min(p, numel(seg))) = NaN;
        y(rows) = seg;
    end
end

function [xa, da] = pairsAt(x, d, l)
% The pairs (x_t, d_(t-l)) as two aligned columns.
    N = numel(x);
    if l >= 0
        xa = x(1 + l:N);
        da = d(1:N - l);
    else
        xa = x(1:N + l);
        da = d(1 - l:N);
    end
end

function [r, n] = pearson(x, d)
% Pearson correlation over the complete pairs, and their count.
    ok = isfinite(x) & isfinite(d);
    n = nnz(ok);
    r = NaN;
    if n >= 3
        xc = x(ok) - mean(x(ok));
        dc = d(ok) - mean(d(ok));
        r = sum(xc .* dc) / sqrt(sum(xc.^2) * sum(dc.^2));
    end
end

function r = pearsonRows(z)
% bootstrap's statistic: Pearson correlation of the two columns of z.
    r = pearson(z(:, 1), z(:, 2));
end

function rho = acfOf(x, L)
% Gap-aware ACF at lags 0..L; [1] when L is 0.
    if L == 0
        rho = 1;
        return
    end
    rho = timeSeriesPreparation.tsmodels.tsAcf(x, L);
end
