classdef TestLayering < matlab.unittest.TestCase
%TESTLAYERING  The layers of CONCEPT 3.2, checked mechanically on the source.
%
%   DESCRIPTION
%     CONCEPT 3.2 assigns every unit of +timeSeriesPreparation to a layer:
%       L3  run
%       L2  mask qc align crnApply fill observability bootstrap crossval
%           drivers correlate report, and checkAlignment (stage 3 of
%           CONCEPT 6.1 with align)
%       L1  Arc Config crnKernel
%       L0  +spectral +tsmodels (sigtools), and +internal helpers
%     and says calls go downward only. Calls within one layer are allowed
%     (sigtools functions call each other, Config reads an Arc); a call to a
%     higher layer is a finding. Further findings, each from CONCEPT 3.1 or
%     10.1:
%       - a unit no layer lists (the work package adding it assigns it here);
%       - L0 referencing gracefoReading (the sigtools half runs in base MATLAB);
%       - any package file referencing lsqvce (a test-only dependency, Q2);
%       - a file referencing gracefoReading without calling
%         timeSeriesPreparation.internal.requirePackage (optional dependency).
%     References are read from code with comments removed, so help text and
%     See also lines never count. Each finding is fault-injected on a planted
%     tree; a healthy planted tree, with a sideways call and an upward name in
%     a comment, stays silent.
%
%   COVERAGE
%     contract    - the repository's package has no finding.
%     robustness  - each of the five findings fires on its planted defect;
%                   the healthy tree is silent.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function repositoryPackageIsLayered(testCase)
            root = fullfile(fileparts(fileparts(mfilename("fullpath"))), "+timeSeriesPreparation");
            testCase.verifyEmpty(layerFindings(root), ...
                "The package violates CONCEPT 3.2 / 3.1.");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function healthyTreeIsSilent(testCase)
            root = plantTree(testCase, healthyFiles());
            testCase.verifyEmpty(layerFindings(root));
        end

        function upwardCallFires(testCase)
            files = healthyFiles();
            files(end+1, :) = ["crnKernel.m", ...
                "function k = crnKernel()" + newline + ...
                "k = timeSeriesPreparation.run();" + newline + "end"];
            testCase.verifyFinding(files, "upward");
        end

        function unassignedUnitFires(testCase)
            files = healthyFiles();
            files(end+1, :) = ["newThing.m", "function newThing()" + newline + "end"];
            testCase.verifyFinding(files, "no layer");
        end

        function gracefoReadingInL0Fires(testCase)
            files = healthyFiles();
            files(end+1, :) = ["+spectral/useReader.m", ...
                "function useReader()" + newline + ...
                "timeSeriesPreparation.internal.requirePackage(""gracefoReading"", ""useReader"");" + newline + ...
                "gracefoReading.findGaps(1);" + newline + "end"];
            testCase.verifyFinding(files, "L0");
        end

        function lsqvceReferenceFires(testCase)
            files = healthyFiles();
            files(end+1, :) = ["bootstrap.m", ...
                "function bootstrap()" + newline + "lsqvce.fit();" + newline + "end"];
            testCase.verifyFinding(files, "lsqvce");
        end

        function unguardedReaderCallFires(testCase)
            files = healthyFiles();
            files(end+1, :) = ["mask.m", ...
                "function mask()" + newline + "gracefoReading.decodeQualFlags(1);" + newline + "end"];
            testCase.verifyFinding(files, "requirePackage");
        end
    end

    methods
        function verifyFinding(testCase, files, needle)
            f = layerFindings(plantTree(testCase, files));
            testCase.verifyNumElements(f, 1, "Exactly one finding expected.");
            testCase.verifyTrue(any(contains(f, needle)), ...
                "Expected a finding containing """ + needle + """, got: " + strjoin(f, " | "));
        end
    end
end

% ------------------------------------------------------------------------

function layers = layerMap()
% CONCEPT 3.2, as data. A new unit is added here by the WP that creates it.
    layers = dictionary( ...
        ["run", ...
         "mask" "qc" "align" "checkAlignment" "crnApply" "fill" "observability" ...
         "bootstrap" "crossval" "drivers" "correlate" "report", ...
         "Arc" "Config" "crnKernel", ...
         "spectral" "tsmodels" "internal"], ...
        [3, 2 2 2 2 2 2 2 2 2 2 2 2, 1 1 1, 0 0 0]);
end

function findings = layerFindings(root)
% All findings for the package folder ROOT, one string each.
    layers = layerMap();
    findings = strings(0, 1);
    for rel = reshape(listFiles(root, ""), 1, [])
        full = fullfile(root, rel);
        if rel == "Contents.m", continue; end
        unit = unitOf(rel);
        if ~isKey(layers, unit)
            findings(end+1, 1) = rel + ": unit '" + unit + "' has no layer in CONCEPT 3.2"; %#ok<AGROW>
            continue
        end
        own = layers(unit);
        code = stripComments(fileread(full));

        tok = regexp(code, "\<timeSeriesPreparation\.(\w+)", "tokens");
        refs = unique(string([tok{:}]));
        for r = reshape(refs, 1, [])
            if ~isKey(layers, r)
                findings(end+1, 1) = rel + ": calls unit '" + r + "' that has no layer"; %#ok<AGROW>
            elseif layers(r) > own
                findings(end+1, 1) = sprintf("%s: upward call from L%d '%s' to L%d '%s'", ...
                    rel, own, unit, layers(r), r); %#ok<AGROW>
            end
        end

        usesReader = ~isempty(regexp(code, "\<gracefoReading\.\w", "once"));
        if usesReader && own == 0
            findings(end+1, 1) = rel + ": L0 references gracefoReading (sigtools half is base MATLAB)"; %#ok<AGROW>
        elseif usesReader && isempty(regexp(code, ...
                "timeSeriesPreparation\.internal\.requirePackage\(\s*[""']gracefoReading[""']", "once"))
            findings(end+1, 1) = rel + ": references gracefoReading without requirePackage"; %#ok<AGROW>
        end
        if ~isempty(regexp(code, "\<lsqvce\.\w", "once"))
            findings(end+1, 1) = rel + ": references lsqvce (test-only dependency)"; %#ok<AGROW>
        end
    end
end

function rel = listFiles(root, sub)
% Every .m file below ROOT as a "/"-separated path relative to it. Built by
% walking, not by cutting a prefix off dir's absolute paths, which on Windows
% may come back in another spelling (short names) than ROOT was given in.
    rel = strings(0, 1);
    entries = dir(fullfile(root, sub));
    for e = reshape(entries, 1, [])
        if e.isdir
            if ~any(strcmp(e.name, {'.', '..'}))
                rel = [rel; listFiles(root, sub + e.name + "/")]; %#ok<AGROW>
            end
        elseif endsWith(e.name, ".m")
            rel(end+1, 1) = sub + e.name; %#ok<AGROW>
        end
    end
end

function unit = unitOf(rel)
% First path component: +sub -> sub, @Class -> Class, name.m -> name.
    head = extractBefore(rel + "/", "/");
    if startsWith(head, ["+" "@"])
        unit = extractAfter(head, 1);
    else
        unit = erase(head, ".m");
    end
end

function out = stripComments(src)
% Remove %{ %} blocks, line comments and text after a continuation "...",
% leaving string and char literals intact. A quote is a transpose when it
% follows an identifier character, a closing bracket, a dot or a transpose.
    lines = splitlines(string(src));
    keep = true(size(lines));
    depth = 0;
    for k = 1:numel(lines)
        t = strtrim(lines(k));
        if t == "%{", depth = depth + 1; keep(k) = false; continue; end
        if t == "%}" && depth > 0, depth = depth - 1; keep(k) = false; continue; end
        if depth > 0, keep(k) = false; continue; end
        lines(k) = stripLine(char(lines(k)));
    end
    out = strjoin(lines(keep), newline);
end

function s = stripLine(c)
    inDq = false; inSq = false; prev = ' ';
    for i = 1:numel(c)
        ch = c(i);
        if inDq
            if ch == '"', inDq = false; end
        elseif inSq
            if ch == '''', inSq = false; end
        elseif ch == '"'
            inDq = true;
        elseif ch == ''''
            if ~(isstrprop(prev, "alphanum") || any(prev == ')]}._'''))
                inSq = true;
            end
        elseif ch == '%'
            s = string(c(1:i-1)); return
        elseif ch == '.' && i + 2 <= numel(c) && all(c(i:i+2) == '...')
            s = string(c(1:i-1)); return
        end
        prev = ch;
    end
    s = string(c);
end

function files = healthyFiles()
% A small tree touching every layer: a sideways L0 call, a downward L2 call,
% a guarded reader call, and an upward name that appears only in comments.
    files = [ ...
        "+spectral/a.m", "function a()" + newline + ...
            "timeSeriesPreparation.tsmodels.b(); % sideways, allowed" + newline + "end"
        "+tsmodels/b.m", "function b()" + newline + "end"
        "Arc.m", "classdef Arc" + newline + "end"
        "qc.m", "function qc()" + newline + ...
            "%{" + newline + "timeSeriesPreparation.run();" + newline + "%}" + newline + ...
            "x = 'it''s'; % timeSeriesPreparation.run is only mentioned" + newline + ...
            "y = x'; timeSeriesPreparation.Arc(); timeSeriesPreparation.spectral.a();" + newline + ...
            "timeSeriesPreparation.internal.requirePackage(""gracefoReading"", ""qc"");" + newline + ...
            "gracefoReading.findGaps(1); ... timeSeriesPreparation.run()" + newline + "end"
        "run.m", "function run()" + newline + "timeSeriesPreparation.qc();" + newline + "end"];
end

function root = plantTree(testCase, files)
    base = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
    root = fullfile(base, "+plantedPkg");
    for k = 1:size(files, 1)
        target = fullfile(root, files(k, 1));
        folder = fileparts(target);
        if ~isfolder(folder), mkdir(folder); end
        writelines(files(k, 2), target);
    end
end
