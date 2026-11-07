classdef TestRegressDrivers < matlab.unittest.TestCase
%TESTREGRESSDRIVERS  regressDrivers: OLS on demeaned drivers, VIF gate, block-bootstrap sigmas.
%
%   DESCRIPTION
%     The coefficients are pinned against backslash on [1, Z - mean(Z)]
%     written out here; a few hundred rows of O(1) numbers, so 1e-12. The
%     VIF of two regressors built with sample correlation exactly rho is
%     1/(1 - rho^2), each a small matrix inverse, so 1e-12. The bootstrap
%     slope sigma against the OLS sigma for white errors lay in 0.86-1.21
%     over 100 NumPy realisations of 600 rows (2026-09-24), held to
%     0.75-1.35. The gate is fault-injected by its own refusal: rho 0.99
%     (VIF 50) must refuse at 10 and pass at 100.
%
%   COVERAGE
%     reference      - coef equals backslash; VIF closed form; bootstrap
%                      slope sigma within the measured band of OLS's.
%     contract       - fields, sizes, default names, gated rows, the
%                      intercept is the mean of the rows used, r2.
%     metamorphic    - scaling a driver by c divides its coefficient and
%                      sigma by c.
%     vectorisation  - two parameters equal the two single calls.
%     robustness     - sizeMismatch, collinear (VIF and exact) and
%                      tooFewRows fire; MaxVif lifts the gate.
%     precision, speed - exempt: backslash is the reference itself; the
%                      cost is NBoot small least-squares solves.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function coefEqualsBackslash(testCase)
            rs = RandStream("twister", "Seed", 81);
            Z = [randn(rs, 200, 1), rand(rs, 200, 1)];
            P = 3 + Z * [0.4; -1.2] + 0.2 * randn(rs, 200, 1);
            P(17) = NaN;
            res = timeSeriesPreparation.regressDrivers(P, Z, NBoot = 20);
            rows = isfinite(P);
            X = [ones(nnz(rows), 1), Z(rows, :) - mean(Z(rows, :), 1)];
            testCase.verifyEqual(res.coef, X \ P(rows), "AbsTol", 1e-12);
        end

        function vifClosedForm(testCase)
            rho = 0.9;
            [u, v] = correlatedPair(rho, 300, 82);
            res = timeSeriesPreparation.regressDrivers(u + v, [u v], NBoot = 20);
            testCase.verifyEqual(res.vif, [1 1] / (1 - rho^2), "RelTol", 1e-12);
        end

        function bootstrapSlopeSigmaNearOls(testCase)
            rs = RandStream("twister", "Seed", 83);
            R = 600;
            Z = randn(rs, R, 2);
            Z(:, 2) = 0.5 * Z(:, 1) + Z(:, 2);
            P = 1 + Z * [0.3; -0.2] + 0.5 * randn(rs, R, 1);
            res = timeSeriesPreparation.regressDrivers(P, Z, NBoot = 400);
            X = [ones(R, 1), Z - mean(Z, 1)];
            e = P - X * (X \ P);
            ols = sqrt(diag(sum(e.^2) / (R - 3) * inv(X' * X)));
            ratio = res.sigma(2:3) ./ ols(2:3);
            testCase.verifyGreaterThan(ratio, 0.75);
            testCase.verifyLessThan(ratio, 1.35);
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndSizes(testCase)
            rs = RandStream("twister", "Seed", 84);
            Z = randn(rs, 120, 3);
            P = [Z * [1; 2; 3] + randn(rs, 120, 1), 5 + randn(rs, 120, 1)];
            P(1:10, 2) = NaN;
            res = timeSeriesPreparation.regressDrivers(P, Z, NBoot = 30, Level = 0.9);
            testCase.verifyEqual(res.names, ["p1" "p2"]);
            testCase.verifyEqual(res.driverNames, ["z1" "z2" "z3"]);
            testCase.verifySize(res.coef, [4 2]);
            testCase.verifySize(res.sigma, [4 2]);
            testCase.verifySize(res.ci, [2 4 2]);
            testCase.verifySize(res.vif, [1 3]);
            testCase.verifyEqual(res.nRows, [120 110]);
            testCase.verifyEqual(res.coef(1, 2), mean(P(11:end, 2)), "AbsTol", 1e-12);
            testCase.verifyGreaterThan(res.r2(1), 0.85);   % signal variance 14, noise 1
            testCase.verifyEqual(res.level, 0.9);
            testCase.verifyTrue(all(res.ci(1, :, :) <= res.ci(2, :, :), "all"));
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function scalingADriverScalesItsCoefficient(testCase)
            rs = RandStream("twister", "Seed", 85);
            Z = randn(rs, 150, 2);
            P = Z * [0.5; 1] + randn(rs, 150, 1);
            a = timeSeriesPreparation.regressDrivers(P, Z, NBoot = 50, BlockLength = 5);
            b = timeSeriesPreparation.regressDrivers(P, Z .* [4 1], NBoot = 50, BlockLength = 5);
            testCase.verifyEqual(b.coef(2, 1), a.coef(2, 1) / 4, "RelTol", 1e-10);
            testCase.verifyEqual(b.sigma(2, 1), a.sigma(2, 1) / 4, "RelTol", 1e-10);
            testCase.verifyEqual(b.coef([1 3], 1), a.coef([1 3], 1), "RelTol", 1e-10);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function twoParametersEqualSingleCalls(testCase)
            rs = RandStream("twister", "Seed", 86);
            Z = randn(rs, 150, 2);
            P = [Z * [0.5; 1], Z * [-1; 0.2]] + randn(rs, 150, 2);
            both = timeSeriesPreparation.regressDrivers(P, Z, NBoot = 50, BlockLength = 5);
            for j = 1:2
                one = timeSeriesPreparation.regressDrivers(P(:, j), Z, NBoot = 50, BlockLength = 5);
                testCase.verifyEqual(both.coef(:, j), one.coef);
                testCase.verifyEqual(both.sigma(:, j), one.sigma);
            end
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusalsAndGate(testCase)
            [u, v] = correlatedPair(0.99, 200, 87);
            P = u + v;
            testCase.verifyError(@() timeSeriesPreparation.regressDrivers(P, [u v], NBoot = 10), ...
                "timeSeriesPreparation:regressDrivers:collinear");
            res = timeSeriesPreparation.regressDrivers(P, [u v], NBoot = 10, MaxVif = 100);
            testCase.verifyEqual(res.vif, [1 1] / (1 - 0.99^2), "RelTol", 1e-10);
            testCase.verifyError(@() timeSeriesPreparation.regressDrivers(P, [u v u + v], NBoot = 10), ...
                "timeSeriesPreparation:regressDrivers:collinear");
            testCase.verifyError(@() timeSeriesPreparation.regressDrivers(P(1:199), [u v], NBoot = 10), ...
                "timeSeriesPreparation:regressDrivers:sizeMismatch");
            testCase.verifyError(@() timeSeriesPreparation.regressDrivers(P, u, DriverNames = ["a" "b"], NBoot = 10), ...
                "timeSeriesPreparation:regressDrivers:sizeMismatch");
            sparse = NaN(200, 1);
            sparse(1:2) = 1;
            % MaxVif lifted so the row check, not the gate, is what fires.
            testCase.verifyError(@() timeSeriesPreparation.regressDrivers(sparse, [u v], NBoot = 10, MaxVif = 100), ...
                "timeSeriesPreparation:regressDrivers:tooFewRows");
        end
    end
end

% ------------------------------------------------------------------------

function [u, v] = correlatedPair(rho, n, seed)
% Two zero-mean columns of unit norm with sample correlation exactly rho.
    Z = randn(RandStream("twister", "Seed", seed), n, 2);
    Z = Z - mean(Z, 1);
    [Q, ~] = qr(Z, "econ");
    u = Q(:, 1);
    v = rho * Q(:, 1) + sqrt(1 - rho^2) * Q(:, 2);
end
