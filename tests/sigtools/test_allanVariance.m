classdef test_allanVariance < matlab.unittest.TestCase
%TEST_ALLANVARIANCE  allanVariance: outputs, averaging grid, noise slopes and confidence bounds.
%
%   DESCRIPTION
%     allanVariance computes the overlapping Allan variance and deviation
%     with confidence bounds, local slopes and the bias instability. Checked
%     here: output sizes and types, the default and custom averaging grids,
%     multi-column input, analytic cases (constant signal, deterministic
%     ramp), the asymptotic slopes of white and random-walk noise, and the
%     ordering and width of the confidence bounds.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - a linear rate ramp has slope +1 and adev =
%                    R*tau/sqrt(2); white noise has slope -1/2, random walk
%                    +1/2.
%     contract     - sizes and classes; a row equals a column; the default
%                    grid is sorted and bounded; bounds bracket adev; bias
%                    instability is 0.664*min(adev); a custom grid is used.
%     metamorphic  - a wider confidence level gives wider bounds.
%     vectorisation - two columns equal two single-column calls.
%     robustness   - a constant signal gives zero variance; averaging
%                    factors too long for the data are dropped.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties
        fs = 100;
        N  = 2^15;
    end

    methods (Test, TestTags = {'reference'})

        function testDeterministicRampGivesSlopeOne(testCase)
            % A linear ramp in rate produces a purely quadratic phase term,
            % giving Allan deviation ~ tau^1 (slope +1) essentially exactly.
            n = (1:testCase.N)';
            x = 0.01 * n; % deterministic drift, no noise
            [tau, ~, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);

            midRange = tau > tau(round(0.2*end)) & tau < tau(round(0.8*end));
            testCase.verifyEqual(info.slope(midRange), ones(nnz(midRange),1), 'AbsTol', 1e-6);

            % check absolute scaling too: for a linear frequency drift R per second,
            % sigma_y(tau) = R*tau/sqrt(2); rate rises 0.01 per sample => R = 0.01*fs.
            R = 0.01 * testCase.fs;
            expectedAdev = R * tau / sqrt(2);
            testCase.verifyEqual(adev, expectedAdev, 'RelTol', 1e-6);
        end

        function testWhiteNoiseAsymptoticSlopeIsMinusHalf(testCase)
            rng(5);
            x = randn(testCase.N, 1);
            [tau, ~, ~, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);
            midRange = tau > 0.05 & tau < 2; % avoid edge effects
            meanSlope = mean(info.slope(midRange));
            testCase.verifyEqual(meanSlope, -0.5, 'AbsTol', 0.1);
        end

        function testRandomWalkAsymptoticSlopeIsPlusHalf(testCase)
            rng(6);
            x = cumsum(randn(testCase.N, 1)) / sqrt(testCase.fs);
            [tau, ~, ~, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);
            midRange = tau > 0.05 & tau < 2;
            meanSlope = mean(info.slope(midRange));
            testCase.verifyEqual(meanSlope, 0.5, 'AbsTol', 0.15);
        end

    end

    methods (Test, TestTags = {'contract'})

        function testOutputSizesAndTypes(testCase)
            rng(1);
            x = randn(testCase.N, 1);
            [tau, avar, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);

            testCase.verifyClass(tau, 'double');
            testCase.verifyClass(avar, 'double');
            testCase.verifyClass(adev, 'double');
            testCase.verifyClass(info, 'struct');

            K = numel(tau);
            testCase.verifySize(avar, [K, 1]);
            testCase.verifySize(adev, [K, 1]);
            testCase.verifySize(info.edf, [K, 1]);
            testCase.verifySize(info.adevLow, [K, 1]);
            testCase.verifySize(info.adevHigh, [K, 1]);
            testCase.verifySize(info.slope, [K, 1]);
            testCase.verifySize(info.biasInstability, [1, 1]);
            testCase.verifySize(info.biasInstabilityTau, [1, 1]);

            testCase.verifyGreaterThan(tau, 0);
            testCase.verifyEqual(adev, sqrt(avar), 'AbsTol', 1e-12);
        end

        function testRowVectorTreatedAsSingleColumn(testCase)
            rng(2);
            xRow = randn(1, testCase.N);
            xCol = xRow(:);
            [tauR, avarR] = timeSeriesPreparation.spectral.allanVariance(xRow, testCase.fs);
            [tauC, avarC] = timeSeriesPreparation.spectral.allanVariance(xCol, testCase.fs);
            testCase.verifyEqual(tauR, tauC);
            testCase.verifyEqual(avarR, avarC);
        end

        function testDefaultMGridMonotonicAndBounded(testCase)
            rng(3);
            x = randn(testCase.N, 1);
            [tau, ~, ~, ~] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);
            testCase.verifyTrue(issorted(tau));
            testCase.verifyGreaterThanOrEqual(tau(1), 1/testCase.fs);
            testCase.verifyLessThan(tau(end), testCase.N/testCase.fs);
        end

        function testConfidenceBoundsOrdering(testCase)
            rng(7);
            x = randn(testCase.N, 1);
            [~, avar, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs, [], 0.6827); %#ok<ASGLU>
            testCase.verifyGreaterThanOrEqual(adev, info.adevLow - 1e-12);
            testCase.verifyGreaterThanOrEqual(info.adevHigh + 1e-12, adev);
            testCase.verifyGreaterThan(info.edf, 0);
        end

        function testBiasInstabilityIsPositiveAndAtCurveMinimum(testCase)
            rng(9);
            x = randn(testCase.N, 1);
            [tau, ~, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);
            testCase.verifyGreaterThan(info.biasInstability, 0);
            [minVal, minIdx] = min(adev);
            testCase.verifyEqual(info.biasInstabilityTau, tau(minIdx));
            testCase.verifyEqual(info.biasInstability, 0.664*minVal, 'AbsTol', 1e-12);
        end

        function testCustomMGridRespected(testCase)
            rng(10);
            x = randn(testCase.N, 1);
            mCustom = [1, 5, 20, 100, 500];
            [tau, avar] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs, mCustom);
            testCase.verifyEqual(tau, mCustom(:)/testCase.fs);
            testCase.verifySize(avar, [numel(mCustom), 1]);
        end

    end

    methods (Test, TestTags = {'metamorphic'})

        function testWiderCiLevelGivesWiderBounds(testCase)
            rng(8);
            x = randn(testCase.N, 1);
            [~, ~, ~, info68] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs, [], 0.6827);
            [~, ~, ~, info95] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs, [], 0.95);
            width68 = info68.adevHigh - info68.adevLow;
            width95 = info95.adevHigh - info95.adevLow;
            testCase.verifyGreaterThan(width95, width68);
        end

    end

    methods (Test, TestTags = {'vectorisation'})

        function testMultiColumnMatchesIndividualColumns(testCase)
            rng(4);
            x1 = randn(testCase.N, 1);
            x2 = cumsum(randn(testCase.N, 1));
            X  = [x1, x2];

            [tauX, avarX] = timeSeriesPreparation.spectral.allanVariance(X, testCase.fs);
            [tau1, avar1] = timeSeriesPreparation.spectral.allanVariance(x1, testCase.fs, []);
            [tau2, avar2] = timeSeriesPreparation.spectral.allanVariance(x2, testCase.fs, []);

            % same default m-grid depends only on N, so tau vectors match
            testCase.verifyEqual(tauX, tau1);
            testCase.verifyEqual(tauX, tau2);
            testCase.verifyEqual(avarX(:,1), avar1, 'AbsTol', 1e-10);
            testCase.verifyEqual(avarX(:,2), avar2, 'AbsTol', 1e-10);
        end

    end

    methods (Test, TestTags = {'robustness'})

        function testConstantSignalGivesZeroVariance(testCase)
            % A perfectly constant rate -> zero second differences of phase
            x = 3.7 * ones(testCase.N, 1);
            [~, avar, adev] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs);
            testCase.verifyEqual(avar, zeros(size(avar)), 'AbsTol', 1e-18);
            testCase.verifyEqual(adev, zeros(size(adev)), 'AbsTol', 1e-9);
        end

        function testInvalidMValuesAreDropped(testCase)
            rng(11);
            x = randn(200, 1); % small N
            mCustom = [1, 10, 50, 100, 1000]; % 1000 -> N-2m<1, must be dropped
            [tau, avar] = timeSeriesPreparation.spectral.allanVariance(x, testCase.fs, mCustom);
            testCase.verifyLessThan(numel(tau), numel(mCustom));
            testCase.verifyEqual(numel(tau), size(avar,1));
        end

    end
end
