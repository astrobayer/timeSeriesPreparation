function [yhat, se, lo, hi] = tsForecast(model, h, alpha, options)
%TSFORECAST  h-step forecasts and prediction intervals of an (S)ARIMA model.
%
%   SYNTAX
%     [yhat, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(model, h)
%     [yhat, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(model, h, alpha)
%     [yhat, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(model, h, 0.05, Bootstrap = true, NBoot = 5000, Seed = 1)
%
%   DESCRIPTION
%     Point forecasts on the original scale, their standard errors and
%     (1 - alpha) prediction intervals, for a model from tsFitArima (and
%     its wrappers tsFitAR, tsFitMA, tsFitARMA, tsAutoArima) or from
%     tsFitSarima. Three paths, chosen from the model's fields:
%       ARIMA     The ARMA recursion runs on the differenced series xd
%                 with future innovations set to zero. The forecast error
%                 variance is sigma^2 cumsum(psi.^2) with the MA(inf)
%                 psi-weights; for d > 0 the path is integrated d times
%                 from the last observed values and psi is summed d times,
%                 so the one-step variance is sigma^2 exactly.
%       SARIMA    (fields arExpanded, maExpanded, diffInfo) The same on
%                 the expanded ARMA; the path is re-integrated through
%                 Delta(B) = (1-B)^d (1-B^s)^D from the observed tail, and
%                 the variance uses Psi(B) = psi(B) / Delta(B).
%       gaps      (field obs not all true; d = D = 0) The missing-data
%                 Kalman filter of the fit runs to the end of the record,
%                 from the stationary covariance of
%                 timeSeriesPreparation.internal.dlyap (tolerance 1e-14,
%                 60 doublings), and the state is projected forward;
%                 se = sqrt(sigma^2 P(1,1)).
%     The Gaussian interval is yhat -/+ z se with z the standard normal
%     quantile at 1 - alpha/2 (Acklam's rational approximation). With
%     Bootstrap the interval is instead the empirical alpha/2 and
%     1 - alpha/2 quantile of yhat + err_k, err_k = sum_j Psi_(j+1) e*_(k-j),
%     over NBoot draws e* with replacement from the centred finite model
%     residuals; it captures skewed or heavy-tailed innovations. se stays
%     the Gaussian psi-weight standard error. Base MATLAB only.
%
%   INPUTS
%     model  (1,1) struct   -   From tsFitArima, tsFitAR, tsFitMA,
%                               tsFitARMA, tsAutoArima or tsFitSarima.
%     h      (1,1) double   -   Forecast horizon in samples, a positive
%                               integer.
%     alpha  (1,1) double   -   Significance of the interval, coverage
%                               1 - alpha; [] or omitted: 0.05.
%
%   OPTIONS
%     Bootstrap  (1,1) logical  [false]  Residual-bootstrap interval
%                                        instead of the Gaussian one; not
%                                        for gap-fitted models.
%     NBoot      (1,1) double   [2000]   Bootstrap replications, >= 100;
%                                        rounded.
%     Seed       (1,1) double   []       rng seed for the bootstrap; the
%                                        global state is restored after.
%                                        [] draws from the global stream.
%
%   OUTPUTS
%     yhat  (h,1) double   -   Point forecasts, original scale.
%     se    (h,1) double   -   Forecast standard errors, non-decreasing in
%                              the horizon.
%     lo    (h,1) double   -   Lower bound of the (1 - alpha) interval.
%     hi    (h,1) double   -   Upper bound of the (1 - alpha) interval.
%
%   ACCURACY
%     Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence holds it bit
%     for bit. The sigtools HANDOFF (section 3) records: the seasonal path
%     against a 150k-200k-run Monte Carlo for SARIMA(1,0,0)(1,1,0)_4 and
%     (1,1,1)(1,1,0)_4 gives the point forecast to Monte-Carlo noise, se
%     within about 0.3 % and the one-step se exactly; the bootstrap
%     half-width reproduces the Gaussian one to about 1-3 % for Gaussian
%     residuals, with about nominal out-of-sample coverage for Gaussian
%     and skewed innovations. The normal quantile is good to about 1e-9
%     (the source's comment on its Acklam approximation).
%
%   ERRORS
%     Model:
%       timeSeriesPreparation:tsForecast:bootGaps - Bootstrap is requested
%           for a gap-fitted model.
%     An h that is not a positive integer scalar (validateattributes), or
%     an alpha or option outside its domain (arguments block), is refused
%     with a MATLAB: identifier.
%
%   EXAMPLE
%     % Ten steps ahead of a CSS-fitted AR(1), with 95 % Gaussian intervals.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 4), 200, 1));
%     [yhat, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, Method = "css"), 10);
%
%   LIMITATIONS
%     The intervals ignore the uncertainty of the estimated coefficients.
%     The Gaussian interval assumes Gaussian innovations. The bootstrap
%     is not available for gap-fitted models and, without Seed, draws from
%     and advances the global random stream. alpha must be a scalar. Options
%     passed as one struct (inputParser's StructExpand) are no longer
%     accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%     J. Durbin, S. J. Koopman (2012), Time Series Analysis by State Space
%     Methods, 2nd ed., Oxford University Press.
%     P. J. Acklam (2003), An algorithm for computing the inverse normal
%     cumulative distribution function.
%     sigtools v1.3.1 HANDOFF, section 3.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsFitSarima, timeSeriesPreparation.tsmodels.tsIntegrate, timeSeriesPreparation.tsmodels.tsModelDisp.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        model (1,1) struct
        h
        alpha {mustBeScalarOrEmpty, mustBeNumeric} = 0.05
        options.Bootstrap (1,1) {mustBeNumericOrLogical} = false
        options.NBoot (1,1) {mustBeGreaterThanOrEqual(options.NBoot, 100)} = 2000
        options.Seed {mustBeScalarOrEmpty} = []
    end
    if isempty(alpha), alpha = 0.05; end
    validateattributes(h, {'numeric'}, {'scalar','integer','positive'});

    doBoot = logical(options.Bootstrap);
    nBoot  = round(options.NBoot);
    seed   = options.Seed;

    % ---- seasonal path: expanded ARMA + combined differencing ----------
    isSeasonal = isfield(model,'arExpanded') && isfield(model,'maExpanded') ...
        && isfield(model,'diffInfo');
    if isSeasonal
        seasonalGaps = isfield(model,'obs') && ~all(model.obs);
        if seasonalGaps
            if doBoot
                error('timeSeriesPreparation:tsForecast:bootGaps', ...
                    'Bootstrap intervals are not available for gap-fitted models.');
            end
            [yhat, se] = local_forecastSarimaKF(model, h);   % d=D=0 guaranteed
            z  = local_norminv(1 - alpha/2);
            lo = yhat - z.*se;  hi = yhat + z.*se;
            return;
        end
        [yhat, se, Psi, s2] = local_forecastSarima(model, h);
        if doBoot
            [lo, hi] = local_bootInterval(yhat, Psi, model.resid, alpha, nBoot, seed);
        else
            z  = local_norminv(1 - alpha/2);
            lo = yhat - z.*se;  hi = yhat + z.*se;
        end
        return;
    end

    p = model.p; q = model.q; d = model.d;
    ar = model.ar(:); ma = model.ma(:); mu = model.mu; s2 = model.sigma2;

    % ---- gap-aware path: forecast from the Kalman state ----------------
    hasGaps = isfield(model,'obs') && ~all(model.obs);
    if hasGaps
        if doBoot
            error('timeSeriesPreparation:tsForecast:bootGaps', ...
                'Bootstrap intervals are not available for gap-fitted models.');
        end
        [yhat, se] = local_forecastKF(model, h);
        z  = local_norminv(1 - alpha/2);
        lo = yhat - z.*se;  hi = yhat + z.*se;
        return;
    end

    w = model.xd(:);                 % differenced (working) series
    e = model.resid(:);
    n = numel(w);
    y = w - mu;

    % ---- point forecasts on the working (differenced) scale ------------
    yext = [y; zeros(h,1)];
    eext = [e; zeros(h,1)];
    fw   = zeros(h,1);
    for s = 1:h
        t = n + s;
        pr = 0;
        for i = 1:p, pr = pr + ar(i)*yext(t-i); end
        for j = 1:q, pr = pr + ma(j)*eext(t-j); end
        yext(t) = pr;                % E[future innovation] = 0
        eext(t) = 0;
        fw(s)   = pr + mu;
    end

    % ---- MA(inf) psi-weights and working-scale error variance ----------
    psi  = local_psiWeights(ar, ma, h-1);      % psi(1)=1,...
    varW = s2 * cumsum(psi.^2);

    % ---- integrate back to original scale (if differenced) -------------
    if d == 0
        yhat = fw;
        varO = varW;
        Psi  = psi;                            % original-scale psi-weights
    else
        [yhat, varO] = local_integrate(fw, varW, model.x(:), d, s2, psi);
        ipsi = psi;                            % original-scale = d-fold cumsum
        for i = 1:d, ipsi = cumsum(ipsi); end
        Psi = ipsi(1:h);
    end

    se = sqrt(varO);
    if doBoot
        [lo, hi] = local_bootInterval(yhat, Psi, model.resid, alpha, nBoot, seed);
    else
        z  = local_norminv(1 - alpha/2);
        lo = yhat - z.*se;
        hi = yhat + z.*se;
    end
end

% ======================================================================
function [yhat, se, Psi, s2] = local_forecastSarima(model, h)
%   Forecast a multiplicative seasonal ARIMA model.
%
%   Strategy
%   --------
%   1. The stationary part is the fully-expanded ARMA with polynomials
%      arExpanded = 1 - a1 B - ...  and  maExpanded = 1 + b1 B + ...
%      acting on the working series w = model.xd (already (1-B)^d and
%      (1-B^s)^D differenced). Point-forecast w recursively with future
%      innovations set to zero.
%   2. Re-integrate the forecast path through the combined differencing
%      operator Delta(B) = (1-B)^d (1-B^s)^D, i.e.
%         x_t = w_t + sum_i gc_i x_{t-i},   gc = -Delta(2:end),
%      seeded with the observed tail of model.x.
%   3. Forecast-error variance: original-scale psi-weights
%      Psi(B) = psiExpanded(B) / Delta(B), var = sigma^2 * cumsum(Psi.^2),
%      so the one-step variance equals sigma^2 exactly.
    arc =  model.arExpanded(2:end);  arc = arc(:);   % x_t = sum arc_i x_{t-i}+..
    arc = -arc;                                      % arExpanded is 1 - a1 B..
    mac =  model.maExpanded(2:end);  mac = mac(:);   % + sum mac_j e_{t-j}
    mu  = model.mu; s2 = model.sigma2;

    w = model.xd(:) - mu;
    e = model.resid(:);
    n = numel(w);
    Pd = numel(arc); Qd = numel(mac);

    % ---- point forecast on the working (differenced) scale -------------
    wext = [w; zeros(h,1)];
    eext = [e; zeros(h,1)];
    fw   = zeros(h,1);
    for st = 1:h
        t  = n + st;
        pr = 0;
        for i = 1:Pd, pr = pr + arc(i)*wext(t-i); end
        for j = 1:Qd, pr = pr + mac(j)*eext(t-j); end
        wext(t) = pr;                 % E[future innovation] = 0
        eext(t) = 0;
        fw(st)  = pr + mu;            % working-scale forecast (mean restored)
    end

    % ---- combined differencing operator Delta(B) ----------------------
    d = model.diffInfo.d; D = model.diffInfo.D; s = model.diffInfo.s;
    delta = 1;
    for i = 1:d, delta = conv(delta, [1; -1]); end
    for i = 1:D
        sd = zeros(s+1,1); sd(1) = 1; sd(s+1) = -1;
        delta = conv(delta, sd);
    end
    gc = -delta(2:end);               % x_t = w_t + sum gc_i x_{t-i}
    gd = numel(gc);

    % ---- re-integrate point forecasts using the observed tail ----------
    if gd == 0
        yhat = fw;
    else
        xhist = model.x(:);
        xbuf  = [xhist; zeros(h,1)];
        base  = numel(xhist);
        for st = 1:h
            t   = base + st;
            acc = fw(st);
            for i = 1:gd, acc = acc + gc(i)*xbuf(t-i); end
            xbuf(t) = acc;
        end
        yhat = xbuf(base+1:base+h);
    end

    % ---- forecast-error variance via original-scale psi-weights --------
    psiW = local_psiWeights(arc, mac, h-1);   % expanded-ARMA psi, psi(1)=1
    Psi  = zeros(h,1);
    for k = 1:h
        v = psiW(k);
        for i = 1:min(gd, k-1), v = v + gc(i)*Psi(k-i); end
        Psi(k) = v;
    end
    se = sqrt(s2 * cumsum(Psi.^2));
end

% ======================================================================
function [lo, hi] = local_bootInterval(yhat, Psi, resid, alpha, nBoot, seed)
%   Residual-bootstrap prediction interval. The h-step forecast error is the
%   MA(inf) combination  err_k = sum_{j=0}^{k-1} Psi_{j+1} * e*_{k-j}, where
%   e* are draws (with replacement) from the centred model residuals. The
%   empirical alpha/2 and 1-alpha/2 quantiles of yhat+err define [lo,hi].
%   Captures non-Gaussian innovation shape (skew, heavy tails).
    h = numel(yhat);
    Psi = Psi(:);
    r = resid(:);
    r = r(isfinite(r));
    r = r - mean(r);                          % centre so the interval is unbiased
    if numel(r) < 2
        % degenerate: fall back to a symmetric zero-width interval at yhat
        lo = yhat; hi = yhat; return;
    end

    if ~isempty(seed)
        rs = rng; cleaner = onCleanup(@() rng(rs)); %#ok<NASGU>
        rng(seed);
    end

    nR = numel(r);
    errs = zeros(nBoot, h);
    for b = 1:nBoot
        estar = r(randi(nR, h, 1));           % h future innovation draws
        acc = 0;
        for k = 1:h
            % err_k = sum_{j=0}^{k-1} Psi(j+1) * estar(k-j)
            acc = Psi(1:k)' * estar(k:-1:1);
            errs(b, k) = acc;
        end
    end

    qlo = local_empQuantile(errs, alpha/2);       % 1xh
    qhi = local_empQuantile(errs, 1 - alpha/2);
    lo = yhat + qlo(:);
    hi = yhat + qhi(:);
end

% ======================================================================
function q = local_empQuantile(X, p)
%   Column-wise empirical quantile (linear interpolation, MATLAB default
%   convention) without the Statistics Toolbox. X is nBoot-by-h, q is 1-by-h.
    X = sort(X, 1);
    n = size(X, 1);
    pos = p*n + 0.5;
    loI = min(max(floor(pos), 1), n);
    hiI = min(loI + 1, n);
    w = min(max(pos - loI, 0), 1);
    q = (1-w).*X(loI, :) + w.*X(hiI, :);
end

% ======================================================================
function [yhat, se] = local_forecastSarimaKF(model, h)
%   Forecast a gapped seasonal ARMA model (d=D=0) from the Kalman state of
%   the fully-expanded ARMA companion form. Filters the missing-data KF to
%   the end of the observed history, then projects the state forward.
    arc = -model.arExpanded(2:end); arc = arc(:);
    mac =  model.maExpanded(2:end); mac = mac(:);
    mu  = model.mu; s2 = model.sigma2;
    y   = model.xd(:) - mu;               % xd == x (d=D=0) with mean removed
    obs = model.obs(:);
    n   = numel(y);

    pe = numel(arc); qe = numel(mac);
    r  = max(pe, qe+1);
    phi = zeros(r,1); phi(1:pe) = arc;
    Rv  = zeros(r,1); Rv(1) = 1; Rv(2:1+qe) = mac;
    T = zeros(r); T(:,1) = phi; T(1:r-1,2:r) = eye(r-1);
    RR = Rv*Rv';

    P = timeSeriesPreparation.internal.dlyap(T, RR, 1e-14, 60);               % in units of s2
    a = zeros(r,1);
    for t = 1:n
        if obs(t)
            F = P(1,1);
            v = y(t) - a(1);
            K = (T*P(:,1)) / F;
            a = T*a + K*v;
            P = T*P*T' + RR - (K*F)*K';
        else
            a = T*a;
            P = T*P*T' + RR;
        end
        P = 0.5*(P + P');
    end

    yhat = zeros(h,1); vv = zeros(h,1);
    for st = 1:h
        yhat(st) = a(1) + mu;
        vv(st)   = s2 * P(1,1);
        a = T*a;
        P = T*P*T' + RR;
        P = 0.5*(P + P');
    end
    se = sqrt(vv);
end

% ======================================================================
function [yhat, se] = local_forecastKF(model, h)
%   Forecast an ARMA model with missing samples by running the missing-data
%   Kalman filter to the end of the history, then projecting the state
%   forward. Works on the (d=0) working series; mu is added back.
    p = model.p; q = model.q;
    ar = model.ar(:); ma = model.ma(:); mu = model.mu; s2 = model.sigma2;
    y  = model.xd(:) - mu;               % d=0 guaranteed when gaps present
    obs = model.obs(:);
    n = numel(y);

    r = max(p, q+1);
    phi = zeros(r,1); phi(1:p) = ar;
    R   = zeros(r,1); R(1) = 1; R(2:1+q) = ma;
    T = zeros(r); T(:,1) = phi; T(1:r-1,2:r) = eye(r-1);
    RR = R*R';

    P = timeSeriesPreparation.internal.dlyap(T, RR, 1e-14, 60);              % in units of s2
    a = zeros(r,1);
    for t = 1:n                          % filter through history
        if obs(t)
            F = P(1,1);
            v = y(t) - a(1);
            K = (T*P(:,1)) / F;
            a = T*a + K*v;
            P = T*P*T' + RR - (K*F)*K';
        else
            a = T*a;
            P = T*P*T' + RR;
        end
        P = 0.5*(P + P');
    end

    yhat = zeros(h,1); vv = zeros(h,1);
    for s = 1:h                          % state already holds 1-step prediction
        yhat(s) = a(1) + mu;
        vv(s)   = s2 * P(1,1);           % forecast variance
        a = T*a;                         % advance to next horizon
        P = T*P*T' + RR;
        P = 0.5*(P + P');
    end
    se = sqrt(vv);
end

% ======================================================================
function psi = local_psiWeights(ar, ma, H)
%   MA(inf) psi-weights of an ARMA(p,q) process, psi(1)=psi_0=1.
%   psi_0 = 1; psi_k = sum_i ar_i psi_{k-i} + theta_k
    p = numel(ar); q = numel(ma);
    psi = zeros(H+1, 1); psi(1) = 1;
    for k = 1:H
        v = 0;
        for i = 1:min(p,k), v = v + ar(i)*psi(k-i+1); end
        if k <= q, v = v + ma(k); end
        psi(k+1) = v;
    end
end

% ======================================================================
function [yhat, varO] = local_integrate(fw, varW, lastVals, d, s2, psi)
%   Undo d-fold differencing on the forecast path and propagate variance.
    H = numel(fw);

    % last observed value at each differencing level 0..d-1
    lev = lastVals;
    seeds = zeros(d,1);
    tmp = lastVals;
    for i = 1:d
        seeds(i) = tmp(end);        % level i-1 last value
        tmp = diff(tmp);
    end

    % point forecasts: integrate d times, seeding with the last level value
    f = fw;
    for i = d:-1:1
        f = seeds(i) + cumsum(f);
    end
    yhat = f;

    % variance: integrated psi-weights are the d-fold cumulative sum of psi
    ipsi = psi;
    for i = 1:d
        ipsi = cumsum(ipsi);
    end
    ipsi = ipsi(1:H);
    varO = s2 * cumsum(ipsi.^2);
end

% ======================================================================
function z = local_norminv(pp)
%   Standard-normal quantile (Acklam rational approximation, ~1e-9 abs err).
    a = [-3.969683028665376e+01  2.209460984245205e+02 -2.759285104469687e+02 ...
          1.383577518672690e+02 -3.066479806614716e+01  2.506628277459239e+00];
    b = [-5.447609879822406e+01  1.615858368580409e+02 -1.556989798598866e+02 ...
          6.680131188771972e+01 -1.328068155288572e+01];
    c = [-7.784894002430293e-03 -3.223964580411365e-01 -2.400758277161838e+00 ...
         -2.549732539343734e+00  4.374664141464968e+00  2.938163982698783e+00];
    dd= [ 7.784695709041462e-03  3.224671290700398e-01  2.445134137142996e+00 ...
          3.754408661907416e+00];
    plow = 0.02425; phigh = 1 - plow;
    if pp < plow
        r = sqrt(-2*log(pp));
        z = (((((c(1)*r+c(2))*r+c(3))*r+c(4))*r+c(5))*r+c(6)) / ...
            ((((dd(1)*r+dd(2))*r+dd(3))*r+dd(4))*r+1);
    elseif pp <= phigh
        r = pp - 0.5; s = r*r;
        z = (((((a(1)*s+a(2))*s+a(3))*s+a(4))*s+a(5))*s+a(6))*r / ...
            (((((b(1)*s+b(2))*s+b(3))*s+b(4))*s+b(5))*s+1);
    else
        r = sqrt(-2*log(1-pp));
        z = -(((((c(1)*r+c(2))*r+c(3))*r+c(4))*r+c(5))*r+c(6)) / ...
             ((((dd(1)*r+dd(2))*r+dd(3))*r+dd(4))*r+1);
    end
end
