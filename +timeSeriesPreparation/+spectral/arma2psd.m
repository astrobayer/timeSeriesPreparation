function [S, f, info] = arma2psd(b, a, Fs, options)
%ARMA2PSD  One-sided PSD (or ASD) of a discrete-time ARMA process.
%
%   SYNTAX
%     [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs)
%     [S, f, info] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, NoiseVariance = 2, NFreq = 4096)
%
%   DESCRIPTION
%     Returns the spectral density of the stationary ARMA process
%     x[n] = filter(b, a, w[n]), w white with variance sigma_w^2, sampled
%     at Fs. It is the inverse of psd2arma and uses the same scaling,
%
%       S(f) = (2 sigma_w^2/Fs) |H(f)|^2,   H = B(z)/A(z), z = exp(-2i pi f/Fs),
%
%     so that trapz(f, S) is the process variance sigma_w^2 sum(psi^2).
%     H is evaluated with sfreqz on NFreq+1 points from 0 to Fs/2, or on
%     the given Frequencies. Sided "two" returns the two-sided level
%     (sigma_w^2/Fs)|H|^2; Output "asd" returns sqrt(S). info.variance is
%     always the trapz of the one-sided PSD. The model's roots are
%     reported, not checked: an unstable A still gives a spectrum.
%
%   INPUTS
%     b   (1,nb+1) double   -    MA (numerator) coefficients,
%                                B(z) = b(1) + b(2) z^-1 + ...
%     a   (1,na+1) double   -    AR (denominator) coefficients, a(1)
%                                normally 1.
%     Fs  (1,1) double      Hz   Sampling rate of the process, > 0, finite.
%
%   OPTIONS
%     NFreq          (1,1) double   [1024]    Grid size; f has NFreq+1
%                                             points from 0 to Fs/2, >= 2.
%     Frequencies    (K,1) double   [[]]      Explicit grid in Hz within
%                                             [0, Fs/2]; overrides NFreq.
%     NoiseVariance  (1,1) double   [1]       sigma_w^2 of the driving
%                                             noise, > 0.
%     Output         (1,1) string   ["psd"]   "psd" (unit^2/Hz) or "asd"
%                                             (unit/sqrt(Hz)).
%     Sided          (1,1) string   ["one"]   "one" or "two" (level
%                                             halved).
%
%   OUTPUTS
%     S     (K,1) double   -    PSD (unit^2/Hz) or ASD (unit/sqrt(Hz)) on f.
%     f     (K,1) double   Hz   Frequency grid, ascending, 0 to Fs/2.
%     info  (1,1) struct   -    Fields: variance (trapz(f,S) of the
%                               one-sided PSD; NaN for a single point),
%                               Poles, Zeros, IsStable, NoiseVariance,
%                               H (K,1) complex response.
%
%   ACCURACY
%     sigtools HANDOFF section 3 (NumPy re-derivation): the Parseval
%     identity trapz(f,S) = sigma_w^2 sum(psi^2) holds to ratio 1.0, up to
%     the trapezoidal quadrature error of the grid. Unchanged from sigtools
%     v1.3.1; TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:arma2psd:freqRange - a Frequencies entry
%           exceeds Fs/2.
%     Options:
%       timeSeriesPreparation:arma2psd:badOption - Output or Sided is not
%           one of its values (case-insensitive), or Frequencies is not
%           empty or a vector of values >= 0.
%       Other options outside their domain are refused by the arguments
%       block with a MATLAB: identifier.
%
%   EXAMPLE
%     % PSD of an ARMA(2,2) process at 500 Hz with noise variance 2.
%     [S, f, info] = timeSeriesPreparation.spectral.arma2psd([1 -0.5 0.2], [1 -1.2 0.6], 500, NoiseVariance = 2);
%
%   LIMITATIONS
%     Discrete-time model only; the spectrum is periodic in Fs and is
%     returned up to Fs/2. info.variance is a trapezoidal sum on the
%     chosen grid, so a coarse grid under-resolves sharp peaks.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins (1970), Time Series Analysis: Forecasting
%     and Control, Holden-Day (ARMA spectrum). sigtools v1.3.1 HANDOFF
%     (docs/inputs), section 5 (PSD scaling).
%
%   See also timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.arma2acv, timeSeriesPreparation.spectral.spec2acv, timeSeriesPreparation.spectral.sfreqz, timeSeriesPreparation.spectral.synthTimeSeries.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        b {mustBeNumeric}
        a {mustBeNumeric}
        Fs (1,1) {mustBeNumeric, mustBePositive, mustBeFinite}
        options.NFreq (1,1) {mustBeNumeric, mustBeGreaterThanOrEqual(options.NFreq, 2)} = 1024
        options.Frequencies {mustBeFrequencyGrid} = []
        options.NoiseVariance (1,1) {mustBeNumeric, mustBePositive} = 1
        options.Output (1,1) string {mustBeOneOf(options.Output, ["psd" "asd"])} = "psd"
        options.Sided (1,1) string {mustBeOneOf(options.Sided, ["one" "two"])} = "one"
    end

    b = b(:).';  a = a(:).';
    o = options;

    if ~isempty(o.Frequencies)
        f = double(o.Frequencies(:));
        if any(f > Fs/2 + eps(Fs)*10)
            error('timeSeriesPreparation:arma2psd:freqRange', 'Frequencies must lie within [0, Fs/2].');
        end
    else
        f = linspace(0, Fs/2, round(o.NFreq) + 1).';
    end

    % Digital frequency response H(e^{j w}), w = 2*pi*f/Fs
    H = timeSeriesPreparation.spectral.sfreqz(b, a, f, Fs);

    sigma_w2 = o.NoiseVariance;
    if strcmpi(o.Sided, 'one')
        S = (2*sigma_w2/Fs) * abs(H).^2;
    else
        S = (sigma_w2/Fs) * abs(H).^2;      % two-sided level
    end

    if strcmpi(o.Output, 'asd')
        Sout = sqrt(S);
    else
        Sout = S;
    end

    info = struct();
    info.NoiseVariance = sigma_w2;
    info.H = H;
    info.Poles = roots(a);
    info.Zeros = roots(b);
    info.IsStable = all(abs(info.Poles) < 1);
    if numel(f) > 1
        info.variance = trapz(f, S);        % process variance (one-sided PSD)
    else
        info.variance = NaN;
    end

    S = Sout;
end

% ----------------------------------------------------------------------
function mustBeOneOf(value, allowed)
% Case-insensitive membership, as v1.3.1's strcmpi validators.
    if ~any(strcmpi(value, allowed))
        error("timeSeriesPreparation:arma2psd:badOption", ...
            "Value must be one of: %s.", strjoin(allowed, ", "));
    end
end

function mustBeFrequencyGrid(f)
% Empty, or a vector of values >= 0 (v1.3.1's rule).
    if ~isempty(f) && ~(isvector(f) && all(f >= 0))
        error("timeSeriesPreparation:arma2psd:badOption", ...
            "Frequencies must be empty or a vector of values >= 0.");
    end
end
