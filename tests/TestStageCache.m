classdef TestStageCache < matlab.unittest.TestCase
%TESTSTAGECACHE  run's stage cache: off by default, hits equal the computation, keys by content.
%
%   DESCRIPTION
%     X-14 (CONCEPT 6.6; owner decisions 2026-09-25). The cache is off
%     unless cfg.run.cacheDir is set. With it set, crn, qc, noise and
%     correlation store their outputs under <cacheDir>/<stage>/<key>.mat;
%     a second run on the same content loads them (status "hit") and must
%     return what the first computed, isequaln. bootstrap and crossval
%     are never cached (function-handle input). The key is
%     internal.contentHash, pinned against a Python rebuild of its byte
%     stream; run's key ignores provenance and changes with one byte of
%     input or one setting. Fault injection: a changed sample and a changed setting
%     must miss, a corrupted file must be rewritten, an unwritable folder
%     must report "unsaved", and a function handle must refuse to hash.
%     The arcs are TestRun's: three sinusoids plus seeded white noise at
%     1 Hz on 2020-01-02, the sinusoids alone as the reference.
%
%   COVERAGE
%     contract       - off by default (every cacheable row "off"); stages
%                      with a function handle are "not cached".
%     reference      - a second run hits and equals the first (qc, noise,
%                      correlation; crn separately); contentHash equals the
%                      Python rebuild and refuses an Arc (L0).
%     robustness     - a changed sample or setting misses, added provenance
%                      hits; a corrupted file
%                      is rewritten; an unwritable folder is "unsaved"; a
%                      function handle refuses to hash.
%     precision, speed, vectorisation, metamorphic - exempt: the cache adds
%                      no arithmetic; a hit is the stored value itself.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-25 23:55 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function offByDefault(testCase)
            [arc, ref] = pair(300);
            cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
            testCase.verifyEqual(cfg.run.cacheDir, "");
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            c = res.diagnostics.cache;
            testCase.verifyEqual(c.stage', ["qc" "noise"]);
            testCase.verifyEqual(c.status', ["off" "off"]);
            testCase.verifyEqual(res.provenance(end).detail.cache, c);
        end

        function handleStagesNeverCached(testCase)
            folder = tempFolder(testCase);
            [arc, ref] = pair(300);
            cfg = set(timeSeriesPreparation.Config(arc), "run", "cacheDir", string(folder));
            cfg = set(set(cfg, "unc", "nBoot", 20), "unc", "blockLength", 10);
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, ...
                Statistic = @(z) mean(z, 1, "omitnan"), Loss = @(a, b) mean(b, 1, "omitnan"));
            c = res.diagnostics.cache;
            k = ismember(c.stage, ["bootstrap" "crossval"]);
            testCase.verifyEqual(c.status(k)', ["not cached" "not cached"]);
            testCase.verifyEqual(c.reason(k)', ["function-handle input" "function-handle input"]);
            testCase.verifyFalse(isfolder(fullfile(folder, "bootstrap")));
        end
    end

    methods (Test, TestTags = {'reference'})
        function secondRunHitsAndEquals(testCase)
            folder = tempFolder(testCase);
            [arc, ref] = pair(600);
            cfg = cachedConfig(arc, folder);
            series = driverSeries(arc);
            a = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, Drivers = series);
            b = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, Drivers = series);
            testCase.verifyEqual(a.diagnostics.cache.stage', ["qc" "noise" "correlation"]);
            testCase.verifyEqual(a.diagnostics.cache.status', ["miss" "miss" "miss"]);
            testCase.verifyEqual(b.diagnostics.cache.status', ["hit" "hit" "hit"]);
            testCase.verifyEqual(b.diagnostics.cache.key, a.diagnostics.cache.key);
            for k = 1:3
                testCase.verifyTrue(isfile(fullfile(folder, a.diagnostics.cache.stage(k), ...
                    a.diagnostics.cache.key(k) + ".mat")));
            end
            testCase.verifyTrue(isequaln(b.diagnostics.qc, a.diagnostics.qc));
            testCase.verifyTrue(isequaln(b.diagnostics.noise, a.diagnostics.noise));
            testCase.verifyTrue(isequaln(b.correlation, a.correlation));
            testCase.verifyEqual(b.arc.weights, a.arc.weights);
            testCase.verifyTrue(isequaln(b.diagnostics.residual.obs, a.diagnostics.residual.obs));
        end

        function crnHitEqualsCompute(testCase)
            folder = tempFolder(testCase);
            n = 4000;                                % 400 s at 10 Hz
            t10 = epochs(n, 1e8);
            tt = (0:n - 1)' / 10;
            sig = 1e-7 * [sin(2 * pi * tt / 100), cos(2 * pi * tt / 100), sin(2 * pi * tt / 150)];
            ref = actArc(t10, sig);
            arc = actArc(t10(1:10:end), sig(1:10:end, :));
            cfg = set(timeSeriesPreparation.Config(arc), "run", "filterReference", true);
            cfg = set(cfg, "run", "cacheDir", string(folder));
            a = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            b = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            row = @(r) r.diagnostics.cache(r.diagnostics.cache.stage == "crn", :);
            testCase.verifyEqual([row(a).status row(b).status], ["miss" "hit"]);
            direct = timeSeriesPreparation.crnApply(ref, timeSeriesPreparation.crnKernel("ACC"), ...
                OutputEpochs = arc.t);
            testCase.verifyTrue(isequaln(b.reference.obs, direct.obs));
            testCase.verifyTrue(isequaln(b.reference.obs, a.reference.obs));
        end

        function contentHashPinned(testCase)
            h = @timeSeriesPreparation.internal.contentHash;
            testCase.verifyEqual(h(uint8('abc')), ...
                "40227623b648a612552d1d3ee04c07d5013520f932d94327a12d1b2554717715");
            testCase.verifyEqual(h("qc", struct("hampelWindow", 61)), ...
                "5bdcf53a514ff0c8eeba0139dc6c1bfbcc3125d4aa8ad79ea3b8a8b19310fc93");
            testCase.verifyError(@() h(pair(10)), "timeSeriesPreparation:contentHash:unsupported", ...
                "contentHash is L0 and knows no Arc; run hashes an Arc's content (CONCEPT 3.2).");
            testCase.verifyNotEqual(h([1 2]), h("12"));
            testCase.verifyNotEqual(h(int32(1)), h(1));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function changedInputOrSettingMisses(testCase)
            folder = tempFolder(testCase);
            [arc, ref] = pair(300);
            cfg = cachedConfig(arc, folder);
            a = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            x = arc.obs;
            x(17, 2) = x(17, 2) + eps(x(17, 2));      % one bit of one sample
            b = timeSeriesPreparation.run(actArc(arc.t, x), Reference = ref, Config = cfg);
            testCase.verifyEqual(b.diagnostics.cache.status', ["miss" "miss"]);
            testCase.verifyNotEqual(b.diagnostics.cache.key, a.diagnostics.cache.key);
            c = timeSeriesPreparation.run(arc, Reference = ref, ...
                Config = set(cfg, "qc", "hampelWindow", 31));
            testCase.verifyEqual(c.diagnostics.cache.status(1), "miss");
            d = timeSeriesPreparation.run(appendProvenance(arc, "other", struct()), ...
                Reference = ref, Config = cfg);
            testCase.verifyEqual(d.diagnostics.cache.status', ["hit" "hit"], ...
                "Provenance carries times; the key must ignore it.");
        end

        function corruptFileRewritten(testCase)
            folder = tempFolder(testCase);
            [arc, ref] = pair(300);
            cfg = cachedConfig(arc, folder);
            a = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            file = fullfile(folder, "qc", a.diagnostics.cache.key(1) + ".mat");
            fid = fopen(file, "w"); fwrite(fid, uint8('not a MAT file')); fclose(fid);
            b = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            testCase.verifyEqual(b.diagnostics.cache.status', ["rewritten" "hit"]);
            testCase.verifyTrue(isequaln(b.diagnostics.qc.mask, a.diagnostics.qc.mask));
            c = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            testCase.verifyEqual(c.diagnostics.cache.status', ["hit" "hit"]);
        end

        function refusalsAndUnsaved(testCase)
            folder = tempFolder(testCase);
            testCase.verifyError(@() timeSeriesPreparation.internal.contentHash(@sin), ...
                "timeSeriesPreparation:contentHash:unsupported");
            blocker = fullfile(folder, "blocker");
            fid = fopen(blocker, "w"); fclose(fid);    % a file where the cache folder would go
            [outs, status] = timeSeriesPreparation.internal.stageCache(string(blocker), "s", "k", 1, @() 42);
            testCase.verifyEqual(status, "unsaved");
            testCase.verifyEqual(outs, {42});
            [outs, status] = timeSeriesPreparation.internal.stageCache("", "s", "k", 1, @() 7);
            testCase.verifyEqual([outs {status}], {7, "off"});
        end
    end
end

% ------------------------------------------------------------------------

function folder = tempFolder(testCase)
% A folder removed after the test.
    fx = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = string(fx.Folder);
end

function cfg = cachedConfig(arc, folder)
    cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
    cfg = set(set(cfg, "drivers", "maxLag", 5), "unc", "nBoot", 20);
    cfg = set(set(cfg, "unc", "blockLength", 10), "run", "cacheDir", string(folder));
end

function t = epochs(n, stepNs)
% n epochs from 2020-01-02 00:00:00 UTC = 00:00:18 GPS, stepNs apart.
    t0 = int64(7306 * 86400 - 43200 + 18) * int64(1e9);
    t = t0 + int64(0:n - 1)' * int64(stepNs);
end

function arc = actArc(t, obs)
% An ACT1B arc of 1 to 3 axes on epochs t.
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    names = names(1:size(obs, 2));
    units = struct();
    for k = 1:numel(names)
        units.(names{k}) = 'm/s2';
    end
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", units, "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end

function [arc, ref] = pair(n)
% Three sinusoids plus seeded white noise at 1 Hz, and the sinusoids alone.
    t = epochs(n, 1e9);
    s = (0:n - 1)';
    sig = 1e-7 * [sin(2 * pi * s / 300), cos(2 * pi * s / 300), sin(2 * pi * s / 200)];
    e = 1e-9 * randn(RandStream("twister", "Seed", 7), n, 3);
    arc = actArc(t, sig + e);
    ref = actArc(t, sig);
end

function s = driverSeries(arc)
    s = struct("name", "beta", "t", arc.t, ...
        "value", sin(2 * pi * (0:numel(arc.t) - 1)' / 97), "unit", "deg");
end
