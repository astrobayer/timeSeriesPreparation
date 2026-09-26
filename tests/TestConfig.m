classdef TestConfig < matlab.unittest.TestCase
%TESTCONFIG  timeSeriesPreparation.Config: sections, strict fields, product, crn preset.
%
%   DESCRIPTION
%     The nine sections of CONCEPT 5 exist and each has fields: crn holds
%     preset (X-04), align its four options (X-06), fill its three (X-08),
%     unc its five (X-07), drivers its four (X-09), mask its five (X-05),
%     qc its eight, noise its five and run its three (X-10, X-14).
%     Config(arc) records mission and product and takes the crn preset and
%     the minimum-data gate from the product. set refuses an unknown section or field;
%     fault injection of the refusal is the refusal itself: a misspelt
%     section and a field no schema lists must both fire.
%
%   COVERAGE
%     contract       - the nine sections, each with fields; qc's, noise's
%                      and run's defaults (qc.screen's and noise's own; order
%                      and filterReference [], seed 0, cacheDir "") and setting them; mask's defaults and its presets
%                      (ACT1B bits 5-7; KBR1B, LRI1B bits 0, 6, 7 and
%                      snrFraction 0.5; others none); drivers' defaults ("pchip", [], [], 10); align's defaults (pchip, [], 60 s, 1 s) and
%                      setting them; fill's defaults ("none", [], []) and
%                      setting them; unc's defaults ([], [], 1000, 0.6827, 5) and
%                      the gate 0.5 for ACC1B, ACT1B, KBR1B and LRI1B only;
%                      mission, product and crn.preset taken from the arc
%                      (ACC1B/ACT1B ACC, KBR1B KBR, others ""); crn.preset
%                      settable; toStruct carries all of them.
%     robustness     - unknown section and unknown field are refused, also
%                      a misspelt align field and a misspelt qc field.
%     precision, reference, speed, vectorisation, metamorphic - exempt: Config
%                      stores settings and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-25 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function nineSectionsAllDefined(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.Sections, ...
                ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]);
            for sec = cfg.Sections
                testCase.verifyNotEmpty(fieldnames(cfg.(sec)), sec);
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

        function fillDefaultsAndSet(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.fill, struct("method", "none", "maxGap", [], "window", []));
            cfg = set(set(cfg, "fill", "method", "collocation"), "fill", "maxGap", 10);
            testCase.verifyEqual([cfg.fill.method string(cfg.fill.maxGap)], ["collocation" "10"]);
        end

        function driversDefaultsAndSet(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.drivers, struct("method", "pchip", "maxGap", [], "maxLag", [], "maxVif", 10));
            cfg = set(set(cfg, "drivers", "maxLag", 5400), "drivers", "maxVif", 5);
            testCase.verifyEqual([cfg.drivers.maxLag cfg.drivers.maxVif], [5400 5]);
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

        function maskDefaultsAndPresets(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.mask, struct("removeBits", zeros(1, 0), "snrFraction", [], ...
                "thrMargin", [], "eclipseMargin", [], "crnEdge", false));
            t = int64(0:4)' * int64(1e9);
            cases = {"ACT1B_2020-01-01_D_04.txt", "ACT1B", [5 6 7], []
                     "KBR1B_2020-01-01_Y_04.txt", "KBR1B", [0 6 7], 0.5
                     "LRI1B_2020-01-01_Y_04.txt", "LRI1B", [0 6 7], 0.5
                     "MAS1B_2020-01-01_C_04.txt", "MAS1B", zeros(1, 0), []};
            for k = 1:size(cases, 1)
                aux = struct("obsNames", {{'x'}}, "variableNames", {{'x'}}, ...
                    "variableFieldNames", {{'x'}}, "variableUnits", struct(), ...
                    "fileName", cases{k, 1}, "product", cases{k, 2});
                cfg = timeSeriesPreparation.Config(timeSeriesPreparation.Arc(t, zeros(5, 1), aux));
                testCase.verifyEqual(cfg.mask.removeBits, cases{k, 3}, cases{k, 2});
                testCase.verifyEqual(cfg.mask.snrFraction, cases{k, 4}, cases{k, 2});
            end
            cfg = set(cfg, "mask", "thrMargin", 10);
            testCase.verifyEqual(cfg.mask.thrMargin, 10);
        end

        function qcNoiseRunDefaultsAndSet(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.qc, struct("whitening", "none", "window", [], ...
                "hampelWindow", 61, "hampelThreshold", 4, "impulseThreshold", 5, ...
                "jumpModel", "level", "jumpPenalty", [], "jumpMinSegment", 30));
            testCase.verifyEqual(cfg.noise, struct("order", [], "method", "exact", ...
                "maxLag", 100, "lags", 20, "welchAverages", 32));
            testCase.verifyEqual(cfg.run, struct("filterReference", [], "seed", 0, "cacheDir", ""));
            cfg = set(set(set(cfg, "qc", "hampelWindow", 31), "noise", "order", [2 0]), ...
                "run", "filterReference", true);
            testCase.verifyEqual([cfg.qc.hampelWindow cfg.noise.order], [31 2 0]);
            testCase.verifyTrue(cfg.run.filterReference);
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
