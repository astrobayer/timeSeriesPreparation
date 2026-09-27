classdef TestSigtoolsDemos < matlab.unittest.TestCase
%TESTSIGTOOLSDEMOS  Every imported sigtools demo runs from demos/ after setup.
%
%   DESCRIPTION
%     The six demo scripts and the launcher sigtoolsDemo moved to demos/ at
%     X-01, with their calls qualified to the new namespace. sigtools' own
%     suites never executed them, so this is the only check that the
%     qualification left them runnable. Each script runs in its own function
%     workspace with its console output captured; figures it opens are
%     closed afterwards (close all: CI opens no other figure). A demo is
%     required to run without error; warnings are not judged here (the demos
%     are sigtools' as imported, X-02 brings them to this toolbox's
%     conventions).
%
%   COVERAGE
%     contract  - each demo script runs; sigtoolsDemo lists all six as on the
%                 path after setupTimeSeriesPreparation.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Demo = {'demo_plotPowerSpectrum', 'allanVariance_demo', ...
            'gap_filling_spectral_comparison', 'demo_tsmodels', ...
            'demo_sigtools_new', 'demo_sigtools_v13'}
    end

    methods (TestMethodSetup)
        function closeFiguresAfterwards(testCase)
            testCase.addTeardown(@close, "all");
        end
    end

    methods (Test, TestTags = {'contract'})
        function demoRuns(testCase, Demo)
            setupTimeSeriesPreparation(Verbose = false);
            file = fullfile(fileparts(fileparts(mfilename("fullpath"))), "demos", Demo + ".m");
            testCase.assertTrue(isfile(file), "Missing " + file);
            runScript(file);
        end

        function launcherFindsEveryDemo(testCase)
            setupTimeSeriesPreparation(Verbose = false);
            menu = evalc("sigtoolsDemo()");
            testCase.verifyFalse(contains(menu, "not on path"), menu);
            for d = ["demo_plotPowerSpectrum" "allanVariance_demo" ...
                    "gap_filling_spectral_comparison" "demo_tsmodels" ...
                    "demo_sigtools_new" "demo_sigtools_v13"]
                testCase.verifySubstring(menu, d);
            end
        end
    end
end

function runScript(file)
% Run FILE in this function's workspace, console output captured.
    evalc("run(file)"); %#ok<EVLC>
end
