classdef tsmodelsExtraTest < matlab.unittest.TestCase
%TSMODELSEXTRATEST  tsFitArima reparametrisation, multi-seed recovery, SE calibration, extras.
%
%   DESCRIPTION
%     Tests of the reparametrised ARIMA estimator (stationary and invertible
%     by construction) and of later additions: multi-seed parameter recovery
%     with mean-based assertions, calibration of the standard errors,
%     tsFitSarima recovery and seasonal differencing, tsCheckResiduals and
%     bootstrap forecast intervals.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - AR(1) and ARMA(2,1) recovered over many seeds; 95 %
%                    Wald intervals cover the truth (> 80 %); SARIMA reduces
%                    to ARIMA and recovers phi and Phi; white residuals pass
%                    Ljung-Box; bootstrap half-width near the Gaussian one.
%     contract     - fits stay stationary and invertible; multi-start CSS is
%                    finite; seasonal and ordinary differencing are
%                    recorded; residual diagnostics structure; ARIMA
%                    bootstrap intervals are ordered, finite and widen.
%     robustness   - a near-unit-root series (phi = 0.97) still gives a
%                    stationary fit.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    % ---- multi-seed recovery (mean-based, robust to single seeds) ------
    function ar1RecoveryMultiSeed(tc)
        phi = 0.6; nrep = 12; est = zeros(nrep,1);
        for r = 1:nrep
            rng(500 + r);
            x = local_simAR(phi, 2000);
            m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
            est(r) = m.ar(1);
        end
        tc.verifyEqual(mean(est), phi, 'AbsTol', 0.02);   % mean is tight
        tc.verifyLessThan(std(est), 0.05);                % low scatter
    end

    function arma21RecoveryMultiSeed(tc)
        phi = [0.5 -0.3]; th = 0.4; nrep = 10;
        A = zeros(nrep,2); M = zeros(nrep,1);
        for r = 1:nrep
            rng(600 + r);
            x = local_simARMA(phi, th, 4000);
            m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1);
            A(r,:) = m.ar; M(r) = m.ma(1);
        end
        tc.verifyEqual(mean(A,1), phi, 'AbsTol', 0.04);
        tc.verifyEqual(mean(M),  th,  'AbsTol', 0.05);
    end

    % ---- standard errors are calibrated (true value within ~k*SE) ------
    function seCoversTruth(tc)
        % Fraction of 95% Wald intervals covering the truth ~ 0.95.
        phi = 0.5; nrep = 30; covered = 0; valid = 0;
        for r = 1:nrep
            rng(700 + r);
            x = local_simAR(phi, 1500);
            m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
            % SE order in stdErr: [mu?, ar, ma]; mu present by default
            seAr = m.stdErr(1 + double(m.const));
            if isfinite(seAr) && seAr > 0
                valid = valid + 1;
                if abs(m.ar(1) - phi) <= 1.96*seAr, covered = covered + 1; end
            end
        end
        tc.assumeGreaterThan(valid, 20);
        frac = covered / valid;
        tc.verifyGreaterThan(frac, 0.80);   % generous band around 0.95
        tc.verifyLessThanOrEqual(frac, 1.0);
    end

    % ---- tsFitSarima ----------------------------------------------------
    function sarimaReducesToArima(tc)
        rng(801);
        x = local_simARMA([0.5 -0.2], 0.3, 2000);
        ms = timeSeriesPreparation.tsmodels.tsFitSarima(x, [2 0 1], [0 0 0], 1);
        tc.verifyEqual(ms.ar, [0.5 -0.2], 'AbsTol', 0.08);
        tc.verifyEqual(ms.ma(1), 0.3, 'AbsTol', 0.10);
    end

    function sarimaSeasonalRecovery(tc)
        % SARIMA(1,0,0)(1,0,0)_12 recovery on simulated seasonal data.
        rng(802);
        s = 12; phi = 0.5; Phi = 0.3;
        AR = conv([1 -phi], [1 zeros(1,s-1) -Phi]);
        arc = -AR(2:end);
        N = 5000; e = randn(N,1); x = zeros(N,1);
        for t = numel(arc)+1:N
            x(t) = e(t);
            for i = 1:numel(arc), x(t) = x(t) + arc(i)*x(t-i); end
        end
        x = x(1001:end);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s);
        tc.verifyEqual(m.ar(1),  phi, 'AbsTol', 0.08);
        tc.verifyEqual(m.sar(1), Phi, 'AbsTol', 0.08);
    end

    function checkResidualsWhiteNoiseLB(tc)
        % Correctly-specified model -> Ljung-Box mostly non-significant.
        rng(902);
        x = local_simAR(0.6, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 20);
        tc.verifyGreaterThan(mean(out.lbP > 0.05), 0.5);
    end

    function bootstrapForecastNonSeasonal(tc)
        % Bootstrap intervals on a plain ARMA: valid ordering, contain the
        % point forecast, half-width near the Gaussian one for Gaussian noise.
        rng(903);
        x = local_simARMA([0.5 -0.2], 0.3, 4000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1);
        [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 8, 0.05, 'Bootstrap', true, ...
            'NBoot', 5000, 'Seed', 3);
        tc.verifyTrue(all(hi >= lo));
        tc.verifyTrue(all(yh >= lo - 1e-9 & yh <= hi + 1e-9));
        z = 1.959963984540054;
        tc.verifyEqual(((hi-lo)/2) ./ (z*se), ones(8,1), 'AbsTol', 0.15);
    end

    end

    methods (Test, TestTags = {'contract'})

    function highOrderStaysInRegion(tc)
        rng(402);
        phi = [0.3 0.2 -0.1 0.15]; x = local_simAR(phi, 3000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 4, 0, 0);
        tc.verifyLessThan(max(abs(roots([1 -m.ar]))), 1.0);  % stationary
    end

    function maStaysInvertible(tc)
        rng(403);
        th = 0.8; x = local_simMA(th, 3000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 0, 0, 1);
        tc.verifyLessThanOrEqual(max(abs(roots([1 m.ma]))), 1.0 + 1e-9);
    end

    function multiStartBeatsSingle(tc)
        % The returned optimum should be at least as good as a zero-start CSS.
        rng(760);
        x = local_simARMA([0.6 -0.3], 0.5, 3000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1, 'Method', 'css');
        tc.verifyTrue(isfinite(m.logL));
        tc.verifyLessThan(max(abs(roots([1 -m.ar]))), 1.0);
    end

    function sarimaSeasonalDifferencing(tc)
        % Seasonal random walk: (1-B^12) removes the seasonal unit root.
        rng(803);
        s = 12; N = 1500;
        base = cumsum(randn(N,1));            % stochastic trend
        seas = repmat(sin(2*pi*(1:s)'/s), ceil(N/s), 1);
        seas = seas(1:N);
        x = base + seas;
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 1 0], [0 1 0], s);
        tc.verifyTrue(isfinite(m.logL));
        tc.verifyEqual(m.D, 1);
        tc.verifyEqual(m.d, 1);
    end

    % ---- tsCheckResiduals ----------------------------------------------
    function checkResidualsStructure(tc)
        rng(901);
        x = local_simARMA([0.5 -0.2], 0.3, 1500);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 15);
        tc.verifySize(out.acf, [15 1]);
        tc.verifySize(out.lbP, [15 1]);
        tc.verifyTrue(all(out.lbP >= 0 & out.lbP <= 1));
        tc.verifyGreaterThan(out.acfConf, 0);
        tc.verifyTrue(isfinite(out.jbP));
    end

    function bootstrapForecastARIMA(tc)
        % Bootstrap must also work through d>0 integration (original-scale Psi).
        rng(904);
        z = cumsum(0.02 + randn(600,1));
        m = timeSeriesPreparation.tsmodels.tsFitArima(z, 1, 1, 1);
        [~, ~, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 12, 0.1, 'Bootstrap', true, ...
            'NBoot', 2000, 'Seed', 5);
        tc.verifyTrue(all(hi >= lo));
        tc.verifyTrue(all(isfinite([lo; hi])));
        tc.verifyTrue(all(diff(hi - lo) >= -1e-6));   % widening intervals
    end

    end

    methods (Test, TestTags = {'robustness'})

    % ---- reparametrisation keeps every fit stationary/invertible -------
    function fitsAlwaysStationary(tc)
        % Even on a near-unit-root series the returned AR poly is stationary.
        rng(401);
        phi = 0.97; x = local_simAR(phi, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
        tc.verifyLessThan(max(abs(roots([1 -m.ar]))), 1.0);
    end

    end
end

% ====================================================================
% Local simulation helpers
% ====================================================================
function x = local_simAR(phi, n, burn)
    if nargin < 3, burn = 300; end
    phi = phi(:); p = numel(phi); N = n + burn;
    e = randn(N,1); x = zeros(N,1);
    for t = p+1:N, x(t) = phi.' * x(t-1:-1:t-p) + e(t); end
    x = x(burn+1:end);
end

function x = local_simMA(theta, n, burn)
    if nargin < 3, burn = 300; end
    theta = theta(:); q = numel(theta); N = n + burn;
    e = randn(N+q,1); x = zeros(N,1);
    for t = 1:N, x(t) = e(t+q) + theta.' * e(t+q-1:-1:t); end
    x = x(burn+1:end);
end

function x = local_simARMA(phi, theta, n, burn)
    if nargin < 4, burn = 400; end
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
