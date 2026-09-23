function model = tsFitSarima(x, order, seasonal, s, options)
%TSFITSARIMA  Fit a seasonal ARIMA(p,d,q)(P,D,Q)_s model by CSS or exact ML.
%
%   SYNTAX
%     model = timeSeriesPreparation.tsmodels.tsFitSarima(x, order, seasonal, s)
%     model = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 1 0], 12, Method = "exact", NStart = 5)
%
%   DESCRIPTION
%     Fits the multiplicative seasonal ARIMA model
%       phi(B) PHI(B^s) (1-B)^d (1-B^s)^D (x_t - mu) = theta(B) THETA(B^s) e_t
%     with e_t ~ N(0, sigma^2). x is differenced d times by (1-B) and then
%     D times by (1-B^s); the seeds are kept in diffInfo for tsForecast.
%     The non-seasonal and seasonal operators are multiplied out into one
%     long ARMA polynomial pair in B (arExpanded, maExpanded), which is
%     evaluated by conditional sum of squares ("css", the default: the
%     first max(p + sP, q + sQ) residuals set to zero) or by exact Gaussian
%     ML ("exact": a Kalman filter on the companion state space of the
%     expanded ARMA, started from the stationary covariance of the shared
%     doubling solver timeSeriesPreparation.internal.dlyap, tolerance
%     1e-14, 80 doublings, Kronecker fallback; sigma^2 concentrated out).
%
%     Each of the four operators is optimised in an unconstrained space:
%     tanh maps to partial autocorrelations in (-1, 1), clamped to
%     +/-0.999, and the Durbin-Levinson recursion gives the coefficients,
%     so every trial operator is stationary and invertible by
%     construction. fminsearch (TolX = TolFun = 1e-8, MaxFunEvals
%     2000 (p+q+P+Q+2)) runs from NStart starts: the white-noise point and
%     NStart - 1 points perturbed by 0.3 randn; the lowest negative
%     log-likelihood wins. AIC = 2 nll + 2 k, BIC = 2 nll + k log(nObs),
%     with k the number of coefficients plus one for sigma^2.
%
%     A seasonal order needs s >= 2; with P = D = Q = 0 the period is
%     ignored and the fit is a plain ARIMA, matching tsFitArima up to the
%     optimiser. The exact method also accepts NaN gaps on a regular time
%     grid: the Kalman filter only predicts there and accrues no
%     likelihood term, which gives the exact ML estimate on the observed
%     data. Gaps require d = D = 0. Base MATLAB only.
%
%   INPUTS
%     x         (:,1) double   -   Series (a row is used as a column); NaN
%                                  marks a gap (exact method, d = D = 0).
%     order     (1,3) double   -   Non-seasonal orders [p d q], integers
%                                  >= 0.
%     seasonal  (1,3) double   -   Seasonal orders [P D Q], integers >= 0.
%     s         (1,1) double   -   Seasonal period in samples, integer
%                                  >= 2 if any seasonal order is nonzero;
%                                  otherwise max(round(s), 1) and unused.
%
%   OPTIONS
%     Method    (1,1) string   ["css"]  "css" or "exact"
%                                       (case-insensitive).
%     Constant  (1,1) logical  [true]   Include the mean mu of the
%                                       differenced series.
%     Display   (1,1) string   ["off"]  fminsearch display: "off", "iter",
%                                       "final" or "notify".
%     MaxIter   (1,1) double   [3000]   fminsearch iteration cap per start,
%                                       > 0.
%     NStart    (1,1) double   [3]      Number of starts, >= 1; rounded.
%
%   OUTPUTS
%     model  (1,1) struct   -   Fields: type (char, e.g.
%                               'SARIMA(1,0,1)(1,1,0)_12'); p, d, q, P, D,
%                               Q, season; const, mu; ar (1,p), ma (1,q),
%                               sar (1,P), sma (1,Q); arExpanded and
%                               maExpanded (1,:), the expanded
%                               polynomials 1 - ... and 1 + ... in B;
%                               sigma2; resid (n,1); logL; n, the length
%                               of the differenced series; nObs, the
%                               samples in the likelihood; k; aic; bic; x;
%                               xd, the differenced series; diffInfo
%                               (struct d, D, s, seeds); method (char);
%                               converged, fminsearch exit flag 1; obs
%                               (n,1) logical, exact method only. No
%                               standard errors.
%
%   ACCURACY
%     Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence holds it bit
%     for bit. The sigtools HANDOFF (section 3) records that the
%     expanded-ARMA Kalman filter reproduces the direct multivariate-normal
%     concentrated log-likelihood to about 1e-14, both for a complete
%     series and with missing samples (gap filter against the density of
%     the observed subset: exact to 0). The optimum is only as good as
%     fminsearch from NStart starts (TolX 1e-8).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:tsFitSarima:badData - an observed sample of
%           a gapped series is Inf.
%       timeSeriesPreparation:tsFitSarima:tooShort - fewer than
%           p + q + s (P + Q) + 3 observed samples after differencing.
%     Gaps:
%       timeSeriesPreparation:tsFitSarima:gapsNeedExact - x has NaN gaps
%           and Method is not "exact".
%       timeSeriesPreparation:tsFitSarima:gapsWithDiff - x has NaN gaps
%           and d > 0 or D > 0.
%     Options:
%       timeSeriesPreparation:tsFitSarima:badOption - Method is not "css"
%           or "exact" (case-insensitive).
%     A non-numeric or complex x, an order that is not three nonnegative
%     integers, or a seasonal s that is not an integer >= 2 is refused by
%     validateattributes, and another option outside its domain by the
%     arguments block, with a MATLAB: identifier.
%
%   EXAMPLE
%     % A seasonal AR(1) with period 12 and PHI = 0.5, fitted by CSS.
%     x = filter(1, [1 zeros(1, 11) -0.5], randn(RandStream("twister", "Seed", 3), 240, 1));
%     model = timeSeriesPreparation.tsmodels.tsFitSarima(x, [0 0 0], [1 0 0], 12, Constant = false);
%
%   LIMITATIONS
%     No standard errors. The perturbed starts draw from the global random
%     stream, whose state is restored afterwards; the fit therefore
%     depends on the current rng state (set rng for a reproducible fit).
%     The expanded ARMA has order p + sP and q + sQ, so the exact method
%     costs O(n r^3) per evaluation with r = max(p + sP, q + sQ + 1) and is
%     slow for long seasons. Gaps and differencing do not mix. Options
%     passed as one struct (inputParser's StructExpand) are no longer
%     accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%     J. Durbin, S. J. Koopman (2012), Time Series Analysis by State Space
%     Methods, 2nd ed., Oxford University Press.
%     J. F. Monahan (1984), Biometrika 71(2), 403-404 (PACF
%     reparametrisation).
%     sigtools v1.3.1 HANDOFF, section 3.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsAutoSarima, timeSeriesPreparation.tsmodels.tsForecast, timeSeriesPreparation.tsmodels.tsCheckResiduals, timeSeriesPreparation.tsmodels.tsModelDisp.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        order
        seasonal
        s
        options.Method {mustBeSarimaMethod} = 'css'
        options.Constant (1,1) {mustBeNumericOrLogical} = true
        options.Display {mustBeTextScalar} = 'off'
        options.MaxIter (1,1) {mustBePositive} = 3000
        options.NStart (1,1) {mustBeGreaterThanOrEqual(options.NStart, 1)} = 3
    end

    x = x(:);
    validateattributes(x, {'numeric'}, {'vector','real'}, mfilename, 'x');
    validateattributes(order,    {'numeric'}, {'numel',3,'nonnegative','integer'}, mfilename, 'order');
    validateattributes(seasonal, {'numeric'}, {'numel',3,'nonnegative','integer'}, mfilename, 'seasonal');

    p = order(1); d = order(2); q = order(3);
    P = seasonal(1); D = seasonal(2); Q = seasonal(3);
    hasSeason = (P+D+Q) > 0;
    if hasSeason
        validateattributes(s, {'numeric'}, {'scalar','integer','>=',2}, mfilename, 's');
    else
        s = max(round(s), 1);
    end

    o = options;
    hasConst = logical(o.Constant);
    method   = lower(char(o.Method));

    % ---- missing-sample handling (exact ML only) ------------------------
    obs = ~isnan(x);
    hasGaps = ~all(obs);
    if hasGaps
        if ~strcmp(method, 'exact')
            error('timeSeriesPreparation:tsFitSarima:gapsNeedExact', ...
                'Missing samples (NaN) require Method=''exact''.');
        end
        if d > 0 || D > 0
            error('timeSeriesPreparation:tsFitSarima:gapsWithDiff', ...
                ['Differencing (d>0 or D>0) across missing samples is undefined. ', ...
                 'Use d=D=0 with Method=''exact'', or difference a complete series.']);
        end
        if any(~isfinite(x(obs)))
            error('timeSeriesPreparation:tsFitSarima:badData', 'Observed samples must be finite.');
        end
    end

    % ---- differencing: (1-B)^d then (1-B^s)^D ---------------------------
    w = x; diffInfo = struct('d', d, 'D', D, 's', s, 'seeds', {{}});
    seeds = {};
    for i = 1:d
        seeds{end+1} = w(1); %#ok<AGROW>
        w = diff(w);
    end
    for i = 1:D
        seeds{end+1} = w(1:s); %#ok<AGROW>
        w = w(s+1:end) - w(1:end-s);
    end
    diffInfo.seeds = seeds;
    n = numel(w);
    obsW = obs(end-n+1:end);          % obs mask aligned to w (differencing gap-free)
    nEffObs = sum(obsW);
    if nEffObs < (p + q + s*(P+Q) + 3)
        error('timeSeriesPreparation:tsFitSarima:tooShort', 'Too few samples after differencing for the requested orders.');
    end

    % ---- objective: CSS or exact Gaussian ML ----------------------------
    switch method
        case 'exact'
            obj = @(psi) local_exactSarima(psi, w, p, q, P, Q, s, hasConst, obsW);
        otherwise
            obj = @(psi) local_cssSarima(psi, w, p, q, P, Q, s, hasConst);
    end

    % ---- unconstrained multi-start --------------------------------------
    muSeed = hasConst * mean(w(obsW));

    opts = optimset('Display', char(o.Display), 'MaxIter', o.MaxIter, ...
                    'MaxFunEvals', 2000*(p+q+P+Q+2), 'TolX', 1e-8, 'TolFun', 1e-8);
    kPar = hasConst + p + q + P + Q;
    starts = cell(1, max(1, round(o.NStart)));
    starts{1} = [repmat(muSeed, hasConst, 1); zeros(p+q+P+Q, 1)];
    rs = rng; cu = onCleanup(@() rng(rs)); %#ok<NASGU>
    for j = 2:numel(starts)
        starts{j} = starts{1} + 0.3*[zeros(hasConst,1); randn(p+q+P+Q,1)];
    end

    bestNLL = inf; psiHat = starts{1}; flag = 0;
    for j = 1:numel(starts)
        [psiTry, nllTry, fl] = fminsearch(obj, starts{j}, opts);
        if isfinite(nllTry) && nllTry < bestNLL
            bestNLL = nllTry; psiHat = psiTry; flag = fl;
        end
    end

    if strcmp(method, 'exact')
        [negLL, e, s2, coef] = local_exactSarima(psiHat, w, p, q, P, Q, s, hasConst, obsW);
        nObs = nEffObs;
    else
        [negLL, e, s2, coef] = local_cssSarima(psiHat, w, p, q, P, Q, s, hasConst);
        nObs = numel(e) - max(numel(coef.arExp)-1, numel(coef.maExp)-1);
        nObs = max(nObs, 1);
    end

    k = kPar + 1;                                  % +1 for sigma^2
    model = struct();
    model.type   = local_sarimaName(p,d,q,P,D,Q,s);
    model.p = p; model.d = d; model.q = q;
    model.P = P; model.D = D; model.Q = Q; model.season = s;
    model.const  = hasConst;
    model.mu     = coef.mu;
    model.ar     = coef.ar(:)';   model.ma  = coef.ma(:)';
    model.sar    = coef.sar(:)';  model.sma = coef.sma(:)';
    model.arExpanded = coef.arExp(:)';
    model.maExpanded = coef.maExp(:)';
    model.sigma2 = s2;
    model.resid  = e;
    model.logL   = -negLL;
    model.n      = n;
    model.nObs   = nObs;
    model.k      = k;
    model.aic    = 2*negLL + 2*k;
    model.bic    = 2*negLL + k*log(nObs);
    model.x      = x;
    model.xd     = w;
    model.diffInfo = diffInfo;
    model.method = method;
    model.converged = flag == 1;
    if strcmp(method, 'exact'), model.obs = obsW; end
end

% ======================================================================
function [nll, e, s2, coef] = local_cssSarima(psi, w, p, q, P, Q, s, hasConst)
% Conditional sum of squares for a multiplicative seasonal ARMA on the
% (already differenced) series w. psi is unconstrained; AR/MA blocks map
% through tanh + Durbin-Levinson to stationary/invertible coefficients.
    i = 1;
    if hasConst, mu = psi(1); i = 2; else, mu = 0; end
    cl  = @(r) min(max(r, -0.999), 0.999);          % strict (-1,1) clamp
    ar  = local_pacf2coef(cl(tanh(psi(i:i+p-1))));  i = i + p;
    ma  = local_pacf2coef(cl(tanh(psi(i:i+q-1))));  i = i + q;
    sar = local_pacf2coef(cl(tanh(psi(i:i+P-1))));  i = i + P;
    sma = local_pacf2coef(cl(tanh(psi(i:i+Q-1))));

    arExp = local_expandAR(ar, sar, s);             % 1 - ... in B
    maExp = local_expandMA(ma, sma, s);             % 1 + ... in B
    arc = -arExp(2:end);                            % x_t = sum arc_i x_{t-i} + ...
    mac =  maExp(2:end);

    y = w - mu; n = numel(y);
    Pd = numel(arc); Qd = numel(mac); m = max(Pd, Qd);
    e = zeros(n,1);
    for t = m+1:n
        pr = 0;
        for a = 1:Pd, pr = pr + arc(a)*y(t-a); end
        for b = 1:Qd, pr = pr + mac(b)*e(t-b); end
        e(t) = y(t) - pr;
    end
    ee = e(m+1:n); nEff = numel(ee);
    s2 = (ee'*ee) / max(nEff,1);
    if ~(s2 > 0) || ~isfinite(s2)
        nll = 1e12;
    else
        nll = 0.5*nEff*(log(2*pi) + log(s2) + 1);
    end
    if nargout > 3
        coef = struct('mu',mu,'ar',ar,'ma',ma,'sar',sar,'sma',sma, ...
                      'arExp',arExp,'maExp',maExp);
    end
end

% ======================================================================
function [nll, e, s2, coef] = local_exactSarima(psi, w, p, q, P, Q, s, hasConst, obs)
% Exact concentrated Gaussian log-likelihood for a multiplicative seasonal
% ARMA on the (already differenced) series w, via a Kalman filter on the
% companion state space of the EXPANDED ARMA. sigma^2 is concentrated out.
% OBS is a logical mask (true = observed): at missing timestamps the update
% is skipped (predict only) and no likelihood term is accrued -> exact ML on
% the observed data. Mirrors tsFitArima's local_negLL_exact.
    i = 1;
    if hasConst, mu = psi(1); i = 2; else, mu = 0; end
    cl  = @(r) min(max(r, -0.999), 0.999);
    ar  = local_pacf2coef(cl(tanh(psi(i:i+p-1))));  i = i + p;
    ma  = local_pacf2coef(cl(tanh(psi(i:i+q-1))));  i = i + q;
    sar = local_pacf2coef(cl(tanh(psi(i:i+P-1))));  i = i + P;
    sma = local_pacf2coef(cl(tanh(psi(i:i+Q-1))));

    arExp = local_expandAR(ar, sar, s);
    maExp = local_expandMA(ma, sma, s);
    arc = -arExp(2:end);                            % AR recursion coefficients
    mac =  maExp(2:end);                            % MA coefficients

    n = numel(w);
    if nargin < 9 || isempty(obs), obs = true(n,1); end
    y = w - mu;

    pe = numel(arc); qe = numel(mac);
    r  = max(pe, qe+1);
    phi = zeros(r,1); phi(1:pe) = arc(:);
    Rv  = zeros(r,1); Rv(1) = 1; Rv(2:1+qe) = mac(:);
    T = zeros(r); T(:,1) = phi; T(1:r-1,2:r) = eye(r-1);
    RR = Rv*Rv';

    P0 = timeSeriesPreparation.internal.dlyap(T, RR, 1e-14, 80);                     % stationary state cov (units s2)
    a  = zeros(r,1);

    e = nan(n,1); S = 0; logF = 0; nObs = 0; ok = true;
    for t = 1:n
        if obs(t)
            F = P0(1,1);
            if ~(F > 0) || ~isfinite(F), ok = false; break; end
            v = y(t) - a(1);
            e(t) = v / sqrt(F);
            S = S + v*v/F; logF = logF + log(F); nObs = nObs + 1;
            K = (T*P0(:,1)) / F;
            a = T*a + K*v;
            P0 = T*P0*T' + RR - (K*F)*K';
        else
            a = T*a;
            P0 = T*P0*T' + RR;
        end
        P0 = 0.5*(P0 + P0');
    end
    if ~ok || nObs == 0
        nll = 1e12; s2 = var(w(obs),1); e = nan(n,1);
    else
        s2 = S / nObs;
        if ~(s2 > 0) || ~isfinite(s2)
            nll = 1e12; e = nan(n,1);
        else
            nll = 0.5*(nObs*log(2*pi) + nObs*log(s2) + logF + nObs);
            e   = e * sqrt(s2);
        end
    end
    if nargout > 3
        coef = struct('mu',mu,'ar',ar,'ma',ma,'sar',sar,'sma',sma, ...
                      'arExp',arExp,'maExp',maExp);
    end
end

% ======================================================================
function phi = local_pacf2coef(r)
% Durbin-Levinson: PACF (|r|<1) -> stationary/invertible coefficients.
    r = r(:); p = numel(r); a = zeros(p,1);
    for k = 1:p
        ak = r(k);
        if k > 1, a(1:k-1) = a(1:k-1) - ak*flipud(a(1:k-1)); end
        a(k) = ak;
    end
    phi = a;
end

% ======================================================================
function AR = local_expandAR(ar, sar, s)
% Expand phi(B)*PHI(B^s) into a single polynomial 1 - c1 B - c2 B^2 - ...
    nsAR = [1; -ar(:)];                    % 1 - ar1 B - ...
    seAR = 1;
    if ~isempty(sar)
        seAR = zeros(1 + s*numel(sar), 1); seAR(1) = 1;
        for k = 1:numel(sar), seAR(1 + k*s) = -sar(k); end
    end
    AR = conv(nsAR, seAR);
end

function MA = local_expandMA(ma, sma, s)
% Expand theta(B)*THETA(B^s) into 1 + c1 B + c2 B^2 + ...
    nsMA = [1; ma(:)];                     % 1 + ma1 B + ...
    seMA = 1;
    if ~isempty(sma)
        seMA = zeros(1 + s*numel(sma), 1); seMA(1) = 1;
        for k = 1:numel(sma), seMA(1 + k*s) = sma(k); end
    end
    MA = conv(nsMA, seMA);
end

% ======================================================================
function str = local_sarimaName(p,d,q,P,D,Q,s)
    if (P+D+Q) > 0
        str = sprintf('SARIMA(%d,%d,%d)(%d,%d,%d)_%d', p,d,q,P,D,Q,s);
    elseif d > 0
        str = sprintf('ARIMA(%d,%d,%d)', p,d,q);
    elseif q == 0 && p > 0
        str = sprintf('AR(%d)', p);
    elseif p == 0 && q > 0
        str = sprintf('MA(%d)', q);
    else
        str = sprintf('ARMA(%d,%d)', p, q);
    end
end

% ======================================================================
function mustBeSarimaMethod(v)
% Case-insensitive "css" or "exact", as v1.3.1's inputParser validator.
    if ~any(strcmpi(char(v), {'css','exact'}))
        error('timeSeriesPreparation:tsFitSarima:badOption', ...
            'Method must be ''css'' or ''exact''.');
    end
end
