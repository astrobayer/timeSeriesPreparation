classdef TestIntegration < matlab.unittest.TestCase
%TESTINTEGRATION  run end to end: a real day against ITSG, and a synthetic arc with planted truth.
%
%   DESCRIPTION
%     The release-1.0 integration tests of X-10 (owner decisions
%     2026-09-24 and 2026-09-25).
%
%     Real day: ACT1B GRACE-C of 2020-01-02 (DATAPOOL, RL04) with its
%     qualflg against ITSG nonConservativeForces of the same day
%     (GRACEFO-1, 10 s, SRF, calibrated accelerometer data; V-4), through
%     run with the ACT1B preset. The ITSG file holds 8 641 epochs, both
%     midnights; at the 8 640 of them on the ACT1B day, where align takes
%     the reference bit for bit, the kept samples of each axis are fitted
%     as obs = b + s * ref by least squares, the convention of qc.residuals
%     and of V-4 (on 2020-01-01 C the z axis gives s = 0.919 this way and
%     1.075 the other way; V-4's z is 0.864). Required, from V-4's
%     measurement of 0.984 / 0.973 / 0.955 and 1.066 / 0.915 / 0.864:
%       - checkAlignment's lag below 1 s on every axis;
%       - correlation >= 0.95 / 0.95 / 0.93;
%       - each scale within 5 % of V-4's (owner decision 2026-09-25).
%
%     Synthetic arc: six hours at 1 Hz, three axes, obs = b + s * ref +
%     white noise (1e-10 m/s2), ref two orbital harmonics of 1e-8 m/s2 at
%     10 s; three spikes of 5e-9 m/s2 and a 30 s gap planted. run, given
%     the planted Bias and Scale and noise order [1 0], must mask the
%     spikes (layer qc), report the gap on every axis (fill), find no lag,
%     model the noise at its planted level (sigma2 within 5 %) and leave
%     data from which the fit recovers b and s (tolerances from the noise,
%     sigma_s about 1e-4).
%
%   COVERAGE
%     reference      - the real day meets the V-4 thresholds; the synthetic
%                      arc's planted truth is recovered.
%     contract, precision, robustness, metamorphic, vectorisation, speed -
%                      exempt: TestRun holds run's contract and each
%                      stage's tests the rest.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-25 13:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        V4Corr  = [0.95 0.95 0.93]      % thresholds; measured 0.984 / 0.973 / 0.955
        V4Scale = [1.066 0.915 0.864]   % V-4, obs = b + s * ref
    end

    methods (Test, TestTags = {'reference'})
        function realDayAgainstItsg(testCase)
            pool = string(getenv("READING_DATA_POOL"));
            testCase.assumeNotEmpty(char(pool), "READING_DATA_POOL is not set.");
            testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), ...
                "gracefoReading is not on the path.");
            day = datetime(2020, 1, 2);

            act = fullfile(pool, "GRACEFO", "L1B", "RL04", "2020", "2020-01-02", ...
                "ACT1B_2020-01-02_C_04.txt");
            testCase.assertTrue(isfile(act), "Missing " + act);
            [t, a, aux] = gracefoReading.readL1b(act, "TimeFormat", "gpsns");
            names = ["lin_accl_x" "lin_accl_y" "lin_accl_z"];
            arc = timeSeriesPreparation.Arc(t, a, aux, Columns = names);

            files = gracefoReading.findItsgFiles(fullfile(pool, "GRACEFO-1"), ...
                "nonConservativeForces", DateRange = [day day], Satellite = "GRACEFO-1");
            testCase.assertNotEmpty(files, "No ITSG nonConservativeForces of 2020-01-02 below " + ...
                fullfile(pool, "GRACEFO-1"));
            [ti, gi, auxi] = gracefoReading.readItsgProduct(files(1), TimeFormat = "gpsns");
            ref = timeSeriesPreparation.Arc(ti, gi, itsgAux(auxi, names, files(1)));

            res = timeSeriesPreparation.run(arc, Reference = ref, QualFlags = aux);
            testCase.verifyEqual(res.diagnostics.stages(1:3), ["mask" "align" "qc"]);
            testCase.verifyLessThan(abs(res.diagnostics.alignment.lag), [1 1 1]);

            [on, k] = ismember(ref.t, res.arc.t);
            testCase.assertEqual(nnz(on), 8640, "ITSG epochs on the ACT1B day (V-4: 8 640).");
            k = k(on);
            y = res.arc.obs(k, :);
            x = res.reference.obs(k, :);
            keep = res.arc.weights(k) > 0 & all(isfinite([x y]), 2);
            testCase.verifyGreaterThan(nnz(keep), 0.9 * 8640);
            [s, r] = fitScale(x(keep, :), y(keep, :));
            testCase.verifyGreaterThanOrEqual(r, testCase.V4Corr);
            testCase.verifyLessThanOrEqual(abs(s ./ testCase.V4Scale - 1), 0.05 * [1 1 1]);
        end

        function syntheticTruthRecovered(testCase)
            n = 21600;
            b = [2e-7 -1e-7 5e-8];
            s = [0.96 1.02 0.90];
            t = epochs(n, 1e9);
            u = (0:n - 1)' * 2 * pi / 5640;             % orbital argument, 1 Hz
            truth = 1e-8 * [sin(u) + 0.3 * cos(2 * u), cos(u), sin(u + 1) - 0.2 * sin(2 * u)];
            obs = b + s .* truth + 1e-10 * randn(RandStream("twister", "Seed", 11), n, 3);
            spikes = [4000 9001 15003];
            obs(spikes(1), 1) = obs(spikes(1), 1) + 5e-9;
            obs(spikes(2), 2) = obs(spikes(2), 2) - 5e-9;
            obs(spikes(3), 3) = obs(spikes(3), 3) + 5e-9;
            gap = 12001:12030;
            obs(gap, :) = NaN;
            arc = actArc(t, obs, "ACT1B_2020-01-02_C_04.txt", "ACT1B");
            ref = actArc(t(1:10:end), truth(1:10:end, :), "reference.txt", "reference");

            cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
            res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg, Bias = b, Scale = s);
            testCase.verifyEqual(res.diagnostics.stages, ["mask" "align" "qc" "noise" "fill"]);
            testCase.verifyEqual(res.flags.alignment, ["aligned" "aligned" "aligned"]);
            testCase.verifyTrue(all(res.arc.layers.qc(spikes)), "Every planted spike is masked.");

            g = res.diagnostics.fill.gaps;
            for m = 1:3
                hit = g.axis == arc.names(m) & g.first == gap(1) & g.last == gap(end);
                testCase.verifyEqual(nnz(hit), 1, "The gap on " + arc.names(m));
            end
            testCase.verifyEqual(res.diagnostics.noise.sigma2, 1e-20 * [1 1 1], "RelTol", 0.05);

            keep = res.arc.weights > 0 & all(isfinite([res.arc.obs res.reference.obs]), 2);
            [sFit, ~, bFit] = fitScale(res.reference.obs(keep, :), res.arc.obs(keep, :));
            testCase.verifyEqual(sFit, s, "AbsTol", 5e-4);
            testCase.verifyEqual(bFit, b, "AbsTol", 5e-12);
        end
    end
