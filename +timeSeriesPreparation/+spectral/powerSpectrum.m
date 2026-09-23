function spec = powerSpectrum(t, x, options)
%POWERSPECTRUM  Power and amplitude spectrum of one series: Welch FFT or Lomb-Scargle.
%
%   SYNTAX
%     spec = timeSeriesPreparation.spectral.powerSpectrum(t, x)
%     spec = timeSeriesPreparation.spectral.powerSpectrum(fs, x, Type = "amplitude", NPeaks = 3)
%     spec = [powerSpectrum(t1, x1, Label = "A"), powerSpectrum(t2, x2, Label = "B")]
%
%   DESCRIPTION
%     The estimation half of sigtools' plotPowerSpectrum, split off at X-02
%     so that numbers never require a figure (owner decision 2026-09-23).
%     The arithmetic is v1.3.1's, unchanged; TestSigtoolsEquivalence holds
%     it bit for bit against the archive.
%
%     An evenly sampled, gap-free series gets a Welch-averaged windowed FFT
%     periodogram; a series with NaN gaps or uneven sampling gets a
%     Lomb-Scargle periodogram (floating-mean GLS by default, Zechmeister and
%     Kuerster 2009). Both use one scaling:
%       power      one-sided PSD, unit^2/Hz, S(f) = 2 |X|^2 / (fs sum w^2)
%       amplitude  sinusoid amplitude, unit
%     so A sin(2 pi f0 t) peaks at about A in the amplitude spectrum
%     whatever the sampling. The PSD follows sigtools' convention
%     (trapz(f, S) = variance), shared with arma2psd and synthTimeSeries.
%
%     FAP gives false-alarm levels for a Lomb-Scargle series: "analytic"
%     uses M = T_span f_max independent frequencies; "bootstrap" shuffles
%     the data over the fixed sampling times NBootstrap times. Both assume a
%     white-noise null; a red-noise record looks over-significant with
%     either. NPeaks returns the highest distinct maxima of the Type
%     quantity, at least MinPeakDistance apart (default the Rayleigh
%     resolution 1/T_span), refined by a 3-point parabola. Several series
%     are one struct array: concatenate the results.
%
%   INPUTS
%     t  (:,1) double   s    Time stamps, or a scalar sampling rate in Hz;
%                            also datetime (stamps) or duration (stamps, or
%                            a scalar sample step).
%     x  (:,1) double   -    Data; NaN marks a gap.
%
%   OPTIONS
%     Label            (1,1) string   ["Series 1"]  Name of the series.
%     Type             (1,1) string   ["psd"]       Quantity the peaks are
%                                                   found on and plotted:
%                                                   "psd" or "amplitude".
%     Frequencies      (:,1) double   []            Frequencies in Hz; forces
%                                                   Lomb-Scargle.
%     Detrend          (1,1) string   ["linear"]    "linear", "mean" or
%                                                   "none".
%     Window           (1,1) string   ["hann"]      FFT window: "hann",
%                                                   "hamming", "blackman",
%                                                   "blackmanharris",
%                                                   "nuttall", "flattop",
%                                                   "kaiser", "tukey",
%                                                   "gauss", "bartlett",
%                                                   "rect", "rectangular",
%                                                   "none".
%     WindowParam      (1,1) double   []            Kaiser beta (8.6), Tukey
%                                                   ratio (0.5) or Gauss
%                                                   sigma (0.4).
%     SegmentLength    (1,1) double   []            Welch segment length in
%                                                   samples, >= 8; [] =
%                                                   whole record.
%     NAvg             (1,1) double   []            Number of Welch averages,
%                                                   instead of SegmentLength.
%     Overlap          (1,1) double   [0.5]         Welch overlap fraction,
%                                                   in [0, 1).
%     LombMethod       (1,1) string   ["gls"]       "gls" (floating mean) or
%                                                   "classic".
%     Oversample       (1,1) double   [4]           Oversampling of the
%                                                   default Lomb-Scargle
%                                                   grid, >= 1.
%     MaxFreq          (1,1) double   []            Upper frequency limit in
%                                                   Hz.
%     NyquistMode      (1,1) string   ["median"]    Sampling step that sets
%                                                   the default f_max =
%                                                   0.5/dt: "median", "min"
%                                                   or "mean".
%     UniformTol       (1,1) double   [1e-6]        Relative step tolerance
%                                                   of the uniformity test.
%     FAP              (1,:) double   []            False-alarm probabilities
%                                                   in (0, 1), e.g. [0.05
%                                                   0.01].
%     FAPMethod        (1,1) string   ["analytic"]  "analytic" or
%                                                   "bootstrap".
%     NBootstrap       (1,1) double   [1000]        Bootstrap realisations,
%                                                   >= 10.
%     NPeaks           (1,1) double   [0]           Number of peaks to
%                                                   return.
%     MinPeakDistance  (1,1) double   []            Least peak separation in
%                                                   Hz; [] = 1/T_span.
%
%   OUTPUTS
%     spec  (1,1) struct   -   Fields: label (char); type ("psd" or
%                              "amplitude"); frequency (M,1) double, Hz;
%                              power (M,1) double, unit^2/Hz; amplitude
%                              (M,1) double, unit; method ('fft' or
%                              'lomb-scargle'); fs, Hz; dof and nseg of the
%                              estimate; variance of the detrended data;
%                              fapLevels (struct fap, method, psd, amp, or
%                              []); spectralWindow (M,1) double, |W(f)|^2
%                              normalised to 1 at f = 0, Lomb-Scargle only;
%                              peakFrequency (K,1) double, Hz;
%                              peakValue (K,1) double, in Type's unit.
%
%   ACCURACY
%     Unchanged from sigtools v1.3.1. A unit sinusoid is recovered at
%     amplitude 1 within the window's scalloping loss (flattop: < 0.01 dB).
%     The Welch dof = 2K is approximate for overlapping segments. The
%     analytic FAP is an approximation (Scargle 1982). The bootstrap level
%     is noisy unless FAP*NBootstrap >= 10, and a warning says so.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:powerSpectrum:sizeMismatch - t is neither a
%           scalar nor as long as x.
%       timeSeriesPreparation:powerSpectrum:badRate - a scalar t is not a
%           positive sampling rate.
%       timeSeriesPreparation:powerSpectrum:tooFewSamples - fewer than 8
%           valid samples.
%       timeSeriesPreparation:powerSpectrum:emptyGrid - the Lomb-Scargle
%           frequency grid is empty (MaxFreq below the first bin).
%     Options:
%       timeSeriesPreparation:powerSpectrum:badOption - a text option is
%           not one of its values (case-insensitive), or Frequencies is
%           not a vector of positive values.
%       Other options outside their domain are refused by the arguments
%       block with a MATLAB: identifier.
%
%   WARNINGS
%     Significance:
%       timeSeriesPreparation:powerSpectrum:fapResolution - FAP*NBootstrap
%           < 10: the bootstrap level is noisy.
%
%   EXAMPLE
%     % A 3 Hz sinusoid at 100 Hz: the amplitude peak is about 1.
%     t = (0:1/100:20)';
%     spec = timeSeriesPreparation.spectral.powerSpectrum(t, sin(2*pi*3*t), Type = "amplitude", NPeaks = 1, Window = "flattop");
%
%   LIMITATIONS
%     One series per call. The bootstrap FAP draws from the global random
%     stream (randperm); set rng for reproducible levels. Lomb-Scargle costs
%     O(N M) with M frequencies.
%
%   REFERENCES
%     P. D. Welch (1967), IEEE Trans. Audio Electroacoust. 15(2), 70-73.
%     J. D. Scargle (1982), ApJ 263, 835-853. M. Zechmeister, M. Kuerster
%     (2009), A&A 496, 577-584. F. J. Harris (1978), Proc. IEEE 66(1),
%     51-83 (windows). sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.plotPowerSpectrum, timeSeriesPreparation.spectral.allanVariance, timeSeriesPreparation.spectral.spec2acv.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        t
        x {mustBeNumeric}
        options.Label (1,1) string = "Series 1"
        options.Type (1,1) string {mustBeOneOf(options.Type, ["psd" "amplitude"])} = "psd"
        options.Frequencies {mustBeNumeric, mustBeFrequencies} = []
        options.Detrend (1,1) string {mustBeOneOf(options.Detrend, ["none" "mean" "linear"])} = "linear"
        options.Window (1,1) string {mustBeOneOf(options.Window, ["hann" "hamming" ...
            "blackman" "blackmanharris" "nuttall" "flattop" "kaiser" "tukey" ...
            "gauss" "bartlett" "rect" "rectangular" "none"])} = "hann"
        options.WindowParam {mustBeScalarOrEmpty, mustBeNumeric, mustBeFinite} = []
        options.SegmentLength {mustBeScalarOrEmpty, mustBeNumeric, mustBeGreaterThanOrEqual(options.SegmentLength, 8)} = []
        options.NAvg {mustBeScalarOrEmpty, mustBeNumeric, mustBeGreaterThanOrEqual(options.NAvg, 1)} = []
        options.Overlap (1,1) double {mustBeGreaterThanOrEqual(options.Overlap, 0), mustBeLessThan(options.Overlap, 1)} = 0.5
        options.LombMethod (1,1) string {mustBeOneOf(options.LombMethod, ["gls" "classic"])} = "gls"
        options.Oversample (1,1) double {mustBeGreaterThanOrEqual(options.Oversample, 1)} = 4
        options.MaxFreq {mustBeScalarOrEmpty, mustBeNumeric, mustBePositive} = []
        options.NyquistMode (1,1) string {mustBeOneOf(options.NyquistMode, ["median" "min" "mean"])} = "median"
        options.UniformTol (1,1) double {mustBePositive} = 1e-6
        options.FAP {mustBeNumeric, mustBeGreaterThan(options.FAP, 0), mustBeLessThan(options.FAP, 1)} = []
        options.FAPMethod (1,1) string {mustBeOneOf(options.FAPMethod, ["analytic" "bootstrap"])} = "analytic"
        options.NBootstrap (1,1) double {mustBeGreaterThanOrEqual(options.NBootstrap, 10)} = 1000
        options.NPeaks (1,1) double {mustBeNonnegative} = 0
        options.MinPeakDistance {mustBeScalarOrEmpty, mustBeNumeric, mustBeNonnegative} = []
    end

    opts = options;
    ser = struct("t", t, "x", x, "label", char(opts.Label));
    spec = analyseSeries(ser, opts);
    spec.type = char(lower(opts.Type));
    spec.peakFrequency = zeros(0, 1);
    spec.peakValue = zeros(0, 1);
    if opts.NPeaks > 0
        mpd = opts.MinPeakDistance;
        if isempty(mpd), mpd = spec.rayleigh; end
        if strcmpi(opts.Type, 'psd'), y = spec.power; else, y = spec.amplitude; end
        [spec.peakFrequency, spec.peakValue] = topPeaks(spec.frequency, y, opts.NPeaks, mpd);
    end
    spec = rmfield(spec, 'rayleigh');
    spec = orderfields(spec, {'label' 'type' 'frequency' 'power' 'amplitude' ...
        'method' 'fs' 'dof' 'nseg' 'variance' 'fapLevels' 'spectralWindow' ...
        'peakFrequency' 'peakValue'});
