classdef TestMask < matlab.unittest.TestCase
%TESTMASK  mask: one named layer per source, product presets, windows, refusals.
%
%   DESCRIPTION
%     Every expected count below is written out from the definition of the
%     layer, on 1 Hz arcs with integer epochs:
%       - a window [lo, hi] removes the samples at the integer seconds in
%         it, so a THR1B firing at 100 s lasting 50 ms with margin 10 s
%         removes 90..110 (21);
%       - the ACT1B margin is half the ACC fit interval, 140.7/2 = 70.35 s,
%         so the same firing removes 30..170 (141);
%       - an eclipse series 1 up to 49 s, 0.5 at 50 s, 0 from 51 s with
%         margin 5 s has one partial sample and two steps, whose windows
%         [44, 55], [45, 55], [45, 56] remove 44..56 (13);
%       - a gap from 50 to 200 s with the ACC half span removes 0..50 and
%         200..270 (51 + 71).
%     The TN-01 reference is gracefoReading's fixture: the first GRACE-C
%     MANV row, epoch 580414784.600034 s and 127 s long, which TN-01a
%     states as "calibration maneuver from 06:19:26 to 06:21:33" UTC on
%     2018-05-24 (GPS - 18 s). On a 1 Hz arc it removes the integer seconds
%     580414785..580414911 (127). qualflg tests decode a hand-built aux
%     with gracefoReading.decodeQualFlags, so they need it on the path.
%
%   COVERAGE
%     contract       - no source, no layer; a user layer sets the weights
%                      and info.layers; the ACT1B preset removes the fill
%                      flags and only reports bits 3/4.
%     reference      - the TN-01 MANV window; thruster windows with a given
%                      and the preset margin; the eclipse transitions; the
%                      CRN edges at a gap; the SNR layer at 0.5 of the
%                      median.
%     metamorphic    - two sources in one call equal two calls; shifting
%                      every epoch shifts nothing in the layers.
%     robustness     - sizeMismatch, badThrusters, badEclipse, badEvents,
%                      marginMissing (LRI1B has no CRN preset) and a
%                      second run on the same arc (Arc:badLayer) fire.
%     precision, speed, vectorisation - exempt: comparisons of integers.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-24 18:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function noSourceNoLayer(testCase)
            [out, info] = timeSeriesPreparation.mask(accArc(10));
            testCase.verifyEqual(height(info.layers), 0);
            testCase.verifyEqual(out.weights, ones(10, 1));
            testCase.verifyEqual(out.provenance(end).stage, "mask");
        end

        function userLayerSetsWeights(testCase)
            u = (1:10)' > 7;
            [out, info] = timeSeriesPreparation.mask(accArc(10), User = u);
            testCase.verifyEqual(out.layers.user, u);
            testCase.verifyEqual(out.weights, double(~u));
            testCase.verifyEqual(info.layers.name, "user");
            testCase.verifyEqual(info.layers.removed, 3);
        end

        function act1bPresetRemovesFillFlagsOnly(testCase)
            requireReader(testCase);
            q = repmat('00000000', 6, 1);
            q(2, 8 - 3) = '1';            % bit 3: clock-offset extrapolation
            q(3, 8 - 4) = '1';            % bit 4
            q(4, 8 - 5) = '1';            % bit 5: interpolated point
            q(5, 8 - 7) = '1';            % bit 7: interpolated point
            [out, info] = timeSeriesPreparation.mask(accArc(6), QualFlags = flagAux(q));
            testCase.verifyEqual(info.layers.name, ["qualflg_b5"; "qualflg_b6"; "qualflg_b7"]);
            testCase.verifyEqual(out.weights, [1 1 1 0 0 1]');
            testCase.verifyEqual(info.qualflg.removes(4:5), [false; false]);   % bits 3, 4
            testCase.verifyEqual(info.qualflg.countSet(4:5), [1; 1]);
        end
    end

    methods (Test, TestTags = {'reference'})
        function soeManoeuvreWindow(testCase)
            requireReader(testCase);
            root = fileparts(fileparts(which("gracefoReading.readL1b")));
            soe = gracefoReading.readEventList(fullfile(root, "tests", "realdata", "TN-01_SOE.txt"), ...
                TimeFormat = "mjd");
            s0 = 580414784.600034;
            t = int64((floor(s0) - 200):(floor(s0) + 400))' * int64(1e9);
            [out, info] = timeSeriesPreparation.mask(accArc(t, "C"), Soe = soe);
            sec = double(t(out.layers.events)) / 1e9;
            testCase.verifyEqual([min(sec) max(sec) numel(sec)], [580414785 580414911 127]);
            testCase.verifyEqual(height(info.windows), 1);
            testCase.verifyEqual(info.windows.source, "TN-01 MANV");
        end

        function thrusterWindows(testCase)
            thr = thrArc(100, 50);
            [out, info] = timeSeriesPreparation.mask(accArc(300), Thrusters = thr, ThrMargin = 10);
            testCase.verifyEqual(find(out.layers.thr)', 91:111);                 % seconds 90..110
            testCase.verifyEqual(info.thrusters, struct("firings", 1, "margin", 10));
            out = timeSeriesPreparation.mask(accArc(300), Thrusters = thr);    % ACC half span
            testCase.verifyEqual(find(out.layers.thr)', 31:171);                 % seconds 30..170
        end

        function eclipseTransitions(testCase)
            e = struct("t", int64(0:99)' * int64(1e9), "value", [ones(50, 1); 0.5; zeros(49, 1)]);
            [out, info] = timeSeriesPreparation.mask(accArc(100), Eclipse = e, EclipseMargin = 5);
            testCase.verifyEqual(find(out.layers.eclipse)', 45:57);              % seconds 44..56
            testCase.verifyEqual(info.eclipse.transitions, 3);
        end

        function crnEdgesAtGap(testCase)
            t = int64([0:50, 200:300])' * int64(1e9);
            out = timeSeriesPreparation.mask(accArc(t), CrnEdge = true);
            sec = double(t(out.layers.crnEdge)) / 1e9;
            testCase.verifyEqual(sec', [0:50, 200:270]);
        end

        function snrBelowHalfTheMedian(testCase)
            x = 700 * ones(20, 1);
            x(5) = 300;                   % 0.43 of the median: removed
            x(9) = 400;                   % 0.57: kept
            [out, info] = timeSeriesPreparation.mask(kbrArc(x));
            testCase.verifyEqual(find(out.layers.snr)', 5);
            testCase.verifyEqual(info.snr.threshold, 350);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function twoSourcesEqualTwoCalls(testCase)
            u = (1:300)' > 290;
            thr = thrArc(100, 50);
            both = timeSeriesPreparation.mask(accArc(300), User = u, Thrusters = thr, ThrMargin = 3);
            one = timeSeriesPreparation.mask(accArc(300), User = u);
            two = timeSeriesPreparation.mask(one, Thrusters = thr, ThrMargin = 3);
            testCase.verifyEqual(both.weights, two.weights);
            testCase.verifyEqual(orderfields(both.layers), orderfields(two.layers));
        end

        function shiftingEpochsShiftsNothing(testCase)
            thr = thrArc(100, 50);
            a = timeSeriesPreparation.mask(accArc(300), Thrusters = thr);
            d = int64(86400) * int64(1e9);
            b = timeSeriesPreparation.mask(accArc(int64(0:299)' * int64(1e9) + d), ...
                Thrusters = thrArc(100, 50, d));
            testCase.verifyEqual(b.layers.thr, a.layers.thr);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            arc = accArc(10);
            testCase.verifyError(@() timeSeriesPreparation.mask(arc, User = true(9, 1)), ...
                "timeSeriesPreparation:mask:sizeMismatch");
            bad = thrArc(5, 50, int64(0), "seconds");
            testCase.verifyError(@() timeSeriesPreparation.mask(arc, Thrusters = bad), ...
                "timeSeriesPreparation:mask:badThrusters");
            e = struct("t", int64(0:9)' * int64(1e9), "value", 2 * ones(10, 1));
            testCase.verifyError(@() timeSeriesPreparation.mask(arc, Eclipse = e), ...
                "timeSeriesPreparation:mask:badEclipse");
            ev = table(int64(5e9), int64(4e9), "TN-01a", "backwards", ...
                'VariableNames', ["tStart" "tEnd" "source" "text"]);
            testCase.verifyError(@() timeSeriesPreparation.mask(arc, Events = ev), ...
                "timeSeriesPreparation:mask:badEvents");
            lri = kbrArc(700 * ones(10, 1), "LRI1B");
            testCase.verifyError(@() timeSeriesPreparation.mask(lri, Thrusters = thrArc(5, 50)), ...
                "timeSeriesPreparation:mask:marginMissing");
            once = timeSeriesPreparation.mask(arc, User = false(10, 1));
            testCase.verifyError(@() timeSeriesPreparation.mask(once, User = false(10, 1)), ...
                "timeSeriesPreparation:Arc:badLayer");
        end
    end
end

% ------------------------------------------------------------------------

function requireReader(testCase)
    testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), ...
        "gracefoReading is not on the path.");
end

function arc = accArc(t, sat)
% An ACT1B arc with one column; t is a sample count (1 Hz from 0) or epochs.
    if nargin < 2, sat = "C"; end
    if isscalar(t), t = int64(0:t - 1)' * int64(1e9); end
    arc = timeSeriesPreparation.Arc(t, zeros(numel(t), 1), ...
        auxOf("lin_accl_x", "m/s2", "ACT1B_2020-01-01_" + sat + "_04.txt", "ACT1B"));
end

function arc = kbrArc(x, product)
% A KBR1B (or LRI1B) arc at 5 s with one SNR column.
    if nargin < 2, product = "KBR1B"; end
    t = int64(0:numel(x) - 1)' * int64(5e9);
    arc = timeSeriesPreparation.Arc(t, x, ...
        auxOf("K_A_SNR", "0.1 dB-Hz", product + "_2020-01-01_Y_04.txt", product));
end

function thr = thrArc(second, onTimeMs, offset, unit)
% A THR1B arc with one firing at SECOND lasting onTimeMs.
    if nargin < 3, offset = int64(0); end
    if nargin < 4, unit = "milliseconds"; end
    t = int64([0; second; 250]) * int64(1e9) + offset;
    thr = timeSeriesPreparation.Arc(t, [0; onTimeMs; 0], ...
        auxOf("on_time_att_ctrl_1_1", unit, "THR1B_2020-01-01_C_04.txt", "THR1B"));
end

function aux = auxOf(name, unit, fileName, product)
    aux = struct("obsNames", {{char(name)}}, "variableNames", {{char(name)}}, ...
        "variableFieldNames", {{char(name)}}, "variableUnits", struct(char(name), char(unit)), ...
        "fileName", fileName, "product", product);
end

function aux = flagAux(q)
% A readL1b-shaped aux holding only an ACT1B qualflg column and its header meanings.
    meanings = {'bit 0 = Vp (proof mass voltage) out of nominal range', 'bit 1 = Not defined', ...
        'bit 2 = At least one of acl_x_res, acl_y_res, and acl_z_res is > 10 microns/s^2', ...
        'bit 3 = Extrapolated CLK1B clock offset value used for data point > 5 s from center of CRN filter window', ...
        'bit 4 = Extrapolated CLK1B clock offset value used for data point <= 5 s from center of CRN filter window', ...
        'bit 5 = Interpolated data point (due to gap) exists > 15 s from center of CRN filter window', ...
        'bit 6 = Interpolated data point (due to gap) exists > 5 s but < 15 s from center of CRN filter window', ...
        'bit 7 = Interpolated data point (due to gap) exists < 5 s from center of CRN filter window'};
    aux = struct("qualflg", q, ...
        "variableAttributes", struct("qualflg", struct("flag_meanings", {meanings})));
end
