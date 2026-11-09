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
%     midnights. V-17 (CONCEPT 9.3; owner decision 2026-09-25): ITSG is
%     about 3 s late against ACT1B (x and z, 2.5-10 mHz, C and D, two
%     days) and band-limited to about 10 mHz, from an undocumented step of
%     its 10 s product (README 2025-10-16 and P-2 App. A read: TU Graz's
%     own ACT1B is timed like JPL's). The test, as the caller, moves the
%     ITSG epochs 3 s earlier; run never shifts. At the 8 640
%     shifted epochs on the ACT1B day, where align takes the reference bit
%     for bit, the kept samples of each axis are fitted as ref = b + s *
%     obs, V-4's direction (CI 2026-09-25: the other direction gave 0.906
%     / 1.032 / 1.058, r^2 / s of V-4's values). Required, from V-4's
%     0.984 / 0.973 / 0.955 and 1.066 / 0.915 / 0.864:
%       - the delay of ITSG against ACT1B over 2.5-10 mHz (cross-spectral
%         phase, bins of coherence > 0.5, least squares weighted by the
%         coherence) below 1 s on x and z after the shift; y is logged
%         (too little signal). run's full-band checkAlignment lags are
%         logged, not asserted: for this pair they measure low-frequency
%         shape, not timing, and have the opposite sign (V-17);
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
%     Classic days (X-13, owner decision 2026-09-27): ACC1B and THR1B of
%     2008-07-02, GRACE A and B (DATAPOOL GRACE\L1B\JPL\RL02, binary),
%     through run with QualFlags and Thrusters and no Reference. Units
%     and qualflg meanings come from gracefoReading >= 1.3.0 (JPL D-22027
%     v1.3 chapter 6). Required: mission GRACE, release 02, m/s2; stages
%     mask and fill, align and qc skipped for want of a reference; layers
%     qualflg_b5-b7 equal to the bits decodeQualFlags gives, meaning
%     "filled data"; a thr layer from at least one firing; weight 0
%     exactly where a layer removes; epochs and kept observations
%     unchanged.
%
%   COVERAGE
%     reference      - the real day, ITSG moved by V-17, meets the V-4
%                      thresholds; the synthetic arc's planted truth is
%                      recovered; the classic days of A and B run end to
%                      end with the classic presets.
%     contract, precision, robustness, metamorphic, vectorisation, speed -
%                      exempt: TestRun holds run's contract and each
%                      stage's tests the rest.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-11-08 23:00 (CET, UTC+01:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        V4Corr  = [0.95 0.95 0.93]      % thresholds; measured 0.984 / 0.973 / 0.955
        V4Scale = [1.066 0.915 0.864]   % V-4, ref = b + s * obs
        ItsgDelay = int64(3e9)          % V-17: ITSG late against ACT1B, ns
    end

    methods (Test, TestTags = {'reference'})
        function realDayAgainstItsg(testCase)
            pool = dataPoolRoot(testCase, "V-4");
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
            % V-17: ITSG is ~3 s late against ACT1B; the caller moves it, run never does.
            ref = timeSeriesPreparation.Arc(ti - testCase.ItsgDelay, gi, itsgAux(auxi, names, files(1)));

            res = timeSeriesPreparation.run(arc, Reference = ref, QualFlags = aux);
            testCase.verifyEqual(res.diagnostics.stages(1:3), ["mask" "align" "qc"]);
            testCase.log(matlab.unittest.Verbosity.Terse, sprintf("run's full-band lags " + ...
                "(V-17: low-frequency shape, not timing): %+.2f / %+.2f / %+.2f s", ...
                res.diagnostics.alignment.lag));

            [on, k] = ismember(ref.t, res.arc.t);
            testCase.assertEqual(nnz(on), 8640, "ITSG epochs on the ACT1B day (V-4: 8 640).");
            k = k(on);
            y = res.arc.obs(k, :);
            x = res.reference.obs(k, :);
            keep = res.arc.weights(k) > 0 & all(isfinite([x y]), 2);
            testCase.verifyGreaterThan(nnz(keep), 0.9 * 8640);
            tau = bandDelay(y, x, 10);
            testCase.log(matlab.unittest.Verbosity.Terse, sprintf( ...
                "V-17 band delay after the shift: %+.2f / %+.2f / %+.2f s (y reported)", tau));
            testCase.verifyLessThan(abs(tau([1 3])), [1 1], "x and z delay, 2.5-10 mHz, after the V-17 shift");
            [s, r] = fitScale(y(keep, :), x(keep, :));      % ref = b + s * obs, as V-4
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

        function classicDaysEndToEnd(testCase)
            % X-13: ACC1B and THR1B of 2008-07-02 (classic GRACE, binary,
            % RL02), A and B, through run with QualFlags and Thrusters.
            pool = dataPoolRoot(testCase, "X-13");
            testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), ...
                "gracefoReading is not on the path.");
            names = ["lin_accl_x" "lin_accl_y" "lin_accl_z"];
            for sat = ["A" "B"]
                [t, a, aux] = gracefoReading.readL1b(classicFile(testCase, pool, "ACC1B", sat), ...
                    "TimeFormat", "gpsns");
                arc = timeSeriesPreparation.Arc(t, a, aux, Columns = names);
                testCase.verifyEqual([arc.mission arc.release arc.satellite], ["GRACE" "02" sat]);
                testCase.verifyEqual(arc.units, repmat("m/s2", 1, 3), "Units from gracefoReading >= 1.3.0.");
                [tt, ot, at] = gracefoReading.readL1b(classicFile(testCase, pool, "THR1B", sat), ...
                    "TimeFormat", "gpsns");
                thr = timeSeriesPreparation.Arc(tt, ot, at);

                res = timeSeriesPreparation.run(arc, QualFlags = aux, Thrusters = thr);
                testCase.verifyEqual(res.diagnostics.stages, ["mask" "fill"], sat);
                sk = res.diagnostics.skipped;
                testCase.verifyEqual(sk.reason(ismember(sk.stage, ["align" "qc"])), ...
                    ["no Reference"; "no Reference"], sat);

                bits = gracefoReading.decodeQualFlags(aux);
                q = res.diagnostics.mask.qualflg;
                for b = [5 6 7]
                    testCase.verifyEqual(res.arc.layers.("qualflg_b" + b), bits(:, b + 1), sat + " bit " + b);
                    testCase.verifyTrue(contains(q.meaning(b + 1), "filled data"), ...
                        sat + " bit " + b + ": " + q.meaning(b + 1));
                end
                testCase.verifyEqual(q.removes', ismember(0:height(q) - 1, [5 6 7]), sat);
                testCase.verifyGreaterThan(res.diagnostics.mask.thrusters.firings, 0, sat);
                testCase.verifyTrue(any(res.arc.layers.thr), sat);
                testCase.verifyEqual(res.arc.weights == 0, ...
                    any(bits(:, 6:8), 2) | res.arc.layers.thr, sat);

                kept = res.arc.weights > 0;
                testCase.verifyGreaterThan(nnz(kept), 0, sat);
                testCase.verifyEqual(res.arc.t, arc.t, sat);
                testCase.verifyEqual(res.arc.obs(kept, :), arc.obs(kept, :), sat);
                testCase.verifyFalse(any(res.arc.filled), sat + ": fill method ""none"" fills nothing.");
                testCase.log(matlab.unittest.Verbosity.Terse, sprintf( ...
                    "X-13 %s: %d epochs, %d removed (qualflg %d, thr %d; %d firings)", sat, ...
                    numel(t), nnz(~kept), nnz(any(bits(:, 6:8), 2)), nnz(res.arc.layers.thr), ...
                    res.diagnostics.mask.thrusters.firings));
            end
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

function f = classicFile(testCase, pool, product, sat)
% The DATAPOOL file of classic PRODUCT of 2008-07-02 for SAT (RL02, binary).
    folder = fullfile(pool, "GRACE", "L1B", "JPL", "RL02", "2008");
    hits = dir(fullfile(folder, "**", product + "_2008-07-02_" + sat + "_*.dat"));
    testCase.assertNotEmpty(hits, "Missing " + fullfile(folder, "**", ...
        product + "_2008-07-02_" + sat + "_*.dat"));
    f = string(fullfile(hits(1).folder, hits(1).name));
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

function tau = bandDelay(x, y, dt)
% Delay of y against x per column, y(t) = x(t - tau), from the Welch
% cross-spectrum (Hann segments of 512 samples, 50 % overlap, each
% linearly detrended) over 2.5-10 mHz: phase P = -2 pi f tau, fitted by
% least squares over the bins of coherence C > 0.5, weighted by C.
    n = 512;
    h = 0.5 * (1 - cos(2 * pi * (0:n - 1)' / n));
    D = [ones(n, 1), (1:n)'];
    f = (1:n / 2 - 1)' / (n * dt);
    band = f >= 2.5e-3 & f <= 10e-3;
    tau = NaN(1, size(x, 2));
    for m = 1:size(x, 2)
        Sxx = 0; Syy = 0; Sxy = 0;
        for s0 = 1:n / 2:size(x, 1) - n + 1
            xs = x(s0:s0 + n - 1, m); ys = y(s0:s0 + n - 1, m);
            if any(~isfinite([xs; ys])), continue; end
            X = fft(h .* (xs - D * (D \ xs)));
            Y = fft(h .* (ys - D * (D \ ys)));
            Sxx = Sxx + abs(X) .^ 2; Syy = Syy + abs(Y) .^ 2; Sxy = Sxy + conj(X) .* Y;
        end
        k = 2:n / 2;
        C = abs(Sxy(k)) .^ 2 ./ (Sxx(k) .* Syy(k));
        P = angle(Sxy(k));
        w = band & C > 0.5;
        tau(m) = -sum(C(w) .* f(w) .* P(w)) / sum(C(w) .* 2 * pi .* f(w) .^ 2);
    end
end
