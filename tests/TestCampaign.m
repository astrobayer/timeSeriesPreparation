classdef TestCampaign < matlab.unittest.TestCase
%TESTCAMPAIGN  run's campaign mode: one result per arc, errors kept, per-day files, a JSON manifest.
%
%   DESCRIPTION
%     X-15 (CONCEPT 6.6 and 5.2; owner decisions 2026-09-26). An Arc array
%     is a campaign: every arc runs the single run's stages with seed
%     cfg.run.seed + k - 1, a refusing arc is kept as an MException while
%     the others continue, and with cfg.run.outDir set each arc's result
%     goes to a MAT v7.3 day file listed with its SHA-256 in
%     manifest.json. The arcs are three days of a 1 Hz ACT1B-like arc
%     (GRACE-FO C, release 04): three sinusoids plus seeded white noise,
%     the sinusoids alone as the reference. Fault injection: a reference
%     in other units fails one arc; a second campaign into the same folder,
%     a day file written twice and a mixed release each refuse; one
%     changed byte changes a file's SHA-256.
%
%   COVERAGE
%     contract       - the campaign's result fields and summary columns;
%                      in memory by default; per-arc inputs counted.
%     reference      - each arc equals its single run with seed + k - 1;
%                      day files and manifest (paths, contents, SHA-256);
%                      internal.fileSha256 against FIPS 180-4.
%     robustness     - a failing arc is captured and the campaign goes on;
%                      existing files are not overwritten unless asked;
%                      a mixed release refuses unless asked; parallel
%                      equals serial.
%     precision, speed, vectorisation, metamorphic - exempt: a campaign
%                      adds no arithmetic; each arc is the single run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-26 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function campaignResultFields(testCase)
            [arcs, refs] = days(3);
            res = timeSeriesPreparation.run(arcs, Reference = refs);
            testCase.verifyEqual(string(fieldnames(res))', ...
                ["results" "summary" "errors" "manifest" "parallel"]);
            testCase.verifyEqual(string(res.summary.Properties.VariableNames), ...
                ["index" "day" "mission" "satellite" "status" "identifier" "message" "file" "sha256"]);
            testCase.verifySize(res.results, [3 1]);
            testCase.verifyEqual(res.summary.day', ["2020-01-02" "2020-01-03" "2020-01-04"]);
            testCase.verifyEqual(res.summary.status', ["ok" "ok" "ok"]);
            single = timeSeriesPreparation.run(arcs(1), Reference = refs(1));
            testCase.verifyEqual(fieldnames(res.results{2}), fieldnames(single));
        end

        function inMemoryByDefault(testCase)
            [arcs, refs] = days(2);
            res = timeSeriesPreparation.run(arcs, Reference = refs);
            testCase.verifyEmpty(res.manifest);
            testCase.verifyFalse(res.parallel);
            testCase.verifyEqual(res.summary.file', ["" ""]);
            testCase.verifyEqual(res.summary.sha256', ["" ""]);
        end

        function pairedInputsCounted(testCase)
            [arcs, refs] = days(3);
            id = "timeSeriesPreparation:run:inputCount";
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, Reference = refs(1:2)), id);
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, User = {[], []}), id);
            testCase.verifyError(@() timeSeriesPreparation.run(arcs(1), Reference = refs(1:2)), id);
            testCase.verifyError(@() timeSeriesPreparation.run(arcs([])), id);
            u = {false(600, 1), false(600, 1), false(600, 1)};
            u{2}(100:109) = true;
            res = timeSeriesPreparation.run(arcs, Reference = refs, User = u);
            testCase.verifyEqual(nnz(res.results{2}.arc.layers.user), 10);
            testCase.verifyEqual(nnz(res.results{1}.arc.layers.user), 0);
        end
    end

    methods (Test, TestTags = {'reference'})
        function eachArcEqualsSingleRun(testCase)
            [arcs, refs] = days(3);
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "noise", "order", [1 0]);
            cfg = set(cfg, "run", "seed", 5);
            h = sin(pi * (0:29)' / 30).^2;
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg, Response = h);
            for k = 1:3
                one = timeSeriesPreparation.run(arcs(k), Reference = refs(k), Response = h, ...
                    Config = set(cfg, "run", "seed", 5 + k - 1));
                testCase.verifyTrue(isequaln(content(res.results{k}), content(one)), ...
                    sprintf("arc %d differs from its single run", k));
                testCase.verifyEqual(res.results{k}.config.run.seed, 5 + k - 1);
            end
        end

        function filesAndManifest(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(3);
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "run", "outDir", folder);
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            m = jsondecode(fileread(fullfile(folder, "manifest.json")));
            testCase.verifyEqual(string(m.software.version), ...
                timeSeriesPreparation.internal.toolboxVersion());
            testCase.verifyEqual(string({m.firstDay m.lastDay}), ["2020-01-02" "2020-01-04"]);
            for k = 1:3
                rel = strjoin([arcs(k).mission, "C", "2020", res.summary.day(k) + ".mat"], "/");
                testCase.verifyEqual(res.summary.file(k), rel);
                f = fullfile(folder, rel);
                testCase.verifyTrue(isfile(f), rel + " was not written");
                S = load(f);
                testCase.verifyEqual(S.schemaVersion, "1");
                testCase.verifyTrue(isequaln(content(S.result), content(res.results{k})));
                testCase.verifyEqual(res.summary.sha256(k), timeSeriesPreparation.internal.fileSha256(f));
                testCase.verifyEqual(string(m.arcs(k).sha256), res.summary.sha256(k));
                testCase.verifyEqual(string(m.arcs(k).status), "ok");
                testCase.verifyEqual(string(m.arcs(k).files), arcs(k).files);
            end
            testCase.verifyEqual(res.manifest.config.hash, ...
                timeSeriesPreparation.internal.contentHash(toStruct(cfg)));
        end

        function fileSha256Pinned(testCase)
            folder = tempFolder(testCase);
            f = fullfile(folder, "abc.txt");
            write(f, uint8('abc'));
            testCase.verifyEqual(timeSeriesPreparation.internal.fileSha256(f), ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            write(f, uint8([]));
            testCase.verifyEqual(timeSeriesPreparation.internal.fileSha256(f), ...
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
            write(f, uint8('abd'));                   % fault injection: one byte
            testCase.verifyNotEqual(timeSeriesPreparation.internal.fileSha256(f), ...
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            testCase.verifyError(@() timeSeriesPreparation.internal.fileSha256(fullfile(folder, "none")), ...
                "timeSeriesPreparation:fileSha256:fileNotFound");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function failingArcIsCaptured(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(3);
            refs(2) = arcOf(refs(2).t, refs(2).obs, "2020-01-03", "m", "04");   % other units: align refuses
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "run", "outDir", folder);
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            testCase.verifyEqual(res.summary.status', ["ok" "error" "ok"]);
            testCase.verifyEqual(res.summary.identifier(2), "timeSeriesPreparation:align:unitMismatch");
            testCase.verifyClass(res.errors{2}, "MException");
            testCase.verifyEmpty(res.results{2});
            testCase.verifyEmpty(res.errors{1});
            testCase.verifyEqual(res.summary.file(2), "");
            testCase.verifyEqual(string(res.manifest.arcs(2).status), "error");
            testCase.verifyTrue(isfile(fullfile(folder, res.summary.file(3))));
        end

        function existingFilesNotOverwritten(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(2);
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "run", "outDir", folder);
            first = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg), ...
                "timeSeriesPreparation:run:fileExists");
            delete(fullfile(folder, "manifest.json"));
            again = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            testCase.verifyEqual(again.summary.status', ["unsaved" "unsaved"]);
            testCase.verifyEqual(again.summary.identifier(1), "timeSeriesPreparation:run:fileExists");
            forced = timeSeriesPreparation.run(arcs, Reference = refs, ...
                Config = set(cfg, "run", "overwrite", true));
            testCase.verifyEqual(forced.summary.status', ["ok" "ok"]);
            testCase.verifyEqual(forced.summary.file, first.summary.file);
            twice = timeSeriesPreparation.run(arcs([1 1]), Reference = refs([1 1]), ...
                Config = set(cfg, "run", "overwrite", true));
            testCase.verifyEqual(twice.summary.status', ["ok" "unsaved"], ...
                "A day file this campaign wrote must not be overwritten by its own second arc.");
        end

        function mixedReleaseRefuses(testCase)
            [arcs, refs] = days(2);
            arcs(2) = arcOf(arcs(2).t, arcs(2).obs, "2020-01-03", "m/s2", "05");
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, Reference = refs), ...
                "timeSeriesPreparation:Arc:mixedRelease");
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "run", "mixedRelease", true);
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            testCase.verifyEqual(res.summary.status', ["ok" "ok"]);
        end

        function parallelEqualsSerial(testCase)
            [arcs, refs] = days(3);
            cfg = set(timeSeriesPreparation.Config(arcs(1)), "noise", "order", [1 0]);
            serial = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            par = timeSeriesPreparation.run(arcs, Reference = refs, ...
                Config = set(cfg, "run", "parallel", true));
            testCase.verifyEqual(par.parallel, canUseParallelPool());
            for k = 1:3
                testCase.verifyTrue(isequaln(content(par.results{k}), content(serial.results{k})), ...
                    sprintf("arc %d differs between parallel and serial", k));
            end
        end
    end
end

% ------------------------------------------------------------------------

function folder = tempFolder(testCase)
% A folder removed after the test.
    fx = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = string(fx.Folder);
end

function write(f, bytes)
    fid = fopen(f, "w");
    fwrite(fid, bytes, "uint8");
    fclose(fid);
end

function [arcs, refs] = days(n)
% n consecutive days from 2020-01-02, 600 s each at 1 Hz: three sinusoids
% plus seeded white noise, and the sinusoids alone as the reference.
    s = (0:599)';
    sig = 1e-7 * [sin(2 * pi * s / 300), cos(2 * pi * s / 300), sin(2 * pi * s / 200)];
    for k = 1:n
        t = int64(7306 + k - 1) * int64(86400e9) - int64(43200e9) + int64(18e9) + int64(s) * int64(1e9);
        day = string(datetime(2020, 1, 1 + k, "Format", "yyyy-MM-dd"));
        e = 1e-9 * randn(RandStream("twister", "Seed", 10 + k), 600, 3);
        arcs(k) = arcOf(t, sig + e, day, "m/s2", "04"); %#ok<AGROW>
        refs(k) = arcOf(t, sig, day, "m/s2", "04"); %#ok<AGROW>
    end
end

function arc = arcOf(t, obs, day, unit, release)
% An ACT1B arc of GRACE-FO C on epochs t, with the day, units and release
% of its file name.
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    units = struct();
    for k = 1:3
        units.(names{k}) = char(unit);
    end
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", units, "fileName", "ACT1B_" + day + "_C_" + release + ".txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end

function x = content(x)
% A result without creation times: every Arc as its content, every field
% named provenance removed, at any depth.
    if isa(x, "timeSeriesPreparation.Arc")
        x = arrayfun(@(a) struct("t", a.t, "obs", a.obs, "names", a.names, "units", a.units, ...
            "weights", a.weights, "layers", a.layers, "filled", a.filled), x);
    elseif iscell(x)
        for k = 1:numel(x)
            x{k} = content(x{k});
        end
    elseif isstruct(x)
        if isfield(x, "provenance")
            x = rmfield(x, "provenance");
        end
        for fn = reshape(string(fieldnames(x)), 1, [])
            for k = 1:numel(x)
                x(k).(fn) = content(x(k).(fn));
            end
        end
    end
end
