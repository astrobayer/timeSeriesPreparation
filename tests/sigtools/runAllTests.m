function results = runAllTests(seed)
%RUNALLTESTS  legacy function-based tsmodels suite of sigtools (29 cases).
%
%   DESCRIPTION
%     RESULTS = runAllTests() runs every legacy case and prints a summary;
%     runAllTests(SEED) fixes the RNG seed (default 12345). RESULTS is a
%     struct array with fields name, passed and msg; a warning
%     runAllTests:failures is issued if any case fails. The cases cover the
%     ACF/PACF, differencing, the ARIMA estimators, order selection,
%     forecasts, input validation and the missing-data paths, in base
%     MATLAB. TestSigtoolsLegacy runs this function once and counts each
%     case as one tagged test.
%
%     This is the sigtools v1.3.1 legacy suite, carried over at X-02 with
%     its code and assertions unchanged; only the help block is new.
%
%   COVERAGE
%     reference    - each case passes against its own oracle (closed forms,
%                    known truth within statistical tolerances), as counted
%                    by TestSigtoolsLegacy.
%     contract     - the function runs exactly 29 named cases and returns
%                    one result per case (TestSigtoolsLegacy).
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    if nargin < 1 || isempty(seed), seed = 12345; end
    rng(seed);

    tests = { ...
        @test_acf_whitenoise, ...
        @test_acf_known, ...
        @test_pacf_ar1, ...
        @test_diff_integrate_roundtrip, ...
        @test_norminv_values, ...
        @test_chi2_ljungbox_null, ...
        @test_yw_ar2_recovery, ...
        @test_exact_ar1_recovery, ...
        @test_exact_ma1_recovery, ...
        @test_exact_arma21_recovery, ...
        @test_exact_vs_css_close, ...
        @test_exact_ll_matches_closedform_ar1, ...
        @test_stderr_positive, ...
        @test_aic_bic_consistency, ...
        @test_auto_selects_true_order, ...
        @test_forecast_ar1_meanrevert, ...
        @test_forecast_interval_coverage, ...
        @test_arima_forecast_runs, ...
        @test_input_validation, ...
        @test_short_series_error, ...
        @test_acf_pairwise_gaps, ...
        @test_miss_ar1_recovery, ...
        @test_miss_arma_recovery, ...
        @test_miss_ll_matches_marginal_ar1, ...
        @test_miss_resid_nan_at_gaps, ...
        @test_miss_forecast_runs, ...
        @test_miss_blockgap_recovery, ...
        @test_miss_requires_exact, ...
        @test_miss_no_diff };

    n = numel(tests);
    results = struct('name', {}, 'passed', {}, 'msg', {});
    nPass = 0;
    fprintf('\n==== tsmodels test suite (seed=%d) ====\n\n', seed);
    for i = 1:n
        name = func2str(tests{i});
        try
            tests{i}();
            results(i) = struct('name', name, 'passed', true, 'msg', '');
            nPass = nPass + 1;
            fprintf('  PASS  %s\n', name);
        catch err
            results(i) = struct('name', name, 'passed', false, 'msg', err.message);
            fprintf('  FAIL  %s  -- %s\n', name, err.message);
        end
    end
    fprintf('\n---- %d/%d passed ----\n\n', nPass, n);
    if nPass < n
        warning('runAllTests:failures', '%d test(s) failed.', n - nPass);
    end
end

% ======================================================================
% Assertion helpers (base MATLAB)
% ======================================================================
function assertTrue(c, msg)
    if ~all(c(:)), error('assert:false', msg); end
end
function assertClose(a, b, tol, msg)
    if nargin < 3 || isempty(tol), tol = 1e-6; end
    if nargin < 4, msg = sprintf('expected %.6g, got %.6g (tol %.2g)', b, a, tol); end
    if any(abs(a(:) - b(:)) > tol), error('assert:close', msg); end
end
function assertError(fh, msg)
    ok = false;
    try, fh(); catch, ok = true; end
    if ~ok, error('assert:noerror', msg); end
end

% ======================================================================
% Simulation helpers
% ======================================================================
function x = simAR(phi, n, burn)
    if nargin < 3, burn = 200; end
    phi = phi(:); p = numel(phi); N = n + burn;
    e = randn(N,1); x = zeros(N,1);
    for t = p+1:N
        x(t) = phi.' * x(t-1:-1:t-p) + e(t);
    end
    x = x(burn+1:end);
end
function x = simMA(theta, n, burn)
    if nargin < 3, burn = 200; end
    theta = theta(:); q = numel(theta); N = n + burn;
    e = randn(N+q,1); x = zeros(N,1);
    for t = 1:N
        x(t) = e(t+q) + theta.' * e(t+q-1:-1:t);
    end
    x = x(burn+1:end);
