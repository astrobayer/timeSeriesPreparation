function [b, a, results] = psd2arma(f, S, Fs, opts)
%PSD2ARMA  Fit a discrete-time ARMA (IIR) process to a target PSD or ASD.
%
%   SYNTAX
%     [b, a] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs)
%     [b, a, results] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, Order = [8 8], InputType = "asd")
%
%   DESCRIPTION
%     Finds B(z)/A(z) such that x[n] = filter(b, a, w[n]), with w white of
%     variance NoiseVariance, has the target one-sided PSD S(f) of a process
%     sampled at Fs. The scaling is sigtools' S(f) = (2 sigma_w^2/Fs)
%     |H(f)|^2, the same as arma2psd, so the two are inverses. Steps:
%       1. S is interpolated (log-log, InterpMethod) onto NFFT+1 uniform
%          points from 0 to Fs/2, floored at 1e-12 of its peak.
%       2. A minimum-phase complex response with that magnitude is built by
%          the real-cepstrum (Hilbert) method. A complex target conditions
%          the rational fit far better than a magnitude-only one.
%       3. B/A is fitted with sinvfreqz (Sanathanan-Koerner, "invfreqz") or
%          sstmcb (Steiglitz-McBride on the impulse response, "stmcb").
%       4. Optionally, poles and zeros outside the unit circle are
%          reflected inside, and the gain is corrected in the log
%          least-squares sense.
%       5. With Order "auto", na = nb = 1..MaxOrder is swept. It keeps the
%          first order within Tol dB RMS ("tol") or the smallest AIC-like
%          value ("aic").
%     Base MATLAB only. Since X-02 the function no longer draws;
%     plotPsd2armaFit draws results (owner decision 2026-09-23, clean
%     break; its Display option is gone). The numbers are v1.3.1's.
%
%   INPUTS
%     f   (M,1) double   Hz   Frequencies of the target, finite; points
%                             outside [0, Fs/2] are dropped with a warning.
%     S   (M,1) double   -    Target PSD (unit^2/Hz) or ASD (unit/sqrt(Hz)),
%                             finite, >= 0.
%     Fs  (1,1) double   Hz   Sampling rate of the modelled process, > 0.
%
%   OPTIONS
%     InputType             (1,1) string   ["psd"]       "psd" or "asd".
%     Sided                 (1,1) string   ["one"]       "one" or "two"
%                                                        (two-sided S is
%                                                        doubled).
%     Order                 (1,:) double   ["auto"]      [na nb], or "auto"
%                                                        for the sweep.
%     MaxOrder              (1,1) double   [30]          Largest order of the
%                                                        sweep.
%     OrderCriterion        (1,1) string   ["tol"]       "tol" or "aic".
%     Tol                   (1,1) double   [0.5]         Target RMS fit error
%                                                        in dB ("tol").
%     NFFT                  (1,1) double   [2048]        Size of the uniform
%                                                        grid.
%     InterpMethod          (1,1) string   ["pchip"]     interp1 method of
%                                                        the log-log
%                                                        interpolation.
%     NoiseVariance         (1,1) double   [1]           Variance of the
%                                                        driving noise.
%     EnforceStability      (1,1) logical  [true]        Reflect unstable
%                                                        poles.
%     EnforceMinPhaseZeros  (1,1) logical  [true]        Reflect zeros
%                                                        outside the circle.
%     Method                (1,1) string   ["invfreqz"]  "invfreqz" or
%                                                        "stmcb".
%     MaxIter               (1,1) double   [30]          Iterations of the
%                                                        SK or SM
%                                                        refinement.
%
%   OUTPUTS
%     b        (1,nb+1) double   -   Numerator (MA) coefficients.
%     a        (1,na+1) double   -   Denominator (AR) coefficients, a(1) = 1.
%     results  (1,1) struct      -   Fields: b, a, Fs, NoiseVariance; fGrid
%                                    (NFFT+1,1) Hz; PSDtarget and PSDfit
%                                    (NFFT+1,1); RMSErrorDb, MaxErrorDb;
%                                    OrderInfo (na, nb, searched, rmsErrDb,
%                                    aic); Poles, Zeros; IsStable,
%                                    IsMinPhaseZeros.
%
%   ACCURACY
%     results.RMSErrorDb and MaxErrorDb measure the achieved fit on the
%     grid. For known ARMA targets, sinvfreqz recovers the generating
%     filter to about 1e-15, and a smooth 4th-order low-pass is fitted to
%     0.0075 dB RMS (sigtools HANDOFF section 3, NumPy re-derivation).
%     The numbers are unchanged from v1.3.1, and TestSigtoolsEquivalence
%     holds them bit for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:psd2arma:sizeMismatch - f and S differ in
%           length.
%       timeSeriesPreparation:psd2arma:tooFewPoints - fewer than 2 points
%           lie within [0, Fs/2].
%       timeSeriesPreparation:psd2arma:zeroPSD - the target is identically
%           zero.
%     Fit:
%       timeSeriesPreparation:psd2arma:fitDiverged - the fit gave
%           non-finite coefficients.
%       timeSeriesPreparation:psd2arma:fitFailed - no order up to MaxOrder
%           could be fitted.
%
%   WARNINGS
%     Input:
%       timeSeriesPreparation:psd2arma:freqRange - frequencies outside
%           [0, Fs/2] were dropped.
%     Fit:
%       timeSeriesPreparation:psd2arma:toleranceNotMet - Tol not reached up
%           to MaxOrder; the best order found is returned.
%
%   EXAMPLE
%     % A 4th-order low-pass PSD, fitted with an ARMA(8,8).
%     f = logspace(-2, 2, 500)';
%     S = 1 ./ (1 + (f/5).^2).^2;
%     [b, a, res] = timeSeriesPreparation.spectral.psd2arma(f, S, 500, Order = [8 8]);
%
%   LIMITATIONS
%     The fit is to the log-log interpolated target, so structure between
%     the given frequencies is invented by InterpMethod. Very steep or
%     notched spectra need high orders. The "auto" sweep uses na = nb.
%
%   REFERENCES
%     C. K. Sanathanan, J. Koerner (1963), IEEE Trans. Autom. Control 8(1),
%     56-58. K. Steiglitz, L. E. McBride (1965), IEEE Trans. Autom. Control
%     10(4), 461-464. A. V. Oppenheim, R. W. Schafer (2010), Discrete-Time
%     Signal Processing, 3rd ed., section 13 (real cepstrum).
%
%   See also timeSeriesPreparation.spectral.plotPsd2armaFit, timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.spectral.sinvfreqz, timeSeriesPreparation.spectral.sstmcb.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    f (:,1) double {mustBeFinite}
    S (:,1) double {mustBeFinite, mustBeNonnegative}
    Fs (1,1) double {mustBePositive, mustBeFinite}
    opts.InputType (1,1) string {mustBeMember(opts.InputType, ["psd","asd"])} = "psd"
    opts.Sided (1,1) string {mustBeMember(opts.Sided, ["one","two"])} = "one"
    opts.Order = "auto"
    opts.MaxOrder (1,1) double {mustBePositive, mustBeInteger} = 30
    opts.OrderCriterion (1,1) string {mustBeMember(opts.OrderCriterion, ["tol","aic"])} = "tol"
    opts.Tol (1,1) double {mustBePositive} = 0.5
    opts.NFFT (1,1) double {mustBePositive, mustBeInteger} = 2048
    opts.InterpMethod (1,1) string = "pchip"
    opts.NoiseVariance (1,1) double {mustBePositive} = 1
    opts.EnforceStability (1,1) logical = true
    opts.EnforceMinPhaseZeros (1,1) logical = true
    opts.Method (1,1) string {mustBeMember(opts.Method, ["invfreqz","stmcb"])} = "invfreqz"
    opts.MaxIter (1,1) double {mustBePositive, mustBeInteger} = 30
