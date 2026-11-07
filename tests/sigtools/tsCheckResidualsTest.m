classdef tsCheckResidualsTest < matlab.unittest.TestCase
%TSCHECKRESIDUALSTEST  tsCheckResiduals: residual diagnostics of fitted models, with gaps.
%
%   DESCRIPTION
%     tsCheckResiduals computes the residual ACF, Ljung-Box and Jarque-Bera
%     statistics of a fitted model. Checked here: the output structure and
%     its plot, large Ljung-Box p-values for a correctly specified model,
%     small ones for a misspecified model, and residuals with gaps. Figures
%     are closed in teardown.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - a correct AR(1) leaves white residuals (median LB p >
%                    0.05); AR(1) on ARMA(2,1) data is detected (min p <
%                    0.05).
%     contract     - sizes of acf and lbP, positive band, finite JB with p
%                    in [0,1]; the residual plot returns a figure.
%     robustness   - with 20 % gaps the residuals are NaN at the gaps and
%                    all lags are tested.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties
        fig
    end

    methods (TestMethodTeardown)
        function closeFig(tc)
            if ~isempty(tc.fig) && all(isgraphics(tc.fig)), close(tc.fig); end
            tc.fig = [];
        end
    end

    methods (Test, TestTags = {'reference'})

    function wellSpecifiedWhiteResiduals(tc)
        % A correctly specified AR(1) leaves white residuals -> large LB p.
        rng(801);
        x = local_simAR(0.7, 3000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 20);
        tc.verifyGreaterThan(median(out.lbP), 0.05);
    end

    function misspecifiedDetected(tc)
        % Fit AR(1) to ARMA(2,1) data with strong structure -> small LB p at
        % higher lags for the leftover autocorrelation.
        rng(802);
        x = local_simARMA([0.6; -0.3], 0.5, 3000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 20);
        tc.verifyLessThan(min(out.lbP), 0.05);
    end

    end

    methods (Test, TestTags = {'contract'})

    function outputShape(tc)
        rng(800);
        x = local_simAR(0.6, 2000);
        m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 15);
        h = timeSeriesPreparation.tsmodels.plotResiduals(out);
        tc.fig = h.figure;
        tc.verifySize(out.acf, [15 1]);
        tc.verifySize(out.lbP, [15 1]);
        tc.verifyGreaterThan(out.acfConf, 0);
        tc.verifyTrue(isfinite(out.jbStat));
        tc.verifyGreaterThanOrEqual(out.jbP, 0);
        tc.verifyLessThanOrEqual(out.jbP, 1);
    end

    end

    methods (Test, TestTags = {'robustness'})

    function handlesGaps(tc)
        rng(803);
        x = local_simAR(0.6, 2000);
        xg = x; xg(rand(numel(x),1) < 0.2) = NaN;
        m = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0);
        out = timeSeriesPreparation.tsmodels.tsCheckResiduals(m, 15);
        tc.verifyTrue(all(isnan(out.resid(~m.obs))));
        tc.verifyEqual(numel(out.lbP), 15);
    end

    end
end

% ====================================================================
function x = local_simAR(phi, n, burn)
    if nargin < 3, burn = 200; end
    phi = phi(:); p = numel(phi); N = n + burn;
    e = randn(N,1); x = zeros(N,1);
    for t = p+1:N
        x(t) = phi.' * x(t-1:-1:t-p) + e(t);
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