end

% ------------------------------------------------------------------------

function [s, r, b] = fitScale(x, y)
% Per axis, y = b + s * x by least squares, and the correlation of x and y.
    M = size(y, 2);
    s = zeros(1, M); b = zeros(1, M); r = zeros(1, M);
    for m = 1:M
        p = [ones(size(x, 1), 1), x(:, m)] \ y(:, m);
        b(m) = p(1);
        s(m) = p(2);
        c = corrcoef(x(:, m), y(:, m));
        r(m) = c(1, 2);
    end
end

function aux = itsgAux(auxi, names, file)
% Arc's aux for the ITSG columns x, y, z, named as the ACT1B columns they
% pair with in align (both in the SRF); units as the file header states.
    c = cellstr(names);
    units = struct();
    for k = 1:numel(c)
        units.(c{k}) = char(auxi.obsUnits{k});
    end
    aux = struct("obsNames", {c}, "variableNames", {c}, "variableFieldNames", {c}, ...
        "variableUnits", units, "fileName", char(file), "product", "nonConservativeForces");
end

function t = epochs(n, stepNs)
% n epochs from 2020-01-02 00:00:18 GPS, stepNs apart.
    t0 = int64(7306 * 86400 - 43200 + 18) * int64(1e9);
    t = t0 + int64(0:n - 1)' * int64(stepNs);
end

function arc = actArc(t, obs, fileName, product)
    c = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    units = struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2');
    aux = struct("obsNames", {c}, "variableNames", {c}, "variableFieldNames", {c}, ...
        "variableUnits", units, "fileName", fileName, "product", product);
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end
