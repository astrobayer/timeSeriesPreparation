classdef TestNoiseReference < matlab.unittest.TestCase
%TESTNOISEREFERENCE  noiseReference: the printed ASD formulas at their corner frequencies.
%
%   DESCRIPTION
%     Each formula is pinned where its printed constants give a closed
%     form, so a mistyped constant fails: at f equal to a corner the
%     factor sqrt(1 + (fc/f)^k) is sqrt(2). The expected values are
%     written from the page, not from the implementation:
%       LRI (Abich et al. 2019, p. 4): 80 nm sqrt(1+(3 mHz/f)^2)
%         sqrt(1+(10 mHz/f)^2); at 3 mHz 80 nm sqrt(2) sqrt(1+(10/3)^2).
%       KBR (Darbeheshti et al. 2017, Eq. 15): at 1.8 mHz sqrt(2) um.
%       LRI-laser (Eq. 21): at 18.2 mHz 5 nm sqrt(2).
%       ACC (Eq. 9): x and z at 5 mHz 1e-10 sqrt(2); y at 0.1 Hz 1e-9
%         sqrt(2).
%     Each is a handful of operations, so 1e-15 relative bounds the
%     rounding. The slopes are checked far from the corners: f^-2 for LRI
%     and KBR, f^-1 for LRI-laser, f^-1/2 for ACC.
%
%   COVERAGE
%     reference      - every model at its corner frequencies and at its
%                      white level.
%     precision      - low-frequency slopes of every model.
%     metamorphic    - Derivative n multiplies by (2 pi f)^n.
%     contract       - shape of asd follows f; info fields, units, band
%                      and inBand.
%     vectorisation  - a vector of frequencies equals the scalar calls.
%     robustness     - an unknown model, ACC without Axis, Axis on a
%                      ranging model and f <= 0 are refused.
%     speed          - exempt: closed-form evaluation.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 22:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function lriRequirementAtCorners(testCase)
            nr = @(f) timeSeriesPreparation.noiseReference("LRI", f);
            testCase.verifyEqual(nr(3e-3), 80e-9 * sqrt(2) * sqrt(1 + (10/3)^2), "RelTol", 1e-15);
            testCase.verifyEqual(nr(10e-3), 80e-9 * sqrt(1 + 0.3^2) * sqrt(2), "RelTol", 1e-15);
            testCase.verifyEqual(nr(1e3), 80e-9, "RelTol", 1e-10);
        end

        function kbrAtCorner(testCase)
            testCase.verifyEqual(timeSeriesPreparation.noiseReference("KBR", 1.8e-3), sqrt(2) * 1e-6, "RelTol", 1e-15);
            testCase.verifyEqual(timeSeriesPreparation.noiseReference("KBR", 1), 1e-6, "RelTol", 1e-10);
        end

        function lriLaserAtCorner(testCase)
            testCase.verifyEqual(timeSeriesPreparation.noiseReference("LRI-laser", 0.0182), sqrt(2) * 5e-9, "RelTol", 1e-15);
        end

        function accAtCorners(testCase)
            nr = @(f, ax) timeSeriesPreparation.noiseReference("ACC", f, Axis = ax);
            testCase.verifyEqual(nr(0.005, "x"), sqrt(2) * 1e-10, "RelTol", 1e-15);
            testCase.verifyEqual(nr(0.005, "z"), sqrt(2) * 1e-10, "RelTol", 1e-15);
            testCase.verifyEqual(nr(0.1, "y"), sqrt(2) * 1e-9, "RelTol", 1e-15);
        end
    end

    methods (Test, TestTags = {'precision'})
        function lowFrequencySlopes(testCase)
            f = [1e-6 2e-6];
            slope = @(a) log(a(2) / a(1)) / log(2);
            testCase.verifyEqual(slope(timeSeriesPreparation.noiseReference("LRI", f)), -2, "AbsTol", 1e-4);
            testCase.verifyEqual(slope(timeSeriesPreparation.noiseReference("KBR", f)), -2, "AbsTol", 1e-4);
            testCase.verifyEqual(slope(timeSeriesPreparation.noiseReference("LRI-laser", f)), -1, "AbsTol", 1e-4);
            testCase.verifyEqual(slope(timeSeriesPreparation.noiseReference("ACC", f, Axis = "x")), -0.5, "AbsTol", 1e-3);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function derivativeMultipliesByTwoPiF(testCase)
            f = logspace(-4, -1, 7)';
            [r, i0] = timeSeriesPreparation.noiseReference("KBR", f);
            [v, i1] = timeSeriesPreparation.noiseReference("KBR", f, Derivative = 1);
            [a, i2] = timeSeriesPreparation.noiseReference("KBR", f, Derivative = 2);
            testCase.verifyEqual(v, r .* (2 * pi * f), "RelTol", 1e-15);
            testCase.verifyEqual(a, r .* (2 * pi * f).^2, "RelTol", 1e-15);
            testCase.verifyEqual([i0.unit i1.unit i2.unit], ["m/sqrt(Hz)" "m/s/sqrt(Hz)" "m/s^2/sqrt(Hz)"]);
            testCase.verifyEqual([i0.quantity i1.quantity i2.quantity], ["range" "range rate" "range acceleration"]);
        end
    end

    methods (Test, TestTags = {'contract'})
        function shapeAndInfo(testCase)
            f = [1e-6 1e-3; 0.05 0.5];
            [asd, info] = timeSeriesPreparation.noiseReference("LRI", f);
            testCase.verifySize(asd, [2 2]);
            testCase.verifyEqual(info.band, [2e-3 100e-3]);
            testCase.verifyEqual(info.inBand, [false false; true false]);
            testCase.verifyEqual(info.status, "requirement");
            testCase.verifyEqual(info.unit, "m/sqrt(Hz)");
            testCase.verifyTrue(contains(info.source, "Abich"));
            [~, acc] = timeSeriesPreparation.noiseReference("ACC", 1e-3, Axis = "y");
            testCase.verifyEqual([acc.axis acc.status acc.unit], ["y" "simulation model" "m/s^2/sqrt(Hz)"]);
            testCase.verifyTrue(contains(acc.source, "Eq. 9"));
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function vectorEqualsScalars(testCase)
            f = logspace(-5, 0, 11);
            for m = ["LRI" "LRI-laser" "KBR"]
                v = timeSeriesPreparation.noiseReference(m, f);
                s = arrayfun(@(x) timeSeriesPreparation.noiseReference(m, x), f);
                testCase.verifyEqual(v, s, m);
            end
        end
    end

    methods (Test, TestTags = {'robustness'})
        function invalidInputsRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.noiseReference("MWI", 1e-3), ...
                "timeSeriesPreparation:noiseReference:unknownModel");
            testCase.verifyError(@() timeSeriesPreparation.noiseReference("ACC", 1e-3), ...
                "timeSeriesPreparation:noiseReference:axis");
            testCase.verifyError(@() timeSeriesPreparation.noiseReference("ACC", 1e-3, Axis = "w"), ...
                "timeSeriesPreparation:noiseReference:axis");
            testCase.verifyError(@() timeSeriesPreparation.noiseReference("KBR", 1e-3, Axis = "x"), ...
                "timeSeriesPreparation:noiseReference:axis");
            testCase.verifyError(@() timeSeriesPreparation.noiseReference("KBR", 0), ...
                "MATLAB:validators:mustBePositive");
        end
    end
end
