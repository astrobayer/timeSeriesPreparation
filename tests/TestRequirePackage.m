classdef TestRequirePackage < matlab.unittest.TestCase
%TESTREQUIREPACKAGE  The optional-dependency resolution of CONCEPT 3.1.
%
%   DESCRIPTION
%     timeSeriesPreparation.internal.requirePackage must pass silently when a
%     namespace resolves and raise timeSeriesPreparation:<caller>:depMissing
%     when it does not. The missing case uses a namespace that cannot exist,
%     so it does not depend on what the runner has installed; the present case
%     for gracefoReading is an assumption, incomplete where CI provides no
%     checkout.
%
%   COVERAGE
%     contract    - present namespace passes; the identifier carries the
%                   caller; setup refuses a folder without +gracefoReading.
%     robustness  - missing namespace and invalid caller are refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function presentNamespacePasses(testCase)
            testCase.verifyWarningFree(@() ...
                timeSeriesPreparation.internal.requirePackage("timeSeriesPreparation", "x"));
        end

        function gracefoReadingResolvesWhenCheckedOut(testCase)
            testCase.assumeNotEmpty(meta.package.fromName('gracefoReading'), ...
                "gracefoReading is not on the path (no deps/ checkout on this runner).");
            testCase.verifyWarningFree(@() ...
                timeSeriesPreparation.internal.requirePackage("gracefoReading", "x"));
        end

        function identifierCarriesCaller(testCase)
            testCase.verifyError(@() ...
                timeSeriesPreparation.internal.requirePackage("noSuchNamespaceTsp", "qualFlagMask"), ...
                "timeSeriesPreparation:qualFlagMask:depMissing");
        end

        function setupRefusesFolderWithoutReader(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            testCase.verifyError(@() ...
                setupTimeSeriesPreparation(GracefoReading = folder, Verbose = false), ...
                "timeSeriesPreparation:setupTimeSeriesPreparation:noGracefoReading");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function missingNamespaceRefused(testCase)
            testCase.verifyError(@() ...
                timeSeriesPreparation.internal.requirePackage("noSuchNamespaceTsp", "x"), ...
                "timeSeriesPreparation:x:depMissing");
        end

        function invalidCallerRefused(testCase)
            testCase.verifyError(@() ...
                timeSeriesPreparation.internal.requirePackage("timeSeriesPreparation", "not valid"), ...
                "MATLAB:validators:mustBeValidVariableName");
        end
    end
end
