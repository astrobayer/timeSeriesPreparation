function [R, lags, info] = spec2acv(f, S, opts)
%SPEC2ACV  One- or two-sided PSD/ASD to auto-covariance / -correlation.
%
%   SYNTAX
%     [R, lags] = timeSeriesPreparation.spectral.spec2acv(f, S)
%     [R, lags, info] = timeSeriesPreparation.spectral.spec2acv(f, S, Method = "direct", Lags = (0:10)'/100, Window = "tukey")
%
%   DESCRIPTION
%     Transforms a spectral density S on the frequency grid f into the
%     auto-covariance R(tau) through the Wiener-Khinchin theorem,
%     R(tau) = integral_0^fNyq S(f) cos(2 pi f tau) df for a one-sided PSD.
%     Measured spectra rarely sit on a uniform grid: non-uniform, offset,
%     unsorted or log-spaced grids are sorted, duplicates averaged, and
%     the spectrum resampled (pchip, in linear or log-log space) onto a
%     uniform DC-aligned grid; below the lowest frequency S is zero-padded
%     and above the highest it is taken as zero. Both methods use the
%     trapezoidal rule with half weight at DC and Nyquist, so with
%     Window "none" and Smooth "none" R(0) equals trapz(f,S) exactly, and
%     "ifft" and "direct" agree to rounding. "ifft" is fast with the fixed
%     lag step dt = 1/(2 fNyq); "direct" evaluates arbitrary Lags with
%     NUFFT when available (R2020a+), otherwise with an O(N L) cosine
%     matrix. Optional spectral smoothing (fixed-width kernels, or
%     constant-relative-bandwidth "octave" smoothing for wideband ASDs)
%     and a spectral taper w(f), w(0) = 1, limit ringing. With DOF (the
%     chi-square degrees of freedom of the PSD estimate, e.g. about 2 nAvg
%     for Welch) the 1-sigma uncertainty of R is propagated to info.Rstd,
%     including the variance reduction of the smoothing. Single and
%     gpuArray inputs are preserved.
%
%   INPUTS
%     f  (M,1) double   Hz   Frequency grid, real; any order or spacing;
%                            negative entries only with Sided "two";
%                            M >= 3.
%     S  (M,1) double   -    PSD (unit^2/Hz) or ASD (unit/sqrt(Hz), with
%                            InputType "asd") on f.
%
%   OPTIONS
%     InputType      (1,1) string   ["psd"]      "psd" or "asd" (squared
%                                                first).
%     Sided          (1,1) string   ["one"]      "one" or "two"; "two"
%                                                folds G(f) = S2(f) +
%                                                S2(-f).
%     Output         (1,1) string   ["acv"]      "acv" or "acf" (R/R(0)).
%     Method         (1,1) string   ["ifft"]     "ifft" or "direct".
%     Lags           (L,1) double   [[]]         Lags in s, >= 0, "direct"
%                                                only; [] = the "ifft"
%                                                grid.
%     InterpFactor   (1,1) double   [1]          Integer >= 1; refines df
%                                                to df/K and extends the
%                                                longest lag K-fold.
%     MaxBins        (1,1) double   [2^20]       Cap on the uniform grid;
%                                                df is coarsened (warning)
%                                                beyond it.
%     ResampleSpace  (1,1) string   ["auto"]     "auto", "linear" or
%                                                "loglog"; "auto" takes
%                                                "loglog" for log-spaced,
%                                                positive spectra.
%     Window         (1,1) string   ["none"]     "none", "cosine", "hann",
%                                                "hamming", "blackman",
%                                                "gauss", "tukey", "exp".
%     WindowParam    (1,1) double   [NaN]        gauss: alpha (sigma =
%                                                fNyq/alpha), 2.5; tukey:
%                                                ratio in [0,1], 0.5; exp:
%                                                decay k, 3.
%     Smooth         (1,1) string   ["none"]     "none", "boxcar",
%                                                "triangle", "cosine",
%                                                "hann", "gauss", "octave".
%     SmoothWidth    (1,1) double   [Inf]        Kernels: full width in Hz
%                                                (gauss: +/-3 sigma), Inf =
%                                                10 df; "octave": width in
%                                                octaves, Inf = 1/3.
%     DOF            (1,1) double   [NaN]        Degrees of freedom of the
%                                                PSD estimate, > 0; NaN =
%                                                no uncertainty.
%     NanPolicy      (1,1) string   ["interp"]   Non-finite bins: "interp"
%                                                (pchip), "zero" or
%                                                "error".
%     GridTol        (1,1) double   [1e-6]       Relative tolerance for
%                                                accepting a grid as
%                                                uniform and DC-aligned.
%
%   OUTPUTS
%     R     (L,1) double   -    Auto-covariance (unit^2) or
%                               auto-correlation; class of S.
%     lags  (L,1) double   s    Lag axis, from 0 for the default grid.
%     info  (1,1) struct   -    Fields: df, dt, N, resampled,
%                               resampleSpace, nBadBins; varIn (trapz of
%                               the input PSD); varOut (R(0) after
%                               smoothing and taper); windowLoss, 1 -
%                               varOut/varIn; integralTimescale,
%                               trapz(lags,R)/R(0), s; firstZero and
%                               tauDecorr, first crossing of 0 and 1/e, s
%                               (NaN if none); Rstd (L,1), [] unless DOF
%                               (for "acf" normalised by R(0), neglecting
%                               the R(0) uncertainty).
%
%   ACCURACY
%     With Window "none" and Smooth "none", R(0) equals trapz(f,S) exactly
%     and "ifft" and "direct" agree to rounding error (original help).
%     The "direct" R(0) is NUFFT-accurate, about 1e-12, and arma2acv equals
%     spec2acv(arma2psd(...)) at integer lags to about 1e-15 on a fine grid
%     (sigtools HANDOFF sections 3 and 3a). Resampling and zero-padding add
%     the interpolation error of the input grid. Unchanged from sigtools
%     v1.3.1; TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:spec2acv:sizeMismatch - f and S differ in
%           length.
%       timeSeriesPreparation:spec2acv:tooShort - fewer than 3 points.
%       timeSeriesPreparation:spec2acv:negFreq - negative frequencies with
%           Sided "one".
%       timeSeriesPreparation:spec2acv:badBins - NanPolicy "error" and
%           non-finite bins, or fewer than 2 valid bins to interpolate.
%     Options:
%       timeSeriesPreparation:spec2acv:lagsNeedDirect - Lags given without
%           Method "direct".
%       timeSeriesPreparation:spec2acv:badDOF - DOF is not positive.
%       Other options outside their domain are refused by the arguments
%       block (case-sensitive values), and a non-positive gauss or exp
%       WindowParam by validateattributes, with a MATLAB: identifier.
%     Normalisation:
%       timeSeriesPreparation:spec2acv:zeroVariance - Output "acf" with
%           R(0) <= 0.
%
%   WARNINGS
%     Input:
%       timeSeriesPreparation:spec2acv:complexS - S has a significant
%           imaginary part; abs(S) is used.
%       timeSeriesPreparation:spec2acv:negS - negative bins clipped to 0.
%     Grid and taper:
%       timeSeriesPreparation:spec2acv:maxBins - the grid would exceed
%           MaxBins; df is coarsened.
%       timeSeriesPreparation:spec2acv:notDecayed - S at Nyquist is above
%           1 % of its maximum and no taper is applied (ringing).
%       timeSeriesPreparation:spec2acv:tukeyClamp - Tukey ratio outside
%           [0,1] is clamped.
%     Uncertainty:
%       timeSeriesPreparation:spec2acv:ciSkipped - Rstd skipped: transform
%           too large and no NUFFT available.
%
%   EXAMPLE
%     % Auto-correlation of a 4th-order low-pass PSD, with uncertainty.
%     fs = 1000; f = (0:0.5:fs/2)';
%     S  = 1./(1 + (f/50).^4);
%     [R, tau, nfo] = timeSeriesPreparation.spectral.spec2acv(f, S, Window = "tukey", Smooth = "octave", SmoothWidth = 1/6, DOF = 32, Output = "acf");
%
%   LIMITATIONS
%     The spectrum is assumed zero outside the given band, so an
%     undersampled low-frequency end biases long lags and R(0). Text
%     options are case-sensitive (v1.3.1). The uncertainty assumes
%     independent chi-square bins before smoothing.
%
%   REFERENCES
%     N. Wiener (1930), Acta Math. 55, 117-258; A. Khintchine (1934), Math.
%     Ann. 109, 604-615 (Wiener-Khinchin theorem). J. S. Bendat,
%     A. G. Piersol (2010), Random Data, 4th ed., Wiley (spectral
%     uncertainty). sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.arma2acv, timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.powerSpectrum.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    f (:,1) {mustBeNumeric, mustBeReal}
    S (:,1) {mustBeNumeric}
    opts.InputType     (1,1) string {mustBeMember(opts.InputType, ["psd","asd"])} = "psd"
    opts.Sided         (1,1) string {mustBeMember(opts.Sided, ["one","two"])} = "one"
    opts.Output        (1,1) string {mustBeMember(opts.Output, ["acv","acf"])} = "acv"
    opts.Method        (1,1) string {mustBeMember(opts.Method, ["ifft","direct"])} = "ifft"
    opts.Lags          (:,1) {mustBeNumeric, mustBeReal, mustBeNonnegative} = []
    opts.InterpFactor  (1,1) {mustBeInteger, mustBePositive} = 1
    opts.MaxBins       (1,1) {mustBeInteger, mustBePositive} = 2^20
    opts.ResampleSpace (1,1) string {mustBeMember(opts.ResampleSpace, ["auto","linear","loglog"])} = "auto"
    opts.Window        (1,1) string {mustBeMember(opts.Window, ...
                       ["none","cosine","hann","hamming","blackman","gauss","tukey","exp"])} = "none"
    opts.WindowParam   (1,1) {mustBeNumeric, mustBeReal} = NaN
    opts.Smooth        (1,1) string {mustBeMember(opts.Smooth, ...
                       ["none","boxcar","triangle","cosine","hann","gauss","octave"])} = "none"
    opts.SmoothWidth   (1,1) {mustBeNumeric, mustBeReal, mustBePositive} = Inf
    opts.DOF           (1,1) {mustBeNumeric, mustBeReal} = NaN
    opts.NanPolicy     (1,1) string {mustBeMember(opts.NanPolicy, ["interp","zero","error"])} = "interp"
    opts.GridTol       (1,1) {mustBeNumeric, mustBeReal, mustBePositive} = 1e-6
end

%% ---- Basic validation --------------------------------------------------
if numel(f) ~= numel(S)
    error("timeSeriesPreparation:spec2acv:sizeMismatch", "f and S must have the same length.");
end
if numel(f) < 3
    error("timeSeriesPreparation:spec2acv:tooShort", "Need at least 3 spectral points.");
end
if ~isempty(opts.Lags) && opts.Method ~= "direct"
    error("timeSeriesPreparation:spec2acv:lagsNeedDirect", "'Lags' requires Method=""direct"".");
end
if opts.Sided == "one" && any(f < 0)
    error("timeSeriesPreparation:spec2acv:negFreq", ...
        "Negative frequencies found; use Sided=""two"" for two-sided spectra.");
end
if ~isnan(opts.DOF) && ~(opts.DOF > 0)
    error("timeSeriesPreparation:spec2acv:badDOF", "DOF must be positive.");
end
if ~isreal(S)
    if max(abs(imag(S))) > 1e-9*max(abs(S))
        warning("timeSeriesPreparation:spec2acv:complexS", ...
            "S is complex; using abs(S). A PSD/ASD should be real.");
    end
    S = abs(S);
end
if isinteger(S), S = double(S); end        % single / gpuArray pass through
if isinteger(f), f = double(f); end

%% ---- Sort, deduplicate -------------------------------------------------
[f, iSrt] = sort(f);
S = S(iSrt);
if any(diff(f) == 0)
    [f, ~, ic] = unique(f);
    S = accumarray(ic, S, [], @mean);
end

%% ---- Fold two-sided spectra --------------------------------------------
if opts.Sided == "two"
    ip = f >= 0;
    fp = f(ip);  Sp = S(ip);
    fn = -flipud(f(~ip));  Sn = flipud(S(~ip));   % ascending |f| of neg branch
    if isempty(fp) || fp(1) > 0                    % ensure a DC bin exists
        fp = [0; fp];  Sp = [zeros(1, "like", S); Sp];
    end
    add = zeros(size(fp), "like", S);
    if ~isempty(fn)
        pos = fp > 0;
        add(pos) = interp1(fn, Sn, fp(pos), "linear", 0);
    end
    add(fp == 0) = Sp(fp == 0);            % S2(-0) = S2(+0): fold doubles DC
    f = fp;  S = Sp + add;
end

%% ---- Repair bad bins (NaN/Inf/negative) --------------------------------
bad = ~isfinite(S);
info.nBadBins = nnz(bad);
if any(bad)
    switch opts.NanPolicy
        case "error"
            error("timeSeriesPreparation:spec2acv:badBins", "%d non-finite bins in S.", nnz(bad));
        case "zero"
            S(bad) = 0;
        case "interp"
            if nnz(~bad) < 2
                error("timeSeriesPreparation:spec2acv:badBins", "Too few valid bins to interpolate.");
            end
            S(bad) = interp1(f(~bad), S(~bad), f(bad), "pchip", 0);
    end
end
if any(S < 0)
    tol = 1e-9 * max(S);
    if any(S < -tol)
        warning("timeSeriesPreparation:spec2acv:negS", ...
            "%d negative bins in S clipped to zero.", nnz(S < -tol));
    end
    S = max(S, 0);
end

%% ---- ASD -> PSD (so all interpolation happens in power) ----------------
if opts.InputType == "asd"
    S = S.^2;
end

%% ---- Resample onto a uniform, DC-aligned grid --------------------------
d      = diff(f);
dfHat  = median(d);
isUnif = all(abs(d - dfHat) <= opts.GridTol * dfHat);
isAlgn = abs(f(1) - round(f(1)/dfHat)*dfHat) <= opts.GridTol * dfHat;
info.resampleSpace = "none";

if isUnif && isAlgn && opts.InterpFactor == 1 && numel(f) + round(f(1)/dfHat) <= opts.MaxBins
    df = dfHat;
    if f(1) > df/2
        nPad = round(f(1)/df);
        S = [zeros(nPad, 1, "like", S); S];
        f = [(0:nPad-1)'*df; f];
    end
    info.resampled = false;
else
    df = min(d(d > 0)) / opts.InterpFactor;
    if ceil(f(end)/df) + 1 > opts.MaxBins
        df = f(end) / (opts.MaxBins - 1);
        warning("timeSeriesPreparation:spec2acv:maxBins", ...
            "Requested grid exceeds MaxBins = %d; df coarsened to %.3g Hz.", ...
            opts.MaxBins, df);
    end
    % choose interpolation space
    space = opts.ResampleSpace;
    fpos  = f(f > 0);
    if space == "auto"
        rlog = diff(log(fpos));
        logSpaced = numel(fpos) > 4 && std(rlog)/mean(rlog) < 0.2;
        mostlyPos = mean(S > 0) > 0.9;
        space = "linear"; if logSpaced && mostlyPos, space = "loglog"; end
    end
    fu = (0:ceil(f(end)/df))' * df;
    Su = zeros(numel(fu), 1, "like", S);
    in = fu >= f(1) & fu <= f(end);
    if space == "loglog"
        ok = f > 0 & S > 0;
        if nnz(ok) < 4
            space = "linear";
        else
            inp = in & fu > 0;
            Su(inp) = exp(interp1(log(f(ok)), log(S(ok)), log(fu(inp)), "pchip"));
            if in(1) && fu(1) == 0 && f(1) == 0, Su(1) = S(1); end
        end
    end
    if space == "linear"
        Su(in) = max(interp1(f, S, fu(in), "pchip"), 0);
    end
    f = fu;  S = Su;
    info.resampled = true;
    info.resampleSpace = space;
end
N = numel(S);
info.df = df;  info.N = N;
info.varIn = trapz(f, S);

%% ---- Smooth the spectrum ------------------------------------------------
dofGain = ones(N, 1, "like", S);           % variance-reduction factor per bin
switch opts.Smooth
    case "none"
        % nothing
    case "octave"
        w = opts.SmoothWidth; if isinf(w), w = 1/3; end
        [S, dofGain] = smoothOctave(S, w, N);
    otherwise
        [S, g] = smoothKernel(S, opts.Smooth, opts.SmoothWidth, df);
        dofGain(:) = g;
end

%% ---- Spectral taper -----------------------------------------------------
if opts.Window ~= "none"
    S = S .* taper(f/f(end), opts.Window, opts.WindowParam);
elseif S(end) > 0.01 * max(S)
    warning("timeSeriesPreparation:spec2acv:notDecayed", ...
        ['Spectrum has not decayed at Nyquist (S(fNyq) = %.1f%% of max); ' ...
         'expect ringing in the ACV. Consider a taper, e.g. Window="tukey".'], ...
        100*S(end)/max(S));
end

%% ---- Transform ----------------------------------------------------------
wTrap = ones(N, 1, "like", S);  wTrap([1 N]) = 0.5;
useNufft = ~isempty(which("nufft"));

switch opts.Method
    case "ifft"
        % Trapezoidal half-weight at DC and Nyquist: identical quadrature
        % to Method="direct", and R(0) == trapz(f,S) exactly.
        S2 = [S(1); S(2:N-1); S(N); flipud(S(2:N-1))] / 2;
        M  = numel(S2);                     % = 2*(N-1)
        R  = M * df * ifft(S2, "symmetric");
        R  = R(1:N);
        lags = (0:N-1)' / (M*df);
    case "direct"
        if isempty(opts.Lags)
            M    = 2*(N-1);
            lags = (0:N-1)' / (M*df);
        else
            lags = opts.Lags;
        end
        R = cosTransform(wTrap .* S, f, lags, df, useNufft);
end

if numel(lags) > 1, info.dt = median(diff(lags)); else, info.dt = NaN; end
info.varOut     = df * (wTrap' * S);
info.windowLoss = 1 - info.varOut / max(info.varIn, realmin);

%% ---- Derived time scales (require lag grid starting at 0) ---------------
info.integralTimescale = NaN; info.firstZero = NaN; info.tauDecorr = NaN;
if numel(lags) > 2 && lags(1) == 0 && all(diff(lags) > 0) && info.varOut > 0
    rho = R / info.varOut;
    info.integralTimescale = trapz(lags, R) / info.varOut;
    info.firstZero = firstCrossing(lags, rho, 0);
    info.tauDecorr = firstCrossing(lags, rho, exp(-1));
end

%% ---- Uncertainty propagation (chi-squared PSD model) ---------------------
info.Rstd = [];
if ~isnan(opts.DOF)
    sig2 = 2 * S.^2 ./ (opts.DOF * dofGain);        % var of smoothed+tapered S
    a    = (wTrap.^2) .* sig2;
    % var R(tau) = df^2 * sum a*cos^2 = df^2*(sum(a) + C2(tau))/2,
    % with C2 = sum a*cos(2*pi*(2f)*tau)
    C2 = cosTransform(a, 2*f, lags, 1, useNufft);   % df=1: raw sum
    if ~isempty(C2)
        info.Rstd = df * sqrt(max((sum(a) + C2)/2, 0));
    else
        warning("timeSeriesPreparation:spec2acv:ciSkipped", ...
            "Rstd skipped: transform too large and no NUFFT available.");
    end
end

%% ---- Normalize if autocorrelation requested ------------------------------
if opts.Output == "acf"
    R0 = info.varOut;
    if ~(R0 > 0)
        error("timeSeriesPreparation:spec2acv:zeroVariance", "R(0) <= 0; cannot normalize.");
    end
    R = R / R0;
    if ~isempty(info.Rstd), info.Rstd = info.Rstd / R0; end
end
end

% ==========================================================================
function R = cosTransform(x, f, lags, df, useNufft)
% R(tau_l) = df * sum_j x_j * cos(2*pi*f_j*tau_l), via NUFFT or matrix.
% Returns [] if the matrix would be too large and NUFFT is unavailable.
if useNufft
    try
        R = df * real(nufft(x, f, lags));
        return
    catch
        % fall through to matrix path (e.g. unsupported type)
    end
end
if numel(x) * numel(lags) > 5e7
    R = [];
    return
end
R = df * (cos(2*pi*lags*f') * x);
end

% ==========================================================================
function tau0 = firstCrossing(lags, rho, level)
% First downward crossing of rho through 'level', linearly interpolated.
idx = find(rho(2:end) <= level & rho(1:end-1) > level, 1) + 1;
if isempty(idx)
    tau0 = NaN;
else
    r1 = rho(idx-1); r2 = rho(idx);
    tau0 = lags(idx-1) + (r1 - level)/(r1 - r2) * (lags(idx) - lags(idx-1));
    tau0 = double(gather(tau0));
end
end

% ==========================================================================
function w = taper(x, name, p)
% x in [0,1] = f/fNyq. All tapers: w(0) = 1, roll-off towards Nyquist.
switch name
    case {"cosine","hann"}
        w = 0.5*(1 + cos(pi*x));
    case "hamming"
        w = 0.54 + 0.46*cos(pi*x);
    case "blackman"
        w = 0.42 + 0.5*cos(pi*x) + 0.08*cos(2*pi*x);
    case "gauss"
        if isnan(p), p = 2.5; end
        validateattributes(p, "numeric", "positive", "", "WindowParam");
        w = exp(-0.5*(p*x).^2);
    case "tukey"
        if isnan(p), p = 0.5; end
        if p < 0 || p > 1
            warning("timeSeriesPreparation:spec2acv:tukeyClamp", "Tukey ratio clamped to [0,1].");
            p = min(max(p, 0), 1);
        end
        w = ones(size(x));
        if p > 0
            idx = x > 1 - p;
            w(idx) = 0.5*(1 + cos(pi*(x(idx) - (1-p))/p));
        end
    case "exp"
        if isnan(p), p = 3; end
        validateattributes(p, "numeric", "positive", "", "WindowParam");
        w = exp(-p*x);
end
end

% ==========================================================================
function [S, g] = smoothKernel(S, name, widthHz, df)
% Fixed-width kernel convolution; edge renormalization preserves power.
% g = variance-reduction factor of the kernel (per-bin DOF multiplier).
if isinf(widthHz), widthHz = 10*df; end
n = max(1, round(widthHz/df/2));
x = (-n:n)'/max(n, 1);
switch name
    case "boxcar",           k = ones(size(x));
    case "triangle",         k = 1 - abs(x);
    case {"cosine","hann"},  k = 0.5*(1 + cos(pi*x));
    case "gauss",            k = exp(-0.5*(3*x).^2);
end
k = k / sum(k);
g = 1 / sum(k.^2);
S = conv(S, k, "same") ./ conv(ones(size(S), "like", S), k, "same");
end

% ==========================================================================
function [S, g] = smoothOctave(S, wOct, N)
% Constant-relative-bandwidth (boxcar) smoothing: each bin i > 1 is the
% mean over f in [f_i*2^(-w/2), f_i*2^(w/2)]. O(N) via cumulative sums.
% The DC bin is left untouched. g = window length in bins.
g  = ones(N, 1, "like", S);
cs = [zeros(1, "like", S); cumsum(S)];
i  = (2:N)';                                % bin index, f_i = (i-1)*df
lo = max(2, ceil((i-1)*2^(-wOct/2)*(1 - 1e-12)) + 1);
hi = min(N, floor((i-1)*2^( wOct/2)*(1 + 1e-12)) + 1);
hi = max(hi, lo);
n  = hi - lo + 1;
S(i) = (cs(hi+1) - cs(lo)) ./ n;
g(i) = n;
end
