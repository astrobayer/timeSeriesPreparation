%DEMO_PLOTPOWERSPECTRUM  Worked examples for powerSpectrum and plotPowerSpectrum.
%
%   Five self-contained scenarios, each in its own cell (run with Ctrl+Enter).
%   They illustrate which option set fits which measurement situation.
%   Since X-02 powerSpectrum computes (one series per call, peaks included)
%   and plotPowerSpectrum draws its result.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

rng(42);                                   % reproducible noise

%% Scenario 1: Long, evenly sampled record -> Welch + confidence interval
% Use case: continuous logger data (magnetometer, seismometer, sensor rig).
% Goal: smooth, low-variance PSD estimate of noise + narrowband lines.
fs = 50;                                   % Hz
t  = (0:1/fs:600)';                        % 10 min record
x  = 0.8*sin(2*pi*1.25*t) ...              % narrowband signal
   + 0.3*sin(2*pi*4.70*t) ...
   + 1.0*randn(size(t));                   % white noise floor

S1 = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Label', 'logger', ...
    'NAvg', 12, 'Overlap', 0.5, ...        % Welch: variance down ~1/12
    'Window', 'hann', 'NPeaks', 2);
timeSeriesPreparation.spectral.plotPowerSpectrum(S1, ...
    'Confidence', 0.95, ...                % chi^2 bar, dof = 2K
    'Unit', 'nT', 'Title', '1: Welch PSD with 95% CI');
fprintf('Scenario 1 peaks: %.3f Hz, %.3f Hz\n', S1.peakFrequency);
% Reading: the CI bar shows the multiplicative uncertainty of the smooth
% noise floor. More NAvg = smoother floor but wider spectral lines
% (resolution = fs/L).

%% Scenario 2: Evenly sampled record WITH data gaps -> Lomb-Scargle + window
% Use case: telemetry dropouts, instrument maintenance windows.
fs = 20;  t = (0:1/fs:400)';
x  = 1.5*sin(2*pi*0.31*t) + 0.8*randn(size(t));
x(1500:2300) = NaN;                        % 40 s gap
x(5000:5600) = NaN;                        % another gap

S2 = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'Label', 'gapped record', ...
    'FAP', [0.05 0.01], ...                % significance levels
    'NPeaks', 1);
timeSeriesPreparation.spectral.plotPowerSpectrum(S2, ...
    'ShowSpectralWindow', true, ...        % judge alias/sidelobe peaks!
    'Title', '2: Gapped record, GLS + spectral window');
% Reading: peaks in the lower |W(f)|^2 panel mark frequencies where the
% sampling pattern itself leaks power. A data peak coinciding with a
% strong window feature deserves suspicion.

%% Scenario 3: Irregular sampling -> GLS + bootstrap FAP
% Use case: field campaigns, satellite conjunctions, astronomical epochs --
% observations at arbitrary times, marginal SNR, significance is the point.
T  = 200;                                  % days
t  = sort(T*rand(600,1));                  % 600 irregular epochs
x  = 0.35*sin(2*pi*t/14.3) + 1.0*randn(size(t));   % weak 14.3 d period

S3 = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'Label', 'campaign', ...
    'LombMethod', 'gls', ...               % floating mean (default)
    'FAP', 0.01, 'FAPMethod', 'bootstrap', 'NBootstrap', 1000, ...
    'NPeaks', 1, 'MaxFreq', 0.5);          % cycles per day
timeSeriesPreparation.spectral.plotPowerSpectrum(S3, ...
    'Title', '3: Irregular sampling, bootstrap 99% level');
fprintf('Scenario 3: peak at %.4f cpd (P = %.1f d), level method: %s\n', ...
    S3.peakFrequency, 1/S3.peakFrequency, S3.fapLevels.method);
% Reading: the peak is real only if it clears the dashed bootstrap level.
% Bootstrap respects the exact sampling pattern; null is WHITE noise.

%% Scenario 4: Precise amplitude measurement -> flattop window
% Use case: calibration signals, tide/line amplitude extraction.
fs = 1000;  t = (0:1/fs:5)';
x  = 2.000*sin(2*pi*123.37*t) + 0.05*randn(size(t));  % off-bin frequency!

SH = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Label', 'hann', 'Type','amplitude', ...
    'Window','hann', 'NPeaks',1);
SF = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Label', 'flattop', 'Type','amplitude', ...
    'Window','flattop', 'NPeaks',1);
timeSeriesPreparation.spectral.plotPowerSpectrum([SH, SF], 'Title','4: Amplitude fidelity');
fprintf(['Scenario 4 (true A = 2.000): hann %.4f, flattop %.4f\n' ...
    '  -> flattop removes scalloping loss for off-bin tones.\n'], ...
    SH.peakValue, SF.peakValue);

%% Scenario 5: Comparing instruments with different sampling in ONE plot
% Use case: cross-validation of two sensors observing the same process.
fs1 = 10;   t1 = (0:1/fs1:300)';
x1  = sin(2*pi*0.8*t1) + 0.5*randn(size(t1));
t2  = sort(300*rand(1200,1));              % second sensor, irregular
x2  = 1.05*sin(2*pi*0.8*t2) + 0.7*randn(size(t2));
fgrid = logspace(-2, log10(4), 800);       % common custom grid

S5 = [timeSeriesPreparation.spectral.powerSpectrum(t1, x1, 'Label', 'sensor A (10 Hz)', ...
          'Frequencies', fgrid, 'Type', 'amplitude', 'NPeaks', 1), ...   % same grid
      timeSeriesPreparation.spectral.powerSpectrum(t2, x2, 'Label', 'sensor B (irregular)', ...
          'Frequencies', fgrid, 'Type', 'amplitude', 'NPeaks', 1)];
h5 = timeSeriesPreparation.spectral.plotPowerSpectrum(S5, 'Unit', 'mV', ...
    'Title', '5: Two instruments, common frequency grid');
set(h5.lines(2), 'LineStyle', ':');        % post-styling via handles
fprintf('Scenario 5: A = %.3f mV vs %.3f mV at 0.8 Hz\n', ...
    S5(1).peakValue, S5(2).peakValue);
% Note: a custom 'Frequencies' grid forces Lomb-Scargle for BOTH series,
% which is exactly what makes them directly comparable.
