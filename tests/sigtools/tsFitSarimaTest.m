classdef tsFitSarimaTest < matlab.unittest.TestCase
%TSFITSARIMATEST  tsFitSarima: seasonal ARIMA estimation, expansion, differencing and gaps.
%
%   DESCRIPTION
%     tsFitSarima estimates SARIMA(p,d,q)(P,D,Q)_s models by CSS or exact
%     ML. Checked here: parameter recovery for SARIMA(1,0,0)(1,0,0)_s by
%     both methods, the expanded AR polynomial, seasonal differencing,
%     reduction to plain ARMA when the seasonal orders are zero, the output
%     structure, exact ML with gaps, and the refusal of gaps with CSS or
%     differencing and of a too-short series.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - phi and Phi recovered over five seeds by CSS and by
%                    exact ML (0.08); the expansion of (1-phi B)(1-Phi B^s);
%                    ARMA(2,1) recovered with P=D=Q=0; exact and CSS sigma2
%                    agree (15 %).
%     contract     - D=1 differencing gives a finite fit; all documented
%                    fields are present.
%     robustness   - exact ML with NaN gaps recovers phi and Phi and marks
%                    the gaps; gaps with CSS, gaps with differencing and a
%                    too-short series are refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function seasonalAR1Recovery(tc)
        % SARIMA(1,0,0)(1,0,0)_12: recover phi and Phi (mean over seeds).
        s = 12; phi = 0.5; Phi = 0.3;
        phiEst = zeros(1,5); PhiEst = zeros(1,5);
        for r = 1:5
            rng(700 + r);
            x = local_simSAR(phi, Phi, s, 3000);
            m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false);
            phiEst(r) = m.ar(1); PhiEst(r) = m.sar(1);
        end
        tc.verifyEqual(mean(phiEst), phi, 'AbsTol', 0.08);
        tc.verifyEqual(mean(PhiEst), Phi, 'AbsTol', 0.08);
    end

    function expandedPolynomialsCorrect(tc)
        % (1-phi B)(1-Phi B^s) expansion must place coefficients correctly.
        s = 12;
        rng(710);
        x = local_simSAR(0.5, 0.3, s, 800);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false);
        % expanded AR has form [1, -phi, 0.., -Phi @ lag s, phi*Phi @ lag s+1]
        arExp = m.arExpanded;
        tc.verifyEqual(arExp(1), 1, 'AbsTol', 1e-12);
        tc.verifyEqual(numel(arExp), 1 + s + 1);          % order p + s*P
        tc.verifyEqual(arExp(2), -m.ar(1), 'AbsTol', 1e-12);
        tc.verifyEqual(arExp(1+s), -m.sar(1), 'AbsTol', 1e-12);
    end

    function reducesToPlainArma(tc)
        % With P=D=Q=0, tsFitSarima is an ARMA(p,q) CSS fit.
        rng(730);
        x = local_simARMA([0.5; -0.2], 0.3, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [2 0 1], [0 0 0], 1);
        tc.verifyEqual(m.ar(:), [0.5; -0.2], 'AbsTol', 0.12);
        tc.verifyEqual(m.ma(1), 0.3, 'AbsTol', 0.15);
        tc.verifyTrue(startsWith(m.type, 'ARMA'));
    end

    function exactMLRecoversSeasonalAR(tc)
        % Exact ML should recover phi, Phi at least as well as CSS.
        s = 12; phi = 0.5; Phi = 0.3;
        phiEst = zeros(1,5); PhiEst = zeros(1,5);
        for r = 1:5
            rng(760 + r);
            x = local_simSAR(phi, Phi, s, 2500);
            m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false, 'Method', 'exact');
            phiEst(r) = m.ar(1); PhiEst(r) = m.sar(1);
        end
        tc.verifyEqual(mean(phiEst), phi, 'AbsTol', 0.08);
        tc.verifyEqual(mean(PhiEst), Phi, 'AbsTol', 0.08);
    end

    function exactMLHigherLogLThanCss(tc)
        % On the same data the exact Gaussian logL should be >= the CSS
        % pseudo-logL is not directly comparable, but exact ML must produce a
        % finite, larger-sample logL and a valid model. Here we sanity-check
        % that exact ML runs, is finite, and its sigma2 is close to CSS.
        rng(765);
        s = 12;
        x = local_simSAR(0.5, 0.3, s, 1500);
        me = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 0 0], s, 'Method', 'exact');
        mc = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 0 0], s, 'Method', 'css');
        tc.verifyTrue(isfinite(me.logL));
        tc.verifyEqual(me.method, 'exact');
        tc.verifyEqual(me.sigma2, mc.sigma2, 'RelTol', 0.15);
    end

    end

    methods (Test, TestTags = {'contract'})

    function seasonalDifferencingApplied(tc)
        % A series with a strong seasonal unit root: (1-B^s)^1 should render
        % it stationary and the fit should be finite / converge.
        s = 4; rng(720);
        base = local_simSAR(0.4, 0.0, s, 1200);
        seas = repmat([2 -1 0.5 -1.5]', ceil(numel(base)/s), 1);
        x = base + seas(1:numel(base)) + cumsum(zeros(numel(base),1));
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [0 1 0], s);
        tc.verifyEqual(m.D, 1);
        tc.verifyTrue(isfinite(m.logL));
        tc.verifyGreaterThan(m.sigma2, 0);
    end

    function outputStructIntegrity(tc)
        rng(740);
        x = local_simSAR(0.5, 0.3, 12, 1500);
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 1 0], 12);
        for fld = {'type','p','d','q','P','D','Q','season','mu','ar','ma', ...
                   'sar','sma','arExpanded','maExpanded','sigma2','resid', ...
                   'logL','aic','bic','k','n','nObs','method','converged'}
            tc.verifyTrue(isfield(m, fld{1}), ['missing field ' fld{1}]);
        end
        tc.verifyEqual(m.method, 'css');
        tc.verifyTrue(startsWith(m.type, 'SARIMA'));
    end

    end

    methods (Test, TestTags = {'robustness'})

    function exactMLHandlesGaps(tc)
        % Exact ML with NaN gaps (d=D=0): recovers seasonal AR and marks obs.
        s = 6; phi = 0.4; Phi = 0.35;
        rng(770);
        x = local_simSAR(phi, Phi, s, 3000);
        x(500:520) = NaN; x(1000:1005) = NaN; x(2000:2050) = NaN;
        m = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Constant', false, 'Method', 'exact');
        tc.verifyTrue(isfield(m, 'obs'));
        tc.verifyEqual(sum(~m.obs), 21 + 6 + 51);
        tc.verifyEqual(m.ar(1),  phi, 'AbsTol', 0.1);
        tc.verifyEqual(m.sar(1), Phi, 'AbsTol', 0.1);
        tc.verifyTrue(isfinite(m.logL));
    end

    function cssRejectsGaps(tc)
        s = 6; rng(775);
        x = local_simSAR(0.4, 0.3, s, 500); x(100) = NaN;
        tc.verifyError(@() timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 0], [1 0 0], s, 'Method', 'css'), ...
            'timeSeriesPreparation:tsFitSarima:gapsNeedExact');
    end

    function exactGapsRejectDifferencing(tc)
        s = 6; rng(776);
        x = local_simSAR(0.4, 0.3, s, 500); x(100) = NaN;
        tc.verifyError(@() timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 1 0], [1 0 0], s, 'Method', 'exact'), ...
            'timeSeriesPreparation:tsFitSarima:gapsWithDiff');
    end

    function shortSeriesErrors(tc)
        tc.verifyError(@() timeSeriesPreparation.tsmodels.tsFitSarima((1:14)', [1 0 0], [1 0 0], 12), ...
            'timeSeriesPreparation:tsFitSarima:tooShort');
    end

    end
end

% ====================================================================
% Local simulation helpers
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
