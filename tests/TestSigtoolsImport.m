classdef TestSigtoolsImport < matlab.unittest.TestCase
%TESTSIGTOOLSIMPORT  Every file of the sigtools v1.3.1 archive is imported or named as replaced.
%
%   DESCRIPTION
%     X-01 moved sigtools v1.3.1 in unchanged (CONCEPT 12.5, 12.9), and
%     until X-02 this test held every imported file byte-identical to the
%     archive, apart from the namespace qualifiers. X-02 changed the
%     conventions (arguments blocks, identifiers, help, the plotting split),
%     so byte identity ended there. The numbers are now held by
%     TestSigtoolsEquivalence, which runs the archive's functions against
%     the converted ones bit for bit. What remains here is completeness:
%     the archive docs/inputs/sigtools_v1.3.1.zip is unzipped into a
%     temporary folder (never into the repository, which the audit walks),
%     and every .m file in it must either exist at its imported place or
%     be named as replaced, with its replacement.
%
%   COVERAGE
%     contract  - the archive is covered completely.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        % Archive files not imported, each with what replaces it.
        NotImported = dictionary( ...
            ["Contents.m", "sigtools_setup.m", "tests/runSigtoolsTests.m"], ...
            ["+spectral/Contents.m and +tsmodels/Contents.m", ...
             "setupTimeSeriesPreparation (adds demos/)", ...
             "timeSeriesPreparationCiGate (runs tests/ with subfolders)"])
    end

    properties (Access = private)
        Archive
        Root
    end

    methods (TestClassSetup)
        function unzipArchive(testCase)
            testCase.Root = string(fileparts(fileparts(mfilename("fullpath"))));
            zipFile = fullfile(testCase.Root, "docs", "inputs", "sigtools_v1.3.1.zip");
            testCase.assertTrue(isfile(zipFile), "Archive missing: " + zipFile);
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            unzip(zipFile, tmp);
            testCase.Archive = string(tmp);
        end
    end

    methods (Test, TestTags = {'contract'})
        function archiveIsCoveredCompletely(testCase)
            archived = listM(testCase.Archive, "");
            orig = importMap(testCase.Archive, testCase.Root);
            missing = setdiff(archived, [orig; keys(testCase.NotImported)]);
            testCase.verifyEmpty(missing, "Archive files neither imported nor replaced.");
        end
    end
end

% ------------------------------------------------------------------------

function [orig, imported] = importMap(archive, root)
% Archive path -> repository path for every imported file that exists.
    orig = strings(0, 1); imported = strings(0, 1);
    rules = ["spectral/", "+timeSeriesPreparation/+spectral/"
             "tsmodels/", "+timeSeriesPreparation/+tsmodels/"
             "demos/",    "demos/"
             "tests/",    "tests/sigtools/"
             "",          "demos/"];                      % sigtoolsDemo.m
    for f = reshape(listM(archive, ""), 1, [])
        for r = 1:size(rules, 1)
            if rules(r, 1) == "" && contains(f, "/"), continue; end
            if startsWith(f, rules(r, 1))
                target = rules(r, 2) + extractAfter(f, strlength(rules(r, 1)));
                if isfile(fullfile(root, target))
                    orig(end+1, 1) = f; imported(end+1, 1) = target; %#ok<AGROW>
                end
                break
            end
        end
    end
end

function rel = listM(root, sub)
% Every .m file below ROOT as a "/"-separated relative path.
    rel = strings(0, 1);
    for e = reshape(dir(fullfile(root, sub)), 1, [])
        if e.isdir
            if ~any(strcmp(e.name, {'.', '..'}))
                rel = [rel; listM(root, sub + e.name + "/")]; %#ok<AGROW>
            end
        elseif endsWith(e.name, ".m")
            rel(end+1, 1) = sub + e.name; %#ok<AGROW>
        end
    end
end
