classdef TestCrossval < matlab.unittest.TestCase
%TESTCROSSVAL  crossval: contiguous folds, a buffer of Gap rows, NaN outside each set.
%
%   DESCRIPTION
%     The partition is checked by construction: with x = row number, the
%     finite entries lossFcn receives are the rows of each set, so the test
%     can see which rows were tested and trained on. Every row must be
%     tested exactly once, and no training row may lie within Gap rows of
%     its test block. On white noise the loss of the training mean as a
%     predictor is the variance times (1 + 1/n_train); for N = 5000 its
%     sampling sd is about sqrt(2/N) = 0.02, so 0.1 is five sigma.
%
%   COVERAGE
%     contract       - fold sizes and order; each row tested once; the
%                      buffer holds; Gap [] is the automatic block length;
%                      malformed losses and impossible splits are refused.
%     reference      - white noise: loss of the mean predictor equals the
%                      variance to sampling error.
%     metamorphic    - that loss is unchanged by a constant shift of x.
%     vectorisation  - a joint call equals the per-column calls to rounding.
%     robustness     - NaN samples reach lossFcn; non-finite fold losses
%                      are left out of the mean.
%     precision, speed - exempt: no numerics of its own beyond a mean;
%                      the cost is Folds calls of the caller's lossFcn.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function foldsAreContiguousAndNearEqual(testCase)
            [~, info] = timeSeriesPreparation.crossval((1:103)', @(tr, te) 0, Folds = 5, Gap = 0);
            testCase.verifyEqual(info.testRows, [1 21; 22 42; 43 63; 64 83; 84 103]);
            testCase.verifyEqual(info.folds, 5);
            testCase.verifyEqual(info.gap, 0);
        end

        function eachRowTestedOnceAndBufferHolds(testCase)
            N = 240;
            gap = 7;
            probe = @(tr, te) [min(te(isfinite(te))), max(te(isfinite(te))), ...
                sum(isfinite(te)), minDistance(tr, te)];
            [~, info] = timeSeriesPreparation.crossval((1:N)', probe, Folds = 6, Gap = gap);
            L = info.foldLoss;
            testCase.verifyEqual(sum(L(:, 3)), N);
            testCase.verifyEqual(L(:, 1:2), info.testRows);
            testCase.verifyEqual(L(2:end, 1), L(1:end-1, 2) + 1);
            testCase.verifyEqual(L(:, 4), (gap + 1) * ones(6, 1));
        end

        function autoGapIsBlockLength(testCase)
            x = filter(1, [1 -0.8], randn(RandStream("twister", "Seed", 21), 1500, 1));
            [~, info] = timeSeriesPreparation.crossval(x, @(tr, te) 0);
            testCase.verifyEqual(info.gap, ceil(timeSeriesPreparation.internal.blockLength(x)));
        end

        function malformedLossRefused(testCase)
            x = (1:100)';
            testCase.verifyError(@() timeSeriesPreparation.crossval(x, @(tr, te) [1; 2], Gap = 0), ...
                "timeSeriesPreparation:crossval:badLoss");
            testCase.verifyError(@() timeSeriesPreparation.crossval(x, @(tr, te) ones(1, 1 + isfinite(te(1))), Gap = 0), ...
                "timeSeriesPreparation:crossval:badLoss");
        end

        function impossibleSplitRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.crossval((1:50)', @(tr, te) 0, Folds = 2, Gap = 30), ...
                "timeSeriesPreparation:crossval:noTraining");
            testCase.verifyError(@() timeSeriesPreparation.crossval((1:3)', @(tr, te) 0, Folds = 5, Gap = 0), ...
                "timeSeriesPreparation:crossval:noTraining");
        end
    end

    methods (Test, TestTags = {'reference'})
        function whiteNoiseLossIsVariance(testCase)
            x = randn(RandStream("twister", "Seed", 22), 5000, 1);
            mse = @(tr, te) mean((te - mean(tr, "omitnan")).^2, "omitnan");
            loss = timeSeriesPreparation.crossval(x, mse, Folds = 5, Gap = 5);
            testCase.verifyEqual(loss, 1, "AbsTol", 0.1);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function shiftLeavesLossUnchanged(testCase)
            x = randn(RandStream("twister", "Seed", 23), 800, 1);
            mse = @(tr, te) mean((te - mean(tr, "omitnan")).^2, "omitnan");
            a = timeSeriesPreparation.crossval(x, mse, Gap = 3);
            b = timeSeriesPreparation.crossval(x + 100, mse, Gap = 3);
            % Differences of numbers near 100 lose about eps(100) = 1.4e-14
            % each; squared and averaged, 1e-10 relative is ample.
            testCase.verifyEqual(b, a, "RelTol", 1e-10);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function jointCallEqualsColumns(testCase)
            X = randn(RandStream("twister", "Seed", 24), 600, 2);
            mse = @(tr, te) mean((te - mean(tr, 1, "omitnan")).^2, 1, "omitnan");
            [j, ij] = timeSeriesPreparation.crossval(X, mse, Gap = 4);
            [a, ia] = timeSeriesPreparation.crossval(X(:, 1), mse, Gap = 4);
            [b, ib] = timeSeriesPreparation.crossval(X(:, 2), mse, Gap = 4);
            % Column sums of N x 2 and N x 1 may round differently: 1e-15.
            testCase.verifyEqual(j, [a b], "AbsTol", 1e-15);
            testCase.verifyEqual(ij.foldLoss, [ia.foldLoss ib.foldLoss], "AbsTol", 1e-15);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function nanSamplesAndFoldsHandled(testCase)
            x = randn(RandStream("twister", "Seed", 25), 500, 1);
            x(1:100) = NaN;
            mse = @(tr, te) mean((te - mean(tr, "omitnan")).^2, "omitnan");
            [loss, info] = timeSeriesPreparation.crossval(x, mse, Folds = 5, Gap = 2);
            % Fold 1 holds only NaN: its loss is NaN and is left out.
            testCase.verifyTrue(isnan(info.foldLoss(1)));
            testCase.verifyEqual(loss, mean(info.foldLoss(2:end)), "RelTol", 1e-15);
            testCase.verifyTrue(isfinite(info.se));
        end
    end
end

function d = minDistance(tr, te)
% Smallest row distance between a training row and a test row (x = row number).
    r = tr(isfinite(tr));
    s = te(isfinite(te));
    d = min(abs(r - s'), [], "all");
end
