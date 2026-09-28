classdef TestNoise < matlab.unittest.TestCase
%TESTNOISE  noise: ARMA per axis on an Arc, exact ML with gaps or PSD -> ARMA.
%
%   DESCRIPTION
%     The stage applies sigtools functions tested in their own suites, so
%     this class checks the application to an Arc and the recovery of a
%     known model within its statistical scatter. For an AR(1), exact ML
%     has standard error sqrt((1 - phi^2)/n) on phi (0.013 for phi 0.7, n
%     3000) and about sqrt(2/n) relative on sigma2 (2.6 %). The tolerances
%     are five of those. The PSD route scatters more (Welch estimate plus
%     the rational fit; 32 Welch averages bias sigma2 by about -2 %), so
%     on 20000 samples it is held to 0.05 on phi and 15 % on sigma2. That
%     band is an expectation, not a measurement: no MATLAB ran before CI.
%     The whiteness check is fault-injected: an AR(0) model of AR(1) data
%     must fail Ljung-Box.
%
%   COVERAGE
%     reference      - AR(1) by exact ML, with a gap, and by the PSD route:
%                      phi and sigma2 within their scatter; acv(0) equals
%                      sigma2/(1 - phi^2) of the fitted model.
%     contract       - fields and sizes; rows of weight 0 are left out;
%                      reruns are identical and the caller's RNG stream is
%                      untouched.
%     robustness     - an underfitted model fails Ljung-Box; an irregular
%                      grid, too few samples and "psd" on a gapped axis
%                      are refused.
%     vectorisation  - a two-axis arc equals the two one-axis arcs.
%     precision, speed, metamorphic - exempt: numerics and cost are those
%                      of tsFitArima, psd2arma and arma2acv, tested in
%                      tests/sigtools.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function exactRecoversAr1WithGap(testCase)
            x = ar1(0.7, 3000, 51);
            x(1000:1100) = NaN;
            nm = timeSeriesPreparation.noise(makeArc(x), [1 0], MaxLag = 5);
            phi = -nm.a(2);
            testCase.verifyEqual(phi, 0.7, "AbsTol", 5 * sqrt((1 - 0.49) / 2899));
            testCase.verifyEqual(nm.sigma2, 1, "RelTol", 5 * sqrt(2 / 2899));
            testCase.verifyEqual(nm.acv(1), nm.sigma2 / (1 - phi^2), "RelTol", 1e-12);
            testCase.verifyGreaterThan(nm.ljungBoxP, 1e-3);
            testCase.verifyEqual(nm.nObs, 2899);
        end

        function psdRouteRecoversAr1(testCase)
            x = ar1(0.7, 20000, 52);
            nm = timeSeriesPreparation.noise(makeArc(x), [1 0], Method = "psd", MaxLag = 5);
            testCase.verifyEqual(-nm.a(2), 0.7, "AbsTol", 0.05);
            testCase.verifyEqual(nm.sigma2, 1, "RelTol", 0.15);
            testCase.verifyTrue(isfinite(nm.ljungBoxQ));
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndWeights(testCase)
            x = ar1(0.5, 1000, 53);
            arc = addLayer(makeArc([x, -x]), "user", (1:1000)' <= 100);
            nm = timeSeriesPreparation.noise(arc, [1 1], MaxLag = 7);
            testCase.verifySize(nm.a, [2 2]);
            testCase.verifySize(nm.b, [2 2]);
            testCase.verifySize(nm.acv, [8 2]);
            testCase.verifyEqual(nm.lags, (0:7)');
            testCase.verifyEqual(nm.nObs, [900 900]);
            testCase.verifyEqual(nm.dt, 1);
            testCase.verifyEqual(nm.order, [1 1]);
            testCase.verifyEqual(nm.axes, arc.names);
            testCase.verifyEqual(nm.seed, timeSeriesPreparation.internal.stageSeed("noise", 0));
        end

        function rerunIdenticalAndGlobalStreamUntouched(testCase)
            x = ar1(0.6, 800, 54);
            arc = makeArc(x);
            before = RandStream.getGlobalStream;
            state = before.State;
            a = timeSeriesPreparation.noise(arc, [1 1], MaxLag = 3);
            b = timeSeriesPreparation.noise(arc, [1 1], MaxLag = 3);
            testCase.verifyEqual(a, b);
            after = RandStream.getGlobalStream;
            testCase.verifySameHandle(after, before);
            testCase.verifyEqual(after.State, state);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function underfitFailsWhiteness(testCase)
            nm = timeSeriesPreparation.noise(makeArc(ar1(0.7, 2000, 55)), [0 0], MaxLag = 1);
            testCase.verifyLessThan(nm.ljungBoxP, 1e-6);
        end

        function irregularGridRefused(testCase)
            arc = makeArc(ar1(0.5, 200, 56));
            aux = auxOf(1);
            t = int64(0:199)' * int64(1e9);
            t(150:end) = t(150:end) + int64(5e8);
            bad = timeSeriesPreparation.Arc(t, arc.obs, aux);
            testCase.verifyError(@() timeSeriesPreparation.noise(bad, [1 0]), ...
                "timeSeriesPreparation:noise:irregularGrid");
        end

        function gapsInPsdRefused(testCase)
            x = ar1(0.5, 500, 60);
            x(10) = NaN;
            testCase.verifyError(@() timeSeriesPreparation.noise(makeArc(x), [1 0], Method = "psd"), ...
                "timeSeriesPreparation:noise:gapsInPsd");
        end

        function tooFewSamplesRefused(testCase)
            x = ar1(0.5, 100, 57);
            x(1:85) = NaN;
            testCase.verifyError(@() timeSeriesPreparation.noise(makeArc(x), [1 0]), ...
                "timeSeriesPreparation:noise:tooFewSamples");
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function twoAxesEqualOneAxisEach(testCase)
            X = [ar1(0.5, 600, 58), ar1(-0.3, 600, 59)];
            X(200:230, 1) = NaN;
            j = timeSeriesPreparation.noise(makeArc(X), [1 0], MaxLag = 4);
            a = timeSeriesPreparation.noise(makeArc(X(:, 1)), [1 0], MaxLag = 4);
            b = timeSeriesPreparation.noise(makeArc(X(:, 2)), [1 0], MaxLag = 4);
            testCase.verifyEqual(j.a, [a.a; b.a]);
            testCase.verifyEqual(j.sigma2, [a.sigma2 b.sigma2]);
            testCase.verifyEqual(j.acv, [a.acv b.acv]);
        end
    end
end

function x = ar1(phi, n, seed)
% A stationary AR(1) of unit innovation variance, 500 burn-in samples dropped.
    x = filter(1, [1 -phi], randn(RandStream("twister", "Seed", seed), n + 500, 1));
    x = x(501:end);
end

function aux = auxOf(M)
% ACT1B-style aux for M columns c1..cM.
    names = cellstr("c" + (1:M));
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, ...
        "variableUnits", cell2struct(repmat({'m/s2'}, M, 1), names, 1), ...
        "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
end

function arc = makeArc(X)
% A 1 Hz ACT1B arc of X.
    arc = timeSeriesPreparation.Arc(int64(0:size(X, 1) - 1)' * int64(1e9), X, auxOf(size(X, 2)));
end