end

%% ---- Input validation & housekeeping ----
if numel(f) ~= numel(S)
    error('timeSeriesPreparation:psd2arma:sizeMismatch', 'f and S must have the same number of elements.');
end

keep = f >= 0 & f <= Fs/2 + eps(Fs)*10;
if ~all(keep)
    warning('timeSeriesPreparation:psd2arma:freqRange', ...
        'Some frequencies lie outside [0, Fs/2]; they are being clipped.');
    f = f(keep); S = S(keep);
end
if numel(f) < 2
    error('timeSeriesPreparation:psd2arma:tooFewPoints', 'Need at least 2 valid (f,S) samples within [0, Fs/2].');
end

[f, ix] = sort(f);
S = S(ix);
[f, iu] = unique(f, 'stable');
S = S(iu);

% Convert ASD -> PSD if needed
if opts.InputType == "asd"
    S = S.^2;
end
% Convert two-sided -> one-sided convention used internally
if opts.Sided == "two"
    S = 2*S;
end

% Make sure the grid spans [0, Fs/2] (flat extrapolation at the edges)
if f(1) > 0
    f = [0; f]; S = [S(1); S];
end
% Tolerant Nyquist check: avoid appending a near-duplicate Fs/2 point
% (logspace endpoints can sit a rounding step below Fs/2), which would make
% the subsequent log-grid non-unique and break interp1 (R2026a is strict).
if f(end) < Fs/2 * (1 - 1e-9)
    f = [f; Fs/2]; S = [S; S(end)];
