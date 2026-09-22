%DEMO_PLOTPOWERSPECTRUM  Worked examples for plotPowerSpectrum.
%
%   Five self-contained scenarios, each in its own cell (run with Ctrl+Enter).
%   They illustrate which option set fits which measurement situation.

rng(42);                                   % reproducible noise

%% Scenario 1: Long, evenly sampled record -> Welch + confidence interval
% Use case: continuous logger data (magnetometer, seismometer, sensor rig).
% Goal: smooth, low-variance PSD estimate of noise + narrowband lines.
fs = 50;                                   % Hz
t  = (0:1/fs:600)';                        % 10 min record
x  = 0.8*sin(2*pi*1.25*t) ...              % narrowband signal
   + 0.3*sin(2*pi*4.70*t) ...
   + 1.0*randn(size(t));                   % white noise floor

[pk1, S1] = timeSeriesPreparation.spectral.plotPowerSpectrum({fs, x, 'logger'}, ...
    'NAvg', 12, 'Overlap', 0.5, ...        % Welch: variance down ~1/12
    'Window', 'hann', ...
    'Confidence', 0.95, ...                % chi^2 bar, dof = 2K
    'NPeaks', 2, 'Unit', 'nT', ...
    'Title', '1: Welch PSD with 95% CI');
fprintf('Scenario 1 peaks: %.3f Hz, %.3f Hz\n', pk1.frequency);
% Reading: the CI bar shows the multiplicative uncertainty of the smooth
% noise floor. More NAvg = smoother floor but wider spectral lines
% (resolution = fs/L, reported in S1.rayleigh).

%% Scenario 2: Evenly sampled record WITH data gaps -> Lomb-Scargle + window
% Use case: telemetry dropouts, instrument maintenance windows.
fs = 20;  t = (0:1/fs:400)';
x  = 1.5*sin(2*pi*0.31*t) + 0.8*randn(size(t));
x(1500:2300) = NaN;                        % 40 s gap
x(5000:5600) = NaN;                        % another gap

timeSeriesPreparation.spectral.plotPowerSpectrum({t, x, 'gapped record'}, ...
    'FAP', [0.05 0.01], ...                % significance levels
    'ShowSpectralWindow', true, ...        % judge alias/sidelobe peaks!
    'NPeaks', 1, ...
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

[pk3, S3] = timeSeriesPreparation.spectral.plotPowerSpectrum({t, x, 'campaign'}, ...
    'LombMethod', 'gls', ...               % floating mean (default)
    'FAP', 0.01, 'FAPMethod', 'bootstrap', 'NBootstrap', 1000, ...
    'NPeaks', 1, 'MaxFreq', 0.5, ...       % cycles per day
    'Title', '3: Irregular sampling, bootstrap 99% level');
fprintf('Scenario 3: peak at %.4f cpd (P = %.1f d), level method: %s\n', ...
    pk3.frequency, 1/pk3.frequency, S3.fapLevels.method);
% Reading: the peak is real only if it clears the dashed bootstrap level.
% Bootstrap respects the exact sampling pattern; null is WHITE noise.

%% Scenario 4: Precise amplitude measurement -> flattop window
% Use case: calibration signals, tide/line amplitude extraction.
fs = 1000;  t = (0:1/fs:5)';
x  = 2.000*sin(2*pi*123.37*t) + 0.05*randn(size(t));  % off-bin frequency!

[pkH] = timeSeriesPreparation.spectral.plotPowerSpectrum({fs, x, 'hann'}, 'Type','amplitude', ...
    'Window','hann', 'NPeaks',1, 'Title','4: Amplitude fidelity');
[pkF] = timeSeriesPreparation.spectral.plotPowerSpectrum({fs, x, 'flattop'}, 'Type','amplitude', ...
    'Window','flattop', 'NPeaks',1);
fprintf(['Scenario 4 (true A = 2.000): hann %.4f, flattop %.4f\n' ...
    '  -> flattop removes scalloping loss for off-bin tones.\n'], ...
    pkH.amplitude, pkF.amplitude);

%% Scenario 5: Comparing instruments with different sampling in ONE plot
% Use case: cross-validation of two sensors observing the same process.
fs1 = 10;   t1 = (0:1/fs1:300)';
x1  = sin(2*pi*0.8*t1) + 0.5*randn(size(t1));
t2  = sort(300*rand(1200,1));              % second sensor, irregular
x2  = 1.05*sin(2*pi*0.8*t2) + 0.7*randn(size(t2));
fgrid = logspace(-2, log10(4), 800);       % common custom grid

[pk5, S5, h5] = timeSeriesPreparation.spectral.plotPowerSpectrum( ...
    {t1, x1, 'sensor A (10 Hz)'}, ...
    {t2, x2, 'sensor B (irregular)'}, ...
    'Frequencies', fgrid, ...              % same grid -> direct comparison
    'Type', 'amplitude', 'NPeaks', 1, 'Unit', 'mV', ...
    'Title', '5: Two instruments, common frequency grid');
set(h5.lines(2), 'LineStyle', ':');        % post-styling via handles
fprintf('Scenario 5: A = %.3f mV vs %.3f mV at 0.8 Hz\n', ...
    pk5(1).amplitude, pk5(2).amplitude);
% Note: a custom 'Frequencies' grid forces Lomb-Scargle for BOTH series,
% which is exactly what makes them directly comparable.