end

% ========================================================================
function out = analyseSeries(ser, opts)
x = double(ser.x(:));  traw = ser.t(:);

% Time input: datetime / duration / numeric; scalar => rate or step
if isdatetime(traw)
    t = seconds(traw - traw(1));
elseif isduration(traw)
    if isscalar(traw), t = (0:numel(x)-1)' * seconds(traw);
    else,              t = seconds(traw - traw(1));
    end
elseif isscalar(traw)
    if ~(traw > 0)
        error('timeSeriesPreparation:powerSpectrum:badRate', ...
            'Sampling rate must be positive.');
    end
    t = (0:numel(x)-1)'/double(traw);
else
    t = double(traw);
end
if numel(t) ~= numel(x)
    error('timeSeriesPreparation:powerSpectrum:sizeMismatch', ...
        '"%s": time vector and data must have equal length.', ser.label);
end

% Drop NaN/Inf samples (data gaps), sort by time
good = isfinite(t) & isfinite(x);
t = t(good); x = x(good);
[t, is] = sort(t); x = x(is);
N = numel(x);
if N < 8
    error('timeSeriesPreparation:powerSpectrum:tooFewSamples', ...
        '"%s": fewer than 8 valid samples.', ser.label);
end

dt = diff(t);  dt(dt == 0) = [];
mdt = median(dt);
switch lower(opts.NyquistMode)
    case 'min',  dtNyq = min(dt);
    case 'mean', dtNyq = mean(dt);
    otherwise,   dtNyq = mdt;