end
% Snap a within-tolerance final point exactly onto Fs/2.
if abs(f(end) - Fs/2) <= Fs/2 * 1e-9
    f(end) = Fs/2;
end

%% ---- Interpolate PSD onto a uniform grid (log-log) ----
Nfft = opts.NFFT;
fgrid = linspace(0, Fs/2, Nfft+1).';

posS = S(S > 0);
if isempty(posS)
    error('timeSeriesPreparation:psd2arma:zeroPSD', 'The target PSD/ASD is identically zero.');
end
floorS = max(posS) * 1e-12;              % numerical floor, -120 dB below peak
Sfl = max(S, floorS);

% Use a small positive surrogate for f=0 so log10 is defined; DC value is
% preserved via flat extrapolation.
fSurrogate = f;
fSurrogate(1) = f(2) / 100;
logf = log10(fSurrogate);
logS = log10(Sfl);

fgSurrogate = fgrid;
fgSurrogate(1) = fgrid(2) / 100;
logfg = log10(fgSurrogate);

logSgrid = interp1(logf, logS, logfg, opts.InterpMethod, 'extrap');
Sgrid = max(10.^logSgrid, floorS);

%% ---- Build target magnitude and minimum-phase complex response ----
% For x[n] = h[n]*w[n], w white with variance sigma_w^2, the one-sided
% PSD of x relates to the discrete-time frequency response by
%   S(f) = (2*sigma_w^2/Fs) * |H(f)|^2
% => |H(f)|^2 = S(f) * Fs / (2*sigma_w^2)
sigma_w2 = opts.NoiseVariance;
magSq = Sgrid * Fs / (2*sigma_w2);
mag = sqrt(magSq);

Hmin = local_minPhaseResponse(mag);

%% ---- Fit rational transfer function ----
w = pi * fgrid / (Fs/2);   % normalized angular frequency, 0..pi

if isstring(opts.Order) || ischar(opts.Order)
    [b, a, orderInfo] = local_autoSelectOrder(Hmin, w, opts);
else
    ord = opts.Order;
    na = ord(1); nb = ord(2);
    [b, a] = local_fitTF(Hmin, w, nb, na, opts);
    orderInfo = struct('na', na, 'nb', nb, 'searched', false);
end

if any(~isfinite(b)) || any(~isfinite(a))
    error('timeSeriesPreparation:psd2arma:fitDiverged', ...
        'The rational fit produced non-finite coefficients. Try a lower order, larger NFFT, or Method=''stmcb''.');
end

%% ---- Enforce stability / minimum-phase zeros ----
if opts.EnforceStability
    a = local_reflectRoots(a);
end
if opts.EnforceMinPhaseZeros
    b = local_reflectRoots(b);
end

%% ---- Gain correction (compensates any reflection / weighting bias) ----
Hfit0 = timeSeriesPreparation.spectral.sfreqz(b, a, w);
psdFit0 = (2*sigma_w2/Fs) * abs(Hfit0).^2;
logGain = mean(log(Sgrid ./ max(psdFit0, floorS))) / 2;   % optimal in log-LS sense
b = b * exp(logGain);

%% ---- Diagnostics ----
Hfit = timeSeriesPreparation.spectral.sfreqz(b, a, w);
psdFit = (2*sigma_w2/Fs) * abs(Hfit).^2;
errDb = 10*log10(max(psdFit, floorS) ./ Sgrid);
rmsErrDb = sqrt(mean(errDb.^2));
maxErrDb = max(abs(errDb));

results = struct();
results.b = b;
results.a = a;
results.Fs = Fs;
results.NoiseVariance = sigma_w2;
results.fGrid = fgrid;
results.PSDtarget = Sgrid;
results.PSDfit = psdFit;
results.RMSErrorDb = rmsErrDb;
results.MaxErrorDb = maxErrDb;
results.OrderInfo = orderInfo;
results.Poles = roots(a);
results.Zeros = roots(b);
results.IsStable = all(abs(results.Poles) < 1);
results.IsMinPhaseZeros = all(abs(results.Zeros) < 1);

end % psd2arma


%% ===================== Local functions =====================

function Hmin = local_minPhaseResponse(mag)
% Reconstruct a minimum-phase complex frequency response from a
% one-sided magnitude spectrum MAG (length N+1, DC..Nyquist) via the
% real-cepstrum method.
N = numel(mag) - 1;          % Nyquist index
Nfull = 2*N;                 % full FFT length

magFull = [mag; flipud(mag(2:end-1))];              % mirror to full spectrum
magFull = max(magFull, max(magFull) * 1e-9);         % avoid log(0)

logMag = log(magFull);
cep = real(ifft(logMag));

