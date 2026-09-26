classdef TestPartialCorrelation < matlab.unittest.TestCase
%TESTPARTIALCORRELATION  partialCorrelation: inverse correlation matrix against two independent forms.
%
%   DESCRIPTION
%     For three columns the partial correlation has the closed form
%     (r_12 - r_13 r_23) / sqrt((1 - r_13^2)(1 - r_23^2)) in the ordinary
%     correlations; for any number it equals the correlation of the
%     residuals of the two columns each regressed (with intercept) on the
%     rest. Both are computed here from corrcoef and backslash, not from
%     the implementation. Each is a few operations on matrices of
%     condition below 10, so 1e-12. The refusals are fault-injected by
%     their own triggers.
%
%   COVERAGE
%     reference      - three-column closed form.
%     precision      - four columns: equals the residual correlation.
%     contract       - fields, symmetry, unit diagonal, two columns give
%                      corrcoef, incomplete rows dropped, ci ordered.
%     metamorphic    - positive affine maps of columns leave r unchanged;
%                      negating a column flips its row and column.
%     robustness     - tooFewVariables, tooFewRows and collinear fire.
%     vectorisation, speed - exempt: one matrix in, one inverse; the cost
%                      is NBoot corrcoef calls.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function threeColumnClosedForm(testCase)
            X = sample(300, 3, 91);
            res = timeSeriesPreparation.partialCorrelation(X, NBoot = 20);
            c = corrcoef(X);
            expected = (c(1, 2) - c(1, 3) * c(2, 3)) / sqrt((1 - c(1, 3)^2) * (1 - c(2, 3)^2));
            testCase.verifyEqual(res.r(1, 2), expected, "AbsTol", 1e-12);
            testCase.verifyEqual(res.r(2, 1), expected, "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'precision'})
        function equalsResidualCorrelation(testCase)
            X = sample(400, 4, 92);
            res = timeSeriesPreparation.partialCorrelation(X, NBoot = 20);
            for pair = [1 2; 1 4; 2 3]'
                rest = setdiff(1:4, pair);
                A = [ones(400, 1), X(:, rest)];
                e1 = X(:, pair(1)) - A * (A \ X(:, pair(1)));
                e2 = X(:, pair(2)) - A * (A \ X(:, pair(2)));
                c = corrcoef(e1, e2);
                testCase.verifyEqual(res.r(pair(1), pair(2)), c(1, 2), "AbsTol", 1e-12);
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndShape(testCase)
            X = sample(200, 3, 93);
            X(5, 2) = NaN;
            res = timeSeriesPreparation.partialCorrelation(X, Names = ["r" "b" "e"], NBoot = 30);
            testCase.verifyEqual(res.names, ["r" "b" "e"]);
            testCase.verifySize(res.r, [3 3]);
            testCase.verifyEqual(res.r, res.r');
            testCase.verifyEqual(diag(res.r), ones(3, 1));
            testCase.verifyEqual(diag(res.sigma), zeros(3, 1));
            testCase.verifyEqual(res.sigma, res.sigma');
            testCase.verifySize(res.ci, [2 3 3]);
            testCase.verifyEqual(res.nRows, 199);
            testCase.verifyTrue(res.ci(1, 1, 2) <= res.ci(2, 1, 2));
            two = timeSeriesPreparation.partialCorrelation(X(:, 1:2), NBoot = 10);
            c = corrcoef(X([1:4, 6:end], 1:2));
            testCase.verifyEqual(two.r(1, 2), c(1, 2), "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function affineAndSignMaps(testCase)
            X = sample(250, 3, 94);
            a = timeSeriesPreparation.partialCorrelation(X, NBoot = 10);
            b = timeSeriesPreparation.partialCorrelation(X .* [3 0.01 7] + [1 -2 5], NBoot = 10);
            testCase.verifyEqual(b.r, a.r, "AbsTol", 1e-12);
            s = timeSeriesPreparation.partialCorrelation(X .* [1 -1 1], NBoot = 10);
            flip = [1 -1 1]' * [1 -1 1];
            testCase.verifyEqual(s.r, a.r .* flip, "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            X = sample(100, 3, 95);
            f = @(varargin) timeSeriesPreparation.partialCorrelation(varargin{:}, "NBoot", 10);
            testCase.verifyError(@() f(X(:, 1)), "timeSeriesPreparation:partialCorrelation:tooFewVariables");
            testCase.verifyError(@() f(X, "Names", ["a" "b"]), ...
                "timeSeriesPreparation:partialCorrelation:tooFewVariables");
            testCase.verifyError(@() f(X(1:4, :)), "timeSeriesPreparation:partialCorrelation:tooFewRows");
            testCase.verifyError(@() f([X(:, 1:2), X(:, 1) + X(:, 2)]), ...
                "timeSeriesPreparation:partialCorrelation:collinear");
        end
    end
end

% ------------------------------------------------------------------------

function X = sample(n, V, seed)
% V correlated columns: each adds half of the previous one to fresh noise.
    X = randn(RandStream("twister", "Seed", seed), n, V);
    for v = 2:V
        X(:, v) = X(:, v) + 0.5 * X(:, v - 1);
    end
end
