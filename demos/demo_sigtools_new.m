%% DEMO_SIGTOOLS_NEW  Showcase of the base-MATLAB additions to sigtools.
%  Covers: the spectral<->time-series loop (arma2psd/psd2arma/spec2acv),
%  seasonal ARIMA (tsFitSarima), and residual diagnostics
%  (tsCheckResiduals). Run setupTimeSeriesPreparation first.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)
clear; clc; rng(1);

%% 1) Spectral <-> time-series round trip (all base MATLAB)
Fs = 500;
bTrue = [1 -0.4 0.15]; aTrue = [1 -1.1 0.5];
[Starget, f] = timeSeriesPreparation.spectral.arma2psd(bTrue, aTrue, Fs, 'NFreq', 1024);   % ARMA -> PSD
[b, a, res]  = timeSeriesPreparation.spectral.psd2arma(f, Starget, Fs, 'Order', [2 2]);    % PSD  -> ARMA
Sfit = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', res.NoiseVariance, 'Frequencies', f);

figure('Name','Spectral round trip');
loglog(f(2:end), Starget(2:end), 'k-', 'LineWidth', 1.5); hold on;
loglog(f(2:end), Sfit(2:end), 'r--', 'LineWidth', 1.2); grid on;
xlabel('Hz'); ylabel('PSD'); legend('arma2psd target','psd2arma refit');
title(sprintf('Round-trip RMS = %.2f dB', res.RMSErrorDb));

% ...and PSD -> autocovariance via spec2acv, checked against theory
[R, tau] = timeSeriesPreparation.spectral.spec2acv(f, Starget, Window="tukey");
fprintf('Process variance: arma2psd=%.4f, spec2acv R(0)=%.4f\n', ...
        trapz(f, Starget), R(1));

%% 2) Seasonal ARIMA on synthetic monthly data
s = 12; N = 600;
phi = 0.6; Phi = 0.4; th = -0.3;
AR = conv([1 -phi], [1 zeros(1,s-1) -Phi]);
arc = -AR(2:end);
e = randn(N+400,1); y = zeros(N+400,1);
for t = numel(arc)+1:numel(y)
    y(t) = e(t) + th*e(t-1);
    for i = 1:numel(arc), y(t) = y(t) + arc(i)*y(t-i); end
end
y = y(401:end);

mS = timeSeriesPreparation.tsmodels.tsFitSarima(y, [1 0 1], [1 0 0], s);
timeSeriesPreparation.tsmodels.tsModelDisp(mS);
fprintf('SARIMA recovered: phi=%.3f (0.60), Phi=%.3f (0.40), theta=%.3f (-0.30)\n', ...
        mS.ar(1), mS.sar(1), mS.ma(1));

%% 3) Residual diagnostics
timeSeriesPreparation.tsmodels.plotResiduals(timeSeriesPreparation.tsmodels.tsCheckResiduals(mS));

%% 4) Reparametrisation keeps difficult fits stationary
xNear = filter(1, [1 -0.97], randn(2000,1));   % near-unit-root AR(1)
mNear = timeSeriesPreparation.tsmodels.tsFitArima(xNear, 1, 0, 0);
fprintf('Near-unit-root AR(1): phi=%.4f, max|root|=%.4f (<1 => stationary)\n', ...
        mNear.ar(1), max(abs(roots([1 -mNear.ar]))));

%% 5) Warmup-free noise synthesis from a PSD or an ARMA model
% Both paths are stationary from the very first sample (no filter start-up
% transient, no burn-in to discard). Demonstrated by comparing the mean
% square of the first block of samples with the last block.
FsSyn = 500; Nsyn = 2^15;

% (a) from a target PSD
fPSD = (0:0.25:FsSyn/2)';  Starget = 1 ./ (1 + (fPSD/20).^4);
[xPSD, tSyn, infoPSD] = timeSeriesPreparation.spectral.synthTimeSeries('psd', fPSD, Starget, FsSyn, Nsyn, 'Seed', 1);
fprintf(['\nSynth from PSD: target var = %.4f, sample var = %.4f\n' ...
         '  first/last block mean-square ratio = %.3f (=> no warmup)\n'], ...
    infoPSD.targetVariance, var(xPSD), ...
    mean(xPSD(1:200).^2) / mean(xPSD(end-199:end).^2));

% (b) from an ARMA model (stationary initial state)
bSyn = [1 -0.5 0.2]; aSyn = [1 -1.2 0.6];
[xARMA, ~, infoARMA] = timeSeriesPreparation.spectral.synthTimeSeries('arma', bSyn, aSyn, FsSyn, Nsyn, ...
    'NoiseVariance', 2, 'Seed', 2);
fprintf(['Synth from ARMA: theory var = %.4f, sample var = %.4f\n' ...
         '  first/last block mean-square ratio = %.3f (=> no warmup)\n'], ...
    infoARMA.targetVariance, var(xARMA), ...
    mean(xARMA(1:200).^2) / mean(xARMA(end-199:end).^2));

% verify the synthesised PSD matches the target
figure('Name','Warmup-free synthesis');
timeSeriesPreparation.spectral.plotPowerSpectrum( ...
    timeSeriesPreparation.spectral.powerSpectrum(FsSyn, xPSD, 'Label', 'synth from PSD', 'NAvg', 16), ...
    'Axes', gca, 'Title', 'synthTimeSeries: recovered PSD matches target'); hold on;
loglog(fPSD, Starget, 'k--', 'LineWidth', 1.4);
