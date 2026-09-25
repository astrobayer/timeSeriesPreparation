classdef TestCiGate < matlab.unittest.TestCase
%TESTCIGATE  The gate turns red on a failing test and on an empty suite.
%
%   DESCRIPTION
%     timeSeriesPreparationCiGate is the check every merge depends on, so its
%     two refusals are fault-injected like any other check: a planted failing
%     test and a folder without tests must each raise the gate's identifier,
%     and a planted passing test must not. The nested gate runs without
%     coverage and without the search database, into a temporary folder.
%
%   COVERAGE
%     contract    - a passing planted suite passes and writes junit.xml.
%     robustness  - a failing planted test and an empty folder are refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function passingSuitePasses(testCase)
            [tests, out] = plant(testCase, "TspGatePlantedPass", "verifyTrue(true)");
            r = timeSeriesPreparationCiGate(TestsFolder = tests, OutputDir = out, ...
                Coverage = false, SearchDatabase = false);
            testCase.verifyNumElements(r, 1);
            testCase.verifyTrue(all([r.Passed]));
            testCase.verifyTrue(isfile(fullfile(out, "junit.xml")));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function failingTestIsRefused(testCase)
            [tests, out] = plant(testCase, "TspGatePlantedFail", "verifyFail('planted')");
            testCase.verifyError(@() timeSeriesPreparationCiGate(TestsFolder = tests, ...
                OutputDir = out, Coverage = false, SearchDatabase = false), ...
                "timeSeriesPreparation:timeSeriesPreparationCiGate:failed");
        end

        function emptyFolderIsRefused(testCase)
            fx = matlab.unittest.fixtures.TemporaryFolderFixture;
            tests = testCase.applyFixture(fx).Folder;
            out = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.verifyError(@() timeSeriesPreparationCiGate(TestsFolder = tests, ...
                OutputDir = out, Coverage = false, SearchDatabase = false), ...
                "timeSeriesPreparation:timeSeriesPreparationCiGate:empty");
        end
    end
end

function [tests, out] = plant(testCase, className, statement)
% A one-test class in its own temporary folder, and a second folder for reports.
    tests = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    out = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    src = ["classdef " + className + " < matlab.unittest.TestCase"
           "    methods (Test, TestTags = {'contract'})"
           "        function planted(testCase)"
           "            testCase." + statement + ";"
           "        end"
           "    end"
           "end"];
    writelines(src, fullfile(tests, className + ".m"));
end
