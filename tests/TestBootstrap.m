classdef TestBootstrap < matlab.unittest.TestCase
%TESTBOOTSTRAP  bootstrap: block resampling, substreamed RNG, seed per stage name.
%
%   DESCRIPTION
%     The moving-block bootstrap is checked against the exact standard
%     error of the mean of an AR(1), sigma_e^2 / ((1 - phi)^2 N) for large
%     N. The band is measured, not assumed: over 200 NumPy realisations
%     (phi 0.5, N 4000, automatic block, 1000 replicates) sigma / exact lay
%     in 0.85-1.16, and resampling single samples gave 0.53-0.61
%     (2026-09-23). One realisation is held to 0.8-1.25, and to at least
%     1.3 times the single-sample sigma (the smallest measured ratio was
%     1.47). The RNG contract of CONCEPT 8 is checked by equality: same
%     seed and stage, same replicates; another stage, other replicates.
%     The FNV-1a values of internal.stageSeed are pinned exactly.
%
%   COVERAGE
%     reference      - sigma of an AR(1) mean within the measured band, and
%                      above the naive single-sample sigma.
%     precision      - ci equals the type-7 quantile of the replicates;
%                      stageSeed equals FNV-1a exactly.
%     contract       - sizes and fields; identical reruns; Stage and Seed
%                      change the draws; malformed statistics and too long
%                      blocks are refused.
%     metamorphic    - shifting x by a constant shifts every replicate of
%                      the mean by it and leaves sigma unchanged.
%     vectorisation  - with a fixed block, each column of a joint call
%                      equals the single-column call to rounding.
%     robustness     - NaN samples reach statFcn; replicates without a
%                      finite statistic are counted, not averaged.
%     speed          - exempt: the cost is NBoot calls of the caller's
%                      statFcn; nothing of its own to budget.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function ar1MeanSigmaWithinMeasuredBand(testCase)
            phi = 0.5;
            N = 4000;
            e = randn(RandStream("twister", "Seed", 11), N + 500, 1);
            x = filter(1, [1 -phi], e);
            x = x(501:end);
            exact = sqrt(1 / ((1 - phi)^2 * N));
            meanFcn = @(z) mean(z, 1);
            [~, info] = timeSeriesPreparation.bootstrap(x, meanFcn, NBoot = 1000);
            [~, naive] = timeSeriesPreparation.bootstrap(x, meanFcn, NBoot = 1000, BlockLength = 1);
            testCase.verifyGreaterThan(info.sigma / exact, 0.8);
            testCase.verifyLessThan(info.sigma / exact, 1.25);
            testCase.verifyGreaterThan(info.sigma / naive.sigma, 1.3);
        end
    end

    methods (Test, TestTags = {'precision'})
        function ciIsType7Quantile(testCase)
            x = randn(RandStream("twister", "Seed", 12), 300, 1);
            [~, info] = timeSeriesPreparation.bootstrap(x, @(z) mean(z, 1), ...
                NBoot = 101, BlockLength = 5, Level = 0.9);
            % Hyndman & Fan type 7: h = (n - 1) p + 1, linear between the
            % order statistics floor(h) and floor(h) + 1.
            v = sort(info.replicates);
            h = (101 - 1) * [(1 - 0.9) / 2; (1 + 0.9) / 2] + 1;
            q = v(floor(h)) + (h - floor(h)) .* (v(floor(h) + 1) - v(floor(h)));
            testCase.verifyEqual(info.ci, q, "AbsTol", 0);
        end

        function stageSeedIsFnv1a(testCase)
            testCase.verifyEqual(timeSeriesPreparation.internal.stageSeed("a", 0), hex2dec("E40C292C"));
            testCase.verifyEqual(timeSeriesPreparation.internal.stageSeed("foobar", 0), hex2dec("BF9CF968"));
            testCase.verifyEqual(timeSeriesPreparation.internal.stageSeed("", 0), hex2dec("811C9DC5"));
            testCase.verifyEqual(timeSeriesPreparation.internal.stageSeed("a", 2^32 - hex2dec("E40C292C")), 0);
        end
    end

    methods (Test, TestTags = {'contract'})
        function sizesAndFields(testCase)
            x = randn(RandStream("twister", "Seed", 13), 500, 2);
            [stat, info] = timeSeriesPreparation.bootstrap(x, @(z) [mean(z, 1), std(z(:, 1))], NBoot = 50);
            testCase.verifySize(stat, [1 3]);
            testCase.verifySize(info.sigma, [1 3]);
            testCase.verifySize(info.ci, [2 3]);
            testCase.verifySize(info.replicates, [50 3]);
            testCase.verifyEqual(info.nFinite, [50 50 50]);
            testCase.verifyEqual(info.nBoot, 50);
            testCase.verifyEqual(info.blockLength, round(info.blockLength));
            testCase.verifyEqual(info.stage, "bootstrap");
            testCase.verifyEqual(info.seed, timeSeriesPreparation.internal.stageSeed("bootstrap", 0));
            testCase.verifyLessThanOrEqual(info.ci(1, :), info.ci(2, :));
        end

        function rerunIsIdentical(testCase)
            x = randn(RandStream("twister", "Seed", 14), 400, 1);
            f = @(z) mean(z, 1);
            [~, a] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8);
            [~, b] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8);
            testCase.verifyEqual(a.replicates, b.replicates);
        end

        function stageAndSeedChangeDraws(testCase)
            x = randn(RandStream("twister", "Seed", 15), 400, 1);
            f = @(z) mean(z, 1);
            [~, a] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8);
            [~, b] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8, Stage = "fill");
            [~, c] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8, Seed = 1);
            testCase.verifyNotEqual(a.replicates, b.replicates);
            testCase.verifyNotEqual(a.replicates, c.replicates);
        end

        function replicateDependsOnlyOnItsSubstream(testCase)
            % Replicate r uses substream r, so the first 10 of 40 equal a
            % 10-replicate run: the order and count of workers cannot matter.
            x = randn(RandStream("twister", "Seed", 16), 400, 1);
            f = @(z) mean(z, 1);
            [~, a] = timeSeriesPreparation.bootstrap(x, f, NBoot = 40, BlockLength = 8);
            [~, b] = timeSeriesPreparation.bootstrap(x, f, NBoot = 10, BlockLength = 8);
            testCase.verifyEqual(a.replicates(1:10, :), b.replicates);
        end

        function malformedStatisticRefused(testCase)
            x = randn(RandStream("twister", "Seed", 17), 200, 1);
            testCase.verifyError(@() timeSeriesPreparation.bootstrap(x, @(z) [1; 2], NBoot = 5, BlockLength = 4), ...
                "timeSeriesPreparation:bootstrap:badStatistic");
            testCase.verifyError(@() timeSeriesPreparation.bootstrap(x, @(z) ones(1, 1 + any(z ~= x)), NBoot = 5, BlockLength = 4), ...
                "timeSeriesPreparation:bootstrap:badStatistic");
        end

        function tooLongBlockRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.bootstrap(zeros(10, 1), @(z) mean(z, 1), BlockLength = 11), ...
                "timeSeriesPreparation:bootstrap:blockTooLong");
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function shiftMovesMeanReplicates(testCase)
            x = randn(RandStream("twister", "Seed", 18), 500, 1);
            f = @(z) mean(z, 1);
            [~, a] = timeSeriesPreparation.bootstrap(x, f, NBoot = 60, BlockLength = 10);
            [~, b] = timeSeriesPreparation.bootstrap(x + 5, f, NBoot = 60, BlockLength = 10);
            % Same rows drawn; mean(z + 5) = mean(z) + 5 up to rounding of
            % 500 additions of numbers near 5: a few eps(5).
            testCase.verifyEqual(b.replicates, a.replicates + 5, "AbsTol", 1e-12);
            testCase.verifyEqual(b.sigma, a.sigma, "RelTol", 1e-9);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function jointCallEqualsSingleColumns(testCase)
            X = randn(RandStream("twister", "Seed", 19), 500, 2);
            f = @(z) mean(z, 1);
            [~, j] = timeSeriesPreparation.bootstrap(X, f, NBoot = 30, BlockLength = 7);
            [~, a] = timeSeriesPreparation.bootstrap(X(:, 1), f, NBoot = 30, BlockLength = 7);
            [~, b] = timeSeriesPreparation.bootstrap(X(:, 2), f, NBoot = 30, BlockLength = 7);
            % Same rows drawn; a column sum of an N x 2 matrix and of an N x 1
            % vector may round differently, so a few eps, not bitwise.
            testCase.verifyEqual(j.replicates, [a.replicates, b.replicates], "AbsTol", 1e-15);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function nanReachesStatistic(testCase)
            x = randn(RandStream("twister", "Seed", 20), 500, 1);
            x(100:120) = NaN;
            [m, info] = timeSeriesPreparation.bootstrap(x, @(z) mean(z, 1, "omitnan"), NBoot = 50, BlockLength = 10);
            testCase.verifyTrue(isfinite(m) && isfinite(info.sigma));
            [~, plain] = timeSeriesPreparation.bootstrap(x, @(z) mean(z, 1), NBoot = 50, BlockLength = 10);
            testCase.verifyLessThan(plain.nFinite, 50);
            testCase.verifyEqual(plain.nFinite, sum(isfinite(plain.replicates)));
        end
    end
end