end
fsEff = 1/mdt;                                % density scale (robust)
isUniform = all(abs(dt - mdt) < opts.UniformTol*mdt);
Tspan = t(end) - t(1);

% Detrend
switch lower(opts.Detrend)
    case 'mean',   x = x - mean(x);
    case 'linear', c = polyfit(t, x, 1); x = x - polyval(c, t);
end
varx = var(x);

out = struct('label',ser.label,'frequency',[],'power',[],'amplitude',[], ...
    'method','','fs',fsEff,'dof',[],'nseg',[],'variance',varx, ...
    'fapLevels',[],'spectralWindow',[],'rayleigh',1/Tspan);

customF = ~isempty(opts.Frequencies);
if isUniform && ~customF
    % ------------- Welch-averaged windowed FFT periodogram --------------
    if ~isempty(opts.SegmentLength)
        L = min(round(opts.SegmentLength), N);
    elseif ~isempty(opts.NAvg) && opts.NAvg > 1
        L = floor(N / (1 + (opts.NAvg-1)*(1-opts.Overlap)));
        L = max(L, 8);
    else
        L = N;
    end
    step   = max(1, round(L*(1-opts.Overlap)));
    starts = 1:step:(N-L+1);
    if L == N, starts = 1; end
    K = numel(starts);

    w  = makeWindow(opts.Window, L, opts.WindowParam);
    nH = floor(L/2);
    acc = zeros(nH,1);
    for kk = 1:K
        seg = x(starts(kk):starts(kk)+L-1);
        seg = seg - mean(seg);                 % per-segment demean (Welch)
        X   = fft(seg .* w);
        acc = acc + abs(X(2:nH+1)).^2;
    end
    P2 = acc / K;                              % averaged |X|^2, DC skipped
    f  = (1:nH)' * fsEff / L;
    psd = 2*P2 / (fsEff * sum(w.^2));
    amp = 2*sqrt(P2) / sum(w);
    if mod(L,2) == 0, psd(end) = psd(end)/2;  amp(end) = amp(end)/2; end
    out.method = 'fft';  out.nseg = K;
    out.dof = 2*K;   % approximate for overlapping segments (conservative)
    out.rayleigh = fsEff / L;                  % actual bin resolution
