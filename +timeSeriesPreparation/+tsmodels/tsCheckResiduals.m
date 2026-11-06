function out = tsCheckResiduals(model, lags)
%TSCHECKRESIDUALS  Residual diagnostics of a fitted ARIMA/SARIMA model: ACF, Ljung-Box, Jarque-Bera.
%
%   SYNTAX
%     out = timeSeriesPreparation.tsmodels.tsCheckResiduals(model)
%     out = timeSeriesPreparation.tsmodels.tsCheckResiduals(model, lags)
%
%   DESCRIPTION
%     The numbers behind the standard residual check of a model from
%     tsFitArima and its wrappers:
%       - the standardised residuals;
%       - the residual ACF with its white-noise band;
%       - the Ljung-Box p-value ladder over lags 1..L, with degrees of
%         freedom L minus the number of ARMA parameters;
%       - the Jarque-Bera normality test (chi-square, 2 dof);
%       - the normal Q-Q pairs.
%     Since X-02 it draws nothing. plotResiduals draws the four-panel figure
%     from this output (owner decision 2026-09-23, clean break). The numbers
%     are v1.3.1's; the output lost the field figure and gained the Q-Q
%     data qqSample and qqTheoretical, which v1.3.1 computed only for the
%     plot. Base MATLAB only.
%
%   INPUTS
%     model  (1,1) struct   -   From tsFitArima, tsFitAR, tsFitMA, tsFitARMA
%                               or tsAutoArima; uses resid, obs, p, q, and P,
%                               Q for SARIMA.
%     lags   (1,1) double   -   Largest lag of the ACF and the ladder; [] or
%                               omitted: min(20, floor(nObs/4)).
%
%   OUTPUTS
%     out  (1,1) struct   -   Fields: resid (N,1) standardised residuals,
%                             NaN at gaps; acf (L,1), lags 1..L; acfConf,
%                             the +/- white-noise band; lags and lbLags
%                             (L,1); lbP and lbQ (L,1), the Ljung-Box
%                             p-values and statistics; jbStat, jbP; qqSample
%                             (nObs,1), the sorted standardised residuals;
%                             qqTheoretical (nObs,1), the normal quantiles at
%                             (k - 0.5)/nObs.
%
%   ACCURACY
%     The chi-square CDF comes from a series and continued-fraction
%     incomplete gamma, converged to 1e-14 relative. The normal quantiles
%     use the Acklam rational approximation, whose relative error is below
%     1.15e-9. The numbers are unchanged from v1.3.1, and
%     TestSigtoolsEquivalence holds them bit for bit.
%
%   ERRORS
%     (none)
%     A model without the field resid, or a lags that is not a scalar, is
%     refused by the arguments block or by MATLAB with a MATLAB: identifier.
%
%   EXAMPLE
%     % An AR(1) fit and its residual numbers.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 2), 500, 1));
%     out = timeSeriesPreparation.tsmodels.tsCheckResiduals(timeSeriesPreparation.tsmodels.tsFitAR(x, 1));
%
%   LIMITATIONS
%     The Ljung-Box degrees of freedom subtract p + q (+ P + Q); for lags
%     below that count they are clamped to 1, so the first p-values are
%     not meaningful.
%
%   REFERENCES
%     G. M. Ljung, G. E. P. Box (1978), Biometrika 65(2), 297-303.
%     C. M. Jarque, A. K. Bera (1980), Econ. Lett. 6(3), 255-259.
%     P. J. Acklam (2003), An algorithm for computing the inverse normal
%     cumulative distribution function.
%
%   See also timeSeriesPreparation.tsmodels.plotResiduals, timeSeriesPreparation.tsmodels.tsLjungBox, timeSeriesPreparation.tsmodels.tsAcf, timeSeriesPreparation.tsmodels.tsFitArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        model (1,1) struct
        lags {mustBeScalarOrEmpty, mustBeNumeric} = []
    end

    e = model.resid(:);
    obs = true(size(e));
    if isfield(model, 'obs') && ~isempty(model.obs), obs = model.obs(:); end

    % Standardize the observed residuals (zero-mean, unit-variance view)
    eObs = e(obs & isfinite(e));
    eObs = eObs(eObs ~= 0 | true);            % keep all finite observed
    mu = mean(eObs); sd = std(eObs);
    if ~(sd > 0), sd = 1; end
    z = (e - mu) / sd;                        % standardized (NaN stays NaN)

    nObs = numel(eObs);
    if isempty(lags)
        lags = min(20, max(1, floor(nObs/4)));
    end
    lags = min(round(lags), nObs - 1);

    nParam = local_paramCount(model);

    % ---- residual ACF ---------------------------------------------------
    [rho, ~, acfConf] = timeSeriesPreparation.tsmodels.tsAcf(e, lags);
    acf = rho(2:end);
    lagAxis = (1:lags)';

    % ---- Ljung-Box ladder ----------------------------------------------
    lbQ = zeros(lags,1); lbP = zeros(lags,1);
    for L = 1:lags
        dfL = max(L - nParam, 1);
        [Q, pv] = timeSeriesPreparation.tsmodels.tsLjungBox(e, L, nParam); %#ok<ASGLU>
        lbQ(L) = Q; lbP(L) = pv;
    end

    % ---- Jarque-Bera normality -----------------------------------------
    zc = eObs - mean(eObs); s = std(eObs, 1);
    if ~(s > 0), s = 1; end
    zc = zc / s;
    skew = mean(zc.^3);
    kurt = mean(zc.^4);
    jbStat = nObs/6 * (skew^2 + (kurt - 3)^2/4);
    jbP    = 1 - local_chi2cdf(jbStat, 2);

    out = struct();
    out.resid   = z;
    out.acf     = acf;
    out.acfConf = acfConf;
    out.lags    = lagAxis;
    out.lbLags  = lagAxis;
    out.lbP     = lbP;
    out.lbQ     = lbQ;
    out.jbStat  = jbStat;
    out.jbP     = jbP;

    % ---- normal Q-Q data (v1.3.1 computed them only for its figure) ------
    out.qqSample      = sort(zc);
    out.qqTheoretical = local_norminv(((1:nObs)' - 0.5)/nObs);
end

% ----------------------------------------------------------------------
function k = local_paramCount(model)
% Number of fitted ARMA parameters (p+q plus seasonal P+Q if SARIMA).
    k = 0;
    if isfield(model,'p'), k = k + model.p; end
    if isfield(model,'q'), k = k + model.q; end
    if isfield(model,'P'), k = k + model.P; end
    if isfield(model,'Q'), k = k + model.Q; end
end

% ----------------------------------------------------------------------
function p = local_chi2cdf(x, k)
    if x <= 0, p = 0; return; end
    p = local_gammainc(x/2, k/2);
end

function g = local_gammainc(x, a)
    if x < a + 1
        ap = a; s = 1/a; del = s;
        for n = 1:1000
            ap = ap + 1; del = del * x/ap; s = s + del;
            if abs(del) < abs(s)*1e-14, break; end
        end
        g = s * exp(-x + a*log(x) - gammaln(a));
    else
        tiny = 1e-300;
        b = x + 1 - a; c = 1/tiny; d = 1/b; h = d;
        for i = 1:1000
            an = -i*(i - a); b = b + 2;
            d = an*d + b; if abs(d) < tiny, d = tiny; end
            c = b + an/c; if abs(c) < tiny, c = tiny; end
            d = 1/d; del = d*c; h = h*del;
            if abs(del - 1) < 1e-14, break; end
        end
        g = 1 - exp(-x + a*log(x) - gammaln(a)) * h;
    end
    g = min(max(g, 0), 1);
end

% ----------------------------------------------------------------------
function z = local_norminv(pp)
% Standard-normal quantile (Acklam rational approximation), vectorised.
    a = [-3.969683028665376e+01  2.209460984245205e+02 -2.759285104469687e+02 ...
          1.383577518672690e+02 -3.066479806614716e+01  2.506628277459239e+00];
    b = [-5.447609879822406e+01  1.615858368580409e+02 -1.556989798598866e+02 ...
          6.680131188771972e+01 -1.328068155288572e+01];
    c = [-7.784894002430293e-03 -3.223964580411365e-01 -2.400758277161838e+00 ...
         -2.549732539343734e+00  4.374664141464968e+00  2.938163982698783e+00];
    dd= [ 7.784695709041462e-03  3.224671290700398e-01  2.445134137142996e+00 ...
          3.754408661907416e+00];
    z = zeros(size(pp));
    plow = 0.02425; phigh = 1 - plow;
    lo = pp < plow; hi = pp > phigh; mid = ~lo & ~hi;
    r = sqrt(-2*log(pp(lo)));
    z(lo) = (((((c(1)*r+c(2)).*r+c(3)).*r+c(4)).*r+c(5)).*r+c(6)) ./ ...
            ((((dd(1)*r+dd(2)).*r+dd(3)).*r+dd(4)).*r+1);
    r = pp(mid) - 0.5; s = r.*r;
    z(mid) = (((((a(1)*s+a(2)).*s+a(3)).*s+a(4)).*s+a(5)).*s+a(6)).*r ./ ...
             (((((b(1)*s+b(2)).*s+b(3)).*s+b(4)).*s+b(5)).*s+1);
    r = sqrt(-2*log(1-pp(hi)));
    z(hi) = -(((((c(1)*r+c(2)).*r+c(3)).*r+c(4)).*r+c(5)).*r+c(6)) ./ ...
             ((((dd(1)*r+dd(2)).*r+dd(3)).*r+dd(4)).*r+1);
end
