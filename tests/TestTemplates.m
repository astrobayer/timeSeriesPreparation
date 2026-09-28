classdef TestTemplates < matlab.unittest.TestCase
%TESTTEMPLATES  The QC template bank and its matched-filter detector, alone and in run.
%
%   DESCRIPTION
%     X-17 (CONCEPT 6.1 row 2; owner decisions 2026-09-26; scan PR #62).
%     qc.templateBank holds the thruster stacks of GRACE-FO C and D;
%     qc.detectTemplates finds them in a 3-axis residual by a matched
%     filter and a robust score, and run adds one layer per class when
%     cfg.qc.templates is true. The synthetic residuals are seeded white
%     noise of 1.5e-10 m/s^2 (the scan's y and z sigma) with templates
%     planted at scales 0.5, 1 and 2; the real day is DC-8, ACT1B and THR1B
%     of GRACE-FO D on 2020-01-04 from the DATAPOOL. Fault injection: a
%     negated template must not be detected.
%
%   COVERAGE
%     contract       - the bank's shape and counts; the output schema; run
%                      adds the layer only when asked.
%     reference      - planted templates on C and D are found at their
%                      samples with each scale within 5 sigma; on DC-8
%                      more than half of the detections lie within 5 s of
%                      a THR1B firing.
%     robustness     - the refusals; white noise with a NaN run gives no
%                      detection; a negated template gives none.
%     precision, speed, vectorisation, metamorphic - exempt: the filter is
%                      conv and a MAD, the bank is data.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-26 19:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function bankShape(testCase)
            b = timeSeriesPreparation.qc.templateBank();
            testCase.verifyEqual(string(fieldnames(b))', "thruster");
            testCase.verifyEqual(b.thruster.lags, (-60:60)');
            for sat = ["C" "D"]
                testCase.verifySize(b.thruster.(sat), [121 3], sat);
                testCase.verifyTrue(all(isfinite(b.thruster.(sat)), "all"), sat);
                testCase.verifyLessThan(min(b.thruster.(sat)(:, 2)), -1e-8, sat);
            end
            testCase.verifyEqual(b.thruster.C(:, 1), zeros(121, 1));
            testCase.verifyEqual([b.thruster.nEvents.C b.thruster.nEvents.D], [27117 24551]);
        end

        function outputSchema(testCase)
            [r, t] = planted("D", 1, 1500);
            [events, info] = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "D");
            schema = timeSeriesPreparation.qc.eventTable().Properties.VariableNames;
            testCase.verifyEqual(events.Properties.VariableNames, schema);
            testCase.verifyEqual(height(events), 1);
            testCase.verifyEqual([events.class events.axis events.source], ["impulse" "all" "unassigned"]);
            testCase.verifyEqual(string(fieldnames(info))', ["thruster" "classes" "layers" ...
                "eventClass" "satellite" "provenance"]);
            testCase.verifyEqual([info.classes info.layers info.eventClass info.satellite], ...
                ["thruster" "tplThruster" "thruster" "D"]);
            testCase.verifyEqual(string(fieldnames(info.thruster))', ["score" "mask" "sigma" ...
                "gain" "peak" "support" "nDetected"]);
            testCase.verifySize(info.thruster.score, [3000 1]);
            testCase.verifyClass(info.thruster.mask, "logical");
            testCase.verifyEqual(info.thruster.nDetected, 1);
        end

        function runLayerOnlyWhenAsked(testCase)
            [arc, ref] = runPair(1200, 600);
            res = timeSeriesPreparation.run(arc, Reference = ref);
            testCase.verifyFalse(isfield(res.arc.layers, "tplThruster"));
            testCase.verifyEmpty(res.diagnostics.templates);
            why = dictionary(res.diagnostics.skipped.stage, res.diagnostics.skipped.reason);
            testCase.verifyEqual(why("templates"), "cfg.qc.templates is false");
            cfg = set(timeSeriesPreparation.Config(arc), "qc", "templates", true);
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
            testCase.verifyEqual(res.diagnostics.stages(1:4), ["mask" "align" "qc" "templates"]);
            testCase.verifyTrue(res.arc.layers.tplThruster(600));
            tev = res.diagnostics.templates.events;
            testCase.verifyEqual(height(tev), 1);
            testCase.verifyTrue(any(res.flags.events.tStart == tev.tStart & res.flags.events.axis == "all"));
        end
    end

    methods (Test, TestTags = {'reference'})
        function plantedRecoveredC(testCase)
            recovered(testCase, "C");
        end

        function plantedRecoveredD(testCase)
            recovered(testCase, "D");
        end

        function realThrusterDay(testCase)
            [tt, ot, at] = readDay(testCase, "THR1B", "2020-01-04", "D");
            thr = timeSeriesPreparation.Arc(tt, ot, at);
            [t, obs, aux] = readDay(testCase, "ACT1B", "2020-01-04", "D");
            act = timeSeriesPreparation.Arc(t, obs, aux);
            lin = startsWith(act.names, "lin_accl_");
            testCase.assertEqual(nnz(lin), 3);
            on = startsWith(thr.names, "on_time_");
            fired = any(thr.obs(:, on) > 0, 2);
            n = nnz(fired);
            tf = utcOf(thr.t(fired));
            priors = timeSeriesPreparation.qc.eventTable(tf, tf, repmat("impulse", n, 1), ...
                repmat("all", n, 1), NaN(n, 1), NaN(n, 1), repmat("THR1B", n, 1), ones(n, 1));
            events = timeSeriesPreparation.qc.detectTemplates(act.obs(:, lin), Epoch = utcOf(act.t), ...
                Satellite = "D", Priors = priors);
            testCase.verifyGreaterThan(height(events), 0);
            testCase.verifyGreaterThan(mean(events.source == "THR1B"), 0.5, ...
                sprintf("%d of %d detections lie within 5 s of a THR1B firing.", ...
                nnz(events.source == "THR1B"), height(events)));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            [r, t] = planted("C", 1, 1500);
            f = @(varargin) timeSeriesPreparation.qc.detectTemplates(varargin{:});
            p = "timeSeriesPreparation:detectTemplates:";
            testCase.verifyError(@() f(r, Epoch = t, Satellite = "A"), p + "unknownSatellite");
            testCase.verifyError(@() f(r, Epoch = t), p + "unknownSatellite");
            testCase.verifyError(@() f(r(:, 1:2), Epoch = t, Satellite = "C"), p + "inputShape");
            testCase.verifyError(@() f(r, Epoch = t(1:10), Satellite = "C"), p + "inputShape");
            testCase.verifyError(@() f(r, Satellite = "C"), p + "inputEpoch");
            tz = t; tz.TimeZone = '';
            testCase.verifyError(@() f(r, Epoch = tz, Satellite = "C"), p + "inputEpoch");
            testCase.verifyError(@() f(r, Epoch = t, Satellite = "C", Threshold = 0), p + "inputRange");
            testCase.verifyError(@() f(r, Epoch = t, Satellite = "C", Priors = 1), p + "inputPriors");
        end

        function noiseOnly(testCase)
            K = 86400;
            r = 1.5e-10 * randn(RandStream("twister", "Seed", 11), K, 3);
            r(40000:40100, 2) = NaN;
            t = datetime(2020, 1, 4, "TimeZone", "UTC") + seconds((0:K - 1)');
            [events, info] = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "D");
            testCase.verifyEqual(height(events), 0);
            testCase.verifyFalse(any(info.thruster.mask));
            testCase.verifyEqual(info.thruster.score(40000:40100), zeros(101, 1));
        end

        function wrongSign(testCase)
            [r, t] = planted("D", -1, 1500);
            events = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "D");
            testCase.verifyEqual(height(events), 0, "A negated template was detected.");
        end
    end
