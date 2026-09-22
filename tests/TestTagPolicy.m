classdef TestTagPolicy < matlab.unittest.TestCase
%TESTTAGPOLICY  Every test carries a tag, and only tags of CONCEPT 9.
%
%   DESCRIPTION
%     CONCEPT 9 names seven test categories: contract, reference, precision,
%     speed, robustness, vectorisation, metamorphic. They are the only tags
%     allowed, so the gate's per-tag counts (timeSeriesPreparationCiGate) mean
%     what the concept says. A test without a tag is invisible to every
%     category count; a misspelt tag ("vectorization") is a category nobody
%     counts. Both are findings. The check is fault-injected: planted classes
%     in a temporary folder must fire it, a healthy one must not.
%
%   COVERAGE
%     contract    - the repository's own tests/ has no finding.
%     robustness  - an untagged test, a misspelt tag and an unknown tag each
%                   fire; a correctly tagged class stays silent.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Claude Code (Anthropic)

    properties (Constant)
        Allowed = ["contract" "reference" "precision" "speed" ...
                   "robustness" "vectorisation" "metamorphic"]
    end

    methods (Test, TestTags = {'contract'})
        function repositoryTestsFollowPolicy(testCase)
            folder = fileparts(mfilename("fullpath"));
            suite = matlab.unittest.TestSuite.fromFolder(folder);
            testCase.verifyNotEmpty(suite);
            testCase.verifyEmpty(tagFindings(suite, testCase.Allowed), ...
                "Tests in tests/ violate the tag policy of CONCEPT 9.");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function untaggedTestFires(testCase)
            suite = plantedSuite(testCase, "TspPlantedUntagged", "");
            testCase.verifyEqual(numel(tagFindings(suite, testCase.Allowed)), 1);
        end

        function misspeltTagFires(testCase)
            suite = plantedSuite(testCase, "TspPlantedMisspelt", "'vectorization'");
            testCase.verifyEqual(numel(tagFindings(suite, testCase.Allowed)), 1);
        end

        function unknownTagBesideValidOneFires(testCase)
            suite = plantedSuite(testCase, "TspPlantedUnknown", "'contract','smoke'");
            testCase.verifyEqual(numel(tagFindings(suite, testCase.Allowed)), 1);
        end

        function healthyClassIsSilent(testCase)
            suite = plantedSuite(testCase, "TspPlantedHealthy", "'contract','metamorphic'");
            testCase.verifyEmpty(tagFindings(suite, testCase.Allowed));
        end
    end
end

function findings = tagFindings(suite, allowed)
% One string per test that has no tag or a tag outside the allowed set.
    findings = strings(0, 1);
    for k = 1:numel(suite)
        tags = string(suite(k).Tags);
        if isempty(tags)
            findings(end+1, 1) = suite(k).Name + ": no tag"; %#ok<AGROW>
        elseif ~all(ismember(tags, allowed))
            findings(end+1, 1) = suite(k).Name + ": unknown tag " + ...
                strjoin(tags(~ismember(tags, allowed)), ", "); %#ok<AGROW>
        end
    end
end

function suite = plantedSuite(testCase, className, tags)
% A one-test class in a temporary folder; tags "" means no TestTags at all.
    folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    if tags == ""
        attr = "methods (Test)";
    else
        attr = "methods (Test, TestTags = {" + tags + "})";
    end
    src = ["classdef " + className + " < matlab.unittest.TestCase"
           "    " + attr
           "        function planted(testCase)"
           "            testCase.verifyTrue(true);"
           "        end"
           "    end"
           "end"];
    writelines(src, fullfile(folder, className + ".m"));
    suite = matlab.unittest.TestSuite.fromFolder(folder);
end