% Causal window -> minimum-phase cepstrum
win = zeros(Nfull, 1);
win(1) = 1;                  % n = 0
win(2:N) = 2;                % n = 1 .. N-1 (double the causal part)
win(N+1) = 1;                % n = N (Nyquist bin, no doubling)
% n = N+1 .. Nfull-1 stays zero (anti-causal part removed)

cepMin = cep .* win;
HminFull = exp(fft(cepMin));

Hmin = HminFull(1:N+1);      % DC..Nyquist half
end

function [b, a] = local_fitTF(Hd, w, nb, na, opts)
% Fit B(z)/A(z) to complex frequency response Hd at angular frequencies
% w (0..pi) using the base-MATLAB sinvfreqz (SK) or sstmcb (Steiglitz-McBride).
%   "invfreqz" -> Sanathanan-Koerner iterative frequency-domain fit.
%   "stmcb"    -> Steiglitz-McBride time-domain fit on the impulse response.
switch opts.Method
    case "invfreqz"
        [b, a] = timeSeriesPreparation.spectral.sinvfreqz(Hd, w, nb, na, opts.MaxIter);
    case "stmcb"
        % Steiglitz-McBride needs a time-domain target; use the impulse
        % response obtained from the (mirrored) minimum-phase spectrum.
        N = numel(Hd) - 1;
        Hfull = [Hd; conj(flipud(Hd(2:end-1)))];
        h = real(ifft(Hfull));
        hLen = min(numel(h), 8*(na+nb+2));
        [b, a] = timeSeriesPreparation.spectral.sstmcb(h(1:hLen), nb, na, opts.MaxIter);
end
end


function [b, a, info] = local_autoSelectOrder(Hd, w, opts)
% Sweep ARMA orders na=nb=1..MaxOrder and pick the smallest order that
% meets the fit tolerance (OrderCriterion = "tol"), or the order that
% minimizes an AIC-like criterion (OrderCriterion = "aic").
best = [];
Sref = abs(Hd).^2;

for n = 1:opts.MaxOrder
    try
        [bn, an] = local_fitTF(Hd, w, n, n, opts);
        if any(~isfinite(bn)) || any(~isfinite(an))
            continue
        end
        Hfit = timeSeriesPreparation.spectral.sfreqz(bn, an, w);
        errDb = 10*log10(max(abs(Hfit).^2, eps) ./ max(Sref, eps));
        rmsErrDb = sqrt(mean(errDb.^2));

        switch opts.OrderCriterion
            case "tol"
                if rmsErrDb <= opts.Tol
                    b = bn; a = an;
                    info = struct('na', n, 'nb', n, 'searched', true, 'rmsErrDb', rmsErrDb);
                    return
                end
                if isempty(best) || rmsErrDb < best.rmsErrDb
                    best = struct('b', bn, 'a', an, 'n', n, 'rmsErrDb', rmsErrDb);
                end
            case "aic"
                k = 2*n;
                Nw = numel(w);
                aic = Nw*log(mean(errDb.^2) + eps) + 2*k;
                if isempty(best) || aic < best.aic
                    best = struct('b', bn, 'a', an, 'n', n, 'rmsErrDb', rmsErrDb, 'aic', aic);
                end
        end
    catch
        continue
    end
end

if isempty(best)
    error('timeSeriesPreparation:psd2arma:fitFailed', ...
        'Could not fit an ARMA model up to order %d. Try increasing MaxOrder or NFFT, or Method=''stmcb''.', ...
        opts.MaxOrder);
end

b = best.b; a = best.a;
info = struct('na', best.n, 'nb', best.n, 'searched', true, 'rmsErrDb', best.rmsErrDb);
if isfield(best, 'aic'); info.aic = best.aic; end

if opts.OrderCriterion == "tol"
    warning('timeSeriesPreparation:psd2arma:toleranceNotMet', ...
        ['Requested tolerance (%.2f dB) not reached within MaxOrder = %d; returning best ', ...
         'order found (n = %d, RMS error = %.2f dB). Increase MaxOrder or Tol.'], ...
        opts.Tol, opts.MaxOrder, best.n, best.rmsErrDb);
end
end

function p = local_reflectRoots(p0)
% Reflect roots of polynomial P0 that lie outside the unit circle to
% their conjugate-reciprocal location inside it. This preserves
% |P(e^jw)| on the unit circle up to a per-root scale factor; the
% original leading coefficient (gain) is restored, and the caller
% applies an overall gain correction afterward.
if numel(p0) <= 1
    p = p0;
    return
end
r = roots(p0);
outside = abs(r) > 1;
if ~any(outside)
    p = p0;
    return
end
r(outside) = 1 ./ conj(r(outside));
pk = poly(r);          % monic polynomial with reflected roots
p = pk * p0(1);         % restore original leading coefficient
end
