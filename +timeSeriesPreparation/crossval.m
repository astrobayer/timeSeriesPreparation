function [loss, info] = crossval(x, lossFcn, options)
%CROSSVAL  Blocked cross-validation with a buffer, for serially correlated rows.
%
%   SYNTAX
%     [loss, info] = timeSeriesPreparation.crossval(x, lossFcn)
%     [loss, info] = timeSeriesPreparation.crossval(x, lossFcn, Folds = 5, Gap = [])
%
%   DESCRIPTION
%     Out-of-sample loss of a model on dependent samples (CONCEPT 6.1, row
%     7). Random K-fold splits leak information when neighbouring rows are
%     correlated: a test row's neighbours sit in the training set. Here
%     the rows are cut into Folds contiguous blocks of near-equal length
%     (the first rem(N, Folds) blocks one row longer). For fold k the
%     test rows are block k; the training rows are all others except the
%     Gap rows on either side of the block, which neither set uses
%     (hv-block cross-validation, Racine 2000, with v = 0).
%
%     lossFcn(xTrain, xTest) returns a 1 x L row. Both arguments are N x M,
%     the full grid, with every row outside the set NaN. The time index
%     therefore stays intact, and NaN is the only missing value (CONCEPT
%     5.2). lossFcn must treat NaN. No least-squares estimator lives here
%     (CONCEPT 3.2): the application fits on xTrain and scores on xTest.
%
%     Gap [] takes the automatic block length of internal.blockLength
%     (Politis & White 2004, Patton et al. 2009) per column, rounded up,
%     the largest over the columns: the range over which rows are still
%     dependent (owner decision 2026-09-23). No random numbers are used.
%
%   INPUTS
%     x        (N,M) double            -   Samples in rows; NaN marks a
%                                          missing sample.
%     lossFcn  (1,1) function_handle   -   (xTrain, xTest) -> (1,L)
%                                          double.
%
%   OPTIONS
%     Folds  (1,1) double   [5]       Number of blocks, integer >= 2.
%     Gap    (1,1) double   [auto]    Rows left out on each side of the
%                                     test block, integer >= 0; [] (auto)
%                                     = the Politis-White block length.
%
%   OUTPUTS
%     loss  (1,L) double   -   Mean over the folds whose loss is finite.
%     info  (1,1) struct   -   Fields: foldLoss (Folds,L), se (1,L)
%                              standard error of loss, std/sqrt(folds);
%                              testRows (Folds,2) first and last row of
%                              each test block; gap, folds.
%
%   ACCURACY
%     Exact partition: every row is tested exactly once, and no training
%     row lies within Gap rows of its test block (TestCrossval checks
%     both). se treats the fold losses as independent, which the buffer
%     makes approximately true; it is a guide, not a confidence bound.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:crossval:badLoss - lossFcn does not return a
%           1 x L double row of the same L for every fold.
%       timeSeriesPreparation:crossval:noTraining - Folds and Gap leave a
%           fold without a training row or without a test row.
%       timeSeriesPreparation:blockLength:tooShort - automatic Gap on too
%           few rows.
%       Options outside their domain are refused by the arguments block
%       with a MATLAB: identifier.
%
%   EXAMPLE
%     % Loss of the training mean as a predictor of the test rows.
%     x = filter(1, [1 -0.5], randn(RandStream("twister", "Seed", 4), 1000, 1));
%     mse = @(tr, te) mean((te - mean(tr, "omitnan")).^2, "omitnan");
%     [loss, info] = timeSeriesPreparation.crossval(x, mse, Folds = 5);
%
%   LIMITATIONS
%     Rows are assumed equally spaced. Folds are contiguous in the row
%     order; a test block at the start or end has a buffer on one side
%     only. The training set is not required to precede the test block
%     (no forward-chaining).
%
%   REFERENCES
%     Racine, J. (2000). Consistent cross-validatory model-selection for
%     dependent data: hv-block cross-validation. J. Econometrics 99(1),
%     39-61. Burman, P., Chow, E., Nolan, D. (1994). A cross-validatory
%     method for dependent data. Biometrika 81(2), 351-358. Bergmeir, C.,
%     Hyndman, R. J., Koo, B. (2018). A note on the validity of
%     cross-validation for evaluating autoregressive time series
%     prediction. Comput. Stat. Data Anal. 120, 70-83. docs/CONCEPT.md
%     section 6.1 (row 7).
%
%   See also timeSeriesPreparation.bootstrap, timeSeriesPreparation.internal.blockLength.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x (:,:) double
        lossFcn (1,1) function_handle
        options.Folds (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.Folds, 2)} = 5
        options.Gap double {mustBeScalarOrEmpty, mustBeInteger, mustBeNonnegative} = []
    end

    N = size(x, 1);
    F = options.Folds;
    gap = options.Gap;
    if isempty(gap)
        gap = max(ceil(timeSeriesPreparation.internal.blockLength(x)));
    end

    len = floor(N / F) * ones(F, 1);
    len(1:rem(N, F)) = len(1:rem(N, F)) + 1;
    last = cumsum(len);
    first = last - len + 1;
    rows = (1:N)';

    foldLoss = [];
    for k = 1:F
        test = rows >= first(k) & rows <= last(k);
        train = rows < first(k) - gap | rows > last(k) + gap;
        if ~any(train) || ~any(test)
            error("timeSeriesPreparation:crossval:noTraining", ...
                "Fold %d has no training or no test row with Folds = %d and Gap = %d on %d rows.", ...
                k, F, gap, N);
        end
        xTrain = x;
        xTrain(~train, :) = NaN;
        xTest = x;
        xTest(~test, :) = NaN;
        v = lossFcn(xTrain, xTest);
        if ~isa(v, "double") || ~isrow(v) || (k > 1 && numel(v) ~= size(foldLoss, 2))
            error("timeSeriesPreparation:crossval:badLoss", ...
                "lossFcn must return a 1 x L double row with the same L every fold.");
        end
        if k == 1
            foldLoss = zeros(F, numel(v));
        end
        foldLoss(k, :) = v;
    end

    L = size(foldLoss, 2);
    loss = NaN(1, L);
    se = NaN(1, L);
    for j = 1:L
        v = foldLoss(isfinite(foldLoss(:, j)), j);
        if ~isempty(v)
            loss(j) = mean(v);
        end
        if numel(v) >= 2
            se(j) = std(v) / sqrt(numel(v));
        end
    end
    info = struct("foldLoss", foldLoss, "se", se, "testRows", [first last], ...
        "gap", gap, "folds", F);
end
