function [stat, info] = bootstrap(x, statFcn, options)
%BOOTSTRAP  Moving-block bootstrap of a statistic, one RNG substream per replicate.
%
%   SYNTAX
%     [stat, info] = timeSeriesPreparation.bootstrap(x, statFcn)
%     [stat, info] = timeSeriesPreparation.bootstrap(x, statFcn, NBoot = 1000, BlockLength = [], Seed = 0, Stage = "bootstrap", Level = 0.6827)
%
%   DESCRIPTION
%     Uncertainty of a statistic of serially correlated samples (CONCEPT
%     6.1, row 7). v2 measured naive sigmas 5-14 times too optimistic on
%     GRACE residuals (CONCEPT 8), because resampling single samples
%     destroys the correlation. The moving-block bootstrap (Kuensch 1989)
%     resamples blocks of BlockLength consecutive rows instead: each
%     replicate joins ceil(N/b) blocks, whose starts are drawn uniformly
%     from 1..N-b+1, and keeps the first N rows. Rows move together, so
%     the correlation between columns is kept.
%
%     BlockLength [] takes the automatic rule of internal.blockLength
%     (Politis & White 2004, Patton et al. 2009) per column, rounded up,
%     and the largest over the columns (a longer block keeps more of the
%     dependence; owner decision 2026-09-23).
%
%     Replicate r draws from substream r of an mrg32k3a stream seeded by
%     internal.stageSeed(Stage, Seed). The result therefore depends on
%     neither the order nor the number of workers that compute the
%     replicates, and a different stage name gives independent draws
%     (CONCEPT 8).
%
%     statFcn maps an N x M matrix to a 1 x K row. It sees NaN where x has
%     NaN (NaN is the only missing value, CONCEPT 5.2), so it must treat
%     them, e.g. mean(z, 1, "omitnan"). No least-squares estimator lives
%     here (CONCEPT 3.2): an application passes its own fit as statFcn.
%
%     sigma is the standard deviation of the replicates over those whose
%     statistic is finite; ci the percentile interval at Level, by the
%     linear-interpolation quantile (Hyndman & Fan type 7).
%
%   INPUTS
%     x        (N,M) double            -   Samples in rows; NaN marks a
%                                          missing sample.
%     statFcn  (1,1) function_handle   -   z (N,M) -> (1,K) double.
%
%   OPTIONS
%     NBoot        (1,1) double   [1000]         Replicates, integer >= 2.
%     BlockLength  (1,1) double   [auto]         Block length in rows,
%                                                integer 1..N; [] (auto) =
%                                                the Politis-White rule.
%     Seed         (1,1) double   [0]            Caller's seed, integer >=
%                                                0.
%     Stage        (1,1) string   ["bootstrap"]  Stage name the seed
%                                                derives from.
%     Level        (1,1) double   [0.6827]       Coverage of ci, in (0,1);
%                                                0.6827 = 1 sigma.
%
%   OUTPUTS
%     stat  (1,K) double   -   statFcn(x).
%     info  (1,1) struct   -   Fields: sigma (1,K), ci (2,K) lower and
%                              upper bound, replicates (NBoot,K),
%                              nFinite (1,K) finite replicates per
%                              column, blockLength, nBoot, seed (the
%                              stream seed), stage, level.
%
%   ACCURACY
%     Monte-Carlo accuracy. For the mean of an AR(1) (phi 0.5, N 4000),
%     200 NumPy realisations with the automatic block and 1000 replicates
%     gave sigma between 0.85 and 1.16 times the exact standard error
%     (mean 0.96; the known small downward bias), where resampling
%     single samples gave 0.53-0.61 (measured 2026-09-23). TestBootstrap
%     holds one realisation to 0.8-1.25.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:bootstrap:badStatistic - statFcn does not
%           return a 1 x K double row of the same K for every replicate.
%       timeSeriesPreparation:bootstrap:blockTooLong - BlockLength
%           exceeds the number of rows.
%       timeSeriesPreparation:blockLength:tooShort - automatic block
%           length on too few rows.
%       Options outside their domain are refused by the arguments block
%       with a MATLAB: identifier.
%
%   EXAMPLE
%     % sigma of the mean of an AR(1): larger than the naive 1/sqrt(N).
%     x = filter(1, [1 -0.5], randn(RandStream("twister", "Seed", 3), 2000, 1));
%     [m, info] = timeSeriesPreparation.bootstrap(x, @(z) mean(z, 1, "omitnan"), NBoot = 200);
%
%   LIMITATIONS
%     Blocks are stationary in the index, not in time: rows are assumed
%     equally spaced. The percentile interval is first-order accurate;
%     no BCa correction. A statistic with a leading bias is not corrected.
%
%   REFERENCES
%     Kuensch, H. R. (1989). The jackknife and the bootstrap for general
%     stationary observations. Ann. Statist. 17(3), 1217-1241. Lahiri, S.
%     N. (2003). Resampling Methods for Dependent Data. Springer, ch. 2.
%     Hyndman, R. J., Fan, Y. (1996). Sample quantiles in statistical
%     packages. Amer. Statistician 50(4), 361-365. L'Ecuyer, P. (1999).
%     Good parameters and implementations for combined multiple recursive
%     random number generators. Oper. Res. 47(1), 159-164 (mrg32k3a).
%     docs/CONCEPT.md sections 6.1 (row 7) and 8.
%
%   See also timeSeriesPreparation.crossval, timeSeriesPreparation.internal.blockLength, timeSeriesPreparation.internal.stageSeed.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x (:,:) double
        statFcn (1,1) function_handle
        options.NBoot (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.NBoot, 2)} = 1000
        options.BlockLength double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Stage (1,1) string = "bootstrap"
        options.Level (1,1) double {mustBeGreaterThan(options.Level, 0), mustBeLessThan(options.Level, 1)} = 0.6827
    end

    N = size(x, 1);
    stat = callStat(statFcn, x, []);
    K = numel(stat);

    b = options.BlockLength;
    if isempty(b)
        b = max(ceil(timeSeriesPreparation.internal.blockLength(x)));
    end
    if b > N
        error("timeSeriesPreparation:bootstrap:blockTooLong", ...
            "BlockLength %d exceeds the %d rows.", b, N);
    end

    seed = timeSeriesPreparation.internal.stageSeed(options.Stage, options.Seed);
    stream = RandStream("mrg32k3a", "Seed", seed);
    nb = ceil(N / b);
    offsets = 0:b-1;
    reps = zeros(options.NBoot, K);
    for r = 1:options.NBoot
        stream.Substream = r;
        starts = randi(stream, N - b + 1, nb, 1);
        idx = reshape((starts + offsets)', [], 1);
        reps(r, :) = callStat(statFcn, x(idx(1:N), :), K);
    end

    ok = isfinite(reps);
    nFinite = sum(ok, 1);
    sigma = NaN(1, K);
    ci = NaN(2, K);
    p = [(1 - options.Level) / 2, (1 + options.Level) / 2];
    for k = 1:K
        v = sort(reps(ok(:, k), k));
        if numel(v) >= 2
            sigma(k) = std(v);
            ci(:, k) = quantile7(v, p);
        end
    end

    info = struct("sigma", sigma, "ci", ci, "replicates", reps, ...
        "nFinite", nFinite, "blockLength", b, "nBoot", options.NBoot, ...
        "seed", seed, "stage", options.Stage, "level", options.Level);
end

function s = callStat(statFcn, z, K)
% statFcn(z), checked to be a double row of K elements (any K when K = []).
    s = statFcn(z);
    if ~isa(s, "double") || ~isrow(s) || (~isempty(K) && numel(s) ~= K)
        error("timeSeriesPreparation:bootstrap:badStatistic", ...
            "statFcn must return a 1 x K double row with the same K every time.");
    end
end

function q = quantile7(v, p)
% Hyndman-Fan type 7 quantiles of the sorted column v at probabilities p.
    n = numel(v);
    h = (n - 1) * p(:) + 1;
    lo = floor(h);
    hi = min(lo + 1, n);
    q = v(lo) + (h - lo) .* (v(hi) - v(lo));
end
