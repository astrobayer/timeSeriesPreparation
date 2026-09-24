classdef TestCorrelate < matlab.unittest.TestCase
%TESTCORRELATE  correlate: Box-Jenkins pre-whitening, lag convention, nEff, Fisher and bootstrap intervals.
%
%   DESCRIPTION
%     With a white model (a = b = 1) pre-whitening is the identity, so r at
%     each lag must equal corrcoef of the shifted vectors, computed here
%     directly; with an ARMA model it must equal the direct filter(a, b, .)
%     of both series followed by the same corrcoef (1e-12: a few thousand
%     products of O(1) numbers). The statistical checks use bands measured
%     in NumPy (2026-09-24):
%       - x_t = e_t + 0.5 d_(t-7), e and d white, n = 4000: the peak is at
%         +7 and r - 0.447 has sd 0.0122 (theory 0.0126), worst of 300
%         realisations 0.038; held to 0.065 (5 sd).
%       - two independent AR(0.95) series, n = 3000, lags -50..50: after
%         pre-whitening max |r| sqrt(n) <= 4.18 over 200 realisations,
%         held to 5.5; nEff/n 0.039-0.069 before and 0.986-1.010 after,
%         held to < 0.1 and 0.95-1.05.
%       - the lag-0 bootstrap sigma over (1 - r^2)/sqrt(n): 0.90-1.10 over
%         100 realisations, held to 0.75-1.3.
%
%   COVERAGE
%     reference      - white model equals corrcoef; the transfer peak sits
%                      at +l0 with rho = beta/sqrt(beta^2 + 1); bootstrap
%                      sigma within the measured band of Fisher's.
%     precision      - ARMA pre-whitening equals the direct filter.
%     contract       - fields and sizes; a gap restarts the filter and
%                      drops p samples per stretch.
%     metamorphic    - pre-whitening lifts nEff/n from ~5 % to ~100 % and
%                      keeps every lag inside the null band.
%     vectorisation  - two axes and two drivers equal the four single calls
%                      to rounding.
%     robustness     - each identifier fires on its planted defect.
%     speed          - exempt: O((2 maxLag + 1) N) per axis and driver,
%                      plus NBoot statistics per bootstrapped lag.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-24 10:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function whiteModelEqualsCorrcoef(testCase)
            rs = RandStream("twister", "Seed", 71);
            x = randn(rs, 500, 1);
            d = 0.3 * x + randn(rs, 500, 1);
            [arc, drv] = pairOf(x, d);
            res = timeSeriesPreparation.correlate(arc, drv, white(1), 6, BootLags = []);
            for l = -6:6
                testCase.verifyEqual(res.r(res.lags == l), shifted(x, d, l), "AbsTol", 1e-12, sprintf("lag %d", l));
            end
        end

        function transferPeakAtItsLag(testCase)
            rs = RandStream("twister", "Seed", 72);
            n = 4000;
            d = randn(rs, n + 7, 1);
            x = randn(rs, n, 1) + 0.5 * d(1:n);
            [arc, drv] = pairOf(x, d(8:end));           % x_t = e_t + 0.5 d'_(t-7)
            res = timeSeriesPreparation.correlate(arc, drv, white(1), 20, BootLags = []);
            [~, i] = max(abs(res.r));
            testCase.verifyEqual(res.lags(i), 7);
            testCase.verifyEqual(res.r(i), 0.5 / sqrt(1.25), "AbsTol", 0.065);
        end

        function bootstrapSigmaNearFisher(testCase)
            rs = RandStream("twister", "Seed", 73);
            n = 2000;
            d = randn(rs, n, 1);
            [arc, drv] = pairOf(randn(rs, n, 1) + 0.5 * d, d);
            res = timeSeriesPreparation.correlate(arc, drv, white(1), 3, NBoot = 500, AcfLags = 3);
            r0 = res.r(res.lags == 0);
            ratio = res.boot.sigma / ((1 - r0^2) / sqrt(n));
            testCase.verifyGreaterThan(ratio, 0.75);
            testCase.verifyLessThan(ratio, 1.3);
            testCase.verifyLessThan(res.boot.ci(1), r0);
            testCase.verifyGreaterThan(res.boot.ci(2), r0);
        end
    end

    methods (Test, TestTags = {'precision'})
        function armaWhiteningEqualsDirectFilter(testCase)
            rs = RandStream("twister", "Seed", 74);
            x = filter([1 0.4], [1 -0.6 0.2], randn(rs, 800, 1));
            d = filter(1, [1 -0.9], randn(rs, 800, 1));
            a = [1 -0.6 0.2];
            b = [1 0.4];
            model = struct("a", a, "b", b, "mu", 0.1);
            [arc, drv] = pairOf(x, d);
            res = timeSeriesPreparation.correlate(arc, drv, model, 5, BootLags = []);
            xw = filter(a, b, x - 0.1);
            dw = filter(a, b, d - mean(d));
            xw(1:2) = NaN;
            dw(1:2) = NaN;
            for l = -5:5
                testCase.verifyEqual(res.r(res.lags == l), shifted(xw, dw, l), "AbsTol", 1e-12, sprintf("lag %d", l));
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndSizes(testCase)
            rs = RandStream("twister", "Seed", 75);
            X = randn(rs, 300, 2);
            [arc, drv] = pairOf(X, randn(rs, 300, 3), 0.5);
            model = struct("a", [1 -0.2; 1 0.1], "b", [1; 1], "mu", [0 0]);
            res = timeSeriesPreparation.correlate(arc, drv, model, 4, BootLags = [0 2], NBoot = 20, Level = 0.9);
            testCase.verifyEqual(res.axes, ["c1" "c2"]);
            testCase.verifyEqual(res.drivers, ["d1" "d2" "d3"]);
            testCase.verifyEqual(res.lags, (-4:4)');
            testCase.verifyEqual(res.lagSeconds, (-4:4)' * 0.5);
            testCase.verifySize(res.r, [9 2 3]);
            testCase.verifySize(res.n, [9 2 3]);
            testCase.verifySize(res.nEff, [2 3]);
            testCase.verifySize(res.ci, [2 9 2 3]);
            testCase.verifyTrue(all(res.ci(1, :) <= res.r(:)' & res.r(:)' <= res.ci(2, :)));
            testCase.verifyEqual(res.level, 0.9);
            testCase.verifyEqual(res.boot.lags, [0; 2]);
            testCase.verifySize(res.boot.sigma, [2 2 3]);
            testCase.verifySize(res.boot.ci, [2 2 2 3]);
            testCase.verifyEqual(res.order, [1 0; 1 0]);
        end

        function gapRestartsTheFilter(testCase)
            rs = RandStream("twister", "Seed", 76);
            x = randn(rs, 200, 1);
            x(80:84) = NaN;
            [arc, drv] = pairOf(x, randn(rs, 200, 1));
            model = struct("a", [1 -0.5 0.1], "b", 1, "mu", 0);
            res = timeSeriesPreparation.correlate(arc, drv, model, 0, BootLags = []);
            % Two stretches of x (1..79, 85..200) and one of d, 2 samples
            % dropped at each stretch start: 195 - 2 - 2 pairs at lag 0.
            testCase.verifyEqual(res.n, 191);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function prewhiteningRemovesSpuriousMemory(testCase)
            rs = RandStream("twister", "Seed", 77);
            n = 3000;
            x = filter(1, [1 -0.95], randn(rs, n + 500, 1));
            d = filter(1, [1 -0.95], randn(rs, n + 500, 1));
            [arc, drv] = pairOf(x(501:end), d(501:end));
            raw = timeSeriesPreparation.correlate(arc, drv, white(1), 50, BootLags = []);
            ar = struct("a", [1 -0.95], "b", 1, "mu", 0);
            pw = timeSeriesPreparation.correlate(arc, drv, ar, 50, BootLags = []);
            testCase.verifyLessThan(raw.nEff / n, 0.1);
            testCase.verifyGreaterThan(pw.nEff / n, 0.95);
            testCase.verifyLessThan(pw.nEff / n, 1.05);
            testCase.verifyLessThan(max(abs(pw.r)) * sqrt(n), 5.5);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function axesAndDriversEqualSingleCalls(testCase)
            rs = RandStream("twister", "Seed", 78);
            X = randn(rs, 400, 2);
            Dv = randn(rs, 400, 2);
            model = struct("a", [1 -0.3; 1 0.2], "b", [1 0.1; 1 0], "mu", [0.05 -0.02]);
            [arc, drv] = pairOf(X, Dv);
            all4 = timeSeriesPreparation.correlate(arc, drv, model, 3, BootLags = []);
            for m = 1:2
                for k = 1:2
                    [a1, d1] = pairOf(X(:, m), Dv(:, k));
                    one = timeSeriesPreparation.correlate(a1, d1, ...
                        struct("a", model.a(m, :), "b", model.b(m, :), "mu", model.mu(m)), 3, BootLags = []);
                    % A column mean of an N x 2 matrix and of an N x 1 vector
                    % may round differently: a few eps, not bitwise.
                    testCase.verifyEqual(all4.r(:, m, k), one.r, "AbsTol", 1e-13);
                    testCase.verifyEqual(all4.nEff(m, k), one.nEff, "RelTol", 1e-12);
                end
            end
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            rs = RandStream("twister", "Seed", 79);
            [arc, drv] = pairOf(randn(rs, 50, 1), randn(rs, 50, 1));
            f = @(varargin) timeSeriesPreparation.correlate(varargin{:}, "BootLags", []);
            testCase.verifyError(@() f(arc, setfield(drv, "t", drv.t + 1), white(1), 3), ...
                "timeSeriesPreparation:correlate:epochMismatch"); %#ok<SFLD>
            testCase.verifyError(@() f(arc, drv, white(2), 3), ...
                "timeSeriesPreparation:correlate:modelMismatch");
            testCase.verifyError(@() f(arc, drv, struct("a", 2, "b", 1, "mu", 0), 3), ...
                "timeSeriesPreparation:correlate:modelMismatch");
            testCase.verifyError(@() f(arc, drv, rmfield(white(1), "mu"), 3), ...
                "timeSeriesPreparation:correlate:modelMismatch");
            testCase.verifyError(@() timeSeriesPreparation.correlate(arc, drv, white(1), 3, BootLags = 4), ...
                "timeSeriesPreparation:correlate:badBootLag");
            [sparse, sd] = pairOf([NaN(45, 1); randn(rs, 5, 1)], randn(rs, 50, 1));
            testCase.verifyError(@() f(sparse, sd, white(1), 3), ...
                "timeSeriesPreparation:correlate:tooFewPairs");
            testCase.verifyError(@() f(arc, drv, white(1), -1), "MATLAB:validators:mustBeNonnegative");
            aux = auxOf(1);
            irregular = timeSeriesPreparation.Arc(int64([0 1 3 4])' * int64(1e9), zeros(4, 1), aux);
            idrv = timeSeriesPreparation.drivers(irregular, struct("name", "d1", "t", irregular.t, ...
                "value", zeros(4, 1), "unit", "1"));
            testCase.verifyError(@() f(irregular, idrv, white(1), 1), ...
                "timeSeriesPreparation:correlate:irregularGrid");
        end
    end
end

% ------------------------------------------------------------------------

function r = shifted(x, d, l)
% corrcoef of the complete pairs (x_t, d_(t-l)), written out directly.
    N = numel(x);
    if l >= 0
        xa = x(1 + l:N);
        da = d(1:N - l);
    else
        xa = x(1:N + l);
        da = d(1 - l:N);
    end
    ok = isfinite(xa) & isfinite(da);
    c = corrcoef(xa(ok), da(ok));
    r = c(1, 2);
end

function model = white(M)
% The identity pre-whitening for M axes.
    model = struct("a", ones(M, 1), "b", ones(M, 1), "mu", zeros(1, M));
end

function [arc, drv] = pairOf(X, D, dt)
% An arc of columns c1..cM and drivers d1..dK on the same grid of step dt s.
    if nargin < 3
        dt = 1;
    end
    N = size(X, 1);
    t = int64(0:N - 1)' * int64(round(dt * 1e9));
    arc = timeSeriesPreparation.Arc(t, X, auxOf(size(X, 2)));
    s = struct("name", {}, "t", {}, "value", {}, "unit", {});
    for k = 1:size(D, 2)
        s(k) = struct("name", "d" + k, "t", t, "value", D(:, k), "unit", "1");
    end
    drv = timeSeriesPreparation.drivers(arc, s);
end

function aux = auxOf(M)
% readL1b-shaped metadata for M columns c1..cM.
    names = cellstr("c" + (1:M));
    units = cell2struct(repmat({'m/s2'}, M, 1), names, 1);
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
end
