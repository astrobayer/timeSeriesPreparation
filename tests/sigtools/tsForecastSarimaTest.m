classdef tsForecastSarimaTest < matlab.unittest.TestCase
%TSFORECASTSARIMATEST  tsForecast on SARIMA models: point path, standard errors, intervals, bootstrap.
%
%   DESCRIPTION
%     The seasonal path of tsForecast forecasts a tsFitSarima model on the
%     expanded ARMA, re-integrates through (1-B)^d (1-B^s)^D and propagates
%     the error variance with the original-scale psi-weights. Checked here:
%     shapes and finiteness, the one-step SE, monotone SE, interval
%     coverage, an independent one-step reconstruction, persistence of the
%     seasonal cycle, reduction to the plain ARMA forecast, a Monte-Carlo
%     forecast distribution, gapped models and bootstrap intervals.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - one-step SE = sigma (1e-10); independent one-step and
%                    plain-ARMA reconstructions (1e-10); the seasonal cycle
%                    persists; 95 % coverage in (0.88, 0.995); Monte-Carlo
%                    mean and SE; bootstrap half-width near the Gaussian
%                    one.
%     contract     - sizes, finiteness and ordered bounds; SE does not
%                    decrease; bootstrap intervals are ordered and contain
%                    the point forecast.
%     metamorphic  - the same bootstrap Seed gives the same intervals.
%     robustness   - a gapped exact-ML model forecasts through the Kalman
%                    path with finite, monotone output.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    % ---------------------------------------------------------------
    function oneStepSeEqualsSigma(tc)
        % The one-step-ahead forecast SE must equal sqrt(sigma2) exactly,
        % regardless of seasonal/nonseasonal differencing.
        rng(801);
        x = local_simSAR(0.4, -0.2, 6, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 1 0], [1 1 0], 6);
        [~, se] = timeSeriesPreparation.tsmodels.tsForecast(m, 10);
        tc.verifyEqual(se(1), sqrt(m.sigma2), 'RelTol', 1e-10);
    end

    % ---------------------------------------------------------------
    function historyReconstructionOneStep(tc)
        % Re-running the model's own one-step prediction machinery from the
        % end of the sample must reproduce the differencing inversion: the
        % first forecast equals the value obtained by feeding the fitted
        % working-scale one-step prediction back through Delta(B) with the
        % observed tail. Here we check it against a direct re-integration.
        rng(803);
        s = 4;
        x = local_simSAR(0.5, 0.3, s, 1200);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [0 1 0], s);   % D=1 only
        yh = timeSeriesPreparation.tsmodels.tsForecast(m, 1);

        % independent one-step reconstruction:
        arc = -m.arExpanded(2:end);
        w   = m.xd(:) - m.mu;
        wpred = 0;
        for i = 1:numel(arc), wpred = wpred + arc(i)*w(end-i+1); end
        wpred = wpred + m.mu;                       % working-scale forecast
        % Delta(B) = (1-B^s)^1 -> x_t = w_t + x_{t-s}
        xhat1 = wpred + x(end-s+1);
        tc.verifyEqual(yh(1), xhat1, 'RelTol', 1e-10, 'AbsTol', 1e-10);
    end

    % ---------------------------------------------------------------
    function seasonalPatternPersists(tc)
        % A dominant deterministic seasonal cycle removed by (1-B^s)^1 must
        % re-appear in the forecast: forecasts one period apart differ far
        % less than forecasts within a period (the cycle is carried).
        rng(804);
        s = 12;
        cyc = sin(2*pi*(1:s)'/s);
        base = local_simSAR(0.3, 0.0, s, 100*s);
        seas = repmat(3*cyc, ceil(numel(base)/s), 1);
        x = base + seas(1:numel(base));
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [0 1 1], s);
        yh = timeSeriesPreparation.tsmodels.tsForecast(m, 2*s);
        withinPeriod  = max(yh(1:s)) - min(yh(1:s));
        acrossPeriods = max(abs(yh(1:s) - yh(s+1:2*s)));
        tc.verifyGreaterThan(withinPeriod, acrossPeriods);
    end

    % ---------------------------------------------------------------
    function reducesToPlainArmaForecast(tc)
        % With P=D=Q=0 and d=0, the seasonal path must coincide with the
        % ordinary ARMA forecast produced from the same coefficients.
        rng(805);
        x = local_simARMA([0.5; -0.2], 0.3, 3000);
        ms = timeSeriesPreparation.tsmodels.tsFitSarima(x, [2 0 1], [0 0 0], 1);   % routed through seasonal path
        [yhS, seS] = timeSeriesPreparation.tsmodels.tsForecast(ms, 15);

        % Build an equivalent plain-ARIMA struct forecast by hand from the
        % same expanded coefficients (arExpanded == ar, maExpanded == ma here).
        arc = -ms.arExpanded(2:end); arc = arc(:);
        mac =  ms.maExpanded(2:end); mac = mac(:);
        w = ms.xd(:) - ms.mu; e = ms.resid(:); n = numel(w);
        h = 15; wext = [w; zeros(h,1)]; eext = [e; zeros(h,1)]; fw = zeros(h,1);
        for st = 1:h
            t = n+st; pr = 0;
            for i = 1:numel(arc), pr = pr + arc(i)*wext(t-i); end
            for j = 1:numel(mac), pr = pr + mac(j)*eext(t-j); end
            wext(t) = pr; eext(t) = 0; fw(st) = pr + ms.mu;
        end
        tc.verifyEqual(yhS, fw, 'RelTol', 1e-10, 'AbsTol', 1e-10);
        tc.verifyEqual(seS(1), sqrt(ms.sigma2), 'RelTol', 1e-10);
    end

    % ---------------------------------------------------------------
    function intervalCoverageIsReasonable(tc)
        % Out-of-sample coverage of the 95% one-step interval across many
        % refits should sit near nominal (loose band to stay robust).
        rng(806);
        s = 4; phi = 0.5; Phi = 0.3; covered = 0; reps = 200;
        for r = 1:reps
            full = local_simSAR(phi, Phi, s, 600 + s + 1);
            xtr  = full(1:end-1);
            xnew = full(end);
            m = timeSeriesPreparation.tsmodels.tsFitSarima(xtr, [1 0 0], [1 0 0], s, 'Constant', false);
            [~, ~, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 1, 0.05);
            covered = covered + (xnew >= lo(1) && xnew <= hi(1));
        end
        cov = covered / reps;
        tc.verifyGreaterThan(cov, 0.88);
        tc.verifyLessThan(cov, 0.995);
    end

    % ---------------------------------------------------------------
    function matchesMonteCarloDistribution(tc)
        % The analytic point forecast and SE must match a Monte-Carlo
        % forecast distribution simulated forward from the fitted model.
        rng(807);
        s = 4;
        x = local_simSAR(0.5, -0.3, s, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 1 0], [1 1 0], s);
        h = 10;
        [yh, se] = timeSeriesPreparation.tsmodels.tsForecast(m, h);

        % Monte-Carlo forward simulation from the fitted expanded model.
        arc = -m.arExpanded(2:end); arc = arc(:);
        mac =  m.maExpanded(2:end); mac = mac(:);
        d = m.diffInfo.d; D = m.diffInfo.D;
        delta = 1;
        for i = 1:d, delta = conv(delta, [1; -1]); end
        for i = 1:D, sd = zeros(s+1,1); sd(1)=1; sd(s+1)=-1; delta = conv(delta, sd); end
        gc = -delta(2:end); gd = numel(gc);
        w0 = m.xd(:) - m.mu; e0 = m.resid(:); x0 = m.x(:);
        Pd = numel(arc); Qd = numel(mac); sg = sqrt(m.sigma2);

        M = 4000; fut = zeros(M, h);
        for mm = 1:M
            wl = w0; el = e0; xl = x0;
            en = sg*randn(h,1);
            for k = 1:h
                pr = 0;
                for i = 1:Pd, pr = pr + arc(i)*wl(end-i+1); end
                for j = 1:Qd, pr = pr + mac(j)*el(end-j+1); end
                pr = pr + en(k);
                wl(end+1,1) = pr; el(end+1,1) = en(k); %#ok<AGROW>
                xt = (pr + m.mu);
                for i = 1:gd, xt = xt + gc(i)*xl(end-i+1); end
                xl(end+1,1) = xt; %#ok<AGROW>
                fut(mm,k) = xt;
            end
        end
        mcMean = mean(fut,1)'; mcStd = std(fut,0,1)';
        % point forecast: within a few MC standard errors
        tc.verifyLessThan(max(abs(yh - mcMean)), 0.15 * max(abs(mcStd)) + 0.05);
        % SE ratio near 1 (MC noise ~ 1/sqrt(2M) per point)
        tc.verifyEqual(se ./ mcStd, ones(h,1), 'AbsTol', 0.08);
    end

    function bootstrapMatchesGaussianForGaussianResid(tc)
        % With near-Gaussian residuals the bootstrap 95% half-width should be
        % close to the Gaussian z*se half-width.
        rng(810);
        s = 6;
        x = local_simSAR(0.4, 0.2, s, 4000);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false);
        [~, se, loB, hiB] = timeSeriesPreparation.tsmodels.tsForecast(m, 8, 0.05, 'Bootstrap', true, ...
            'NBoot', 5000, 'Seed', 7);
        z = 1.959963984540054;
        hwBoot  = (hiB - loB)/2;
        hwGauss = z*se;
        tc.verifyEqual(hwBoot ./ hwGauss, ones(8,1), 'AbsTol', 0.15);
    end

    end

    methods (Test, TestTags = {'contract'})

    % ---------------------------------------------------------------
    function outputShapesAndFiniteness(tc)
        rng(800);
        x = local_simSAR(0.5, 0.3, 12, 1500);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], 12, 'Constant', false);
        h = 24;
        [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, h);
        tc.verifySize(yh, [h 1]);
        tc.verifySize(se, [h 1]);
        tc.verifySize(lo, [h 1]);
        tc.verifySize(hi, [h 1]);
        tc.verifyTrue(all(isfinite([yh; se; lo; hi])));
        tc.verifyTrue(all(hi >= lo));
    end

    % ---------------------------------------------------------------
    function seIsNonDecreasing(tc)
        rng(802);
        x = local_simSAR(0.5, 0.25, 12, 1500);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 1 0], 12);
        [~, se] = timeSeriesPreparation.tsmodels.tsForecast(m, 36);
        tc.verifyTrue(all(diff(se) >= -1e-9));
    end

    % ---------------------------------------------------------------
    function bootstrapIntervalRuns(tc)
        % Bootstrap intervals for a seasonal model: correct shape, ordering,
        % and contain the point forecast.
        rng(809);
        s = 12;
        x = local_simSAR(0.5, 0.3, s, 1500);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false);
        [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 20, 0.05, 'Bootstrap', true, ...
            'NBoot', 1500, 'Seed', 1);
        tc.verifySize(lo, [20 1]);
        tc.verifyTrue(all(hi >= lo));
        tc.verifyTrue(all(yh >= lo - 1e-9 & yh <= hi + 1e-9));
        tc.verifyTrue(all(isfinite(se)));
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function bootstrapReproducibleWithSeed(tc)
        rng(811);
        x = local_simSAR(0.5, 0.3, 12, 1200);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], 12, 'Constant', false);
        [~, ~, lo1, hi1] = timeSeriesPreparation.tsmodels.tsForecast(m, 10, 0.05, 'Bootstrap', true, 'Seed', 42);
        [~, ~, lo2, hi2] = timeSeriesPreparation.tsmodels.tsForecast(m, 10, 0.05, 'Bootstrap', true, 'Seed', 42);
        tc.verifyEqual(lo1, lo2);
        tc.verifyEqual(hi1, hi2);
    end

    end

    methods (Test, TestTags = {'robustness'})

    % ---------------------------------------------------------------
    function gappedSeasonalForecastRuns(tc)
        % A gapped exact-ML SARIMA model must forecast via the Kalman-state
        % path: finite outputs, monotone SE, one-step SE == sqrt(sigma2).
        rng(808);
        s = 6;
        x = local_simSAR(0.4, 0.35, s, 2500);
        x(400:410) = NaN; x(1200:1230) = NaN;
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false, 'Method', 'exact');
        [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 3*s);
        tc.verifySize(yh, [3*s 1]);
        tc.verifyTrue(all(isfinite([yh; se; lo; hi])));
        tc.verifyTrue(all(diff(se) >= -1e-9));
        tc.verifyEqual(se(1), sqrt(m.sigma2), 'RelTol', 1e-9);
        tc.verifyTrue(all(hi >= lo));
    end

    end
end

% ====================================================================
% Local simulation helpers (mirrors tsFitSarimaTest)
% ====================================================================
function x = local_simSAR(phi, Phi, s, n, burn)
%   SARIMA(1,0,0)(1,0,0)_s: (1-phi B)(1-Phi B^s) x = e
    if nargin < 5, burn = 400; end
    N = n + burn; e = randn(N,1); x = zeros(N,1);
    for t = s+2:N
        x(t) = phi*x(t-1) + Phi*x(t-s) - phi*Phi*x(t-s-1) + e(t);
    end
    x = x(burn+1:end);
end

function x = local_simARMA(phi, theta, n, burn)
    if nargin < 4, burn = 300; end
    phi = phi(:); theta = theta(:);
    p = numel(phi); q = numel(theta); N = n + burn;
    e = randn(N,1); x = zeros(N,1);
    for t = max(p,q)+1:N
        ar = 0; if p>0, ar = phi.'  * x(t-1:-1:t-p); end
        ma = 0; if q>0, ma = theta.'* e(t-1:-1:t-q); end
        x(t) = ar + e(t) + ma;
    end
    x = x(burn+1:end);
end
