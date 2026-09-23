classdef TestConfig < matlab.unittest.TestCase
%TESTCONFIG  timeSeriesPreparation.Config: sections, strict fields, product, crn preset.
%
%   DESCRIPTION
%     The nine sections of CONCEPT 5 exist; crn holds preset (X-04), the
%     rest are empty. Config(arc) records mission and product and takes the
%     crn preset from the product. set refuses an unknown section or field;
%     fault injection of the refusal is the refusal itself: a misspelt
%     section and a field no schema lists must both fire.
%
%   COVERAGE
%     contract       - the nine sections, empty but crn.preset; mission,
%                      product and crn.preset taken from the arc (ACC1B/ACT1B
%                      ACC, KBR1B KBR, others ""); crn.preset settable;
%                      toStruct carries all of them.
%     robustness     - unknown section and unknown field are refused.
%     precision, reference, speed, vectorisation, metamorphic - exempt: Config
%                      stores settings and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function nineEmptySections(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.Sections, ...
                ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]);
            for sec = setdiff(cfg.Sections, "crn", "stable")
                testCase.verifyEqual(cfg.(sec), struct(), sec);
            end
            testCase.verifyEqual(cfg.crn, struct("preset", ""));
            testCase.verifyEqual([cfg.mission cfg.product], ["" ""]);
        end

        function productFromArc(testCase)
            t = int64(0:4)' * int64(1e9);
            aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, ...
                "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct(), ...
                "fileName", "ACT1B_2020-01-01_D_04.txt", "product", "ACT1B");
            cfg = timeSeriesPreparation.Config(timeSeriesPreparation.Arc(t, zeros(5, 1), aux));
            testCase.verifyEqual([cfg.mission cfg.product], ["GRACE-FO" "ACT1B"]);
            testCase.verifyEqual(cfg.crn.preset, "ACC");
        end

        function crnPresetPerProduct(testCase)
            t = int64(0:4)' * int64(1e9);
            for c = ["ACC1B_2008-01-01_A_02.dat" "ACC1B" "ACC"
                     "KBR1B_2020-01-01_Y_04.txt" "KBR1B" "KBR"
                     "MAS1B_2020-01-01_C_04.txt" "MAS1B" ""]'
                aux = struct("obsNames", {{'x'}}, "variableNames", {{'x'}}, ...
                    "variableFieldNames", {{'x'}}, "variableUnits", struct(), ...
                    "fileName", c(1), "product", c(2));
                cfg = timeSeriesPreparation.Config(timeSeriesPreparation.Arc(t, zeros(5, 1), aux));
                testCase.verifyEqual(cfg.crn.preset, c(3), c(2));
            end
        end

        function crnPresetCanBeSet(testCase)
            cfg = set(timeSeriesPreparation.Config(), "crn", "preset", "KBR");
            testCase.verifyEqual(cfg.crn.preset, "KBR");
        end

        function toStructCarriesEverything(testCase)
            s = toStruct(timeSeriesPreparation.Config());
            testCase.verifyEqual(string(fieldnames(s))', ...
                ["mission" "product" "mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function unknownSectionRefused(testCase)
            testCase.verifyError(@() set(timeSeriesPreparation.Config(), "qcc", "window", 5), ...
                "timeSeriesPreparation:Config:unknownSection");
        end

        function unknownFieldRefused(testCase)
            testCase.verifyError(@() set(timeSeriesPreparation.Config(), "qc", "windw", 5), ...
                "timeSeriesPreparation:Config:unknownField");
        end
    end
end
