function [R, lags, info] = arma2acv(b, a, maxLag, options)
%ARMA2ACV  Exact auto-covariance / -correlation of a discrete-time ARMA process.
%
%   SYNTAX
%     [R, lags] = timeSeriesPreparation.spectral.arma2acv(b, a, maxLag)
%     [R, lags, info] = timeSeriesPreparation.spectral.arma2acv(b, a, maxLag, NoiseVariance = 2, Output = "acf", Fs = 10)
%
%   DESCRIPTION
%     Returns the theoretical auto-covariance R(0..maxLag) of the
%     stationary ARMA process x[n] = filter(b, a, w[n]), w white with
%     variance sigma_w^2. Together with arma2psd and spec2acv it closes the
%     spectral <-> time-series loop: arma2acv(b, a, ...) and
%     spec2acv(arma2psd(b, a, ...)) agree to quadrature accuracy.
%
%     The default method is exact. The ARMA(p,q) is written in companion
%     state-space form, T = [phi, I; 0] (r x r, r = max(p, q+1)), with
%     noise loading R = [1; theta_1..theta_q; 0]. The stationary state
%     covariance solves the discrete Lyapunov equation
%     P = T P T' + sigma_w^2 R R' (doubling iteration, tolerance 1e-15, 80
%     steps, Kronecker fallback; timeSeriesPreparation.internal.dlyap),
%     and gamma(k) = e1' T^k P e1, since the first state is x[n]. There is
%     no truncation error, and R(1) is the exact process variance. Method
%     "psi" instead sums the MA(inf) weights, gamma(k) = sigma_w^2
%     sum_j psi_j psi_(j+k), truncated at PsiTerms terms; by default so
%     many that the slowest pole has decayed to 1e-6 in amplitude (about
%     1e-12 of R(0) in gamma), at least maxLag+50, at most 1e5.
%
%     b and a are normalised by a(1). A root of A with |z| >= 1 - 1e-12 is
%     refused as non-stationary.
%
%   INPUTS
%     b       (1,nb+1) double   -   MA (numerator) coefficients; b = 1 for
%                                   a pure AR process.
%     a       (1,na+1) double   -   AR (denominator) coefficients, a(1)
%                                   normally 1; all roots inside the unit
%                                   circle.
%     maxLag  (1,1) double      -   Largest lag in samples, integer >= 0;
%                                   R and lags have maxLag+1 elements.
%
%   OPTIONS
%     NoiseVariance  (1,1) double   [1]            sigma_w^2 of the driving
%                                                  noise, > 0; R scales
%                                                  linearly with it.
%     Output         (1,1) string   ["acv"]        "acv" (auto-covariance)
%                                                  or "acf" (R(k)/R(0)).
%     Method         (1,1) string   ["lyapunov"]   "lyapunov" (exact) or
%                                                  "psi" (truncated MA(inf)).
%     PsiTerms       (1,1) double   [[]]           Number of psi-weights for
%                                                  "psi", >= 2; [] = chosen
%                                                  from the slowest pole.
%     Fs             (1,1) double   [[]]           Sampling rate in Hz, > 0;
%                                                  if given, lags are in s
%                                                  and info.dt = 1/Fs.
%
%   OUTPUTS
%     R     (maxLag+1,1) double   -      Auto-covariance (unit^2) or
%                                        auto-correlation at lags
%                                        0..maxLag.
%     lags  (maxLag+1,1) double   sa|s   Lag axis: samples, or seconds when
%                                        Fs is given.
%     info  (1,1) struct          -      Fields: variance (R(0) before any
%                                        acf normalisation); method
%                                        ('lyapunov' | 'psi'); Poles, Zeros;
%                                        IsStable; NoiseVariance;
%                                        integralTime, (0.5 + sum_(k>=1)
%                                        rho(k)) dt, one-sided; dt (1 or
%                                        1/Fs); psiTerms (NaN for
%                                        "lyapunov").
%
%   ACCURACY
%     sigtools HANDOFF section 3 (NumPy re-derivation): the Lyapunov and
%     psi methods agree to about 1e-15 across AR(1), MA(2), ARMA(2,1) and
%     ARMA(1,3); the AR(1) and MA(q) closed forms are exact; arma2acv
%     equals spec2acv(arma2psd(...)) at integer lags to about 1e-15 on a
%     fine grid; the doubling Lyapunov solve matches the Kronecker solve to
%     about 1e-15. Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence
%     holds it bit for bit.
%
%   ERRORS
%     Model:
%       timeSeriesPreparation:arma2acv:badAR - a(1) is zero.
%       timeSeriesPreparation:arma2acv:nonstationary - a root of A lies on
%           or outside the unit circle (|z| >= 1 - 1e-12).
%       timeSeriesPreparation:arma2acv:zeroVariance - Output "acf" with
%           R(0) <= 0.
%     Options:
%       timeSeriesPreparation:arma2acv:badOption - Output or Method is not
%           one of its values (case-insensitive).
%       Other inputs outside their domain are refused by the arguments
%       block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Auto-covariance of an ARMA(2,1) process up to lag 30.
%     [R, k, info] = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 30, NoiseVariance = 2);
%
%   LIMITATIONS
%     Stationary models only; no integrated (ARIMA) or seasonal
%     differencing. Method "psi" is approximate for poles near the unit
%     circle (truncation at 1e5 terms). info.integralTime is a finite sum
%     up to maxLag, not the infinite integral.
%
%   REFERENCES
%     P. J. Brockwell, R. A. Davis (1991), Time Series: Theory and Methods,
%     2nd ed., Springer, section 3.3 (ARMA autocovariance). A. C. Harvey
%     (1989), Forecasting, Structural Time Series Models and the Kalman
%     Filter, Cambridge University Press (state-space form). sigtools
%     v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.spectral.spec2acv, timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.synthTimeSeries, timeSeriesPreparation.internal.dlyap.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        b {mustBeNumeric}
        a {mustBeNumeric}
        maxLag (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
        options.NoiseVariance (1,1) {mustBeNumeric, mustBePositive} = 1
        options.Output (1,1) string {mustBeOneOf(options.Output, ["acv" "acf"])} = "acv"
        options.Method (1,1) string {mustBeOneOf(options.Method, ["lyapunov" "psi"])} = "lyapunov"
        options.PsiTerms {mustBeScalarOrEmpty, mustBeNumeric, mustBeGreaterThanOrEqual(options.PsiTerms, 2)} = []
        options.Fs {mustBeScalarOrEmpty, mustBeNumeric, mustBePositive} = []
    end

    b = b(:).';  a = a(:).';
    o = options;

    % normalise leading AR coefficient to 1
    if a(1) == 0, error('timeSeriesPreparation:arma2acv:badAR', 'a(1) must be nonzero.'); end
    b = b / a(1);  a = a / a(1);

    poles = roots(a);
    if any(abs(poles) >= 1 - 1e-12)
        error('timeSeriesPreparation:arma2acv:nonstationary', ...
            'ARMA process is non-stationary (a root of A lies on/outside the unit circle).');
    end

    p = numel(a) - 1;  q = numel(b) - 1;
    ar = -a(2:end);                     % x_t = sum ar_i x_{t-i} + ...
    ma =  b(2:end);
    s2 = o.NoiseVariance;

    if strcmpi(o.Method, 'psi')
        [R, psiTerms] = local_acvPsi(ar, ma, s2, maxLag, poles, o.PsiTerms);
        methodUsed = 'psi';
    else
        R = local_acvLyapunov(ar, ma, s2, maxLag);
        psiTerms = NaN;
        methodUsed = 'lyapunov';
    end
    R = R(:);

    variance = R(1);
    if strcmpi(o.Output, 'acf')
        if ~(variance > 0)
            error('timeSeriesPreparation:arma2acv:zeroVariance', 'R(0) <= 0; cannot form the ACF.');
        end
        R = R / variance;
    end

    if isempty(o.Fs)
        lags = (0:maxLag)';  dt = 1;
    else
        lags = (0:maxLag)' / o.Fs;  dt = 1/o.Fs;
    end

    % one-sided integral timescale in lag units: (0.5 + sum_{k>=1} rho_k)*dt
    if strcmpi(o.Output, 'acf')
        rho = R;                     % R already normalised to R(0)=1
    else
        rho = R / variance;
    end
    integralTime = (0.5 + sum(rho(2:end))) * dt;

    info = struct();
    info.variance      = variance;
    info.method        = methodUsed;
    info.Poles         = poles;
    info.Zeros         = roots(b);
    info.IsStable      = all(abs(poles) < 1);
    info.NoiseVariance = s2;
    info.integralTime  = integralTime;
    info.dt            = dt;
    info.psiTerms      = psiTerms;
end

% ======================================================================
function R = local_acvLyapunov(ar, ma, s2, maxLag)
%   Exact ARMA autocovariance via the state covariance P of the companion
%   state-space form and the propagation gamma(k) = e1' T^k P e1.
    p = numel(ar);  q = numel(ma);
    r = max(p, q+1);
    phi = zeros(r,1); phi(1:p) = ar;
    Rv  = zeros(r,1); Rv(1) = 1; Rv(2:1+q) = ma;
    T = zeros(r); T(:,1) = phi; T(1:r-1,2:r) = eye(r-1);
    QQ = s2 * (Rv*Rv');

    P = timeSeriesPreparation.internal.dlyap(T, QQ, 1e-15, 80);

    R = zeros(maxLag+1, 1);
    col = P(:,1);                    % P*e1
    R(1) = col(1);                   % gamma(0)
    for k = 1:maxLag
        col = T*col;                 % T^k * P * e1
        R(k+1) = col(1);
    end
end

% ======================================================================
function [R, nPsi] = local_acvPsi(ar, ma, s2, maxLag, poles, nPsiReq)
%   ARMA autocovariance from MA(inf) psi-weights:
%   gamma(k) = s2 * sum_{j>=0} psi_j psi_{j+k}, truncated at nPsi terms.
    if isempty(nPsiReq)
        rmax = max(abs(poles));
        if rmax <= 0 || ~isfinite(rmax)
            nPsi = max(maxLag + 50, 200);
        else
            % want rmax^nPsi ~ 1e-6 (amplitude); tail in gamma ~ 1e-12
            nPsi = ceil(log(1e-6) / log(rmax));
            nPsi = max(nPsi, maxLag + 50);
        end
        nPsi = min(nPsi, 1e5);
    else
        nPsi = round(nPsiReq);
    end
    nPsi = max(nPsi, maxLag + 1);

    p = numel(ar);  q = numel(ma);
    psi = zeros(nPsi, 1);  psi(1) = 1;
    for k = 1:nPsi-1
        v = 0;
        for i = 1:min(p,k), v = v + ar(i)*psi(k-i+1); end
        if k <= q, v = v + ma(k); end
        psi(k+1) = v;
    end

    R = zeros(maxLag+1, 1);
    for k = 0:maxLag
        R(k+1) = s2 * (psi(1:nPsi-k)' * psi(k+1:nPsi));
    end
end

% ======================================================================
function mustBeOneOf(value, allowed)
% Case-insensitive membership, as v1.3.1's strcmpi validators.
    if ~any(strcmpi(value, allowed))
        error("timeSeriesPreparation:arma2acv:badOption", ...
            "Value must be one of: %s.", strjoin(allowed, ", "));
    end
end
