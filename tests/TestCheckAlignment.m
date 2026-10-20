classdef TestCheckAlignment < matlab.unittest.TestCase
%TESTCHECKALIGNMENT  checkAlignment: bounded lag search, verdicts, warnings, never a shift.
%
%   DESCRIPTION
%     checkAlignment reports the lag between observation and reference over
%     +/-60 s and never shifts either (CONCEPT 6.1, row 3; v3 F2). The test
%     signal is one day at 1 s: 1/rev plus 2/rev (orbit 5640 s) plus 40
%     deterministic tones from 2 to 50 mHz. A NumPy transcription of the
%     estimator (2026-09-23) recovers 7.0 s to 1.1e-5 s, 7.3 s to 1e-3 s,
%     45 s to 1.1e-5 s and 7.0 s with two gaps to 3.2e-5 s. The bounds
%     below are ten times those or more, a margin for the different
%     summation order of MATLAB and NumPy. Each warning
%     fires on its broken input and stays silent on a healthy one (fault
%     injection).
%
%   COVERAGE
%     contract       - report fields and sizes; one output, so no shifted
%                      series can be returned.
%     reference      - 7.0 s recovered to 0.05 s with verdict "offset" and
%                      its warning; identical series give lag 0 exactly,
%                      "aligned", no warning; r(L) equals a direct loop.
%     precision      - 7.3 s (between grid points) to 0.01 s.
%     robustness     - 45 s is "gross" and warns; a smooth signal 90 s off
%                      peaks on the edge ("gross"); a constant and disjoint
%                      spans are "undetermined" and warn; gaps tolerated;
%                      bad grid and column count refused.
%     metamorphic    - swapping obs and ref negates the lag; an affine map
%                      of ref keeps it.
%     vectorisation  - three columns equal three single-column calls,
%                      bitwise.
%     speed          - one day, 3 columns, +/-60 s in under 2 s.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function reportFields(testCase)
            t = 0:3599;
            rep = timeSeriesPreparation.checkAlignment(arcOf(g(t'), "ACT1B", t), ...
                arcOf(g(t'), "MOD1B", t));
            testCase.verifyEqual(string(fieldnames(rep))', ["lag" "peak" "verdict" ...
                "names" "lags" "corr" "pairs" "maxLag" "threshold" "step"]);
            testCase.verifyEqual(rep.lags, (-60:60)');
            testCase.verifyEqual(size(rep.corr), [121 1]);
            testCase.verifyEqual(size(rep.pairs), [121 1]);
            testCase.verifyEqual([rep.maxLag rep.threshold rep.step], [60 1 1]);
            testCase.verifyEqual(rep.names, "lin_accl_x");
        end

        function oneOutputOnly(testCase)
            % A report is all it returns: there is no output to carry a
            % shifted series (v3 F2).
            testCase.verifyEqual(nargout(@timeSeriesPreparation.checkAlignment), 1);
        end
    end

    methods (Test, TestTags = {'reference'})
        function sevenSecondsRecovered(testCase)
            t = 0:86399;
            obs = arcOf(g(t' - 7), "ACT1B", t);
            ref = arcOf(g(t'), "MOD1B", t);
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment(obs, ref), ...
                "timeSeriesPreparation:checkAlignment:offset");
            testCase.verifyEqual(rep.lag, 7, "AbsTol", 0.05);
            testCase.verifyEqual(rep.verdict, "offset");
        end

        function identicalSeriesAligned(testCase)
            t = 0:86399;
            rep = testCase.verifyWarningFree(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(g(t'), "ACT1B", t), arcOf(g(t'), "MOD1B", t)));
            testCase.verifyEqual(rep.lag, 0);
            testCase.verifyEqual(rep.verdict, "aligned");
            testCase.verifyEqual(rep.peak, 1, "AbsTol", 1e-12);
        end

        function correlationEqualsDirectLoop(testCase)
            t = 0:1999;
            a = g(t' - 3); b = g(t');
            rep = timeSeriesPreparation.checkAlignment(arcOf(a, "ACT1B", t), ...
                arcOf(b, "MOD1B", t), MaxLag = 10);
            a = a - mean(a); b = b - mean(b);
            want = zeros(21, 1);
            for L = -10:10
                num = 0; sa = 0; sb = 0;
                for i = 1:2000
                    if i - L >= 1 && i - L <= 2000
                        num = num + a(i) * b(i - L);
                        sa = sa + a(i)^2; sb = sb + b(i - L)^2;
                    end
                end
                want(L + 11) = num / sqrt(sa * sb);
            end
            testCase.verifyEqual(rep.corr, want, "AbsTol", 1e-12);
            testCase.verifyEqual(rep.pairs, 2000 - abs((-10:10)'));
        end
    end

    methods (Test, TestTags = {'precision'})
        function subSampleLag(testCase)
            t = 0:86399;
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(g(t' - 7.3), "ACT1B", t), arcOf(g(t'), "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:offset");
            testCase.verifyEqual(rep.lag, 7.3, "AbsTol", 0.01);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function grossOffsetWarns(testCase)
            t = 0:86399;
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(g(t' - 45), "ACT1B", t), arcOf(g(t'), "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:grossOffset");
            testCase.verifyEqual(rep.lag, 45, "AbsTol", 0.05);
            testCase.verifyEqual(rep.verdict, "gross");
        end

        function smoothSignalBeyondWindowOnEdge(testCase)
            t = 0:86399;
            f = @(t) sin(2 * pi * t / 5640) + 0.5 * cos(4 * pi * t / 5640 + 0.3);
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(f(t' - 90), "ACT1B", t), arcOf(f(t'), "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:grossOffset");
            testCase.verifyEqual([rep.lag string(rep.verdict)], ["60" "gross"]);
        end

        function constantUndetermined(testCase)
            t = 0:999;
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(ones(1000, 1), "ACT1B", t), arcOf(ones(1000, 1), "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:undetermined");
            testCase.verifyEqual(rep.verdict, "undetermined");
            testCase.verifyTrue(isnan(rep.lag));
        end

        function disjointSpansUndetermined(testCase)
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(g((0:999)'), "ACT1B", 0:999), arcOf(g((0:999)'), "MOD1B", 5000:5999)), ...
                "timeSeriesPreparation:checkAlignment:undetermined");
            testCase.verifyEqual(rep.pairs, zeros(121, 1));
            testCase.verifyEqual(rep.verdict, "undetermined");
        end

        function gapsTolerated(testCase)
            t = 0:86399;
            a = g(t' - 7); b = g(t');
            a(20001:23000) = NaN;
            b(50001:52000) = NaN;
            rep = testCase.verifyWarning(@() timeSeriesPreparation.checkAlignment( ...
                arcOf(a, "ACT1B", t), arcOf(b, "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:offset");
            testCase.verifyEqual(rep.lag, 7, "AbsTol", 0.05);
        end

        function badGridRefused(testCase)
            t = 0:99;
            obs = arcOf(g(t'), "ACT1B", t);
            ref = arcOf(g(t'), "MOD1B", t);
            testCase.verifyError(@() timeSeriesPreparation.checkAlignment(obs, ref, Step = 1e-10), ...
                "timeSeriesPreparation:checkAlignment:badGrid");
            testCase.verifyError(@() timeSeriesPreparation.checkAlignment(obs, ref, MaxLag = 7.5), ...
                "timeSeriesPreparation:checkAlignment:badGrid");
        end

        function columnCountRefused(testCase)
            t = 0:99;
            testCase.verifyError(@() timeSeriesPreparation.checkAlignment( ...
                arcOf([g(t') g(t')], "ACT1B", t), arcOf(g(t'), "MOD1B", t)), ...
                "timeSeriesPreparation:checkAlignment:columnMismatch");
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function swapNegatesLag(testCase)
            t = 0:86399;
            obs = arcOf(g(t' - 7), "ACT1B", t);
            ref = arcOf(g(t'), "MOD1B", t);
            w = warning("off", "timeSeriesPreparation:checkAlignment:offset");
            restore = onCleanup(@() warning(w));
            ab = timeSeriesPreparation.checkAlignment(obs, ref);
            ba = timeSeriesPreparation.checkAlignment(ref, obs);
            testCase.verifyEqual(ba.lag, -ab.lag, "AbsTol", 1e-12);
            testCase.verifyEqual(ba.corr, flipud(ab.corr));
        end

        function affineReferenceKeepsLag(testCase)
            t = 0:86399;
            obs = arcOf(g(t' - 7), "ACT1B", t);
            w = warning("off", "timeSeriesPreparation:checkAlignment:offset");
            restore = onCleanup(@() warning(w));
            a = timeSeriesPreparation.checkAlignment(obs, arcOf(g(t'), "MOD1B", t));
            b = timeSeriesPreparation.checkAlignment(obs, arcOf(3 * g(t') + 5, "MOD1B", t));
            testCase.verifyEqual(b.lag, a.lag, "AbsTol", 1e-9);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function columnsEqualSingleColumns(testCase)
            t = 0:9999;
            A = [g(t' - 2) g(t' + 4) g(t' - 11)];
            B = [g(t') g(t') g(t')];
            w = warning("off", "all");
            restore = onCleanup(@() warning(w));
            whole = timeSeriesPreparation.checkAlignment(arcOf(A, "ACT1B", t), arcOf(B, "MOD1B", t));
            for j = 1:3
                one = timeSeriesPreparation.checkAlignment(arcOf(A(:, j), "ACT1B", t), ...
                    arcOf(B(:, j), "MOD1B", t));
                testCase.verifyTrue(isequal(whole.corr(:, j), one.corr) ...
                    && isequal(whole.lag(j), one.lag), sprintf("column %d", j));
            end
        end
    end

    methods (Test, TestTags = {'speed'})
        function oneDayUnderTwoSeconds(testCase)
            % Absolute budget, as for align (v3 WP-11: one day < 2 s); the
            % median of three runs, after one warm-up.
            t = 0:86399;
            obs = arcOf([g(t' - 1) g(t') g(t' + 1)], "ACT1B", t);
            ref = arcOf([g(t') g(t') g(t')], "MOD1B", t);
            w = warning("off", "all");
            restore = onCleanup(@() warning(w));
            f = @() timeSeriesPreparation.checkAlignment(obs, ref);
            f();
            s = median(arrayfun(@(r) timed(f), 1:3));
            testCase.verifyLessThan(s, 2, sprintf("checkAlignment one day: %.3f s", s));
        end
    end
end

% ------------------------------------------------------------------------

function y = g(t)
% 1/rev + 2/rev (orbit 5640 s) plus 40 fixed tones from 2 to 50 mHz; the
% same signal as the NumPy prototype that set the tolerances.
    T = 5640;
    k = 1:40;
    fr = linspace(0.002, 0.05, 40);
    ph = mod(k * 2.399963, 2 * pi);
    am = 0.3 * (0.2 + 0.8 * mod(k * 0.618034, 1));
    y = sin(2 * pi * t / T) + 0.5 * cos(4 * pi * t / T + 0.3) ...
        + sin(2 * pi * t * fr + ph) * am';
end

function arc = arcOf(x, product, tsec)
% An arc of PRODUCT with the columns of X at TSEC seconds past 2020-01-01.
    t = int64(631152000) * int64(1e9) + int64(round(tsec(:) * 1e9));
    names = "lin_accl_" + ["x" "y" "z"];
    names = cellstr(names(1:size(x, 2)));
    units = struct();
    for n = names, units.(n{1}) = "m/s2"; end
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", product + "_2020-01-01_C_04.txt", "product", product);
    arc = timeSeriesPreparation.Arc(t, x, aux);
end

function s = timed(f)
    tic; f(); s = toc;
end