end

% ------------------------------------------------------------------------

function recovered(testCase, sat)
% Scales 0.5, 1 and 2 at samples 500, 1500 and 2500: three events at
% their samples, each scale within 5 sigma.
    scales = [0.5 1 2];
    [r, t] = planted(sat, scales, [500 1500 2500]);
    [events, info] = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = sat);
    testCase.assertEqual(height(events), 3);
    testCase.verifyEqual(events.tStart, t([500 1500 2500]' + info.thruster.support(1)));
    testCase.verifyEqual(events.tEnd, t([500 1500 2500]' + info.thruster.support(2)));
    hp = info.thruster.peak;
    testCase.verifyLessThanOrEqual(abs(events.amplitude - scales' * hp), 5 * events.sigma, ...
        sat + ": a planted scale is off by more than 5 sigma.");
end

function [r, t] = planted(sat, scales, centers)
% White noise of 1.5e-10 m/s^2 on 3000 x 3 at 1 Hz with the thruster
% template of SAT times each scale, centred at each sample.
    b = timeSeriesPreparation.qc.templateBank();
    r = 1.5e-10 * randn(RandStream("twister", "Seed", 3), 3000, 3);
    for k = 1:numel(centers)
        rows = centers(k) - 60:centers(k) + 60;
        r(rows, :) = r(rows, :) + scales(k) * b.thruster.(sat);
    end
    t = datetime(2020, 1, 4, "TimeZone", "UTC") + seconds((0:2999)');
end

function [arc, ref] = runPair(n, center)
% A 1 Hz ACT1B-like arc of GRACE-FO C: three sinusoids plus white noise
% of 1.5e-10 and the C thruster template at CENTER; the sinusoids alone.
    t0 = int64(7306 * 86400 - 43200 + 18) * int64(1e9);
    t = t0 + int64(0:n - 1)' * int64(1e9);
    s = (0:n - 1)';
    sig = 1e-7 * [sin(2 * pi * s / 300), cos(2 * pi * s / 300), sin(2 * pi * s / 200)];
    x = sig + 1.5e-10 * randn(RandStream("twister", "Seed", 7), n, 3);
    b = timeSeriesPreparation.qc.templateBank();
    rows = center - 60:center + 60;
    x(rows, :) = x(rows, :) + b.thruster.C;
    arc = actArc(t, x);
    ref = actArc(t, sig);
end

function arc = actArc(t, obs)
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    units = struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2');
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", units, "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end

function e = utcOf(t)
% As run: UTC of int64 GPS nanoseconds past 2000-01-01 12:00:00 GPS.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end

function [t, obs, aux] = readDay(testCase, product, day, sat)
% The DATAPOOL day file (as TestDefectCatalogue); incomplete without it.
    pool = string(getenv("READING_DATA_POOL"));
    testCase.assumeNotEmpty(char(pool), "READING_DATA_POOL is not set (X-17 needs the DATAPOOL).");
    testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), "gracefoReading is not on the path.");
    folder = fullfile(pool, "GRACEFO", "L1B", "RL04", extractBefore(day, 5), day);
    hits = dir(fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    testCase.assertNotEmpty(hits, "X-17 file missing: " + fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    [t, obs, aux] = gracefoReading.readL1b(string(fullfile(hits(1).folder, hits(1).name)), "TimeFormat", "gpsns");
end
