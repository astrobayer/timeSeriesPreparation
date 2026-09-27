classdef TestDrivers < matlab.unittest.TestCase
%TESTDRIVERS  drivers: supplied series onto arc epochs by align's rule; names and units checked.
%
%   DESCRIPTION
%     drivers applies internal.resampleOnto, the rule of align, per driver.
%     The reference is align itself: a driver stating the arc's unit must
%     come out bit for bit as align's result. Linear interpolation of a
%     linear driver is exact to rounding (a few eps of values near 30), so
%     1e-12. pchip is homogeneous of degree 1 for a positive factor (its
%     slopes are harmonic means), so scaling a driver scales the result to
%     rounding. The refusals are fault-injected by their own triggers.
%
%   COVERAGE
%     reference      - equals align on a same-unit driver, bitwise.
%     precision      - "linear" reproduces a linear driver to 1e-12.
%     contract       - fields and sizes; coinciding epochs taken bitwise;
%                      a hole and the ends are not bridged, gap marks them.
%     metamorphic    - scaling a driver by c > 0 scales its values.
%     vectorisation  - K drivers in one call equal K one-driver calls.
%     robustness     - badSeries, duplicateName and unitUnknown fire.
%     speed          - exempt: one interp1 per driver and stretch.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-24 10:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function equalsAlign(testCase)
            arc = makeArc(int64(0:599)' * int64(1e9), "ACT1B");
            tr = int64(0:5:600)' * int64(1e9);
            v = sin(double(tr) * 1e-9 / 100) + 0.3 * cos(double(tr) * 1e-9 / 37);
            v(40) = NaN;
            ref = timeSeriesPreparation.Arc(tr, v, auxOf("MOD1B"));
            expected = timeSeriesPreparation.align(arc, ref);
            drv = timeSeriesPreparation.drivers(arc, driver("x", tr, v, "m/s2"));
            testCase.verifyEqual(drv.values, expected.obs);
        end
    end

    methods (Test, TestTags = {'precision'})
        function linearIsExactOnALine(testCase)
            arc = makeArc(int64(0:599)' * int64(1e9), "ACT1B");
            tb = int64(0:60:600)';
            drv = timeSeriesPreparation.drivers(arc, driver("betaPrime", tb * int64(1e9), ...
                30 + double(tb) / 600, "deg"), Method = "linear");
            testCase.verifyEqual(drv.values, 30 + (0:599)' / 600, "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'contract'})
        function fieldsAndCoincidingEpochs(testCase)
            t = int64(0:99)' * int64(1e9);
            arc = makeArc(t, "ACT1B");
            v = randn(RandStream("twister", "Seed", 61), 100, 1);
            drv = timeSeriesPreparation.drivers(arc, [driver("a", t, v, "1"), ...
                driver("b", t(1:2:end), v(1:2:end), "K")]);
            testCase.verifyEqual(drv.t, t);
            testCase.verifyEqual(drv.names, ["a" "b"]);
            testCase.verifyEqual(drv.units, ["1" "K"]);
            testCase.verifySize(drv.values, [100 2]);
            testCase.verifyEqual(drv.values(:, 1), v);
            testCase.verifyEqual(drv.values(1:2:end, 2), v(1:2:end));
            testCase.verifyEqual(drv.method, "pchip");
            testCase.verifyEqual(drv.maxGap, [1.5 3]);
            testCase.verifyEqual(drv.gap, isnan(drv.values));
        end

        function holesAndEndsNotBridged(testCase)
            arc = makeArc(int64(0:99)' * int64(1e9), "ACT1B");
            tb = int64(10:5:80)' * int64(1e9);
            v = (1:numel(tb))';
            v(8) = NaN;                                 % the sample at 45 s
            drv = timeSeriesPreparation.drivers(arc, driver("d", tb, v, "1"));
            covered = false(100, 1);
            covered(11:41) = true;                      % 10 .. 40 s
            covered(51:81) = true;                      % 50 .. 80 s
            testCase.verifyEqual(drv.gap, ~covered);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function scalingScalesValues(testCase)
            arc = makeArc(int64(0:299)' * int64(1e9), "ACT1B");
            tb = int64(0:7:300)' * int64(1e9);
            v = 2 + sin(double(tb) * 1e-9 / 20);
            a = timeSeriesPreparation.drivers(arc, driver("d", tb, v, "1"));
            b = timeSeriesPreparation.drivers(arc, driver("d", tb, 3.7 * v, "1"));
            testCase.verifyEqual(nanToZero(b.values), 3.7 * nanToZero(a.values), "RelTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function manyEqualOneEach(testCase)
            arc = makeArc(int64(0:199)' * int64(1e9), "ACT1B");
            rs = RandStream("twister", "Seed", 62);
            s = [driver("a", int64(0:3:199)' * int64(1e9), randn(rs, 67, 1), "1"), ...
                 driver("b", int64(1:4:199)' * int64(1e9), randn(rs, 50, 1), "K")];
            s(2).value(10) = NaN;
            both = timeSeriesPreparation.drivers(arc, s);
            one = timeSeriesPreparation.drivers(arc, s(1));
            two = timeSeriesPreparation.drivers(arc, s(2));
            testCase.verifyEqual(nanToZero(both.values), nanToZero([one.values two.values]));
            testCase.verifyEqual(both.gap, [one.gap two.gap]);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            arc = makeArc(int64(0:9)' * int64(1e9), "ACT1B");
            t = int64(0:9)' * int64(1e9);
            ok = driver("d", t, zeros(10, 1), "1");
            f = @(s) timeSeriesPreparation.drivers(arc, s);
            testCase.verifyError(@() f(rmfield(ok, "unit")), "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f(driver("d", double(t), zeros(10, 1), "1")), ...
                "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f(driver("d", flipud(t), zeros(10, 1), "1")), ...
                "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f(driver("d", t, zeros(9, 1), "1")), ...
                "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f(driver("d", t, [Inf; zeros(9, 1)], "1")), ...
                "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f(driver("1d", t, zeros(10, 1), "1")), ...
                "timeSeriesPreparation:drivers:badSeries");
            testCase.verifyError(@() f([ok ok]), "timeSeriesPreparation:drivers:duplicateName");
            testCase.verifyError(@() f(driver("d", t, zeros(10, 1), "")), ...
                "timeSeriesPreparation:drivers:unitUnknown");
            testCase.verifyError(@() f(driver("d", t, zeros(10, 1), " ")), ...
                "timeSeriesPreparation:drivers:unitUnknown");
        end
    end
end

% ------------------------------------------------------------------------

function s = driver(name, t, value, unit)
% One element of drivers' series argument.
    s = struct("name", string(name), "t", t, "value", value, "unit", string(unit));
end

function y = nanToZero(x)
% X with NaN replaced by 0, so arrays with NaN compare by value.
    y = x;
    y(isnan(y)) = 0;
end

function arc = makeArc(t, product)
% A one-column arc of zeros in m/s2 on epochs t.
    arc = timeSeriesPreparation.Arc(t, zeros(numel(t), 1), auxOf(product));
end

function aux = auxOf(product)
% readL1b-shaped metadata for one column lin_accl_x in m/s2.
    aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, ...
        "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), ...
        "fileName", product + "_2020-01-01_C_04.txt", "product", product);
end
