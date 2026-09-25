classdef tNgfQc < NgfTestCase
%TNGFQC  Tests of qc.hampel and qc.eventTable, ported with NonGravForces.qc 0.12.0.
%
%   DESCRIPTION
%     NonGravForces' tests of the two units at 3cc0123, run as the gate of
%     the port (X-05). hampel is held to an independent Python oracle
%     (tests/tools/pyxcheck/hampel_check.py, standard library only) and to
%     the Gaussian consistency of the scaled MAD; eventTable to its schema.
%     X-05b changed only this help and the tag spelling (vectorisation).
%
%   COVERAGE
%     contract       - hampel's and eventTable's shapes and refusals.
%     reference      - hampel's flags equal the Python oracle's.
%     precision      - the robust sigma of white noise is 1 to 2 %.
%     vectorisation  - M channels at once equal each channel alone.
%     robustness     - NaN gaps, constant and empty series; eventTable's
%                      non-finite refusals.
%     metamorphic    - affine and time-reversal invariance of hampel; split
%                      and merge of eventTable.
%     speed          - hampel on a day of 3 channels against movmedian.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Static)
        function [x, flagged] = oracle()
            here = fileparts(mfilename('fullpath'));
            T = readtable(fullfile(fileparts(here), 'tools', 'pyxcheck', 'hampel_oracle.csv'));
            x = T.x; flagged = logical(T.flagged);
        end
    end
    methods (Test, TestTags = {'contract'})
        function hampelContract(tc)
            x = randn(100, 2);
            [m, info] = timeSeriesPreparation.qc.hampel(x);
            tc.verifySize(m, [100 2]); tc.verifyClass(m, 'logical');
            tc.verifySize(info.score, [100 2]); tc.verifyEqual(size(info.nFlagged), [1 2]);
            tc.verifyEqual(size(timeSeriesPreparation.qc.hampel(randn(1, 50))), [50 1], 'a row is one channel');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.hampel(randn(3,3,3)), 'timeSeriesPreparation:hampel:inputShape');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.hampel(x, 'Window', 10), 'timeSeriesPreparation:hampel:inputWindow');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.hampel(x, 'Window', 1), 'timeSeriesPreparation:hampel:inputWindow');
            tc.verifyError(@() timeSeriesPreparation.qc.hampel(x, 'Threshold', -1), 'MATLAB:validators:mustBePositive');
            tc.verifyEqual(info.provenance.unit, "qc.hampel");
        end
        function eventTableContract(tc)
            T = timeSeriesPreparation.qc.eventTable();
            tc.verifyEqual(height(T), 0);
            tc.verifyEqual(T.Properties.VariableNames, {'tStart','tEnd','class','axis','amplitude','sigma','source','confidence'});
            t = datetime(2020,1,1,'TimeZone','UTC') + seconds([10 20]);
            T2 = timeSeriesPreparation.qc.eventTable(t, t, ["outlier","jump"], ["x","all"], [1e-8 2e-9], [1e-9 1e-9], ["THR1B","eclipse"], [0.9 0.5]);
            tc.verifyEqual(height(T2), 2);
            tc.verifyErrorId(@() timeSeriesPreparation.qc.eventTable(t), 'timeSeriesPreparation:eventTable:inputArity');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.eventTable(t, t, ["blip","jump"], ["x","all"], [1 2], [1 1], ["THR1B","eclipse"], [0.9 0.5]), 'timeSeriesPreparation:eventTable:inputClass');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.eventTable(t, t(1), ["outlier","jump"], ["x","all"], [1 2], [1 1], ["THR1B","eclipse"], [0.9 0.5]), 'timeSeriesPreparation:eventTable:inputLength');
            tc.verifyErrorId(@() timeSeriesPreparation.qc.eventTable(t, t, ["outlier","jump"], ["x","all"], [1 2], [1 1], ["THR1B","eclipse"], [0.9 1.5]), 'timeSeriesPreparation:eventTable:inputClass');
        end
    end
    methods (Test, TestTags = {'reference'})
        function hampelReference(tc)
            % Oracle: tools/pyxcheck/hampel_check.py (standard library since 2026-09-07, independent code path).
            [x, flagged] = tNgfQc.oracle();
            m = timeSeriesPreparation.qc.hampel(x, 'Window', 21, 'Threshold', 4);
            tc.verifyEqual(m, flagged, 'flag pattern differs from the independent Python oracle');
            % Planted (0-based in Python: 50 51 200 333) = 1-based 51 52 201 334.
            tc.verifyTrue(all(m([51 52 201 334])), 'the four planted outliers must be flagged');
            tc.verifyEqual(nnz(m), 5, 'four planted plus one chance exceedance in the oracle');
        end
    end
    methods (Test, TestTags = {'precision'})
        function hampelPrecision(tc)
            % Robust sigma of white Gaussian noise: 1.4826*MAD -> 1 within the
            % sampling error of a 61-sample MAD (~0.13 at 1 sigma); assert the
            % mean over 10^4 windows to 2 %, which is 5x its standard error.
            rng(1); x = randn(1e4, 1);
            [~, info] = timeSeriesPreparation.qc.hampel(x, 'Window', 61);
            tc.verifyBoundAndRecord("hampel robust sigma bias", abs(mean(info.sigma) - 1), 0.02, "-", "mean over 1e4 windows");
        end
    end
    methods (Test, TestTags = {'vectorisation'})
        function hampelVectorization(tc)
            % M channels at once must equal each channel alone, bit for bit.
            rng(2); x = randn(300, 3); x(100, 2) = 20;
            [mAll, iAll] = timeSeriesPreparation.qc.hampel(x);
            for j = 1:3
                [mj, ij] = timeSeriesPreparation.qc.hampel(x(:, j));
                tc.verifyEqual(mAll(:, j), mj); tc.verifyEqual(iAll.score(:, j), ij.score);
            end
        end
    end
    methods (Test, TestTags = {'robustness'})
        function eventTableRobustness(tc)
            % Degenerate inputs: an empty event list is a valid answer, and non-finite numbers are not.
            t0 = datetime.empty(0, 1); t0.TimeZone = 'UTC';
            E = timeSeriesPreparation.qc.eventTable(t0, t0, string.empty(0,1), string.empty(0,1), zeros(0,1), zeros(0,1), string.empty(0,1), zeros(0,1));
            tc.verifyEqual(height(E), 0);
            tc.verifyEqual(E.Properties.VariableNames, timeSeriesPreparation.qc.eventTable().Properties.VariableNames);
            t = datetime(2020, 1, 1, 'TimeZone', 'UTC');
            e = @(am, sg, cf) timeSeriesPreparation.qc.eventTable(t, t, "jump", "x", am, sg, "unassigned", cf);
            % A NaN confidence passed the [0,1] test until 2026-09-07: every comparison with NaN is false.
            tc.verifyErrorId(@() e(1e-9, 1e-10, NaN), 'timeSeriesPreparation:eventTable:numericNaN');
            tc.verifyErrorId(@() e(Inf, 1e-10, 0.5), 'timeSeriesPreparation:eventTable:numericNaN');
            tc.verifyErrorId(@() e(1e-9, Inf, 0.5), 'timeSeriesPreparation:eventTable:numericNaN');
            tc.verifyErrorId(@() e(1e-9, -1e-10, 0.5), 'timeSeriesPreparation:eventTable:inputClass');
            % but a NaN amplitude and sigma mean 'not estimated' and must be accepted: that is
            % exactly what io.readTHR1B writes for every thruster firing.
            tc.verifyEqual(height(e(NaN, NaN, 1)), 1, 'a certain epoch with an unknown size is a valid event');
            tc.verifyEqual(height(e(0, 0, 0)), 1, 'the boundary values 0 are admissible');
            tc.verifyEqual(height(e(0, 0, 1)), 1, 'the boundary value 1 is admissible');
        end
        function hampelRobustness(tc)
            % NaN gaps: never flagged, never poison the neighbours; all-NaN and
            % constant series flag nothing; empty input gives empty output.
            x = randn(200, 1); x(90:110) = NaN; x(150) = 30;
            m = timeSeriesPreparation.qc.hampel(x);
            tc.verifyFalse(any(m(90:110))); tc.verifyTrue(m(150));
            tc.verifyFalse(any(timeSeriesPreparation.qc.hampel(nan(50,1))));
            tc.verifyFalse(any(timeSeriesPreparation.qc.hampel(ones(50,1))), 'zero MAD must not flag');
            tc.verifyFalse(any(timeSeriesPreparation.qc.hampel(ones(50,1), 'MinSigma', 1e-3)));
            tc.verifyEmpty(timeSeriesPreparation.qc.hampel(zeros(0,1)));
        end
    end
    methods (Test, TestTags = {'metamorphic'})
        function eventTableMetamorphic(tc)
            % Building one table from concatenated columns equals concatenating two tables built apart:
            % the schema constructor may not depend on how the rows were grouped.
            t = datetime(2020, 1, 1, 'TimeZone', 'UTC') + seconds([0 30 90 120]');
            cl = ["outlier"; "impulse"; "jump"; "outlier"]; ax = ["x"; "all"; "z"; "y"];
            am = [1e-9; -2e-9; 5e-9; 3e-10]; sg = [1e-10; 2e-10; 3e-10; 1e-10];
            so = ["unassigned"; "THR1B"; "eclipse"; "MAS1B"]; cf = [0.2; 1; 0.9; 0.5];
            whole = timeSeriesPreparation.qc.eventTable(t, t, cl, ax, am, sg, so, cf);
            i1 = 1:2; i2 = 3:4;
            a = timeSeriesPreparation.qc.eventTable(t(i1), t(i1), cl(i1), ax(i1), am(i1), sg(i1), so(i1), cf(i1));
            b = timeSeriesPreparation.qc.eventTable(t(i2), t(i2), cl(i2), ax(i2), am(i2), sg(i2), so(i2), cf(i2));
            tc.verifyEqual([a; b], whole, 'split and merge must agree exactly');
            % and a row order permutation only permutes the rows
            p = [3 1 4 2];
            perm = timeSeriesPreparation.qc.eventTable(t(p), t(p), cl(p), ax(p), am(p), sg(p), so(p), cf(p));
            tc.verifyEqual(perm, whole(p, :), 'the constructor must not reorder or reindex rows');
        end
        function hampelMetamorphic(tc)
            % Flags are invariant under affine transforms x -> a*x + b (a ~= 0)
            % and under time reversal; they shift with a circular shift of the
            % interior (edges excluded).
            rng(3); x = randn(500, 1); x([77 240 401]) = [11 -9 13];
            m = timeSeriesPreparation.qc.hampel(x);
            tc.verifyEqual(timeSeriesPreparation.qc.hampel(-3 * x + 7), m);
            tc.verifyEqual(timeSeriesPreparation.qc.hampel(flipud(x)), flipud(m));
            ms = timeSeriesPreparation.qc.hampel(circshift(x, 5));
            tc.verifyEqual(ms(41:460), m(36:455));
        end
    end
    methods (Test, TestTags = {'speed'})
        function hampelSpeed(tc)
            % Budget: one day of 1 Hz, 3 axes (86400x3) in under 20 s on any host.
            % Asserted as a ratio against a plain movmedian of the same data so
            % that the host speed cancels. Measured 2026-08-27 on R2026a: 382x,
            % which is the interpreted-loop vs compiled-builtin gap, not an
            % algorithmic defect (O(K*W) both). Bound 1000; the loop is the
            % first candidate for the C/MEX port (HANDOVER O-1).
            rng(4); x = randn(86400, 3);
            t1 = tic; timeSeriesPreparation.qc.hampel(x); tH = toc(t1);
            t2 = tic; movmedian(x, 61); tM = toc(t2);
            tc.verifyBoundAndRecord("hampel time 86400x3", tH, 20, "s");
            tc.verifyBoundAndRecord("hampel / movmedian ratio", tH / tM, 1000, "-");
        end
    end
end
