%% gap_filling_spectral_comparison.m
% Compares how different gap-handling strategies affect the power spectrum
% of a test signal, using ONLY the base-MATLAB sigtools functions (no
% Signal Processing Toolbox):
%   1) Linear interpolation (naive baseline)         -> powerSpectrum (FFT)
%   2) AR-model gap filling (tsFitArima + recursion) -> powerSpectrum
%   3) Lomb-Scargle directly on the gapped data      -> powerSpectrum (LS)
%   4) Reference spectrum of the ungapped signal
%
% Run setupTimeSeriesPreparation first so the functions are on the path.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

clear; close all; clc;

%% 1. Create a test signal: two sinusoids + noise
fs = 100;                      % Hz
T  = 20;                       % seconds
t  = (0:1/fs:T-1/fs)';
f1 = 3; f2 = 11.5;             % Hz, non-integer to test spectral leakage
rng(1);
x = sin(2*pi*f1*t) + 0.5*sin(2*pi*f2*t) + 0.1*randn(size(t));

%% 2. Introduce gaps (several missing chunks)
gapMask = true(size(t));
gapSpecs = [3.0 3.8; 8.5 9.6; 14.0 14.3; 17.0 18.5];   % [start end] in seconds
for k = 1:size(gapSpecs,1)
    gapMask(t >= gapSpecs(k,1) & t <= gapSpecs(k,2)) = false;
end
xGapped = x; xGapped(~gapMask) = NaN;
fprintf('Gap fraction: %.1f%%\n', 100*sum(~gapMask)/numel(t));

idxKnown = find(gapMask);

%% 3. Method 1 - Linear interpolation (naive baseline)
xLinInterp = interp1(t(idxKnown), x(idxKnown), t, 'linear', 'extrap');

%% 4. Method 2 - AR-model based gap filling (base-MATLAB tsFitArima)
% Fit an AR model on the observed samples (exact missing-data ML handles the
% NaNs directly), then fill each gap by recursive AR prediction.
order = 20;
mAR = timeSeriesPreparation.tsmodels.tsFitArima(xGapped, order, 0, 0);     % exact ML on the gapped series
arc = mAR.ar(:); muAR = mAR.mu;

xFillAR = xGapped;
starts = find(~gapMask & [true; gapMask(1:end-1)]);
ends   = find(~gapMask & [gapMask(2:end); true]);
for g = 1:numel(starts)
    s = starts(g); e = ends(g);
    for n = s:e
        hist = xFillAR(max(1,n-order):n-1) - muAR;
        hist(isnan(hist)) = 0;
        L = numel(hist);
        pred = arc(1:min(order,L)).' * flipud(hist(end-min(order,L)+1:end));
        xFillAR(n) = muAR + pred;
    end
end

%% 5. Spectra via sigtools (base MATLAB only)
figure('Position',[100 100 1000 720]);

subplot(3,2,[1 2]);
plot(t, x, 'k-'); hold on;
plot(t(~gapMask), x(~gapMask), 'r.', 'MarkerSize', 8);
title('Original signal with gaps marked (red = missing)');
xlabel('Time (s)'); ylabel('Amplitude'); legend('Signal','Gaps'); grid on;

ax1 = subplot(3,2,3);
timeSeriesPreparation.spectral.plotPowerSpectrum(timeSeriesPreparation.spectral.powerSpectrum( ...
    fs, x, 'Label', 'reference', 'Type','psd', 'Window','hann'), ...
    'Axes', ax1, 'Title','Reference (no gaps)');

ax2 = subplot(3,2,4);
timeSeriesPreparation.spectral.plotPowerSpectrum(timeSeriesPreparation.spectral.powerSpectrum( ...
    fs, xLinInterp, 'Label', 'linear', 'Type','psd', 'Window','hann'), ...
    'Axes', ax2, 'Title','Linear interpolation');

ax3 = subplot(3,2,5);
timeSeriesPreparation.spectral.plotPowerSpectrum(timeSeriesPreparation.spectral.powerSpectrum( ...
    fs, xFillAR, 'Label', 'AR-filled', 'Type','psd', 'Window','hann'), ...
    'Axes', ax3, 'Title','AR gap filling (tsFitArima)');

ax4 = subplot(3,2,6);
timeSeriesPreparation.spectral.plotPowerSpectrum(timeSeriesPreparation.spectral.powerSpectrum( ...
    t, xGapped, 'Label', 'gapped (LS)', 'Type','psd', 'MaxFreq', fs/2), ...
    'Axes', ax4, 'Title','Lomb-Scargle on gapped data');

sgtitle('Effect of gap-handling method on the spectral estimate (base MATLAB)');

%% 6. Quantitative comparison: amplitude at the known peak frequencies
fprintf('\n--- Recovered amplitude at the true peaks (target: 1.00 and 0.50) ---\n');
pk_ref = local_peakAmp(fs, x,          [f1 f2]);
pk_lin = local_peakAmp(fs, xLinInterp, [f1 f2]);
pk_ar  = local_peakAmp(fs, xFillAR,    [f1 f2]);
fprintf('%-16s %6.3f (%.1f Hz)  %6.3f (%.1f Hz)\n', 'reference',     pk_ref(1), f1, pk_ref(2), f2);
fprintf('%-16s %6.3f            %6.3f\n', 'linear interp', pk_lin(1), pk_lin(2));
fprintf('%-16s %6.3f            %6.3f\n', 'AR gap fill',    pk_ar(1),  pk_ar(2));

function amp = local_peakAmp(fs, x, freqs)
    S = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Type','amplitude', 'Window','hann');
    amp = zeros(size(freqs));
    for i = 1:numel(freqs)
        [~, k] = min(abs(S.frequency - freqs(i)));
        amp(i) = S.amplitude(k);
    end
end
