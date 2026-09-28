function model = tsFitArima(x, p, d, q, options)
%TSFITARIMA  Fit an ARIMA(p,d,q) model by exact ML, CSS or Yule-Walker.
%
%   SYNTAX
%     model = timeSeriesPreparation.tsmodels.tsFitArima(x, p, d, q)
%     model = timeSeriesPreparation.tsmodels.tsFitArima(x, p, d, q, Method = "css", Constant = false)
%
%   DESCRIPTION
%     The one ARIMA estimator of the package; tsFitAR, tsFitMA, tsFitARMA
%     and tsAutoArima call it. It fits
%       phi(B) (1-B)^d (x_t - mu) = theta(B) e_t,   e_t ~ N(0, sigma^2),
%     phi(B) = 1 - phi_1 B - ... - phi_p B^p,
%     theta(B) = 1 + theta_1 B + ... + theta_q B^q; (p,0,0) is AR(p),
%     (0,0,q) MA(q), (p,0,q) ARMA(p,q). x is differenced d times first
%     (tsDiff); the mean mu (Constant) is that of the differenced series.
%
%     Methods:
%       "exact"  exact Gaussian ML (default). A Kalman filter on the
%                Harvey state space of dimension r = max(p, q+1), started
%                from the stationary covariance P = T P T' + R R' (the
%                shared doubling solver timeSeriesPreparation.internal.
%                dlyap, tolerance 1e-14, 60 doublings, Kronecker fallback),
%                with sigma^2 concentrated out.
%       "css"    conditional sum of squares, the first max(p,q) residuals
%                set to zero.
%       "yw"     Yule-Walker, pure AR only: a closed-form fast path, the
%                mean is the sample mean, no optimiser, no standard errors.
%
%     For exact ML and CSS the AR and the MA block are optimised in an
%     unconstrained space: tanh maps each value to a partial
%     autocorrelation in (-1, 1), clamped to +/-0.999, and the
%     Durbin-Levinson recursion turns these into coefficients. Every trial
%     polynomial is therefore stationary and invertible by construction.
%     fminsearch (TolX = TolFun = 1e-8, MaxFunEvals 2000 (p+q+2)) runs from
%     four starts: a Yule-Walker seed, a white-noise seed and two seeds
%     perturbed by 0.3 randn; the lowest negative log-likelihood wins.
%     Standard errors come from the observed-information Hessian of the
%     penalty-free objective in the natural parameters: central
%     differences at steps h = 1e-3 max(|theta|, 1) and h/2, combined by
%     Richardson extrapolation, with an eigenvalue repair when the inverse
%     is not positive definite. AIC = 2 nll + 2 k and BIC = 2 nll + k
%     log(nObs), with k the number of coefficients plus one for sigma^2.
%
%     Gaps: NaN marks a missing sample on a regular time grid. With the
%     exact method the Kalman filter only predicts at a gap and accrues no
%     likelihood term there, which gives the exact ML estimate on the
%     observed data. Gaps require d = 0 and Method "exact"; resid is NaN
%     there and nObs counts the observed samples. Base MATLAB only.
%
%   INPUTS
%     x  (:,1) double   -   Series (a row is used as a column); NaN marks a
%                           missing sample (exact method, d = 0 only).
%     p  (1,1) double   -   AR order, >= 0; rounded.
%     d  (1,1) double   -   Differencing order, >= 0; rounded.
%     q  (1,1) double   -   MA order, >= 0; rounded.
%
%   OPTIONS
%     Constant  (1,1) logical  [true]     Include the mean mu. Ignored by
%                                         "yw", which always fits it.
%     Method    (1,1) string   ["exact"]  "exact", "css" or "yw"
%                                         (case-insensitive).
%     Display   (1,1) string   ["off"]    fminsearch display: "off",
%                                         "iter", "final" or "notify".
%     MaxIter   (1,1) double   [2000]     fminsearch iteration cap per
%                                         start, > 0.
%
%   OUTPUTS
%     model  (1,1) struct   -   Fields: type (char, e.g. 'ARMA(2,1)'); p,
%                               d, q; const; mu; ar (1,p), ma (1,q);
%                               sigma2; resid (N-d,1), NaN at gaps; stdErr
%                               (1,k-1), standard errors of [mu ar ma];
%                               logL; n, the length of the differenced
%                               series; nObs, the observed samples; obs
%                               (N,1) logical, true = observed; k; aic;
%                               bic; x, xd (differenced), x0 (tsDiff
%                               seeds); method (char); converged,
%                               fminsearch exit flag 1. A "yw" model has
%                               no nObs and obs, stdErr is [] and k = p+2.
%
%   ACCURACY
%     Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence holds it bit
%     for bit. The sigtools HANDOFF (section 3) records independent NumPy
%     re-derivations: the exact AR(1) log-likelihood matches the closed-form
%     Gaussian density to about 1e-12; the Richardson-Hessian standard
%     error of an AR(1) matches sqrt((1 - phi^2)/n) to a ratio of 1.000;
%     the PACF <-> coefficient round trip is exact; the doubling Lyapunov
%     solve matches the Kronecker solve to about 1e-15. The optimum itself
%     is only as good as fminsearch from four starts (TolX 1e-8).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:tsFitArima:badData - an observed sample is
%           Inf.
%       timeSeriesPreparation:tsFitArima:tooShort - fewer than p + q + 2
%           observed samples.
%     Gaps:
%       timeSeriesPreparation:tsFitArima:gapsWithDiff - x has NaN gaps
%           and d > 0.
%       timeSeriesPreparation:tsFitArima:gapsNeedExact - x has NaN gaps
%           and Method is not "exact".
%     Method:
%       timeSeriesPreparation:tsFitArima:ywMA - Method "yw" with q > 0.
%       timeSeriesPreparation:tsFitArima:method - Method is not "exact",
%           "css" or "yw".
%     A non-numeric or complex x (validateattributes), or an order or
%     option outside its domain (arguments block), is refused with a
%     MATLAB: identifier.
%
%   EXAMPLE
%     % AR(1) with phi = 0.6 and zero mean: exact ML recovers ar near 0.6.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 1), 200, 1));
%     model = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, Constant = false);
%
%   LIMITATIONS
%     The two perturbed starts draw from the global random stream, whose
%     state is restored afterwards; the fit therefore depends on the
%     current rng state (set rng for a reproducible fit). The exact
%     likelihood costs O(n r^3) per evaluation; fminsearch needs hundreds
%     of evaluations, so large p + q is slow. Gaps and differencing do not
%     mix. Options passed as one struct (inputParser's StructExpand) are no
%     longer accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%     J. Durbin, S. J. Koopman (2012), Time Series Analysis by State Space
%     Methods, 2nd ed., Oxford University Press.
%     R. H. Jones (1980), Technometrics 22(3), 389-395 (ARMA likelihood
%     with missing observations).
%     J. F. Monahan (1984), Biometrika 71(2), 403-404 (PACF
%     reparametrisation).
%     J. A. Nelder, R. Mead (1965), Comput. J. 7(4), 308-313.
%     sigtools v1.3.1 HANDOFF, section 3.
%
%   See also timeSeriesPreparation.tsmodels.tsFitAR, timeSeriesPreparation.tsmodels.tsFitMA, timeSeriesPreparation.tsmodels.tsFitARMA, timeSeriesPreparation.tsmodels.tsAutoArima, timeSeriesPreparation.tsmodels.tsFitSarima, timeSeriesPreparation.tsmodels.tsForecast, timeSeriesPreparation.tsmodels.tsCheckResiduals.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        p (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        d (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        q (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        options.Constant (1,1) {mustBeNumericOrLogical} = true
        options.Method {mustBeTextScalar} = 'exact'
        options.Display {mustBeTextScalar} = 'off'
        options.MaxIter (1,1) {mustBePositive} = 2000
    end
    opt = options;
    method   = lower(char(opt.Method));
    hasConst = logical(opt.Constant);

    x = x(:);
    validateattributes(x, {'numeric'}, {'vector','real'});
    [p,d,q] = deal(round(p), round(d), round(q));

    obs = ~isnan(x);                       % observed-sample mask
    hasGaps = ~all(obs);
    if any(~isfinite(x(obs)))
        error('timeSeriesPreparation:tsFitArima:badData','Observed samples must be finite (Inf not allowed).');
    end

    if hasGaps
        if d > 0
            error('timeSeriesPreparation:tsFitArima:gapsWithDiff', ...
                ['Differencing (d>0) across missing samples is undefined. ', ...
                 'Difference the fully-observed series yourself, or model with d=0.']);
        end
        if ~strcmp(method,'exact')
            error('timeSeriesPreparation:tsFitArima:gapsNeedExact', ...
                ['Missing samples require Method=''exact'' (missing-data Kalman ', ...
                 'filter). CSS and Yule-Walker assume a complete series.']);
        end
    end

    [w, x0] = timeSeriesPreparation.tsmodels.tsDiff(x, d);                % w == x when d==0 (gap case)
    n = numel(w);
    if sum(obs) < p + q + 2
        error('timeSeriesPreparation:tsFitArima:tooShort', 'Too few observed samples for the requested order.');
    end

    % ---- Yule-Walker fast path (pure AR, no constant) -------------------
    if strcmp(method,'yw')
        if q > 0, error('timeSeriesPreparation:tsFitArima:ywMA','Yule-Walker supports pure AR only.'); end
        model = local_finishYW(x, w, x0, p, d);
        return;
    end

    % ---- Natural-coefficient objective in [mu?, ar(1:p), ma(1:q)] -------
    % objNat  : penalised (guards the optimiser against boundary excursions)
    % objRaw  : penalty-free (used for the observed-information Hessian so the
    %           standard errors are not corrupted by the barrier term when the
    %           finite-difference stencil steps near the stationarity boundary)
    switch method
        case 'exact'
            objNat = @(th) local_negLL_exact(th, w, p, q, hasConst, obs, true);
            objRaw = @(th) local_negLL_exact(th, w, p, q, hasConst, obs, false);
        case 'css'
            objNat = @(th) local_negLL_css(th, w, p, q, hasConst, true);
            objRaw = @(th) local_negLL_css(th, w, p, q, hasConst, false);
        otherwise, error('timeSeriesPreparation:tsFitArima:method','Unknown Method "%s".', method);
    end

    % ---- Reparametrised (unconstrained) objective ----------------------
    % The optimiser searches psi = [mu?, yAR(1:p), yMA(1:q)] in R^k.
    % local_reparam maps psi -> natural [mu?, ar, ma] via tanh + the
    % Durbin-Levinson PACF->coef recursion, so every trial AR/MA polynomial
    % is stationary/invertible BY CONSTRUCTION (no soft-barrier penalty).
    objPsi = @(psi) objNat(local_reparam(psi, p, q, hasConst));

    % ---- Multi-start optimisation --------------------------------------
    o = optimset('Display', char(opt.Display), 'MaxIter', opt.MaxIter, ...
                 'MaxFunEvals', 2000*(p+q+2), 'TolX', 1e-8, 'TolFun', 1e-8);

    obsW = obs(end-numel(w)+1:end);   % mask aligned to differenced w (all-true if d>0)
    starts = local_startSet(w, obsW, p, q, hasConst);   % cell of psi vectors
    bestNLL = inf; psiHat = starts{1}; flag = 0;
    for si = 1:numel(starts)
        [psiTry, nllTry, fl] = fminsearch(objPsi, starts{si}, o);
        if isfinite(nllTry) && nllTry < bestNLL
            bestNLL = nllTry; psiHat = psiTry; flag = fl;
        end
    end

    thHat = local_reparam(psiHat, p, q, hasConst);     % natural coefficients
    [negLL, e, s2] = objNat(thHat);
    [mu, ar, ma]   = local_unpack(thHat, p, q, hasConst);

    k = numel(thHat) + 1;                 % +1 for sigma^2
    % Standard errors on the NATURAL parameters via the observed-information
    % Hessian of the penalty-free objective (Richardson-extrapolated).
    se = local_stdErr(objRaw, thHat);
    nObs = sum(obs);

    model = struct();
    model.type   = local_typeName(p,d,q);
    model.p = p; model.d = d; model.q = q;
    model.const  = hasConst;
    model.mu     = mu;
    model.ar     = ar(:)';
    model.ma     = ma(:)';
    model.sigma2 = s2;
    model.resid  = e;                     % NaN at missing timestamps (exact)
    model.stdErr = se(:)';                % SEs of [mu? ar ma]
    model.logL   = -negLL;
    model.n      = n;                     % total timestamps
    model.nObs   = nObs;                  % observed samples used in likelihood
    model.obs    = obs;                   % logical mask (true = observed)
    model.k      = k;
    model.aic    = 2*negLL + 2*k;
    model.bic    = 2*negLL + k*log(nObs); % IC use observed count
    model.x  = x; model.xd = w; model.x0 = x0;
    model.method    = method;
    model.converged = flag == 1;
end

% ======================================================================
% Parameter (un)packing
% ======================================================================
function [mu, ar, ma] = local_unpack(th, p, q, hasConst)
    i = 1;
    if hasConst, mu = th(i); i = i + 1; else, mu = 0; end
    ar = th(i:i+p-1); i = i + p;
    ma = th(i:i+q-1);
end

% ======================================================================
% Reparametrisation: unconstrained psi -> natural [mu?, ar, ma]
% ======================================================================
function th = local_reparam(psi, p, q, hasConst)
% Map an unconstrained vector psi = [mu?, yAR(1:p), yMA(1:q)] to natural
% coefficients. AR and MA blocks pass through tanh (-> PACF in (-1,1)) and
% the Durbin-Levinson recursion, yielding a stationary AR polynomial and an
% invertible MA polynomial for ANY real psi. mu is passed through directly.
    psi = psi(:);
    i = 1; th = zeros(p+q+hasConst, 1);
    if hasConst, th(1) = psi(1); i = 2; end
    if p > 0
        rAR = local_clampPacf(tanh(psi(i:i+p-1)));
        th((1:p) + hasConst) = local_pacf2coef(rAR);
        i = i + p;
    end
    if q > 0
        rMA = local_clampPacf(tanh(psi(i:i+q-1)));
        th((1:q) + hasConst + p) = local_pacf2coef(rMA);
    end
end

function r = local_clampPacf(r)
% Keep reflection coefficients strictly inside (-1,1). tanh can saturate to
% exactly +/-1 in floating point for large arguments, which would place the
% AR/MA polynomial on the unit circle; clamping to +/-0.999 guarantees a
% strictly stationary/invertible result.
    r = min(max(r, -0.999), 0.999);
end

function phi = local_pacf2coef(r)
% Durbin-Levinson: partial autocorrelations r (|r|<1) -> AR/MA coefficients
% of a stationary/invertible polynomial. Column vector out.
    r = r(:); p = numel(r);
    a = zeros(p, 1);
    for k = 1:p
        ak = r(k);
        if k > 1
            prev = a(1:k-1);
            a(1:k-1) = prev - ak*flipud(prev);
        end
        a(k) = ak;
    end
    phi = a;
end

% ======================================================================
% Multi-start set of unconstrained initial vectors
% ======================================================================
function starts = local_startSet(w, obs, p, q, hasConst)
% Build a small set of psi start points: (1) a Yule-Walker-informed seed
% mapped back to unconstrained space, (2) a zero (white-noise) seed, and
% (3) a few small random perturbations. Derivative-free fminsearch benefits
% from the diversity without a big cost.
    muSeed = hasConst * mean(w(obs));
    yAR = zeros(p,1); yMA = zeros(q,1);
    if p > 0
        try
            arYW = local_ywCoefs(w(obs) - muSeed, p);
            rAR  = local_coef2pacf(arYW);
            yAR  = atanh(min(max(rAR, -0.99), 0.99));
        catch
        end
    end
    base = [repmat(muSeed, hasConst, 1); yAR; yMA];
    zero = [repmat(muSeed, hasConst, 1); zeros(p+q,1)];
    starts = {base, zero};
    rng_state = rng; c = onCleanup(@() rng(rng_state));  %#ok<NASGU>
    for j = 1:2
        pert = base + 0.3*[zeros(hasConst,1); randn(p+q,1)];
        starts{end+1} = pert; %#ok<AGROW>
    end
end

function r = local_coef2pacf(phi)
% Inverse Levinson-Durbin: AR/MA coefficients -> partial autocorrelations.
% Returns r clamped away from +/-1 for a safe atanh.
    phi = phi(:); p = numel(phi);
    a = phi; r = zeros(p,1);
    for k = p:-1:1
        rk = a(k); r(k) = rk;
        if k > 1
            den = 1 - rk^2;
            if abs(den) < 1e-10, den = sign(den + eps)*1e-10; end
            a(1:k-1) = (a(1:k-1) + rk*flipud(a(1:k-1))) / den;
        end
    end
    r = min(max(r, -0.999), 0.999);
end

% ======================================================================
% Conditional sum of squares (concentrated Gaussian log-likelihood)
% ======================================================================
function [nll, e, s2] = local_negLL_css(th, w, p, q, hasConst, usePenalty)
    if nargin < 6 || isempty(usePenalty), usePenalty = true; end
    [mu, ar, ma] = local_unpack(th, p, q, hasConst);
    n = numel(w); m = max(p, q);
    y = w - mu;
    e = zeros(n,1);
    for t = m+1:n
        pr = 0;
        for i = 1:p, pr = pr + ar(i)*y(t-i); end
        for j = 1:q, pr = pr + ma(j)*e(t-j); end
        e(t) = y(t) - pr;
    end
    ee = e(m+1:n); nEff = numel(ee);
    s2 = (ee'*ee) / nEff;
    if ~(s2 > 0) || ~isfinite(s2), nll = 1e12; return; end
    nll = 0.5*nEff*(log(2*pi) + log(s2) + 1);
    if usePenalty
        nll = nll + local_penalty(ar) + local_penalty(ma);
    end
end

% ======================================================================
% Exact Gaussian log-likelihood via Kalman filter (Harvey state space).
%   State dim r = max(p, q+1); stationary initial covariance from the
%   discrete Lyapunov equation. sigma^2 concentrated out. OBS is a logical
%   mask (true = observed): at missing timestamps the update step is
%   skipped (predict only) and no likelihood term is accrued.
% ======================================================================
function [nll, e, s2] = local_negLL_exact(th, w, p, q, hasConst, obs, usePenalty)
    n = numel(w);
    if nargin < 6 || isempty(obs), obs = true(n,1); end
    if nargin < 7 || isempty(usePenalty), usePenalty = true; end
    [mu, ar, ma] = local_unpack(th, p, q, hasConst);
    if usePenalty && (local_penalty(ar) > 0 || local_penalty(ma) > 0)
        % Optimiser guard: keep trial roots inside the unit circle.
        nll = 1e12; e = nan(n,1); s2 = var(w(obs),1); return;
    end
    % When usePenalty is false (Hessian / standard-error evaluation) the
    % likelihood is still computed for mildly non-stationary coefficients:
    % internal.dlyap falls back to the Kronecker solve, and the KF F>0 guard
    % below catches any genuinely degenerate case.
    y = w - mu;
    r = max(p, q+1);
    phi = zeros(r,1); phi(1:p) = ar(:);
    R   = zeros(r,1); R(1) = 1; R(2:1+q) = ma(:);      % [1 th1..thq 0..]'

    T = zeros(r); T(:,1) = phi; T(1:r-1, 2:r) = eye(r-1);
    RR = R*R';

    % Stationary initial state covariance: P = T P T' + RR  (units of s2)
    P = timeSeriesPreparation.internal.dlyap(T, RR, 1e-14, 60);
    a = zeros(r,1);

    e = nan(n,1); S = 0; logF = 0; nObs = 0; ok = true;
    for t = 1:n
        if obs(t)                              % ----- observed: full KF step
            F = P(1,1);
            if ~(F > 0) || ~isfinite(F), ok = false; break; end
            v = y(t) - a(1);
            e(t) = v / sqrt(F);                % standardized innovation
            S = S + v*v/F; logF = logF + log(F); nObs = nObs + 1;
            K = (T*P(:,1)) / F;
            a = T*a + K*v;
            P = T*P*T' + RR - (K*F)*K';
        else                                   % ----- missing: predict only
            a = T*a;
            P = T*P*T' + RR;
        end
        P = 0.5*(P + P');                      % keep symmetric
    end
    if ~ok || nObs == 0, nll = 1e12; s2 = var(w(obs),1); e = nan(n,1); return; end
    s2 = S / nObs;
    if ~(s2 > 0) || ~isfinite(s2), nll = 1e12; e = nan(n,1); return; end
    nll = 0.5*(nObs*log(2*pi) + nObs*log(s2) + logF + nObs);
    e   = e * sqrt(s2);                        % scale innovations to ~ N(0,s2)
end

% ======================================================================
% Root-based stationarity / invertibility guard (smooth barrier).
% With the PACF reparametrisation the optimiser never proposes a
% non-stationary/-invertible point, so this no longer shapes the search.
% It is retained only as a defensive guard on the natural-parameter
% objective (e.g. Hessian perturbations for standard errors), where it
% keeps the exact Kalman filter and CSS well defined at the boundary.
% ======================================================================
function pen = local_penalty(c)
    pen = 0;
    if isempty(c), return; end
    mr = max(abs(roots([1; -c(:)])));       % roots of 1 - c1 z - ... (companion)
    if mr > 0.999
        pen = 1e3*(mr - 0.999) + 1e4*(mr - 0.999)^2;
    end
end

% ======================================================================
% Standard errors from the numerical Hessian of the negative log-likelihood
% (observed information). Central differences with Richardson extrapolation
% in the step size, and a symmetric-eigenvalue fallback if the raw inverse
% is not positive definite.
% ======================================================================
function se = local_stdErr(obj, th)
    k = numel(th);
    h0 = 1e-3*max(abs(th), 1);          % base step
    H1 = local_hessian(obj, th, h0);        % step h0
    H2 = local_hessian(obj, th, h0/2);      % step h0/2
    % Richardson extrapolation for a central 2nd difference (O(h^2) -> O(h^4))
    H  = (4*H2 - H1) / 3;
    H  = 0.5*(H + H');

    se = nan(k,1);
    warn = warning('off','MATLAB:singularMatrix');
    try
        C = inv(H);
        dv = diag(C);
        if all(isfinite(dv)) && all(dv > 0)
            se = sqrt(dv);
        else
            % symmetric eigen-repair: clip tiny/negative curvature
            [V, Dd] = eig(H);
            dd = real(diag(Dd));
            dd(dd < eps*max(dd)) = eps*max(abs(dd) + realmin);
            Cr = V * diag(1./dd) * V';
            dvr = real(diag(Cr));
            se(dvr > 0) = sqrt(dvr(dvr > 0));
        end
    catch
    end
    warning(warn);
    se = se(:);
end

function H = local_hessian(obj, th, h)
% Central-difference Hessian of a scalar objective at th with step vector h.
    k = numel(th); H = zeros(k);
    for i = 1:k
        for j = i:k
            ei = zeros(k,1); ei(i) = h(i);
            ej = zeros(k,1); ej(j) = h(j);
            fpp = obj(th+ei+ej); fpm = obj(th+ei-ej);
            fmp = obj(th-ei+ej); fmm = obj(th-ei-ej);
            H(i,j) = (fpp - fpm - fmp + fmm) / (4*h(i)*h(j));
            H(j,i) = H(i,j);
        end
    end
end

% ======================================================================
% Yule-Walker helpers
% ======================================================================
function a = local_ywCoefs(y, p)
    r = timeSeriesPreparation.tsmodels.tsAcf(y, p);
    a = toeplitz(r(1:p)) \ r(2:p+1);
end

function model = local_finishYW(x, w, x0, p, d)
    n  = numel(w);
    mu = mean(w);
    r  = timeSeriesPreparation.tsmodels.tsAcf(w - mu, p);
    ar = toeplitz(r(1:p)) \ r(2:p+1);
    s2 = var(w,1) * (1 - ar'*r(2:p+1));
    y  = w - mu; e = zeros(n,1);
    for t = p+1:n
        pr = 0; for i = 1:p, pr = pr + ar(i)*y(t-i); end
        e(t) = y(t) - pr;
    end
    nEff = n - p;
    logL = -0.5*nEff*(log(2*pi) + log(s2) + 1);
    k = p + 2;
    model = struct('type', local_typeName(p,d,0), 'p',p,'d',d,'q',0, ...
        'const',true,'mu',mu,'ar',ar(:)','ma',[],'sigma2',s2, ...
        'resid',e,'stdErr',[],'logL',logL,'n',n,'k',k, ...
        'aic',-2*logL+2*k,'bic',-2*logL+k*log(n), ...
        'x',x,'xd',w,'x0',x0,'method','yw','converged',true);
end

% ======================================================================
function s = local_typeName(p,d,q)
    if d == 0
        if     q==0 && p>0, s = sprintf('AR(%d)',p);
        elseif p==0 && q>0, s = sprintf('MA(%d)',q);
        else,               s = sprintf('ARMA(%d,%d)',p,q);
        end
    else
        s = sprintf('ARIMA(%d,%d,%d)',p,d,q);
    end
end
