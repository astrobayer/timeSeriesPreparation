function [Q, pValue, df] = tsLjungBox(resid, lags, nParam)
%TSLJUNGBOX  Ljung-Box portmanteau test for residual autocorrelation.
%
%   SYNTAX
%     [Q, pValue, df] = timeSeriesPreparation.tsmodels.tsLjungBox(resid)
%     [Q, pValue, df] = timeSeriesPreparation.tsmodels.tsLjungBox(resid, lags)
%     [Q, pValue, df] = timeSeriesPreparation.tsmodels.tsLjungBox(resid, lags, nParam)
%
%   DESCRIPTION
%     Tests whether the residuals of a fitted model are white, jointly over
%     the first L lags: H0 says the innovations are uncorrelated up to lag
%     L. NaN residuals (missing epochs) and leading exact zeros (the
%     conditioning samples of a CSS fit) are dropped, the mean is removed,
%     and with r_k the sample ACF of tsAcf,
%       Q = N (N + 2) sum_{k=1..L} r_k^2 / (N - k),
%     which under H0 is chi-square with df = max(L - nParam, 1) degrees of
%     freedom, nParam = p + q the fitted ARMA parameters. pValue is the
%     upper tail 1 - chi2cdf(Q, df); a small value rejects whiteness. Base
%     MATLAB only: the chi-square CDF is the regularised incomplete gamma
%     function, by series (x < a + 1) or Lentz continued fraction.
%
%   INPUTS
%     resid   (:,1) double   -   Residual series; NaN marks a missing
%                                epoch.
%     lags    (1,1) double   -   Number of lags L tested; [] or omitted: 20.
%                                Rounded and capped at N - 1.
%     nParam  (1,1) double   -   Fitted parameter count p + q, subtracted
%                                from the degrees of freedom; [] or
%                                omitted: 0.
%
%   OUTPUTS
%     Q       (1,1) double   -   Ljung-Box statistic.
%     pValue  (1,1) double   -   Upper-tail p-value, 1 - chi2cdf(Q, df).
%     df      (1,1) double   -   Degrees of freedom, max(L - nParam, 1).
%
%   ACCURACY
%     The incomplete gamma series and continued fraction stop at a relative
%     change below 1e-14 (at most 1000 terms), as in tsCheckResiduals. The
%     chi-square law of Q is asymptotic (Ljung and Box 1978). Unchanged from
%     sigtools v1.3.1; TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none)
%     A non-numeric or complex resid, or a lags or nParam that is not a
%     numeric scalar or [], is refused by the arguments block with a
%     MATLAB: identifier.
%
%   EXAMPLE
%     % White noise: the p-value is typically large.
%     e = randn(RandStream("twister", "Seed", 3), 500, 1);
%     [Q, pValue, df] = timeSeriesPreparation.tsmodels.tsLjungBox(e, 20);
%
%   LIMITATIONS
%     Every exact zero before the first nonzero residual is dropped, a
%     genuine zero included. With gaps the ACF is pairwise (tsAcf) and N
%     counts the observed residuals only.
%
%   REFERENCES
%     G. M. Ljung, G. E. P. Box (1978), Biometrika 65(2), 297-303.
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley.
%
%   See also timeSeriesPreparation.tsmodels.tsCheckResiduals, timeSeriesPreparation.tsmodels.tsAcf, timeSeriesPreparation.tsmodels.tsModelDisp.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        resid {mustBeNumeric, mustBeReal}
        lags {mustBeScalarOrEmpty, mustBeNumeric} = 20
        nParam {mustBeScalarOrEmpty, mustBeNumeric} = 0
    end

    if isempty(lags),   lags = 20;   end
    if isempty(nParam), nParam = 0;  end

    e = resid(:);
    e = e(~isnan(e));                         % drop missing-timestamp residuals
    nz = find(e ~= 0, 1, 'first');            % trim leading conditioned zeros
    if ~isempty(nz), e = e(nz:end); end
    e = e - mean(e);
    N = numel(e);
    lags = min(round(lags), N-1);

    r = timeSeriesPreparation.tsmodels.tsAcf(e, lags); r = r(2:end);         % rho_1..rho_lags
    k = (1:lags)';
    Q  = N*(N+2) * sum( r.^2 ./ (N - k) );
    df = max(lags - nParam, 1);
    pValue = 1 - local_chi2cdf(Q, df);
end

% ----------------------------------------------------------------------
function p = local_chi2cdf(x, k)
    if x <= 0, p = 0; return; end
    p = local_gammainc(x/2, k/2);             % regularised lower incomplete gamma
end

function g = local_gammainc(x, a)
    if x < a + 1                              % series expansion
        ap = a; s = 1/a; del = s;
        for n = 1:1000
            ap = ap + 1; del = del * x/ap; s = s + del;
            if abs(del) < abs(s)*1e-14, break; end
        end
        g = s * exp(-x + a*log(x) - gammaln(a));
    else                                      % continued fraction (Lentz)
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