end
function x = simARMA(phi, theta, n, burn)
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

% ======================================================================
% Tests
% ======================================================================
function test_acf_whitenoise()
    x = randn(5000,1);
    [rho,~,conf] = timeSeriesPreparation.tsmodels.tsAcf(x, 20);
    assertClose(rho(1), 1, 1e-12, 'ACF at lag 0 must be 1');
    assertTrue(mean(abs(rho(2:end)) < 3*conf) > 0.9, 'white-noise ACF within band');
end

function test_acf_known()
    % ACF of MA(1) with theta: rho1 = theta/(1+theta^2)
    th = 0.5; x = simMA(th, 20000);
    rho = timeSeriesPreparation.tsmodels.tsAcf(x, 2);
    assertClose(rho(2), th/(1+th^2), 0.03, 'MA(1) lag-1 ACF');
    assertClose(rho(3), 0, 0.03, 'MA(1) lag-2 ACF ~ 0');
end

function test_pacf_ar1()
    % AR(1): PACF(1)=phi, PACF(k>=2)~0
    phi = 0.7; x = simAR(phi, 20000);
    pac = timeSeriesPreparation.tsmodels.tsPacf(x, 5);
    assertClose(pac(1), phi, 0.03, 'AR(1) PACF lag1 = phi');
    assertTrue(all(abs(pac(2:end)) < 0.05), 'AR(1) PACF lag>=2 ~ 0');
end

function test_diff_integrate_roundtrip()
    x = cumsum(cumsum(randn(80,1))) + (1:80)'.^1.5;
    for d = 0:3
        [y, x0] = timeSeriesPreparation.tsmodels.tsDiff(x, d);
        xr = timeSeriesPreparation.tsmodels.tsIntegrate(y, x0);
        assertClose(xr, x, 1e-8, sprintf('diff/integrate round-trip d=%d', d));
    end
end

function test_norminv_values()
    z = @(p) local_call_norminv(p);
    assertClose(z(0.975),  1.959964, 1e-5, 'norminv 0.975');
    assertClose(z(0.025), -1.959964, 1e-5, 'norminv 0.025');
    assertClose(z(0.5),    0.0,      1e-8, 'norminv 0.5');
end

function test_chi2_ljungbox_null()
    % On white noise, Ljung-Box p-value should usually be large
    x = randn(3000,1);
    [~, pv] = timeSeriesPreparation.tsmodels.tsLjungBox(x, 20, 0);
    assertTrue(pv > 0.01, 'white noise should not reject at 1%');
end

function test_yw_ar2_recovery()
    phi = [0.5; -0.3]; x = simAR(phi, 5000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 0, 'Method', 'yw');
    assertClose(m.ar(:), phi, 0.05, 'YW AR(2) recovery');
    assertTrue(m.sigma2 > 0, 'sigma2 positive');
end

function test_exact_ar1_recovery()
    phi = 0.7; x = simAR(phi, 3000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, 'Method', 'exact');
    assertClose(m.ar(1), phi, 0.05, 'exact AR(1) phi');
    assertClose(m.mu, 0, 0.1, 'exact AR(1) mu ~ 0');
end

function test_exact_ma1_recovery()
    th = 0.6; x = simMA(th, 3000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 0, 0, 1, 'Method', 'exact');
    assertClose(m.ma(1), th, 0.06, 'exact MA(1) theta');
end

function test_exact_arma21_recovery()
    phi = [0.5; -0.3]; th = 0.4;
    x = simARMA(phi, th, 4000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1, 'Method', 'exact');
    assertClose(m.ar(:), phi, 0.08, 'exact ARMA ar');
    assertClose(m.ma(1), th, 0.10, 'exact ARMA ma');
end

function test_exact_vs_css_close()
    phi = 0.6; x = simAR(phi, 3000);
    me = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, 'Method', 'exact');
    mc = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, 'Method', 'css');
    assertClose(me.ar(1), mc.ar(1), 0.02, 'exact vs css AR coef close');
end

function test_exact_ll_matches_closedform_ar1()
    % Exact concentrated logL must match closed-form AR(1) at the MLE.
    phi = 0.5; x = simAR(phi, 500); x = x - mean(x);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0, 'Method', 'exact', 'Constant', false);
    ph = m.ar(1); s2 = m.sigma2; n = numel(x);
    v0 = s2/(1 - ph^2);
    ll = -0.5*(log(2*pi*v0) + x(1)^2/v0);
    for t = 2:n
        ll = ll - 0.5*(log(2*pi*s2) + (x(t)-ph*x(t-1))^2/s2);
    end
    assertClose(m.logL, ll, 1e-6, 'exact logL matches closed form');
end