else
    % --------------------- Lomb-Scargle periodogram ---------------------
    if customF
        f = sort(double(opts.Frequencies(:)));
    else
        df   = 1/(opts.Oversample * Tspan);
        fmax = 0.5 / dtNyq;
        if ~isempty(opts.MaxFreq), fmax = min(fmax, opts.MaxFreq); end
        f = (df:df:fmax)';
        if isempty(f)
            error('timeSeriesPreparation:powerSpectrum:emptyGrid', ...
                '"%s": empty frequency grid.', ser.label);
        end
    end
    if strcmpi(opts.LombMethod,'gls')
        A2 = lombGLS(t, x, f);                 % fitted sinusoid amplitude^2
    else
        P  = lombClassic(t, x, f);
        A2 = 4*P/N;
    end
    P   = N*A2/4;                              % classical-equivalent power
    psd = 2*P / fsEff;
    amp = sqrt(A2);
    out.method = 'lomb-scargle';  out.nseg = 1;  out.dof = 2;

    % FAP significance levels
    if ~isempty(opts.FAP) && N > 5
        fap = sort(opts.FAP(:),'descend');
        if strcmpi(opts.FAPMethod,'bootstrap')
            % Permutation bootstrap: shuffle x over the fixed sampling
            % times (white-noise null hypothesis), record the maximum
            % periodogram value over the *searched* grid per realization.
            B = round(opts.NBootstrap);
            if min(fap)*B < 10
                warning('timeSeriesPreparation:powerSpectrum:fapResolution', ...
                    ['"%s": NBootstrap = %d gives < 10 exceedances for ' ...
                     'FAP = %g; level is noisy. Increase NBootstrap.'], ...
                    ser.label, B, min(fap));
            end
            mx = zeros(B,1);
            for bb = 1:B
                xb = x(randperm(N));
                if strcmpi(opts.LombMethod,'gls')
                    mx(bb) = max(lombGLS(t, xb, f));
                else
                    mx(bb) = max(4*lombClassic(t, xb, f)/N);
                end
            end
            A2L = quantileBase(mx, 1 - fap);
            fapMethod = 'bootstrap';
        else
            % Analytic approximation, M independent frequencies ~ T*df
            M  = max(round(Tspan * (f(end)-f(1))), 1);
            pnL = 1 - (1 - (1 - fap).^(1/M)).^(2/(N-3));
            pnL = min(max(pnL,0), 1-1e-12);
            A2L = 2*varx*pnL;                  % pn -> sinusoid amplitude^2
            fapMethod = 'analytic';
        end
        out.fapLevels = struct('fap',fap, 'method',fapMethod, ...
            'psd', 2*(N*A2L/4)/fsEff, 'amp', sqrt(A2L));
    end

    % Spectral window of the sampling pattern (normalized, |W(0)|^2 = 1)
    out.spectralWindow = spectralWindow(t, f);
