%% ALLANVARIANCE_DEMO
% Demonstrates allanVariance (overlapping estimator, CI bounds, slope,
% bias instability) on four canonical noise types:
%
%   White noise (angle/velocity random walk) -> slope -1/2
%   Flicker noise (bias instability)         -> slope  0  (flat)
%   Random walk (rate random walk)           -> slope +1/2
%   Quantization noise                       -> slope -1
%
% Only base MATLAB functions are used (filter, cumsum, round, erfinv, ...).
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

clear; clc; close all;

fs = 100;          % sample rate [Hz]
N  = 2^16;         % number of samples
rng(1);            % reproducibility

%% Generate the four noise types
whiteN = randn(N, 1);

% Flicker (pink, 1/f) noise: standard IIR approximation applied to white noise
b = [0.049922035, -0.095993537, 0.050612699, -0.004408786];
a = [1, -2.494956002, 2.017265875, -0.522189400];
flickerN = filter(b, a, whiteN);
flickerN = flickerN / std(flickerN);

% Random walk (Brownian) noise: integral of white noise
rwN = cumsum(randn(N, 1)) / sqrt(fs);

% Quantization noise: round a smooth signal to a coarse resolution
resolution = 0.5;
quantN = round(randn(N, 1) / resolution) * resolution;

names = {'White noise', 'Flicker noise', 'Random walk', 'Quantization'};
refSlopes = [-0.5, 0, 0.5, -1]; % expected reference slope per noise type

%% Combine into one NxP matrix and run allanVariance once for all columns
X = [whiteN, flickerN, rwN, quantN];
[tau, avar, adev, info] = timeSeriesPreparation.spectral.allanVariance(X, fs, [], 0.6827); %#ok<ASGLU>

%% Combined log-log plot with CI shading
figure('Name', 'Allan Deviation Comparison'); hold on; grid on;
colors = lines(4);
for p = 1:4
    fill([tau; flipud(tau)], [info.adevLow(:,p); flipud(info.adevHigh(:,p))], ...
         colors(p,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    loglog(tau, adev(:,p), 'LineWidth', 1.5, 'Color', colors(p,:));
end
set(gca, 'XScale', 'log', 'YScale', 'log');
xlabel('\tau [s]'); ylabel('\sigma_y(\tau)');
title('Allan Deviation for Different Noise Types (1\sigma CI shaded)');
legend(names, 'Location', 'best');

% overlay faint reference slope lines through the mid-point of each curve
for p = 1:4
    midIdx = round(numel(tau)/2);
    t0 = tau(midIdx); y0 = adev(midIdx, p);
    refLine = y0 * (tau/t0).^refSlopes(p);
    loglog(tau, refLine, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
end

fprintf('\nBias instability (0.664 * min(ADEV)) and its tau:\n');
for p = 1:4
    fprintf('  %-14s: %.4g @ tau = %.3g s\n', names{p}, ...
        info.biasInstability(p), info.biasInstabilityTau(p));
end

%% Per-noise-type panels with local slope underneath
figure('Name', 'Allan Deviation + Local Slope per Noise Type');
tiledlayout(2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
for p = 1:4
    nexttile(p); hold on; grid on;
    fill([tau; flipud(tau)], [info.adevLow(:,p); flipud(info.adevHigh(:,p))], ...
         colors(p,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    loglog(tau, adev(:,p), 'LineWidth', 1.5, 'Color', colors(p,:));
    set(gca, 'XScale', 'log', 'YScale', 'log');
    title(names{p}); xlabel('\tau [s]'); ylabel('\sigma_y');

    nexttile(p + 4); hold on; grid on;
    plot(logSafe(tau), info.slope(:,p), 'Color', colors(p,:), 'LineWidth', 1.2);
    yline(refSlopes(p), '--', sprintf('expected %.1f', refSlopes(p)));
    xlabel('log_{10}(\tau)'); ylabel('local slope');
    ylim([-1.5, 1.5]);
end

function y = logSafe(x)
y = log10(x);
end
