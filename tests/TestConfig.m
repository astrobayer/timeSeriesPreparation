classdef TestConfig < matlab.unittest.TestCase
%TESTCONFIG  timeSeriesPreparation.Config skeleton: sections, strict fields, product.
%
%   DESCRIPTION
%     The skeleton's promises: the nine sections of CONCEPT 5 exist and are
%     empty, Config(arc) records mission and product, and set refuses an
%     unknown section or field - which, with every schema still empty, means
%     every field. Fault injection of the refusal is the refusal itself: a
%     misspelt section and a field no schema lists must both fire.
%
%   COVERAGE
%     contract       - the nine sections, empty; mission and product taken
%                      from the arc; toStruct carries all of them.
%     robustness     - unknown section and unknown field are refused.
%     precision, reference, speed, vectorisation, metamorphic - exempt: the
%                      skeleton stores settings and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function nineEmptySections(testCase)
            cfg = timeSeriesPreparation.Config();
            testCase.verifyEqual(cfg.Sections, ...
                ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]);
            for sec = cfg.Sections
                testCase.verifyEqual(cfg.(sec), struct(), sec);
            end
            testCase.verifyEqual([cfg.mission cfg.product], ["" ""]);
        end

        function productFromArc(testCase)
            t = int64(0:4)' * int64(1e9);
            aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, ...
                "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct(), ...
                "fileName", "ACT1B_2020-01-01_D_04.txt", "product", "ACT1B");
            cfg = timeSeriesPreparation.Config(timeSeriesPreparation.Arc(t, zeros(5, 1), aux));
            testCase.verifyEqual([cfg.mission cfg.product], ["GRACE-FO" "ACT1B"]);
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
