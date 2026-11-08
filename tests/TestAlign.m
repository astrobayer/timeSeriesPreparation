classdef TestAlign < matlab.unittest.TestCase
%TESTALIGN  align: reference onto observation epochs, holes never bridged, units checked.
%
%   DESCRIPTION
%     align moves the reference onto obs.t (CONCEPT 6.1, row 3). The
%     promises pinned here are these:
%       - Coinciding epochs are copied bit for bit.
%       - Without holes, the result is interp1 on the whole reference, bit
%         for bit.
%       - A NaN, a removed sample or a spacing above MaxGap ends a stretch.
%         Values on either side then equal those obtained with the other
%         side erased, bit for bit, and the epochs in between are NaN
%         (layer alignGap).
%       - Nothing is extrapolated.
%       - Units are checked (CONCEPT 5.2): mismatch, unstated unit and
%         column count all refuse, while "m/s^2" and "m/s2" match. Each
%         refusal fires on its broken input, and the healthy spelling
%         variant stays silent (fault injection).
%     Precision: pchip at 5 s evaluated at 1 s errs by 3.8e-6 of the
%     amplitude on a 1/rev plus 2/rev signal (measured with a NumPy
%     transcription, 2026-09-23); 1e-5 is required.
%
%   COVERAGE
%     contract       - result on obs.t with the reference's names and units,
%                      provenance "align" then the alignGap layer.
%     reference      - coinciding epochs bitwise; equals interp1 on the whole
%                      reference, bitwise, when nothing is missing.
%     precision      - pchip interpolation error below 1e-5 of the amplitude.
%     robustness     - NaN, removed sample and wide spacing each end a
%                      stretch; no extrapolation; unit mismatch, unstated
%                      unit and column count refused; spelling variants
%                      accepted.
%     metamorphic    - a common time shift and a scale by 2 change nothing
%                      but the scale, bitwise.
%     vectorisation  - three columns equal three single-column calls,
%                      bitwise.
%     speed          - one day, 3 columns, 1 Hz from 5 s with 102 holes, in
%                      under 2 s (v3 WP-11 budget for one day).
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.2 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function resultOnObservationEpochs(testCase)
            obs = arcOf(zeros(121, 1), "ACT1B", 0:120);
            ref = arcOf(sin((0:5:120)' / 30), "MOD1B", 0:5:120);
            out = timeSeriesPreparation.align(obs, ref);
            testCase.verifyEqual(out.t, obs.t);
            testCase.verifyEqual([out.names out.units out.product], ...
                [ref.names ref.units "MOD1B"]);
            testCase.verifyEqual([out.provenance(end - 1:end).stage], ["align" "addLayer"]);
            testCase.verifyEqual(out.provenance(end - 1).detail.method, "pchip");
            testCase.verifyEqual(out.provenance(end - 1).detail.maxGap, 7.5);
            testCase.verifyEqual(out.layers.alignGap, false(121, 1));
            testCase.verifyEqual(out.provenance(end - 1).detail.exact, 25);
        end
    end

    methods (Test, TestTags = {'reference'})
        function coincidingEpochsBitwise(testCase)
            x = randn(RandStream("twister", "Seed", 1), 600, 3);
            obs = arcOf(zeros(300, 3), "ACT1B", 100:399);
            ref = arcOf(x, "MOD1B", 0:599);
            out = timeSeriesPreparation.align(obs, ref);
            testCase.verifyTrue(isequal(out.obs, x(101:400, :)));
        end

        function equalsInterp1WithoutHoles(testCase)
            tr = 0:5:3600;
            y = [sin(tr' / 300) cos(tr' / 70)];
            obs = arcOf(zeros(3600, 2), "ACT1B", 0.5 + (0:3599));
            ref = arcOf(y, "MOD1B", tr);
            x = double(ref.t - ref.t(1)) * 1e-9;
            xq = double(obs.t - ref.t(1)) * 1e-9;
            for m = ["pchip" "linear" "makima" "spline"]
                out = timeSeriesPreparation.align(obs, ref, Method = m);
                want = [interp1(x, y(:, 1), xq, m) interp1(x, y(:, 2), xq, m)];
                inside = xq < x(end);
                testCase.verifyTrue(isequal(out.obs(inside, :), want(inside, :)), m);
                testCase.verifyTrue(all(isnan(out.obs(~inside, :)), "all"), m);
            end
        end
    end

    methods (Test, TestTags = {'precision'})
        function pchipErrorBelowBound(testCase)
            T = 5640;
            f = @(t) sin(2 * pi * t / T) + 0.5 * cos(4 * pi * t / T + 0.3);
            tr = 0:5:86400;
            to = 0.5 + (0:86399);
            out = timeSeriesPreparation.align(arcOf(zeros(numel(to), 1), "ACT1B", to), ...
                arcOf(f(tr'), "MOD1B", tr));
            err = max(abs(out.obs - f(to')));
            testCase.verifyLessThan(err, 1e-5, sprintf("pchip error %.3g", err));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function nanEndsAStretch(testCase)
            [obs, ref, y] = holeCase();
            y(41, :) = NaN;                                 % ref epoch 200 s
            out = timeSeriesPreparation.align(obs, withObs(ref, y));
            verifyHole(testCase, out, obs, ref, y, 195, 205);
        end

        function removedSampleEqualsNaN(testCase)
            [obs, ref, y] = holeCase();
            removed = addLayer(ref, "user", (1:numel(ref.t))' == 41);
            yNaN = y; yNaN(41, :) = NaN;
            testCase.verifyTrue(isequaln( ...
                timeSeriesPreparation.align(obs, removed).obs, ...
                timeSeriesPreparation.align(obs, withObs(ref, yNaN)).obs));
        end

        function wideSpacingEndsAStretch(testCase)
            tr = [0:5:195, 230:5:400];                      % 35 s missing
            y = sin(tr' / 40);
            obs = arcOf(zeros(401, 1), "ACT1B", 0:400);
            out = timeSeriesPreparation.align(obs, arcOf(y, "MOD1B", tr));
            rel = obs.t - T0;
            hole = rel > int64(195e9) & rel < int64(230e9);
            testCase.verifyTrue(all(isnan(out.obs(hole))));
            testCase.verifyEqual(out.layers.alignGap, hole);
            wide = timeSeriesPreparation.align(obs, arcOf(y, "MOD1B", tr), MaxGap = 40);
            testCase.verifyTrue(all(isfinite(wide.obs)));
        end

        function noExtrapolation(testCase)
            obs = arcOf(zeros(200, 1), "ACT1B", -50:149);
            out = timeSeriesPreparation.align(obs, arcOf(sin((0:5:100)' / 9), "MOD1B", 0:5:100));
            rel = obs.t - T0;
            outside = rel < 0 | rel > int64(100e9);
            testCase.verifyEqual(isnan(out.obs), outside);
        end

        function unitMismatchRefused(testCase)
            obs = arcOf(zeros(10, 1), "ACT1B", 0:9);
            ref = arcOf(zeros(10, 1), "MOD1B", 0:9, "m/s");
            testCase.verifyError(@() timeSeriesPreparation.align(obs, ref), ...
                "timeSeriesPreparation:align:unitMismatch");
        end

        function unstatedUnitRefused(testCase)
            obs = arcOf(zeros(10, 1), "ACT1B", 0:9);
            ref = arcOf(zeros(10, 1), "MOD1B", 0:9, "");
            testCase.verifyError(@() timeSeriesPreparation.align(obs, ref), ...
                "timeSeriesPreparation:align:unitUnknown");
            testCase.verifyError(@() timeSeriesPreparation.align(ref, obs), ...
                "timeSeriesPreparation:align:unitUnknown");
        end

        function columnCountRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.align( ...
                arcOf(zeros(10, 2), "ACT1B", 0:9), arcOf(zeros(10, 1), "MOD1B", 0:9)), ...
                "timeSeriesPreparation:align:columnMismatch");
        end

        function unitSpellingVariantsAccepted(testCase)
            obs = arcOf(ones(10, 1), "ACT1B", 0:9, "m/s^2");
            ref = arcOf(ones(10, 1), "MOD1B", 0:9, "m / s2");
            out = testCase.verifyWarningFree(@() timeSeriesPreparation.align(obs, ref));
            testCase.verifyEqual(out.obs, ones(10, 1));
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function commonTimeShiftChangesNothing(testCase)
            to = 0.5 + (0:999);
            tr = [0:5:400, 420:5:1000];
            y = [sin(tr' / 50) cos(tr' / 13)];
            a = timeSeriesPreparation.align(arcOf(zeros(1000, 2), "ACT1B", to), arcOf(y, "MOD1B", tr));
            b = timeSeriesPreparation.align(arcOf(zeros(1000, 2), "ACT1B", to + 86400), ...
                arcOf(y, "MOD1B", tr + 86400));
            testCase.verifyTrue(isequaln(a.obs, b.obs));
        end

        function scaleByTwoScalesResult(testCase)
            to = 0.5 + (0:999);
            tr = 0:5:1000;
            y = sin(tr' / 50) + 0.2 * cos(tr' / 9);
            obs = arcOf(zeros(1000, 1), "ACT1B", to);
            a = timeSeriesPreparation.align(obs, arcOf(y, "MOD1B", tr));
            b = timeSeriesPreparation.align(obs, arcOf(2 * y, "MOD1B", tr));
            testCase.verifyTrue(isequaln(2 * a.obs, b.obs));
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function columnsEqualSingleColumns(testCase)
            to = 0.5 + (0:1999);
            tr = [0:5:700, 740:5:2000];
            y = randn(RandStream("twister", "Seed", 3), numel(tr), 3);
            obs3 = arcOf(zeros(2000, 3), "ACT1B", to);
            whole = timeSeriesPreparation.align(obs3, arcOf(y, "MOD1B", tr));
            for j = 1:3
                one = timeSeriesPreparation.align(arcOf(zeros(2000, 1), "ACT1B", to), ...
                    arcOf(y(:, j), "MOD1B", tr));
                testCase.verifyTrue(isequaln(whole.obs(:, j), one.obs), sprintf("column %d", j));
            end
        end
    end

    methods (Test, TestTags = {'speed'})
        function oneDayUnderTwoSeconds(testCase)
            % Absolute budget from v3 WP-11 (one day < 2 s); the median of
            % three runs, after one warm-up.
            tr = 0:5:86400;
            keep = true(size(tr));
            keep(100:170:end) = false;                       % 102 holes
            tr = tr(keep);
            y = randn(RandStream("twister", "Seed", 4), numel(tr), 3);
            obs = arcOf(zeros(86400, 3), "ACT1B", 0.5 + (0:86399));
            ref = arcOf(y, "MOD1B", tr);
            f = @() timeSeriesPreparation.align(obs, ref);
            f();
            s = median(arrayfun(@(r) timed(f), 1:3));
            testCase.verifyLessThan(s, 2, sprintf("align one day: %.3f s", s));
        end
    end
end

% ------------------------------------------------------------------------

function t = T0()
% 2020-01-01 00:00:00 in GPS ns past 2000-01-01 12:00 (the tests' origin).
    t = int64(631152000) * int64(1e9);
end

function arc = arcOf(x, product, tsec, unit)
% An arc of PRODUCT with the columns of X at TSEC seconds past T0.
    if nargin < 4, unit = "m/s2"; end
    t = T0 + int64(round(tsec(:) * 1e9));
    names = "lin_accl_" + ["x" "y" "z"];
    names = cellstr(names(1:size(x, 2)));
    units = struct();
    for n = names, units.(n{1}) = unit; end
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", product + "_2020-01-01_C_04.txt", "product", product);
    arc = timeSeriesPreparation.Arc(t, x, aux);
end

function arc = withObs(arc, y)
% The same arc with new values (via derive, so metadata stay).
    arc = arc.derive(arc.t, y, "test");
end

function [obs, ref, y] = holeCase()
% 1 Hz observation over 400 s, 5 s reference of two columns.
    tr = 0:5:400;
    y = [sin(tr' / 40) cos(tr' / 25)];
    obs = arcOf(zeros(400, 2), "ACT1B", 0.5 + (0:399));
    ref = arcOf(y, "MOD1B", tr);
end

function verifyHole(testCase, out, obs, ref, y, lo, hi)
% Epochs in (LO, HI) s are NaN; each side equals the result with every
% sample of the other side erased (same epochs, so the same time origin).
    ts = double(obs.t - ref.t(1)) / 1e9;           % exact for whole ns
    hole = ts > lo & ts < hi;
    testCase.verifyTrue(all(isnan(out.obs(hole, :)), "all"));
    testCase.verifyEqual(out.layers.alignGap, hole);
    tr = double(ref.t - ref.t(1)) / 1e9;
    yl = y; yl(tr > lo, :) = NaN;
    yr = y; yr(tr < hi, :) = NaN;
    a = timeSeriesPreparation.align(obs, withObs(ref, yl));
    b = timeSeriesPreparation.align(obs, withObs(ref, yr));
    testCase.verifyTrue(isequal(out.obs(ts < lo, :), a.obs(ts < lo, :)), "left side");
    testCase.verifyTrue(isequal(out.obs(ts > hi, :), b.obs(ts > hi, :)), "right side");
end

function s = timed(f)
    tic; f(); s = toc;
end
