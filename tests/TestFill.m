classdef TestFill < matlab.unittest.TestCase
%TESTFILL  fill: gap report, and covariance collocation against closed forms and the whole record.
%
%   DESCRIPTION
%     Collocation is pinned where the conditional expectation has a
%     closed form, all written from the AR(1) autocovariance
%     gamma_k = phi^k / (1 - phi^2), not from fill's code:
%       - one missing sample: phi/(1 + phi^2) (x_(t-1) + x_(t+1)), variance
%         1/(1 + phi^2);
%       - a bridge of k samples between x_a and x_b, sample j:
%         [(phi^j - phi^(2k+2-j)) x_a + (phi^(k+1-j) - phi^(k+1+j)) x_b]
%         / (1 - phi^(2k+2)), variance (1 - phi^(2j))(1 - phi^(2(k+1-j)))
%         / ((1 - phi^(2k+2))(1 - phi^2)).
%     An AR(p) gap with a window >= p equals the prediction from the whole
%     record, solved here directly (the AR precision matrix is banded). An
%     ARMA(1,1) (phi 0.6, theta 0.5, 20-sample gap) converges to it: NumPy
%     measured at most 1.1e-12 sigma at L = 100 and 4.7e-15 sigma at L = 140
%     over 200 realisations (2026-09-24), so 1e-11 and 1e-13. Each value is
%     a solve with a matrix of condition below 1e3, so 1e-12 bounds the
%     rounding of the closed forms. The refusals are fault-injected by
%     their own trigger.
%
%   COVERAGE
%     reference      - AR(1) one sample and bridge (mean and sigma); AR(2)
%                      window equals the whole record.
%     precision      - ARMA(1,1) converges to the whole record as L grows.
%     contract       - "none" reports and changes nothing; statuses edge,
%                      tooLong, beyondModel and filled, flags, sigma and
%                      provenance; MaxGap is inclusive at 3 x 0.1 s;
%                      Window lowers W, and W = 1 is exact for AR(1).
%     metamorphic    - filling a filled arc again gives the same values;
%                      scaling x, acv and mu scales the fill and sigma.
%     vectorisation  - a two-axis call equals the one-axis calls.
%     robustness     - each identifier fires on its planted defect.
%     speed          - exempt: one Cholesky of at most 2W + k samples per
%                      gap; the stage is O(gaps (2W + k)^3) and W is
%                      capped by the model.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-24 08:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function ar1OneSampleClosedForm(testCase)
            phi = 0.7;
            x = ar1Series(phi, 400, 41);
            x(200) = NaN;
            [out, info] = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                Model = ar1Model(phi, 50), MaxGap = 1);
            testCase.verifyEqual(out.obs(200), phi / (1 + phi^2) * (x(199) + x(201)), "AbsTol", 1e-12);
            testCase.verifyEqual(info.sigma(200), sqrt(1 / (1 + phi^2)), "AbsTol", 1e-12);
        end

        function ar1BridgeClosedForm(testCase)
            phi = 0.7;
            k = 7;
            x = ar1Series(phi, 400, 42);
            x(100:106) = NaN;
            [out, info] = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                Model = ar1Model(phi, 50), MaxGap = 10);
            j = (1:k)';
            xa = x(99);
            xb = x(107);
            expected = ((phi.^j - phi.^(2*k + 2 - j)) * xa + (phi.^(k + 1 - j) - phi.^(k + 1 + j)) * xb) ...
                / (1 - phi^(2*k + 2));
            variance = (1 - phi.^(2*j)) .* (1 - phi.^(2*(k + 1 - j))) / ((1 - phi^(2*k + 2)) * (1 - phi^2));
            testCase.verifyEqual(out.obs(100:106), expected, "AbsTol", 1e-12);
            testCase.verifyEqual(info.sigma(100:106), sqrt(variance), "AbsTol", 1e-12);
        end

        function arpWindowEqualsWholeRecord(testCase)
            a = [1 -0.5 0.3];
            x = filter(1, a, randn(RandStream("twister", "Seed", 43), 1500, 1));
            x = x(501:end);
            N = numel(x);
            x([400:411, 420]) = NaN;                  % 420 lies inside the window
            acv = timeSeriesPreparation.spectral.arma2acv(1, a, N - 1);
            acv = acv(:);
            model = struct("acv", acv(1:40), "dt", 1, "mu", 0);
            [out, info] = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                Model = model, MaxGap = 12);
            [whole, wholeSigma] = wholeRecord(x, acv, 400:411);
            testCase.verifyEqual(info.gaps.width(1), 14);
            testCase.verifyEqual(out.obs(400:411), whole, "AbsTol", 1e-12);
            testCase.verifyEqual(info.sigma(400:411), wholeSigma, "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'precision'})
        function armaWindowConvergesToWholeRecord(testCase)
            b = [1 0.5];
            a = [1 -0.6];
            x = filter(b, a, randn(RandStream("twister", "Seed", 44), 3000, 1));
            x = x(1001:end);
            N = numel(x);
            x(900:919) = NaN;
            acv = timeSeriesPreparation.spectral.arma2acv(b, a, N - 1);
            acv = acv(:);
            whole = wholeRecord(x, acv, 900:919);
            sigma = sqrt(acv(1));
            for c = [100 1e-11; 140 1e-13]'
                model = struct("acv", acv(1:c(1) + 1), "dt", 1, "mu", 0);
                out = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                    Model = model, MaxGap = 20);
                testCase.verifyEqual(out.obs(900:919), whole, "AbsTol", c(2) * sigma, ...
                    sprintf("L = %d", c(1)));
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function noneReportsAndChangesNothing(testCase)
            X = ones(60, 2);
            X(10:12, 1) = NaN;
            X(1:2, 2) = NaN;
            arc = addLayer(makeArc(X, 0.2), "user", (1:60)' == 50);
            [out, info] = timeSeriesPreparation.fill(arc);
            testCase.verifyEqual(out.obs, arc.obs);
            testCase.verifyEqual(out.filled, false(60, 1));
            testCase.verifyEqual(numel(out.provenance), numel(arc.provenance));
            g = info.gaps;
            testCase.verifyEqual(g.axis, ["c1"; "c1"; "c2"; "c2"]);
            testCase.verifyEqual([g.first g.last], [10 12; 50 50; 1 2; 50 50]);
            testCase.verifyEqual(g.duration, [0.6; 0.2; 0.4; 0.2], "AbsTol", 1e-15);
            testCase.verifyEqual(g.status, repmat("notRequested", 4, 1));
            testCase.verifyTrue(all(isnan(g.width)));
            testCase.verifyEqual(info.nFilled, [0 0]);
            testCase.verifyEqual(info.method, "none");
        end

        function statusesFlagsAndProvenance(testCase)
            x = ar1Series(0.5, 300, 45);
            x([1:3, 100:130, 150:160, 200:204]) = NaN;
            [out, info] = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                Model = ar1Model(0.5, 10), MaxGap = 12);
            testCase.verifyEqual(info.gaps.status, ["edge"; "tooLong"; "beyondModel"; "filled"]);
            testCase.verifyEqual(nanToZero(info.gaps.width), [0; 0; 0; 3]);
            filled = false(300, 1);
            filled(200:204) = true;
            testCase.verifyEqual(out.filled, filled);
            testCase.verifyTrue(all(isfinite(out.obs(200:204))));
            testCase.verifyEqual(isnan(out.obs), isnan(x) & ~filled);
            testCase.verifyEqual(isfinite(info.sigma), filled);
            testCase.verifyEqual(info.nFilled, 5);
            testCase.verifyEqual(out.provenance(end).stage, "fill");
            testCase.verifyEqual(out.provenance(end).detail.method, "collocation");
            testCase.verifyEqual(out.provenance(end).detail.nFilled, 5);
        end

        function maxGapIsInclusive(testCase)
            x = ar1Series(0.5, 100, 46);
            x(40:42) = NaN;
            [~, info] = timeSeriesPreparation.fill(makeArc(x, 0.1), Method = "collocation", ...
                Model = setfield(ar1Model(0.5, 20), "dt", 0.1), MaxGap = 0.3); %#ok<SFLD>
            testCase.verifyEqual(info.gaps.status, "filled");
            [~, info] = timeSeriesPreparation.fill(makeArc(x, 0.1), Method = "collocation", ...
                Model = setfield(ar1Model(0.5, 20), "dt", 0.1), MaxGap = 0.29); %#ok<SFLD>
            testCase.verifyEqual(info.gaps.status, "tooLong");
        end

        function windowLowersWidth(testCase)
            phi = 0.7;
            x = ar1Series(phi, 400, 47);
            x(200) = NaN;
            [out, info] = timeSeriesPreparation.fill(makeArc(x, 1), Method = "collocation", ...
                Model = ar1Model(phi, 50), MaxGap = 1, Window = 1);
            testCase.verifyEqual(info.gaps.width, 1);
            testCase.verifyEqual(info.window, 1);
            testCase.verifyEqual(out.obs(200), phi / (1 + phi^2) * (x(199) + x(201)), "AbsTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function refillingGivesTheSameValues(testCase)
            x = ar1Series(0.6, 300, 48);
            x([50:53, 120, 200:209]) = NaN;
            opts = {"Method", "collocation", "Model", ar1Model(0.6, 40), "MaxGap", 10};
            once = timeSeriesPreparation.fill(makeArc(x, 1), opts{:});
            twice = timeSeriesPreparation.fill(once, opts{:});
            testCase.verifyEqual(twice.obs, once.obs);
            testCase.verifyEqual(twice.filled, once.filled);
            testCase.verifyEqual([twice.provenance(end-1:end).stage], ["fill" "fill"]);
        end

        function scalingScalesTheFill(testCase)
            x = ar1Series(0.6, 300, 49);
            x([50:53, 200:209]) = NaN;
            c = -3e-8;
            model = ar1Model(0.6, 40);
            model.mu = 0.2;
            [a, ia] = timeSeriesPreparation.fill(makeArc(x + 0.2, 1), Method = "collocation", ...
                Model = model, MaxGap = 10);
            scaled = struct("acv", model.acv * c^2, "dt", 1, "mu", 0.2 * c);
            [b, ib] = timeSeriesPreparation.fill(makeArc(c * (x + 0.2), 1), Method = "collocation", ...
                Model = scaled, MaxGap = 10);
            testCase.verifyEqual(b.obs, c * a.obs, "RelTol", 1e-12);
            testCase.verifyEqual(nanToZero(ib.sigma), abs(c) * nanToZero(ia.sigma), "RelTol", 1e-12);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function twoAxesEqualOneAxisEach(testCase)
            X = [ar1Series(0.6, 300, 50), ar1Series(0.3, 300, 51)];
            X([40:44, 150], 1) = NaN;
            X([41:43, 250:255], 2) = NaN;
            m1 = ar1Model(0.6, 30);
            m2 = ar1Model(0.3, 30);
            both = struct("acv", [m1.acv m2.acv], "dt", 1, "mu", [0 0]);
            [j, ij] = timeSeriesPreparation.fill(makeArc(X, 1), Method = "collocation", ...
                Model = both, MaxGap = 10);
            [a, ia] = timeSeriesPreparation.fill(makeArc(X(:, 1), 1), Method = "collocation", ...
                Model = m1, MaxGap = 10);
            [b, ib] = timeSeriesPreparation.fill(makeArc(X(:, 2), 1), Method = "collocation", ...
                Model = m2, MaxGap = 10);
            testCase.verifyEqual(j.obs, [a.obs b.obs]);
            testCase.verifyEqual(nanToZero(ij.sigma), nanToZero([ia.sigma ib.sigma]));
            testCase.verifyEqual(j.filled, a.filled | b.filled);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            x = ar1Series(0.5, 100, 52);
            x(50) = NaN;
            arc = makeArc(x, 1);
            model = ar1Model(0.5, 10);
            f = @(varargin) timeSeriesPreparation.fill(arc, varargin{:});
            testCase.verifyError(@() f("Method", "reference"), ...
                "timeSeriesPreparation:fill:referenceDeferred");
            testCase.verifyError(@() f("Method", "collocation", "Model", model), ...
                "timeSeriesPreparation:fill:maxGapMissing");
            testCase.verifyError(@() f("Method", "collocation", "MaxGap", 5), ...
                "timeSeriesPreparation:fill:modelMissing");
            bad = model;
            bad.dt = 2;
            testCase.verifyError(@() f("Method", "collocation", "Model", bad, "MaxGap", 5), ...
                "timeSeriesPreparation:fill:modelMismatch");
            bad = model;
            bad.acv = [bad.acv bad.acv];
            testCase.verifyError(@() f("Method", "collocation", "Model", bad, "MaxGap", 5), ...
                "timeSeriesPreparation:fill:modelMismatch");
            testCase.verifyError(@() f("Method", "collocation", "Model", rmfield(model, "mu"), "MaxGap", 5), ...
                "timeSeriesPreparation:fill:modelMismatch");
            bad = struct("acv", [1; 1.2; 1.2; 0; 0], "dt", 1, "mu", 0);
            testCase.verifyError(@() f("Method", "collocation", "Model", bad, "MaxGap", 5), ...
                "timeSeriesPreparation:fill:notPositiveDefinite");
            testCase.verifyError(@() f("Method", "collocation", "Model", model, "MaxGap", -1), ...
                "MATLAB:validators:mustBePositive");
            irregular = timeSeriesPreparation.Arc(int64([0 1 3])' * int64(1e9), [1; NaN; 2], auxOf(1));
            testCase.verifyError(@() timeSeriesPreparation.fill(irregular), ...
                "timeSeriesPreparation:fill:irregularGrid");
        end
    end
end

% ------------------------------------------------------------------------

function x = ar1Series(phi, N, seed)
% A stationary AR(1) of unit innovation variance, after a burn-in of 500.
    x = filter(1, [1 -phi], randn(RandStream("twister", "Seed", seed), N + 500, 1));
    x = x(501:end);
end

function model = ar1Model(phi, L)
% The AR(1) autocovariance gamma_k = phi^k / (1 - phi^2) to lag L, at 1 s.
    model = struct("acv", phi.^(0:L)' / (1 - phi^2), "dt", 1, "mu", 0);
end

function [expected, sigma] = wholeRecord(x, acv, gap)
% Conditional mean and sigma of x(gap) given every finite sample, zero mean.
    o = find(isfinite(x));
    gap = gap(:);
    C = @(r, c) reshape(acv(abs(r(:) - c(:)') + 1), numel(r), numel(c));
    R = chol(C(o, o));
    expected = C(gap, o) * (R \ (R' \ x(o)));
    V = R' \ C(gap, o)';
    sigma = sqrt(acv(1) - sum(V.^2, 1)');
end

function y = nanToZero(x)
% X with NaN replaced by 0, so arrays with NaN compare by value.
    y = x;
    y(isnan(y)) = 0;
end

function arc = makeArc(X, dt)
% An arc of columns c1..cM at step dt seconds.
    N = size(X, 1);
    t = int64(0:N - 1)' * int64(round(dt * 1e9));
    arc = timeSeriesPreparation.Arc(t, X, auxOf(size(X, 2)));
end

function aux = auxOf(M)
% readL1b-shaped metadata for M columns c1..cM.
    names = cellstr("c" + (1:M));
    units = cell2struct(repmat({'m/s2'}, M, 1), names, 1);
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
end
