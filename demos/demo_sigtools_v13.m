%% DEMO_SIGTOOLS_V13  Newest sigtools additions (v1.2 / v1.3, base MATLAB).
%  Covers:
%    1) arma2acv        - exact ARMA autocovariance (Lyapunov) and the
%                         three-way agreement with arma2psd -> spec2acv.
%    2) tsFitSarima     - exact-ML seasonal fitting, including NaN gaps.
%    3) tsForecast      - seasonal forecasting and residual-bootstrap
%                         prediction intervals.
%    4) tsAutoSarima    - seasonal order search by AIC/BIC.
%  Run setupTimeSeriesPreparation first.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)
clear; clc; rng(1);

%% 1) Exact ARMA autocovariance and the spectral round trip
Fs = 10; b = [1 -0.5]; a = [1 -1.2 0.6]; s2 = 2.0; L = 25;
[R, k]        = timeSeriesPreparation.spectral.arma2acv(b, a, L, 'NoiseVariance', s2);          % direct, exact
[S, f]        = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 200000);
Rspec         = timeSeriesPreparation.spectral.spec2acv(f, S, 'Method', 'direct', 'Lags', (0:L)'/Fs);  % spectral route

figure('Name','arma2acv vs spectral route');
stem(k, R, 'filled'); hold on; plot(k, Rspec, 'ro'); grid on;
xlabel('lag [samples]'); ylabel('\gamma(k)');
legend('arma2acv (Lyapunov)', 'spec2acv(arma2psd)');
title(sprintf('max|difference| = %.2e', max(abs(R - Rspec))));
fprintf('1) arma2acv vs spectral route: max abs diff = %.2e\n', max(abs(R - Rspec)));

%% 2) Exact-ML seasonal ARIMA, with and without gaps
s = 12; N = 800;
phi = 0.6; Phi = 0.4; th = -0.3;
AR  = conv([1 -phi], [1 zeros(1,s-1) -Phi]);          % (1-phi B)(1-Phi B^s)
x   = filter([1 th], AR, randn(N,1));                 % SARMA(1,0,1)(1,0,0)_12

mCss   = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 0 0], s, 'Method', 'css');
mExact = timeSeriesPreparation.tsmodels.tsFitSarima(x, [1 0 1], [1 0 0], s, 'Method', 'exact');
fprintf('\n2) SARIMA(1,0,1)(1,0,0)_12   (true phi=%.2f, Phi=%.2f, th=%.2f)\n', phi, Phi, th);
fprintf('   CSS   : phi=%.3f  Phi=%.3f  th=%.3f  logL=%.1f\n', ...
        mCss.ar(1),  mCss.sar(1),  mCss.ma(1),  mCss.logL);
fprintf('   exact : phi=%.3f  Phi=%.3f  th=%.3f  logL=%.1f\n', ...
        mExact.ar(1), mExact.sar(1), mExact.ma(1), mExact.logL);

% exact ML tolerates missing samples (NaN) that CSS cannot
xg = x; xg(200:210) = NaN; xg(500:503) = NaN;
mGap = timeSeriesPreparation.tsmodels.tsFitSarima(xg, [1 0 1], [1 0 0], s, 'Method', 'exact');
fprintf('   exact w/ %d gaps : phi=%.3f Phi=%.3f (nObs=%d)\n', ...
        sum(~mGap.obs), mGap.ar(1), mGap.sar(1), mGap.nObs);

%% 3) Seasonal forecast + Gaussian vs bootstrap prediction intervals
h = 36;
[yh, se, loG, hiG] = timeSeriesPreparation.tsmodels.tsForecast(mExact, h);                       % Gaussian PI
[~,  ~,  loB, hiB] = timeSeriesPreparation.tsmodels.tsForecast(mExact, h, 0.05, ...
                                'Bootstrap', true, 'NBoot', 3000, 'Seed', 1);

figure('Name','Seasonal forecast');
tt = (1:N)'; tf = N + (1:h)';
plot(tt(end-4*s:end), x(end-4*s:end), 'k-'); hold on;
plot(tf, yh, 'b-', 'LineWidth', 1.3);
fill([tf; flipud(tf)], [loG; flipud(hiG)], 'b', 'FaceAlpha', 0.12, 'EdgeColor', 'none');
plot(tf, loB, 'r--'); plot(tf, hiB, 'r--');
grid on; xlabel('t'); ylabel('x');
legend('history','forecast','95% Gaussian','95% bootstrap', 'Location','best');
title('Seasonal forecast with Gaussian and bootstrap intervals');
fprintf('\n3) Forecast one-step SE = %.3f (=sqrt(sigma2)=%.3f)\n', se(1), sqrt(mExact.sigma2));

%% 4) Seasonal order search
[best, tbl] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 1], [1 0 1], s, 'Criterion', 'bic');
fprintf('\n4) tsAutoSarima (BIC) picked: %s\n', best.type);
fprintf('   top 3 rows [p d q P D Q crit]:\n');
disp(tbl(1:min(3,size(tbl,1)), [1:6 7]));
