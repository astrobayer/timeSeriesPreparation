classdef TestCrnKernel < matlab.unittest.TestCase
%TESTCRNKERNEL  crnKernel against ORC-1, the ATBD App. B page transcribed in NumPy.
%
%   DESCRIPTION
%     The taps and derivative kernels of both presets are pinned against
%     tests/oracles/crn_atbd_asprinted.json, written by an independent NumPy
%     transcription of the GRACE L1B ATBD App. B (R-1, PDF p. 40) that shares
%     no code with crnKernel (ORC-1). The DC gains are pinned against the
%     numbers CONCEPT 8 recorded when the page was first read (2026-09-19):
%     1 + 1.115e-7 (ACC) and 1 + 1.10e-11 (KBR); the misplaced exponent of v2
%     would give 1.0004533 and fail. Tolerances name the term they bound: each
%     tap is an Nf-term sum rounded differently in two programs, worst case
%     Nf*eps = 3.1e-13 of the largest tap, so 1e-12 of it.
%
%   COVERAGE
%     reference      - taps F, dF, ddF of ACC and KBR equal the oracle; DC
%                      gains equal the oracle and CONCEPT 8.
%     precision      - unit gain at f0; F and ddF even, dF odd, to a few eps.
%     metamorphic    - in the passband the derivative kernels respond as
%                      i*2*pi*f and (i*2*pi*f)^2 times the filter.
%     contract       - sizes and parameters of both presets; overrides are
%                      recorded; the preset name is case-insensitive.
%     robustness     - "LRI", an unknown preset, an even span, an even Nc and
%                      an empty passband are refused.
%     speed, vectorisation - exempt: the kernel is built once per preset and
%                      has no batched form; crnApply carries both.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-23 08:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Preset = {'ACC', 'KBR'}
    end

    properties (Access = private)
        Oracle
    end

    methods (TestClassSetup)
        function readOracle(testCase)
            file = fullfile(fileparts(mfilename("fullpath")), "oracles", "crn_atbd_asprinted.json");
            testCase.Oracle = jsondecode(fileread(file));
        end
    end

    methods (Test, TestTags = {'reference'})
        function tapsEqualOracle(testCase, Preset)
            k = timeSeriesPreparation.crnKernel(Preset);
            o = testCase.Oracle.(Preset);
            for f = ["F" "dF" "ddF"]
                ref = o.(f)(:);
                testCase.verifyEqual(k.(f), ref, "AbsTol", 1e-12 * max(abs(ref)), f);
            end
            testCase.verifyEqual(k.FNorm, o.FNorm, "RelTol", 1e-12);
        end

        function dcGainEqualsOracleAndConcept(testCase)
            acc = timeSeriesPreparation.crnKernel("ACC");
            kbr = timeSeriesPreparation.crnKernel("KBR");
            % Sum of Nf taps each within 1e-12 of max|F| of the oracle: at
            % worst Nf * 1e-12 * 7.8e-3 = 1.1e-11, far below the 1.1e-7 pinned.
            testCase.verifyEqual(acc.dcGain, testCase.Oracle.ACC.dcGain, "AbsTol", 2e-11);
            testCase.verifyEqual(kbr.dcGain, testCase.Oracle.KBR.dcGain, "AbsTol", 2e-11);
            testCase.verifyEqual(acc.dcGain - 1, 1.115e-7, "AbsTol", 1e-10);   % CONCEPT 8
            testCase.verifyEqual(kbr.dcGain - 1, 1.10e-11, "AbsTol", 1e-13);   % CONCEPT 8
        end
    end

    methods (Test, TestTags = {'precision'})
        function unitGainAtF0(testCase, Preset)
            k = timeSeriesPreparation.crnKernel(Preset);
            testCase.verifyEqual(k.gainAtF0, 1, "AbsTol", 1e-14);
        end

        function symmetryToRounding(testCase, Preset)
            % Mirrored rows of cos(A) are equal, but a BLAS may round them in
            % different lanes (NumPy: 5.8e-18 on max|F| = 7.8e-3), so the
            % bound is a few eps of the largest tap, not exact equality.
            k = timeSeriesPreparation.crnKernel(Preset);
            for f = ["F" "ddF"]
                testCase.verifyEqual(k.(f), flipud(k.(f)), "AbsTol", 64 * eps(max(abs(k.(f)))), f);
            end
            testCase.verifyEqual(k.dF, -flipud(k.dF), "AbsTol", 64 * eps(max(abs(k.dF))));
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function derivativesAreDerivatives(testCase, Preset)
            k = timeSeriesPreparation.crnKernel(Preset);
            t = k.lags / k.fs;
            for f = [1e-3 1e-2]
                e = exp(-2i * pi * f * t);
                G = sum(k.F .* e);
                testCase.verifyEqual(sum(k.dF .* e) / (2i * pi * f * G), 1, "AbsTol", 1e-12);
                testCase.verifyEqual(sum(k.ddF .* e) / ((2i * pi * f)^2 * G), 1, "AbsTol", 1e-12);
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function presetParameters(testCase)
            acc = timeSeriesPreparation.crnKernel("ACC");
            kbr = timeSeriesPreparation.crnKernel("kbr");
            testCase.verifyEqual([acc.fs acc.Nc acc.Tf acc.B acc.f0 acc.Nf acc.NB acc.Nh], ...
                [10 7 140.7 0.035 0.37e-3 1407 5 703]);
            testCase.verifyEqual([kbr.fs kbr.Nc kbr.Tf kbr.B kbr.f0 kbr.Nf kbr.NB kbr.Nh], ...
                [10 7 70.7 0.1 0.37e-3 707 7 353]);
            testCase.verifyEqual(kbr.preset, "KBR");
            testCase.verifyEqual(size(acc.F), [1407 1]);
            testCase.verifyEqual(acc.lags, (-703:703)');
            testCase.verifyEmpty(acc.overridden);
        end

        function overridesAreRecorded(testCase)
            k = timeSeriesPreparation.crnKernel("ACC", Tf = 120.1, B = 0.04);
            testCase.verifyEqual(sort(k.overridden), ["B" "Tf"]);
            testCase.verifyEqual([k.Nf k.NB], [1201 5]);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function lriRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("LRI"), ...
                "timeSeriesPreparation:crnKernel:unverifiedPreset");
        end

        function unknownPresetRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("GPS"), ...
                "timeSeriesPreparation:crnKernel:unknownPreset");
        end

        function badParametersRefused(testCase)
            id = "timeSeriesPreparation:crnKernel:badParameters";
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("ACC", Tf = 140.8), id); % Nf even
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("ACC", Tf = 140.75), id); % not integer
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("ACC", Nc = 6), id);
            testCase.verifyError(@() timeSeriesPreparation.crnKernel("ACC", B = 1e-3), id);   % NB = 0
        end
    end
end
