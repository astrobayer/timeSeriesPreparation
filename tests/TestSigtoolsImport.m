classdef TestSigtoolsImport < matlab.unittest.TestCase
%TESTSIGTOOLSIMPORT  The sigtools import is byte-identical to the archive, bar namespace.
%
%   DESCRIPTION
%     X-01 moves sigtools v1.3.1 in unchanged (CONCEPT 12.5, 12.9). The only
%     edit a namespace forces is qualifying calls between sigtools functions
%     (tsAcf -> timeSeriesPreparation.tsmodels.tsAcf), plus the demos naming
%     setupTimeSeriesPreparation instead of sigtools_setup. This test unzips
%     the archived docs/inputs/sigtools_v1.3.1.zip into a temporary folder -
%     never into the repository, which the audit walks - and requires every
%     imported file to equal its original once exactly those edits are
%     undone. A qualifier into the wrong subpackage is not undone and is a
%     finding. Line endings are compared as LF, since a Windows checkout may
%     write CRLF. Every .m file of the archive is either imported or named as
%     replaced, with the replacement.
%
%   COVERAGE
%     reference   - every imported file equals the archive modulo the
%                   namespace edits; the archive is covered completely.
%     robustness  - the comparison fires on a changed digit and on a
%                   qualifier into the wrong subpackage, and stays silent on
%                   a correctly qualified line.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

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

    methods (Test, TestTags = {'reference'})
        function importedFilesEqualArchive(testCase)
            [orig, imported] = importMap(testCase.Archive, testCase.Root);
            testCase.assertNotEmpty(orig);
            names = subpackageNames(testCase.Root);
            bad = strings(0, 1);
            for k = 1:numel(orig)
                a = fileread(fullfile(testCase.Archive, orig(k)));
                b = fileread(fullfile(testCase.Root, imported(k)));
                if ~sameModuloNamespace(b, a, names)
                    bad(end+1, 1) = imported(k); %#ok<AGROW>
                end
            end
            testCase.verifyEmpty(bad, "Imported files differ from the archive beyond the namespace edits.");
        end

        function archiveIsCoveredCompletely(testCase)
            archived = listM(testCase.Archive, "");
            orig = importMap(testCase.Archive, testCase.Root);
            missing = setdiff(archived, [orig; keys(testCase.NotImported)]);
            testCase.verifyEmpty(missing, "Archive files neither imported nor replaced.");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function changedDigitFires(testCase)
            names = subpackageNames(testCase.Root);
            testCase.verifyFalse(sameModuloNamespace( ...
                "y = timeSeriesPreparation.tsmodels.tsAcf(x, 21);", "y = tsAcf(x, 20);", names));
        end

        function wrongSubpackageFires(testCase)
            names = subpackageNames(testCase.Root);
            testCase.verifyFalse(sameModuloNamespace( ...
                "y = timeSeriesPreparation.spectral.tsAcf(x, 20);", "y = tsAcf(x, 20);", names));
        end

        function correctQualifierIsSilent(testCase)
            names = subpackageNames(testCase.Root);
            testCase.verifyTrue(sameModuloNamespace( ...
                "y = timeSeriesPreparation.tsmodels.tsAcf(x, 20);" + char(13) + newline + ...
                "setupTimeSeriesPreparation", "y = tsAcf(x, 20);" + newline + "sigtools_setup", names));
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

function names = subpackageNames(root)
% "spectral" and "tsmodels" -> their function names, from the repository.
    names = struct();
    for sub = ["spectral" "tsmodels"]
        files = dir(fullfile(root, "+timeSeriesPreparation", "+" + sub, "*.m"));
        n = erase(string({files.name}), ".m");
        names.(sub) = n(n ~= "Contents");
    end
end

function tf = sameModuloNamespace(imported, original, names)
% Undo exactly the X-01 edits in IMPORTED, then compare with ORIGINAL as LF text.
    s = toLf(imported);
    for sub = ["spectral" "tsmodels"]
        for n = names.(sub)
            s = replace(s, "timeSeriesPreparation." + sub + "." + n, n);
        end
    end
    s = replace(s, "setupTimeSeriesPreparation", "sigtools_setup");
    tf = (s == toLf(original));
end

function s = toLf(text)
    s = replace(replace(string(text), string(char([13 10])), string(newline)), ...
        string(char(13)), string(newline));
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
