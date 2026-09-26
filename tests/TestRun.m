classdef TestRun < matlab.unittest.TestCase
%TESTRUN  run: the result-field contract, input-driven stages, equality to the direct calls.
%
%   DESCRIPTION
%     run adds no arithmetic of its own, so its numbers are held to the
%     stages it calls: every stage's output in the result must equal the
%     direct call of that stage on the same inputs (isequaln, NaN = NaN).
%     The arcs are synthetic ACT1B arcs on GPS epochs from 2020-01-02
%     00:00:00 UTC (GPS 00:00:18, 18 leap seconds): three sinusoids of
%     1e-7 m/s2 plus white noise of 1e-9 m/s2 (seeded), with the sinusoids
%     alone as the reference, so the residual is the noise and
%     checkAlignment finds no lag. The UTC conversion is checked by a spike
%     planted at 300 s, whose qc event must carry 00:05:00 UTC. The
%     contract pins the seven result fields of CONCEPT 4 and the fields of
%     diagnostics and flags; fault injection: a result with a field added or
%     removed must fail the pin.
%
%   COVERAGE
%     contract       - the result fields (and the pin fails on an added or
%                      removed field); a bare arc runs mask and fill only
%                      and lists the other eight stages as skipped; the
%                      Config used is the one returned; provenance ends
%                      with the run entry; each skipped stage states why.
%     reference      - mask, align, qc, residual and noise equal their
%                      direct calls; the qc event of a planted spike is at
%                      00:05:00 UTC; the CRN-filtered reference equals
%                      crnApply; gate, bootstrap, crossval and correlation
%                      equal their direct calls; collocation fills as fill.
%     robustness     - an arc array (campaignDeferred), a stage's refusal
%                      (observability:sizeMismatch) and the minimum-data
%                      gate (observability:insufficientData) stop the run.
%     precision, speed, vectorisation, metamorphic - exempt: run adds no
%                      arithmetic; each stage's tests hold these.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-25 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        Fields = ["arc" "reference" "diagnostics" "correlation" "flags" "config" "provenance"]
    end

    methods (Test, TestTags = {'contract'})
        function resultFieldsPinned(testCase)
            res = timeSeriesPreparation.run(pair(120));
            testCase.verifyEqual(string(fieldnames(res))', testCase.Fields);
            testCase.verifyEqual(string(fieldnames(res.diagnostics))', ["stages" "skipped" ...
                "mask" "alignment" "qc" "residual" "noise" "gate" "bootstrap" "crossval" "fill" "cache"]);
            testCase.verifyEqual(string(fieldnames(res.flags))', ...
                ["events" "alignment" "weightFraction" "nFilled"]);
            testCase.verifyClass(res.arc, "timeSeriesPreparation.Arc");
            % fault injection: the pin must fail on an added or a removed field
            added = res; added.extra = 1;
            testCase.verifyNotEqual(string(fieldnames(added))', testCase.Fields);
            testCase.verifyNotEqual(string(fieldnames(rmfield(res, "flags")))', testCase.Fields);
        end

        function bareArcRunsMaskAndFill(testCase)
            arc = pair(300);
            res = timeSeriesPreparation.run(arc);
            testCase.verifyEqual(res.diagnostics.stages, ["mask" "fill"]);
            testCase.verifyEqual(res.diagnostics.skipped.stage', ["crn" "align" "qc" "noise" ...
                "gate" "bootstrap" "crossval" "correlation"]);
            testCase.verifyEqual(res.arc.obs, arc.obs);
            testCase.verifyEmpty(res.reference);
            testCase.verifyEmpty(res.correlation);
            testCase.verifyEmpty(res.diagnostics.qc);
            testCase.verifyEqual(res.diagnostics.fill.method, "none");
            testCase.verifyEqual(height(res.flags.events), 0);
            testCase.verifyEqual([res.flags.weightFraction res.flags.nFilled], [1 0]);
        end

        function configIsTheOneUsed(testCase)
            arc = whiteArc(300);
            res = timeSeriesPreparation.run(arc);
            testCase.verifyEqual(res.config, toStruct(timeSeriesPreparation.Config(arc)));
            cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
            res = timeSeriesPreparation.run(arc, Config = cfg);
            testCase.verifyEqual(res.config, toStruct(cfg));
            testCase.verifyEqual(res.diagnostics.stages, ["mask" "noise" "fill"]);
            testCase.verifyEqual(res.diagnostics.noise.order, [1 0]);
        end

        function provenanceEndsWithRun(testCase)
            u = false(300, 1); u(10:20) = true;
            res = timeSeriesPreparation.run(pair(300), User = u);
            p = res.provenance(end);
            testCase.verifyEqual(p.stage, "run");
            testCase.verifyEqual(p.detail.stages, res.diagnostics.stages);
            testCase.verifyEqual(p.detail.skipped, res.diagnostics.skipped.stage');
            testCase.verifyMatches(p.detail.configHash, "^[0-9a-f]{8}$");
            testCase.verifyTrue(isequaln(res.provenance, res.arc.provenance));
            testCase.verifyTrue(any([res.provenance.stage] == "mask"));
            testCase.verifyEqual(res.arc.layers.user, u);
        end

        function skippedStagesSayWhy(testCase)
            [arc, ref] = pair(300);
            cfg = set(set(timeSeriesPreparation.Config(arc), "fill", "method", "collocation"), ...
                "fill", "maxGap", 5);
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, Drivers = driverSeries(arc));
            why = reasons(res);
            testCase.verifyEqual(why("crn"), "cfg.run.filterReference not stated");
            testCase.verifyEqual(why("fill"), "collocation needs the noise stage (cfg.noise.order)");
            testCase.verifyEqual(why("correlation"), "pre-whitening needs the noise stage (cfg.noise.order)");
            res = timeSeriesPreparation.run(arc, Reference = ref, Drivers = driverSeries(arc), ...
                Config = set(set(cfg, "noise", "order", [1 0]), "run", "filterReference", false));
            why = reasons(res);
            testCase.verifyEqual(why("crn"), "cfg.run.filterReference is false");
            testCase.verifyTrue(startsWith(why("fill"), "the noise model is the residual's"));
            testCase.verifyEqual(why("correlation"), "cfg.drivers.maxLag not stated");
        end
    end

    methods (Test, TestTags = {'reference'})
        function stagesEqualDirectCalls(testCase)
            [arc, ref] = pair(600);
            u = false(600, 1); u(100:110) = true;
            cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
            res = timeSeriesPreparation.run(arc, Reference = ref, User = u, Config = cfg);
            testCase.verifyEqual(res.diagnostics.stages, ["mask" "align" "qc" "noise" "fill"]);

            m = timeSeriesPreparation.mask(arc, User = u);
            r = timeSeriesPreparation.align(m, ref);
            testCase.verifyTrue(isequaln(res.reference.obs, r.obs));
            rep = timeSeriesPreparation.checkAlignment(m, ref);
            testCase.verifyEqual(res.flags.alignment, rep.verdict);
            [qm, ev] = timeSeriesPreparation.qc.screen(m.obs, r.obs, utc(m.t));
            testCase.verifyEqual(res.diagnostics.qc.mask, qm);
            testCase.verifyTrue(isequaln(res.flags.events(:, 3:end), ev(:, 3:end)));
            m = addLayer(addLayer(m, "alignGap", r.layers.alignGap), "qc", any(qm, 2));
            testCase.verifyEqual(res.arc.layers, m.layers);
            testCase.verifyEqual(res.arc.weights, m.weights);

            s = derive(m, m.t, timeSeriesPreparation.qc.residuals(m.obs, r.obs), "residual");
            for name = string(fieldnames(m.layers))'
                s = addLayer(s, name, m.layers.(name));
            end
            testCase.verifyTrue(isequaln(res.diagnostics.residual.obs, s.obs));
            testCase.verifyEqual(res.diagnostics.residual.weights, s.weights);
            testCase.verifyTrue(isequaln(res.diagnostics.noise, timeSeriesPreparation.noise(s, [1 0])));
        end

        function qcSpikeEventInUtc(testCase)
            [arc, ref] = pair(600);
            x = arc.obs;
            x(301, 1) = x(301, 1) + 1e-6;           % 300 s after 00:00:00 UTC
            res = timeSeriesPreparation.run(actArc(arc.t, x), Reference = ref);
            testCase.verifyTrue(res.arc.layers.qc(301));
            ev = res.flags.events;
            at = datetime(2020, 1, 2, 0, 5, 0, "TimeZone", "UTC");
            k = find(ev.class == "outlier" & ev.axis == "x" & abs(seconds(ev.tStart - at)) < 1e-6);
            testCase.verifyNumElements(k, 1);
        end

        function crnFilteredReference(testCase)
            n = 4000;                                % 400 s at 10 Hz
            t10 = epochs(n, 1e8);
            tt = (0:n - 1)' / 10;
            sig = 1e-7 * [sin(2 * pi * tt / 100), cos(2 * pi * tt / 100), sin(2 * pi * tt / 150)];
            ref = actArc(t10, sig);
            arc = actArc(t10(1:10:end), sig(1:10:end, :));
            cfg = set(timeSeriesPreparation.Config(arc), "run", "filterReference", true);
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            testCase.verifyEqual(res.diagnostics.stages(1:4), ["mask" "crn" "align" "qc"]);
            direct = timeSeriesPreparation.crnApply(ref, timeSeriesPreparation.crnKernel("ACC"), ...
                OutputEpochs = arc.t);
            testCase.verifyTrue(isequaln(res.reference.obs, direct.obs));
            testCase.verifyEqual(res.arc.layers.alignGap, all(isnan(direct.obs), 2));
            testCase.verifyGreaterThan(nnz(~res.arc.layers.alignGap), 200);
        end

        function laterStagesEqualDirectCalls(testCase)
            [arc, ref] = pair(600);
            cfg = timeSeriesPreparation.Config(arc);
            cfg = set(set(cfg, "noise", "order", [1 0]), "drivers", "maxLag", 5);
            cfg = set(set(cfg, "unc", "nBoot", 50), "unc", "blockLength", 10);
            series = driverSeries(arc);
            stat = @(z) mean(z, 1, "omitnan");
            loss = @(a, b) mean(b, 1, "omitnan") - mean(a, 1, "omitnan");
            X = [ones(600, 1), (1:600)' / 600];
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, Drivers = series, ...
                Statistic = stat, Loss = loss, Design = X, Names = ["bias" "drift"]);
            testCase.verifyEqual(res.diagnostics.stages, ["mask" "align" "qc" "noise" "gate" ...
                "bootstrap" "crossval" "fill" "correlation"]);

            s = res.diagnostics.residual;
            x = s.obs;
            x(s.weights == 0, :) = NaN;
            testCase.verifyTrue(isequaln(res.diagnostics.gate, timeSeriesPreparation.observability( ...
                res.arc, X, Names = ["bias" "drift"])));
            testCase.verifyTrue(isequaln(res.diagnostics.bootstrap.stat, ...
                timeSeriesPreparation.bootstrap(x, stat, NBoot = 50, BlockLength = 10)));
            testCase.verifyTrue(isequaln(res.diagnostics.crossval.loss, ...
                timeSeriesPreparation.crossval(x, loss)));
            drv = timeSeriesPreparation.drivers(res.arc, series);
            testCase.verifyTrue(isequaln(res.correlation, timeSeriesPreparation.correlate(s, drv, ...
                res.diagnostics.noise, 5, NBoot = 50, BlockLength = 10)));
        end

        function collocationFillsAsFill(testCase)
            x = 1e-9 * filter(1, [1 -0.8], randn(RandStream("twister", "Seed", 3), 600, 1));
            x(200:204) = NaN;
            arc = actArc(epochs(600, 1e9), x);
            cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
            cfg = set(set(cfg, "fill", "method", "collocation"), "fill", "maxGap", 10);
            res = timeSeriesPreparation.run(arc, Config = cfg);
            nm = timeSeriesPreparation.noise(arc, [1 0]);
            [f, info] = timeSeriesPreparation.fill(arc, Method = "collocation", Model = nm, MaxGap = 10);
            testCase.verifyTrue(isequaln(res.arc.obs, f.obs));
            testCase.verifyEqual(res.arc.filled, f.filled);
            testCase.verifyTrue(isequaln(res.diagnostics.fill, info));
            testCase.verifyEqual(res.flags.nFilled, 5);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusalsStopTheRun(testCase)
            arc = pair(300);
            testCase.verifyError(@() timeSeriesPreparation.run([arc arc]), ...
                "timeSeriesPreparation:run:campaignDeferred");
            testCase.verifyError(@() timeSeriesPreparation.run(arc, Design = ones(10, 1)), ...
                "timeSeriesPreparation:observability:sizeMismatch");
        end

        function minimumDataGateStopsRun(testCase)
            u = false(300, 1); u(1:200) = true;       % a third of the arc survives
            testCase.verifyError(@() timeSeriesPreparation.run(pair(300), User = u, ...
                Design = ones(300, 1)), "timeSeriesPreparation:observability:insufficientData");
        end
    end
end

% ------------------------------------------------------------------------

function t = epochs(n, stepNs)
% n epochs from 2020-01-02 00:00:00 UTC = 00:00:18 GPS, stepNs apart;
% 7306 days after 2000-01-01, the GPS-ns origin being 12:00:00 that day.
    t0 = int64(7306 * 86400 - 43200 + 18) * int64(1e9);
    t = t0 + int64(0:n - 1)' * int64(stepNs);
end

function e = utc(t)
% UTC of epochs on 2020-01-02 (no leap second that day), for the direct calls.
    e = datetime(2020, 1, 2, "TimeZone", "UTC") + seconds(double(t - epochs(1, 1)) * 1e-9);
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

function arc = whiteArc(n)
    arc = actArc(epochs(n, 1e9), 1e-9 * randn(RandStream("twister", "Seed", 5), n, 1));
end

function s = driverSeries(arc)
    s = struct("name", "beta", "t", arc.t, ...
        "value", sin(2 * pi * (0:numel(arc.t) - 1)' / 97), "unit", "deg");
end

function why = reasons(res)
    why = dictionary(res.diagnostics.skipped.stage, res.diagnostics.skipped.reason);
end