function test_stderr_positive()
    x = simAR(0.6, 2000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
    assertTrue(~isempty(m.stdErr), 'stdErr present');
    assertTrue(all(m.stdErr(~isnan(m.stdErr)) > 0), 'stdErr positive');
end

function test_aic_bic_consistency()
    x = simAR(0.6, 1000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
    assertClose(m.aic, -2*m.logL + 2*m.k, 1e-9, 'AIC formula');
    assertClose(m.bic, -2*m.logL + m.k*log(m.n), 1e-9, 'BIC formula');
end

function test_auto_selects_true_order()
    phi = [0.6; -0.25]; x = simAR(phi, 3000);
    best = timeSeriesPreparation.tsmodels.tsAutoArima(x, 3, 2, 0, 'Criterion', 'bic');
    assertTrue(best.p >= 2, 'auto picks AR order >= 2 for AR(2)');
    assertTrue(best.q <= 1, 'auto keeps MA small for AR(2)');
end

function test_forecast_ar1_meanrevert()
    % AR(1) forecasts decay geometrically toward mu.
    phi = 0.6; x = simAR(phi, 2000) + 5;   % mean ~ 5
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
    yh = timeSeriesPreparation.tsmodels.tsForecast(m, 30);
    assertClose(yh(end), m.mu, 0.3, 'AR(1) long-horizon forecast -> mu');
    assertTrue(abs(yh(1)-m.mu) > abs(yh(end)-m.mu), 'forecast reverts to mean');
end

function test_forecast_interval_coverage()
    % One-step interval width ~ 2*z*sigma; se(1)=sigma.
    phi = 0.5; x = simAR(phi, 2000);
    m = timeSeriesPreparation.tsmodels.tsFitArima(x, 1, 0, 0);
    [~, se] = timeSeriesPreparation.tsmodels.tsForecast(m, 5, 0.05);
    assertClose(se(1), sqrt(m.sigma2), 1e-6, 'one-step SE = sigma');
    assertTrue(all(diff(se) >= -1e-9), 'forecast SE non-decreasing');
end

function test_arima_forecast_runs()
    z = cumsum(0.05 + randn(400,1));   % random walk + drift
    m = timeSeriesPreparation.tsmodels.tsFitArima(z, 1, 1, 1);
    [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 15);
    assertTrue(numel(yh) == 15 && all(isfinite(yh)), 'ARIMA forecast finite');
    assertTrue(all(hi >= lo), 'ARIMA interval ordered');
    assertTrue(all(diff(se) > 0), 'ARIMA SE grows with horizon');
end

function test_input_validation()
    assertError(@() timeSeriesPreparation.tsmodels.tsAcf([1 2 Inf 4]), 'ACF rejects Inf in observed data');
    assertError(@() timeSeriesPreparation.tsmodels.tsDiff(1:5, 10),    'diff rejects too-large order');
    assertError(@() timeSeriesPreparation.tsmodels.tsFitArima(1:5, 2, 0, 2), 'fit rejects too-short series');
end

function test_short_series_error()
    assertError(@() timeSeriesPreparation.tsmodels.tsFitArima((1:6)', 3, 0, 3), 'too-short ARMA errors');
end

% ---------------------------------------------------------------------
% Missing-data (regular grid, NaN-flagged samples)
% ---------------------------------------------------------------------
function xg = gapify(x, frac)
    xg = x; xg(rand(numel(x),1) < frac) = NaN;
end

function test_acf_pairwise_gaps()
    % Pairwise ACF of gapped AR(1) still tracks phi^k.
    phi = 0.7; x = simAR(phi, 8000);
    xg = gapify(x, 0.3);
    [rho, ~, ~, nP] = timeSeriesPreparation.tsmodels.tsAcf(xg, 4);
    assertClose(rho(1), 1, 1e-12, 'ACF lag0 = 1');
    assertClose(rho(2), phi,    0.04, 'gapped ACF lag1 ~ phi');
    assertClose(rho(3), phi^2,  0.05, 'gapped ACF lag2 ~ phi^2');
    assertTrue(nP(2) > 0 && nP(2) < numel(x), 'pair count reduced by gaps');
end

function test_miss_ar1_recovery()
    phi = 0.7; x = simAR(phi, 3000);
    xg = gapify(x, 0.3);
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0);            % exact by default
    assertClose(m.ar(1), phi, 0.06, 'missing-data AR(1) phi');
    assertTrue(m.nObs < m.n, 'nObs < n with gaps');
    assertTrue(m.nObs == sum(~isnan(xg)), 'nObs equals observed count');
end

function test_miss_arma_recovery()
    phi = [0.5; -0.3]; th = 0.4;
    x = simARMA(phi, th, 5000);
    xg = gapify(x, 0.25);
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 2, 0, 1);
    assertClose(m.ar(:), phi, 0.10, 'missing ARMA ar');
    assertClose(m.ma(1), th,  0.12, 'missing ARMA ma');
end

function test_miss_ll_matches_marginal_ar1()
    % Missing-data Kalman logL must equal the exact marginal Gaussian
    % density of the observed subset for AR(1) (mu=0, no constant).
    phi = 0.6; x = simAR(phi, 400); x = x - mean(x);
    xg = x; xg(rand(numel(x),1) < 0.35) = NaN; xg(50:70) = NaN;  % MAR + block
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0, 'Constant', false);
    ph = m.ar(1); s2 = m.sigma2;
    idx = find(~isnan(xg)); xo = xg(idx); mm = numel(idx);
    v   = s2/(1 - ph^2);
    D   = abs(idx - idx');
    Sig = v * ph.^D;                        % AR(1) marginal covariance
    L   = chol(Sig, 'lower');
    sol = L \ xo;
    ll  = -0.5*(mm*log(2*pi) + 2*sum(log(diag(L))) + sol'*sol);
    assertClose(m.logL, ll, 1e-4, 'missing-data logL matches exact marginal');
end

function test_miss_resid_nan_at_gaps()
    x  = simAR(0.6, 1000);
    xg = gapify(x, 0.2);
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0);
    assertTrue(all(isnan(m.resid(~m.obs))), 'residuals NaN at gaps');
    assertTrue(all(isfinite(m.resid(m.obs))), 'residuals finite where observed');
end

function test_miss_forecast_runs()
    x  = simAR(0.6, 1500) + 3;
    xg = gapify(x, 0.25);
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0);
    [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(m, 20);
    assertTrue(numel(yh) == 20 && all(isfinite(yh)), 'gapped forecast finite');
    assertTrue(all(hi >= lo), 'interval ordered');
    assertTrue(all(diff(se) >= -1e-9), 'forecast SE non-decreasing');
    assertClose(yh(end), m.mu, 0.4, 'forecast reverts to mu');
end

function test_miss_blockgap_recovery()
    % Non-random contiguous gap (eclipse/maneuver-like) must not bias much.
    phi = 0.7; x = simAR(phi, 3000);
    xg = x; xg(1200:1500) = NaN;            % 300-sample block
    m  = timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0);
    assertClose(m.ar(1), phi, 0.06, 'block-gap AR(1) phi');
end

function test_miss_requires_exact()
    xg = gapify(simAR(0.6, 500), 0.2);
    assertError(@() timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0, 'Method', 'css'), ...
        'gaps must reject CSS');
    assertError(@() timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 0, 0, 'Method', 'yw'), ...
        'gaps must reject YW');
