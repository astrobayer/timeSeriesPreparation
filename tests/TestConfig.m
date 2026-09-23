classdef TestConfig < matlab.unittest.TestCase
%TESTCONFIG  timeSeriesPreparation.Config: sections, strict fields, product, crn preset.
%
%   DESCRIPTION
%     The nine sections of CONCEPT 5 exist; crn holds preset (X-04), align
%     its four options (X-06), unc its five (X-07), the rest are empty.
%     Config(arc) records mission and product and takes the crn preset and
%     the minimum-data gate from the product. set refuses an unknown section or field;
%     fault injection of the refusal is the refusal itself: a misspelt
%     section and a field no schema lists must both fire.
%
%   COVERAGE
%     contract       - the nine sections, empty but crn, align and unc;
%                      align's defaults (pchip, [], 60 s, 1 s) and setting
%                      them; unc's defaults ([], [], 1000, 0.6827, 5) and
%                      the gate 0.5 for ACC1B, ACT1B, KBR1B and LRI1B only;
%                      mission, product and crn.preset taken from the arc
%                      (ACC1B/ACT1B ACC, KBR1B KBR, others ""); crn.preset
%                      settable; toStruct carries all of them.
%     robustness     - unknown section and unknown field are refused, also
%                      a misspelt align field.
%     precision, reference, speed, vectorisation, metamorphic - exempt: Config
%                      stores settings and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function nineSectionsSomeEmpty(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.Sections, ...
                ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]);
            for sec = setdiff(cfg.Sections, ["crn" "align" "unc"], "stable")
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

        function alignDefaultsAndSet(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.align, struct("method", "pchip", ...
                "maxGap", [], "maxLag", 60, "threshold", 1));
            cfg = set(set(cfg, "align", "maxLag", 30), "align", "maxGap", 15);
            testCase.verifyEqual([cfg.align.maxLag cfg.align.maxGap], [30 15]);
        end

        function uncDefaultsAndGatePreset(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.unc, struct("minWeightFraction", [], ...
                "blockLength", [], "nBoot", 1000, "level", 0.6827, "folds", 5));
            t = int64(0:4)' * int64(1e9);
            for c = ["ACC1B_2008-01-01_A_02.dat" "ACC1B" "0.5"
                     "ACT1B_2020-01-01_D_04.txt" "ACT1B" "0.5"
                     "KBR1B_2020-01-01_Y_04.txt" "KBR1B" "0.5"
                     "LRI1B_2020-01-01_Y_04.txt" "LRI1B" "0.5"
                     "MAS1B_2020-01-01_C_04.txt" "MAS1B" ""]'
                aux = struct("obsNames", {{'x'}}, "variableNames", {{'x'}}, ...
                    "variableFieldNames", {{'x'}}, "variableUnits", struct(), ...
                    "fileName", c(1), "product", c(2));
                cfg = timeSeriesPreparation.Config(timeSeriesPreparation.Arc(t, zeros(5, 1), aux));
                expected = [];
                if c(3) ~= ""
                    expected = str2double(c(3));
                end
                testCase.verifyEqual(cfg.unc.minWeightFraction, expected, c(2));
            end
            cfg = set(cfg, "unc", "minWeightFraction", 0.7);
            testCase.verifyEqual(cfg.unc.minWeightFraction, 0.7);
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

        function misspeltAlignFieldRefused(testCase)
            testCase.verifyError(@() set(timeSeriesPreparation.Config(), "align", "maxlag", 30), ...
                "timeSeriesPreparation:Config:unknownField");
        end

        function unknownFieldRefused(testCase)
            testCase.verifyError(@() set(timeSeriesPreparation.Config(), "qc", "windw", 5), ...
                "timeSeriesPreparation:Config:unknownField");
        end
    end
end
