classdef TestDefectCatalogue < matlab.unittest.TestCase
%TESTDEFECTCATALOGUE  D-9 (V-12, ORC-11): each defect class on its real day, three synthetic.
%
%   DESCRIPTION
%     HANDOVER X-05 PR-A records the catalogue: file, epoch range and
%     expected verdict per class, found by the scans of 2020-01 and
%     2020-07 (throwaway PRs #49, #50). Each reference test reads its day
%     from the DATAPOOL (DATAPOOL, else READING_DATA_POOL; GRACEFO\L1B\RL04) with
%     gracefoReading.readL1b and checks the recorded numbers first, so a
%     changed file fails loudly, then the verdict of this toolbox. Without
%     a pool variable or gracefoReading the tests are incomplete, never passed.
%     Seconds are GPS seconds of the file's day.
%       DC-1  GRACE-D safe mode: ACT1B D 2020-01-18 ends at 18229 s, the
%             01-19 file holds no data, 01-22 starts at 43385 s; the
%             TN-01a window (01-18 05:05 to 01-22 12:05 UTC, i.e. GPS + 18
%             s) removes 01-22 up to 43518 s and nothing after.
%       DC-2  KBR1B 2020-01-14 82235 s to 2020-01-15 4675 s is one gap of
%             findGaps across the day boundary, longer than the 21-s L1B
%             fill limit.
%       DC-3  KBR1B 2020-01-08: gaps after 70170 (740 s), 78290 (610),
%             79215 (75), 82025 (100); 2020-07-09 after 81680 (965).
%       DC-4  KBR1B 2020-01-14: K_B_SNR 288 at 82150 s is removed by the
%             "snr" layer (0.5 of the median); 2020-07-12 at 61455 s is not.
%       DC-5  KBR1B 2020-07-01 and 07-09: one phase break (bit 0) each,
%             removed; the epoch is logged, the scan did not print it.
%       DC-6  ACT1B C 2020-01-08: bits 3/4 (clock-offset extrapolation) are
%             reported and remove nothing; the weights are the fill flags.
%       DC-7  KBR1B 2020-01-09: bit 5 (time-tag bias correction) on all
%             17182 samples, reported, removes nothing.
%       DC-8  THR1B D 2020-01-04, 727 records: every firing's ACT1B D
%             sample is inside the "thr" layer.
%     No real instance in either month (owner, 2026-09-24), so synthetic:
%       - a duplicate epoch at a day boundary is refused by Arc;
%       - an LRI1B phase break (bit 0) is removed by the preset;
%       - a level jump in ACT1B-like noise is reported by qc.screen and
%         left in the data (jumps are never masked).
%
%   COVERAGE
%     reference   - DC-1 ... DC-8 on the real days.
%     robustness  - the three synthetic classes.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-11-08 23:00 (CET, UTC+01:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function dc1SafeMode(testCase)
            [t18] = readDay(testCase, "ACT1B", "2020-01-18", "D");
            testCase.verifyEqual(sod(t18(end), "2020-01-18"), 18229, "AbsTol", 1);
            f19 = dayFile(testCase, "ACT1B", "2020-01-19", "D");
            testCase.verifyError(@() gracefoReading.readL1b(f19, "TimeFormat", "gpsns"), ...
                "gracefoReading:readL1b:noData");
            [t, obs, aux] = readDay(testCase, "ACT1B", "2020-01-22", "D");
            testCase.verifyEqual(sod(t(1), "2020-01-22"), 43385, "AbsTol", 1);
            ev = table(gpsns("2020-01-18", 5 * 3600 + 5 * 60 + 18), gpsns("2020-01-22", 12 * 3600 + 5 * 60 + 18), ...
                "TN-01a", "GRACE-D AOCS safe mode 2020-01-18 05:05 to nominal 2020-01-22 12:05 (UTC)", ...
                'VariableNames', ["tStart" "tEnd" "source" "text"]);
            [out, info] = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux), Events = ev);
            s = sod(t, "2020-01-22");
            testCase.verifyEqual(out.layers.events, s <= 43518);
            testCase.verifyGreaterThan(nnz(out.layers.events), 0);
            testCase.verifyEqual(height(info.windows), 1);
        end

        function dc2DayBoundaryGap(testCase)
            t1 = readDay(testCase, "KBR1B", "2020-01-14", "Y");
            t2 = readDay(testCase, "KBR1B", "2020-01-15", "Y");
            gaps = gracefoReading.findGaps([t1; t2]);
            k = find(gaps.indexBefore == numel(t1));
            testCase.assertNumElements(k, 1, "No gap at the day boundary.");
            testCase.verifyEqual(gaps.secBefore(k), 82235, "AbsTol", 1);
            testCase.verifyEqual(gaps.secAfter(k), 4675, "AbsTol", 1);
            testCase.verifyGreaterThan(gaps.durationSec(k), 21);
        end

        function dc3GapsInsideADay(testCase)
            cases = {"2020-01-08", [70170 740; 78290 610; 79215 75; 82025 100]
                     "2020-07-09", [81680 965]};
            for c = 1:size(cases, 1)
                t = readDay(testCase, "KBR1B", cases{c, 1}, "Y");
                gaps = gracefoReading.findGaps(t);
                want = cases{c, 2};
                for r = 1:size(want, 1)
                    hit = abs(gaps.secBefore - want(r, 1)) <= 1 & abs(gaps.durationSec - want(r, 2)) <= 1;
                    testCase.verifyEqual(nnz(hit), 1, sprintf("%s gap after %d s", cases{c, 1}, want(r, 1)));
                    testCase.verifyGreaterThan(want(r, 2), 21);
                end
            end
        end

        function dc4SnrDrop(testCase)
            [t, obs, aux] = readDay(testCase, "KBR1B", "2020-01-14", "Y");
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            j = arc.names == "K_B_SNR";
            [lo, i] = min(arc.obs(:, j));
            testCase.verifyEqual([lo sod(t(i), "2020-01-14")], [288 82150], "AbsTol", 1);
            out = timeSeriesPreparation.mask(arc);
            testCase.verifyTrue(out.layers.snr(i));
            [t, obs, aux] = readDay(testCase, "KBR1B", "2020-07-12", "Y");
            out = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux));
            [~, i] = min(abs(sod(t, "2020-07-12") - 61455));
            testCase.verifyFalse(out.layers.snr(i));
        end

        function dc5KbrPhaseBreak(testCase)
            for day = ["2020-07-01" "2020-07-09"]
                [t, obs, aux] = readDay(testCase, "KBR1B", day, "Y");
                out = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux), QualFlags = aux);
                testCase.verifyEqual(nnz(out.layers.qualflg_b0), 1, day);
                testCase.log(matlab.unittest.Verbosity.Terse, sprintf("DC-5 %s: phase break at %.3f s", ...
                    day, sod(t(out.layers.qualflg_b0), day)));
            end
        end

        function dc6ClockExtrapolationReported(testCase)
            [t, obs, aux] = readDay(testCase, "ACT1B", "2020-01-08", "C");
            [out, info] = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux), QualFlags = aux);
            bits = gracefoReading.decodeQualFlags(aux);
            testCase.verifyGreaterThan(sum(info.qualflg.countSet([4 5])), 16000);
            testCase.verifyFalse(any(info.qualflg.removes([4 5])));
            testCase.verifyEqual(out.weights == 0, any(bits(:, 6:8), 2));
        end

        function dc7TimeTagBiasReported(testCase)
            [t, obs, aux] = readDay(testCase, "KBR1B", "2020-01-09", "Y");
            [out, info] = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux), QualFlags = aux);
            testCase.verifyEqual([numel(t) info.qualflg.countSet(6)], [17182 17182]);
            testCase.verifyFalse(info.qualflg.removes(6));
            testCase.verifyFalse(isfield(out.layers, "qualflg_b5"));
        end

        function dc8ThrusterHeavyDay(testCase)
            [tt, ot, at] = readDay(testCase, "THR1B", "2020-01-04", "D");
            testCase.verifyEqual(numel(tt), 727);
            thr = timeSeriesPreparation.Arc(tt, ot, at);
            [t, obs, aux] = readDay(testCase, "ACT1B", "2020-01-04", "D");
            [out, info] = timeSeriesPreparation.mask(timeSeriesPreparation.Arc(t, obs, aux), Thrusters = thr);
            fired = any(thr.obs(:, startsWith(thr.names, "on_time_")) > 0, 2);
            testCase.verifyEqual(info.thrusters.firings, nnz(fired));
            idx = interp1(double(t - t(1)), 1:numel(t), double(tt(fired) - t(1)), "nearest", "extrap");
            testCase.verifyTrue(all(out.layers.thr(idx)));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function syntheticDayBoundaryDuplicate(testCase)
            t = int64([86398; 86399; 86399; 86400]) * int64(1e9);
            aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, ...
                "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), ...
                "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, zeros(4, 1), aux), ...
                "timeSeriesPreparation:Arc:timeNotIncreasing");
        end

        function syntheticLriPhaseJump(testCase)
            testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), "gracefoReading is not on the path.");
            n = 20;
            q = repmat('00000000', n, 1);
            q(7, 8) = '1';                                   % bit 0 on sample 7
            aux = struct("obsNames", {{'K_A_SNR'}}, "variableNames", {{'K_A_SNR'}}, ...
                "variableFieldNames", {{'K_A_SNR'}}, "variableUnits", struct("K_A_SNR", "0.1 dB-Hz"), ...
                "fileName", "LRI1B_2020-01-01_Y_04.txt", "product", "LRI1B", "qualflg", q, ...
                "variableAttributes", struct("qualflg", struct("flag_meanings", {{'bit 0 = Phase break'}})));
            arc = timeSeriesPreparation.Arc(int64(0:n - 1)' * int64(2e9), 87 * ones(n, 1), aux);
            out = timeSeriesPreparation.mask(arc, QualFlags = aux);
            testCase.verifyEqual(find(out.layers.qualflg_b0)', 7);
        end

        function syntheticBiasJumpReportedNotMasked(testCase)
            rs = RandStream("twister", "Seed", 91);
            K = 3000;
            x = 1e-9 * randn(rs, K, 1);
            x(2001:end) = x(2001:end) + 10e-9;               % a 10-sigma level jump
            t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds((0:K - 1)');
            [m, ev] = timeSeriesPreparation.qc.screen(x, zeros(K, 1), t);
            j = ev(ev.class == "jump", :);
            testCase.assertNotEmpty(j);
            [d, q] = min(abs(seconds(j.tStart - t(2001))));
            testCase.verifyLessThanOrEqual(d, 1);
            testCase.verifyEqual(j.amplitude(q), 10e-9, "AbsTol", 3 * j.sigma(q));
            testCase.verifyFalse(any(m(1990:2010)), "A jump is reported, never masked.");
        end
    end
end

% ------------------------------------------------------------------------

function f = dayFile(testCase, product, day, sat)
% The DATAPOOL file of PRODUCT on DAY for SAT; the test is incomplete without it.
    pool = dataPoolRoot(testCase, "D-9");
    testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), "gracefoReading is not on the path.");
    folder = fullfile(pool, "GRACEFO", "L1B", "RL04", extractBefore(day, 5), day);
    hits = dir(fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    testCase.assertNotEmpty(hits, "D-9 file missing: " + fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    f = string(fullfile(hits(1).folder, hits(1).name));
end

function [t, obs, aux] = readDay(testCase, product, day, sat)
    [t, obs, aux] = gracefoReading.readL1b(dayFile(testCase, product, day, sat), "TimeFormat", "gpsns");
end

function n = gpsns(day, second)
% GPS nanoseconds past 2000-01-01 12:00 of SECOND of the GPS day DAY.
    d = days(datetime(day, "InputFormat", "yyyy-MM-dd") - datetime(2000, 1, 1));
    n = int64(d) * int64(86400e9) - int64(43200e9) + int64(round(second * 1e9));
end

function s = sod(t, day)
% Seconds of the GPS day DAY of the epochs t.
    s = double(t - gpsns(day, 0)) / 1e9;
end
