%% DEMO_TSMODELS  Walkthrough of the base-MATLAB time-series toolbox.
%  Run RUNALLTESTS first to confirm everything works in your MATLAB.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)
clear; clc; rng(1);

%% 1) Simulate an ARMA(2,1) series
n   = 800; phi = [0.5 -0.3]; th = 0.4; mu = 1.0;
e   = randn(n+100,1); y = zeros(n+100,1);
for t = 3:n+100
    y(t) = mu + phi(1)*(y(t-1)-mu) + phi(2)*(y(t-2)-mu) + e(t) + th*e(t-1);
end
x = y(101:end);

%% 2) Identification: ACF & PACF
[rho, lagA, cA] = timeSeriesPreparation.tsmodels.tsAcf(x, 30);
[pac, lagP, cP] = timeSeriesPreparation.tsmodels.tsPacf(x, 30);
figure('Name','Identification');
subplot(2,1,1); stem(lagA, rho, 'filled'); yline([cA -cA],'--r');
title('ACF'); xlabel('lag'); grid on;
subplot(2,1,2); stem(lagP, pac, 'filled'); yline([cP -cP],'--r');
title('PACF'); xlabel('lag'); grid on;

%% 3) Fit with exact ML (default) and inspect standard errors
mAR   = timeSeriesPreparation.tsmodels.tsFitAR(x, 2);            % exact ML
mMA   = timeSeriesPreparation.tsmodels.tsFitMA(x, 1);
mARMA = timeSeriesPreparation.tsmodels.tsFitARMA(x, 2, 1);
timeSeriesPreparation.tsmodels.tsModelDisp(mAR);
timeSeriesPreparation.tsmodels.tsModelDisp(mMA);
timeSeriesPreparation.tsmodels.tsModelDisp(mARMA);

%% 4) Compare estimation methods on the same data
fprintf('Method comparison for ARMA(2,1):\n');
mExact = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1, 'Method', 'exact');
mCss   = timeSeriesPreparation.tsmodels.tsFitArima(x, 2, 0, 1, 'Method', 'css');
fprintf('  exact: ar=[% .3f % .3f] ma=% .3f  logL=%.2f  AIC=%.2f\n', ...
        mExact.ar, mExact.ma, mExact.logL, mExact.aic);
fprintf('  css  : ar=[% .3f % .3f] ma=% .3f  logL=%.2f  AIC=%.2f\n', ...
        mCss.ar,   mCss.ma,   mCss.logL,   mCss.aic);

%% 5) Automatic order selection (BIC)
[best, tbl] = timeSeriesPreparation.tsmodels.tsAutoArima(x, 3, 3, 0, 'Criterion', 'bic');
fprintf('\nAuto-selected: %s (BIC=%.2f)\n', best.type, best.bic);
disp(array2table(tbl, 'VariableNames', {'p','q','crit','AIC','BIC','logL'}));

%% 6) Forecast 25 steps with 95% interval
h = 25; [yh, se, lo, hi] = timeSeriesPreparation.tsmodels.tsForecast(best, h, 0.05);
figure('Name','Forecast');
tt = (1:numel(x))'; tf = numel(x) + (1:h)';
plot(tt, x, 'k'); hold on; plot(tf, yh, 'b', 'LineWidth', 1.4);
fill([tf; flipud(tf)], [lo; flipud(hi)], 'b', 'FaceAlpha', 0.15, 'EdgeColor','none');
legend('data','forecast','95% PI'); grid on;
title(sprintf('%s forecast', best.type));

%% 7) ARIMA(1,1,1) on a random walk with drift
z  = cumsum(0.05 + randn(400,1));
mI = timeSeriesPreparation.tsmodels.tsFitArima(z, 1, 1, 1);
timeSeriesPreparation.tsmodels.tsModelDisp(mI);
[zh, zse] = timeSeriesPreparation.tsmodels.tsForecast(mI, 15);
fprintf('ARIMA(1,1,1) 3-step forecast: %.3f %.3f %.3f  (SE grows: %.3f -> %.3f)\n', ...
        zh(1:3), zse(1), zse(end));

%% 8) Missing samples on a regular grid (exact missing-data ML)
rng(7);
phi = 0.7; xfull = zeros(2000,1); e = randn(2000,1);
for t = 2:2000, xfull(t) = phi*xfull(t-1) + e(t); end
xg = xfull;
xg(rand(2000,1) < 0.30) = NaN;      % 30% missing at random
xg(800:900) = NaN;                  % plus a contiguous block gap

mFull = timeSeriesPreparation.tsmodels.tsFitArima(xfull, 1, 0, 0);
mGap  = timeSeriesPreparation.tsmodels.tsFitArima(xg,    1, 0, 0); % exact by default; handles NaN
fprintf('\nMissing-data comparison (true phi = 0.70):\n');
fprintf('  complete : phi = %.4f  (n=%d)\n', mFull.ar(1), mFull.n);
fprintf('  30%%+block: phi = %.4f  (nObs=%d of %d)\n', ...
        mGap.ar(1), mGap.nObs, mGap.n);

% Identification still works via pairwise-complete ACF
[rho, lg, cf, npr] = timeSeriesPreparation.tsmodels.tsAcf(xg, 10);
fprintf('  gapped ACF lag1 = %.3f (expect ~%.2f), min pairs = %d\n', ...
        rho(2), phi, min(npr(2:end)));

[yh, se] = timeSeriesPreparation.tsmodels.tsForecast(mGap, 15);
fprintf('  gapped forecast 1-step = %.3f +/- %.3f\n', yh(1), se(1));