end

if ~customF && ~isempty(opts.MaxFreq)
    keep = f <= opts.MaxFreq;
    f = f(keep); psd = psd(keep); amp = amp(keep);
    if ~isempty(out.spectralWindow), out.spectralWindow = out.spectralWindow(keep); end
end
out.frequency = f;  out.power = psd;  out.amplitude = amp;
end

% ========================================================================
function [A2, pn] = lombGLS(t, x, f)
% Generalized (floating-mean) Lomb-Scargle, unweighted
% (Zechmeister & Kuerster 2009). Returns fitted sinusoid amplitude^2 and
% normalized power pn = fraction of variance explained, chunk-vectorised.
N = numel(t);
A2 = zeros(size(f));  pn = zeros(size(f));
Ybar = mean(x);  YY = mean(x.^2) - Ybar^2;  YY = max(YY, eps);
chunk = max(1, floor(4e6 / N));
for i0 = 1:chunk:numel(f)
    idx = i0:min(i0+chunk-1, numel(f));
    th  = t * (2*pi*f(idx)');                 % N x m
    c = cos(th);  s = sin(th);
    C  = mean(c,1);          S  = mean(s,1);
    YC = (x'*c)/N - Ybar*C;  YS = (x'*s)/N - Ybar*S;
    CC = mean(c.^2,1) - C.^2;
    SS = mean(s.^2,1) - S.^2;
    CS = mean(c.*s,1) - C.*S;
    D  = CC.*SS - CS.^2;  D(abs(D) < eps) = eps;
    a  = (YC.*SS - YS.*CS)./D;
    b  = (YS.*CC - YC.*CS)./D;
    A2(idx) = a.^2 + b.^2;
    pn(idx) = (SS.*YC.^2 + CC.*YS.^2 - 2*CS.*YC.*YS) ./ (YY*D);
end
pn = min(max(pn,0),1);
end

% ========================================================================
function P = lombClassic(t, x, f)
% Classical Lomb-Scargle periodogram (fixed mean), chunk-vectorised.
N = numel(t);  x = x - mean(x);  P = zeros(size(f));
chunk = max(1, floor(4e6 / N));
for i0 = 1:chunk:numel(f)
    idx = i0:min(i0+chunk-1, numel(f));
    w   = 2*pi*f(idx)';
    wt  = t * w;
    tau = atan2(sum(sin(2*wt),1), sum(cos(2*wt),1)) ./ (2*w);
    arg = wt - ones(N,1)*(w.*tau);
    C = cos(arg);  S = sin(arg);
    xC = x' * C;   xS = x' * S;
    CC = sum(C.^2,1);  SS = sum(S.^2,1);
    CC(CC < eps) = eps;  SS(SS < eps) = eps;
    P(idx) = 0.5*(xC.^2 ./ CC + xS.^2 ./ SS);
end
end

% ========================================================================
function W = spectralWindow(t, f)
% Normalized spectral window |W(f)|^2 of the sampling pattern.
N = numel(t);  W = zeros(size(f));
chunk = max(1, floor(4e6 / N));
for i0 = 1:chunk:numel(f)
    idx = i0:min(i0+chunk-1, numel(f));
    th  = t * (2*pi*f(idx)');
    W(idx) = (sum(cos(th),1).^2 + sum(sin(th),1).^2) / N^2;
end
end

% ========================================================================
function [pf, pa] = topPeaks(f, y, nPk, minDist)
% N highest distinct local maxima (greedy min-distance selection) with
% 3-point parabolic sub-bin refinement.
y = y(:); f = f(:);
i = find(y(2:end-1) > y(1:end-2) & y(2:end-1) >= y(3:end)) + 1;
if isempty(i), pf = []; pa = []; return; end
[~, order] = sort(y(i), 'descend');
i = i(order);
sel = [];
for k = 1:numel(i)
    if isempty(sel) || all(abs(f(i(k)) - f(sel)) >= minDist)
        sel(end+1) = i(k); %#ok<AGROW>
        if numel(sel) == nPk, break; end
    end
end
pf = zeros(numel(sel),1);  pa = zeros(numel(sel),1);
for k = 1:numel(sel)
    j = sel(k);
    y1 = y(j-1); y2 = y(j); y3 = y(j+1);
    den = y1 - 2*y2 + y3;
    if abs(den) > eps, d = max(min(0.5*(y1-y3)/den, 0.5), -0.5);
    else,              d = 0;
    end
    pf(k) = f(j) + d * 0.5*(f(j+1) - f(j-1));
    pa(k) = y2 - 0.25*(y1 - y3)*d;
end
end

% ========================================================================
function w = makeWindow(name, N, prm)
% Window generation in base MATLAB. Cosine-sum windows use the PERIODIC
% form (denominator N), preferable for spectral analysis.
n = (0:N-1)';  rp = n/N;  rs = n/(N-1);
switch lower(name)
    case 'hann'
        w = 0.5 - 0.5*cos(2*pi*rp);
    case 'hamming'
        w = 0.54 - 0.46*cos(2*pi*rp);
    case 'blackman'
        w = 0.42 - 0.5*cos(2*pi*rp) + 0.08*cos(4*pi*rp);
    case 'blackmanharris'                     % 4-term, -92 dB sidelobes
        a = [0.35875 0.48829 0.14128 0.01168];
        w = a(1) - a(2)*cos(2*pi*rp) + a(3)*cos(4*pi*rp) - a(4)*cos(6*pi*rp);
    case 'nuttall'
        a = [0.355768 0.487396 0.144232 0.012604];
        w = a(1) - a(2)*cos(2*pi*rp) + a(3)*cos(4*pi*rp) - a(4)*cos(6*pi*rp);
    case 'flattop'                            % minimal scalloping loss
        a = [0.21557895 0.41663158 0.277263158 0.083578947 0.006947368];
        w = a(1) - a(2)*cos(2*pi*rp) + a(3)*cos(4*pi*rp) ...
                 - a(4)*cos(6*pi*rp) + a(5)*cos(8*pi*rp);
    case 'kaiser'                             % prm = beta (default 8.6)
        if isempty(prm), prm = 8.6; end
        w = besseli(0, prm*sqrt(1 - (2*rs - 1).^2)) / besseli(0, prm);
    case 'tukey'                              % prm = taper ratio (0.5)
        if isempty(prm), prm = 0.5; end
        prm = max(min(prm,1),0);
        w = ones(N,1);
        if prm > 0
            L = floor(prm*(N-1)/2);  k = (0:L)';
            taper = 0.5*(1 + cos(pi*(2*k/(prm*(N-1)) - 1)));
            w(1:L+1) = taper;  w(end-L:end) = flipud(taper);
        end
    case 'gauss'                              % prm = sigma (default 0.4)
        if isempty(prm), prm = 0.4; end
        w = exp(-0.5*((2*rs - 1)/prm).^2);
    case 'bartlett'
        w = 1 - abs(2*rs - 1);
    otherwise                                 % 'rect'/'rectangular'/'none'
        w = ones(N,1);
end
end

% ========================================================================
function q = quantileBase(v, p)
% Sample quantiles with linear interpolation (base MATLAB; quantile()
% belongs to the Statistics Toolbox). Matches MATLAB's default method.
v = sort(v(:));  n = numel(v);  p = p(:);
pos = p*n + 0.5;                              % MATLAB quantile convention
lo  = max(floor(pos), 1);  hi = min(lo+1, n);
w   = pos - lo;  w = min(max(w,0),1);
q   = (1-w).*v(lo) + w.*v(hi);
end

% ========================================================================
function mustBeOneOf(value, allowed)
% Case-insensitive membership, as v1.3.1's strcmpi validators.
    if ~any(strcmpi(value, allowed))
        error("timeSeriesPreparation:powerSpectrum:badOption", ...
            "Value must be one of: %s.", strjoin(allowed, ", "));
    end
end

function mustBeFrequencies(f)
% Empty, or a vector of positive frequencies (v1.3.1's rule).
    if ~isempty(f) && ~(isvector(f) && all(f > 0))
        error("timeSeriesPreparation:powerSpectrum:badOption", ...
            "Frequencies must be a vector of positive values.");
    end
end