end

function test_miss_no_diff()
    xg = gapify(simAR(0.6, 500), 0.2);
    assertError(@() timeSeriesPreparation.tsmodels.tsFitArima(xg, 1, 1, 0), 'gaps + d>0 must error');
end

% helper to reach the private norminv via forecast path is awkward;
% replicate the call by a tiny local copy check through tsForecast SE at
% alpha giving known z. Instead expose through a nested arithmetic check.
function z = local_call_norminv(p)
    % Reconstruct z from a trivial model forecast: hi = yhat + z*se, se known.
    % Simpler: use the same Acklam constants here for an independent check.
    a = [-3.969683028665376e+01  2.209460984245205e+02 -2.759285104469687e+02 ...
          1.383577518672690e+02 -3.066479806614716e+01  2.506628277459239e+00];
    b = [-5.447609879822406e+01  1.615858368580409e+02 -1.556989798598866e+02 ...
          6.680131188771972e+01 -1.328068155288572e+01];
    c = [-7.784894002430293e-03 -3.223964580411365e-01 -2.400758277161838e+00 ...
         -2.549732539343734e+00  4.374664141464968e+00  2.938163982698783e+00];
    dd= [ 7.784695709041462e-03  3.224671290700398e-01  2.445134137142996e+00 ...
          3.754408661907416e+00];
    plow = 0.02425; phigh = 1 - plow;
    if p < plow
        r = sqrt(-2*log(p));
        z = (((((c(1)*r+c(2))*r+c(3))*r+c(4))*r+c(5))*r+c(6)) / ...
            ((((dd(1)*r+dd(2))*r+dd(3))*r+dd(4))*r+1);
    elseif p <= phigh
        r = p - 0.5; s = r*r;
        z = (((((a(1)*s+a(2))*s+a(3))*s+a(4))*s+a(5))*s+a(6))*r / ...
            (((((b(1)*s+b(2))*s+b(3))*s+b(4))*s+b(5))*s+1);
    else
        r = sqrt(-2*log(1-p));
        z = -(((((c(1)*r+c(2))*r+c(3))*r+c(4))*r+c(5))*r+c(6)) / ...
             ((((dd(1)*r+dd(2))*r+dd(3))*r+dd(4))*r+1);
    end
end
