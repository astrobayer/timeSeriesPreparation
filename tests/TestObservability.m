classdef TestObservability < matlab.unittest.TestCase
%TESTOBSERVABILITY  observability: design metrics against closed forms; the minimum-data gate.
%
%   DESCRIPTION
%     The metrics are pinned against closed forms. For the design [1, a]
%     the estimates correlate at -mean(a)/sqrt(mean(a.^2)); demeaning a
%     makes that 0. Two regressors built with sample correlation exactly r
%     have VIF 1/(1 - r^2). Orthonormal columns have condition number 1.
%     Each is a few operations on P x P matrices of condition at most a few
%     hundred, so 1e-12 bounds their rounding. The gate is fault-injected
%     by its own refusal: an axis at 0.4 against the 0.5 preset must fail,
%     and a product without a preset must ask for the threshold.
%
%   COVERAGE
%     reference      - bias/scale correlation and its demeaned form; VIF of
%                      two correlated regressors; the quiet-arc -1.
%     precision      - orthonormal design: cond 1, paramCorr identity.
%     contract       - fields and sizes; weight fraction from layers and
%                      NaN per axis; the gate refuses below the preset,
%                      passes above it, and an explicit threshold overrides.
%     metamorphic    - scaling a regressor changes neither cond, vif nor
%                      |paramCorr|.
%     vectorisation  - a two-axis arc equals the two one-axis arcs.
%     robustness     - dependent columns give Inf/NaN, warning-free;
%                      a product without preset and a size mismatch refuse.
%     speed          - exempt: P x P algebra per axis after one pass over
%                      the rows.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function biasScaleCorrelationClosedForm(testCase)
            a = 3 + sin((1:500)' / 20);
            arc = makeArc("ACT1B", a);
            r = timeSeriesPreparation.observability(arc, [ones(500, 1), a]);
            testCase.verifyEqual(r.paramCorr(1, 2), -mean(a) / sqrt(mean(a.^2)), "RelTol", 1e-12);
            testCase.verifyEqual(r.maxAbsCorr, abs(r.paramCorr(1, 2)), "RelTol", 1e-14);
            d = timeSeriesPreparation.observability(arc, [ones(500, 1), a - mean(a)]);
            testCase.verifyEqual(d.paramCorr(1, 2), 0, "AbsTol", 1e-12);
        end

        function quietArcCorrelatesAtMinusOne(testCase)
            model = 1e-7 + 1e-9 * sin((0:999)' / 100);
            r = timeSeriesPreparation.observability(makeArc("ACT1B", model), [ones(1000, 1), model]);
            testCase.verifyLessThan(r.paramCorr(1, 2), -0.9999);
            testCase.verifyGreaterThan(r.cond, 100);
        end

        function vifOfTwoCorrelatedRegressors(testCase)
            rho = 0.9;
            Z = randn(RandStream("twister", "Seed", 31), 400, 2);
            Z = Z - mean(Z, 1);
            [Q, ~] = qr(Z, "econ");
            u = Q(:, 1);
            v = rho * Q(:, 1) + sqrt(1 - rho^2) * Q(:, 2);
            r = timeSeriesPreparation.observability(makeArc("ACT1B", u), [ones(400, 1), u, v]);
            testCase.verifyTrue(isnan(r.vif(1)));
            testCase.verifyEqual(r.vif(2:3), [1; 1] / (1 - rho^2), "RelTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'precision'})
        function orthonormalDesign(testCase)
            [Q, ~] = qr(randn(RandStream("twister", "Seed", 32), 300, 3), "econ");
            r = timeSeriesPreparation.observability(makeArc("ACT1B", Q(:, 1)), Q);
            testCase.verifyEqual(r.cond, 1, "AbsTol", 1e-12);
            testCase.verifyEqual(r.paramCorr, eye(3), "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndWeightFractions(testCase)
            N = 1000;
            obs = randn(RandStream("twister", "Seed", 33), N, 2);
            obs(1:150, 2) = NaN;
            arc = makeArc("ACT1B", obs);
            arc = addLayer(arc, "user", (1:N)' > 900);
            r = timeSeriesPreparation.observability(arc, [ones(N, 1), (1:N)'], Names = ["bias" "drift"]);
            testCase.verifyEqual(r.weightFraction, [0.9 0.75], "AbsTol", 1e-15);
            testCase.verifyEqual(r.nRows, [900 750]);
            testCase.verifyEqual(r.threshold, 0.5);
            testCase.verifyEqual(r.names, ["bias" "drift"]);
            testCase.verifyEqual(r.axes, arc.names);
            testCase.verifySize(r.paramCorr, [2 2 2]);
            testCase.verifySize(r.vif, [2 2]);
            testCase.verifySize(r.cond, [1 2]);
            d = timeSeriesPreparation.observability(arc, [ones(N, 1), (1:N)']);
            testCase.verifyEqual(d.names, ["x1" "x2"]);
        end

        function gateRefusesBelowPreset(testCase)
            obs = randn(RandStream("twister", "Seed", 34), 100, 1);
            obs(1:60) = NaN;
            arc = makeArc("KBR1B", obs);
            X = ones(100, 1);
            testCase.verifyError(@() timeSeriesPreparation.observability(arc, X), ...
                "timeSeriesPreparation:observability:insufficientData");
            r = timeSeriesPreparation.observability(arc, X, MinWeightFraction = 0.3);
            testCase.verifyEqual(r.weightFraction, 0.4, "AbsTol", 1e-15);
            obs(1:60) = 0;
            r = timeSeriesPreparation.observability(makeArc("LRI1B", obs), X);
            testCase.verifyEqual(r.threshold, 0.5);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function scalingARegressorChangesNothing(testCase)
            a = 3 + sin((1:500)' / 20);
            b = cos((1:500)' / 7);
            arc = makeArc("ACT1B", a);
            r1 = timeSeriesPreparation.observability(arc, [ones(500, 1), a, b]);
            r2 = timeSeriesPreparation.observability(arc, [ones(500, 1), -1e6 * a, b]);
            testCase.verifyEqual(r2.cond, r1.cond, "RelTol", 1e-12);
            testCase.verifyEqual(r2.vif, r1.vif, "RelTol", 1e-12);
            testCase.verifyEqual(abs(r2.paramCorr), abs(r1.paramCorr), "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function twoAxesEqualOneAxisEach(testCase)
            N = 600;
            obs = randn(RandStream("twister", "Seed", 35), N, 2);
            obs(50:120, 1) = NaN;
            X = [ones(N, 1), (1:N)', sin((1:N)' / 30)];
            j = timeSeriesPreparation.observability(makeArc("ACT1B", obs), X);
            a = timeSeriesPreparation.observability(makeArc("ACT1B", obs(:, 1)), X);
            b = timeSeriesPreparation.observability(makeArc("ACT1B", obs(:, 2)), X);
            testCase.verifyEqual(j.cond, [a.cond b.cond]);
            testCase.verifyEqual(j.vif, [a.vif b.vif]);
            testCase.verifyEqual(j.paramCorr, cat(3, a.paramCorr, b.paramCorr));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function dependentColumnsWarningFree(testCase)
            a = sin((1:200)' / 10);
            arc = makeArc("ACT1B", a);
            r = testCase.verifyWarningFree(@() timeSeriesPreparation.observability(arc, [ones(200, 1), a, 2 * a]));
            testCase.verifyGreaterThan(r.cond, 1e12);
            testCase.verifyTrue(all(isnan(r.paramCorr), "all"));
            testCase.verifyEqual(r.vif(2:3), [Inf; Inf]);
        end

        function productWithoutPresetNeedsThreshold(testCase)
            arc = makeArc("MAS1B", zeros(10, 1));
            testCase.verifyError(@() timeSeriesPreparation.observability(arc, ones(10, 1)), ...
                "timeSeriesPreparation:observability:noThreshold");
            r = timeSeriesPreparation.observability(arc, ones(10, 1), MinWeightFraction = 0.5);
            testCase.verifyEqual(r.weightFraction, 1);
        end

        function sizeMismatchRefused(testCase)
            arc = makeArc("ACT1B", zeros(10, 1));
            testCase.verifyError(@() timeSeriesPreparation.observability(arc, ones(9, 1)), ...
                "timeSeriesPreparation:observability:sizeMismatch");
            testCase.verifyError(@() timeSeriesPreparation.observability(arc, ones(10, 2), Names = "one"), ...
                "timeSeriesPreparation:observability:sizeMismatch");
        end
    end
end

function arc = makeArc(product, obs)
% A 1 Hz arc of the given product with columns c1..cM.
    M = size(obs, 2);
    names = cellstr("c" + (1:M));
    units = cell2struct(repmat({'m/s2'}, M, 1), names, 1);
    sat = "C";
    if any(product == ["KBR1B" "LRI1B"])
        sat = "Y";
    end
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", product + "_2020-01-01_" + sat + "_04.txt", "product", product);
    t = int64(0:size(obs, 1) - 1)' * int64(1e9);
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end
