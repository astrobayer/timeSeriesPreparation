function [H, w] = sfreqz(b, a, w, Fs)
%SFREQZ  Digital frequency response of an IIR/FIR filter (base MATLAB).
%
%   SYNTAX
%     H = timeSeriesPreparation.spectral.sfreqz(b, a, w)
%     [H, w] = timeSeriesPreparation.spectral.sfreqz(b, a, f, Fs)
%
%   DESCRIPTION
%     Evaluates the complex response H = B(z)/A(z) of a rational filter on
%     a supplied grid, as the Signal Processing Toolbox freqz does, but in
%     base MATLAB. The polynomials are in ascending powers of z^-1,
%     B(z) = b(1) + b(2) z^-1 + ..., A(z) = a(1) + a(2) z^-1 + ..., and are
%     evaluated at z^-1 = exp(-1i w) by accumulating powers. With Fs, the
%     third argument is read as frequencies in Hz and converted by
%     w = 2 pi f/Fs. |A| below 1e-300 is clamped to 1e-300, so a pole on the
%     grid gives a huge but finite value. Real or complex coefficients work,
%     and the class of w (single, gpuArray) is kept. No grid is generated
%     and nothing is drawn. psd2arma and arma2psd evaluate their models with
%     it.
%
%   INPUTS
%     b   (1,nb+1) double   -        Numerator coefficients [b0 ... b_nb].
%     a   (1,na+1) double   -        Denominator coefficients [a0 ... a_na];
%                                    a0 is usually 1.
%     w   (M,1) double      rad/sa   Angular frequencies, typically in
%                                    [0, pi]; in Hz when Fs is given.
%     Fs  (1,1) double      Hz       Optional sampling rate, > 0. If given
%                                    (and not []), w is converted from Hz.
%
%   OUTPUTS
%     H  (M,1) double   -        Complex frequency response at each w.
%     w  (M,1) double   rad/sa   Angular frequencies actually used.
%
%   ACCURACY
%     Direct evaluation of the two polynomials; the error is that of the
%     power accumulation, which grows with the order. sigtools' HANDOFF
%     states no separate number for it; its fits (sinvfreqz, sstmcb) are
%     checked through it. Unchanged from sigtools v1.3.1;
%     TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none)
%     A non-numeric input, or an Fs that is not a positive finite scalar,
%     is refused by the arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Response of an ARMA(2,2) filter on 512 points from 0 to pi.
%     w = linspace(0, pi, 512)';
%     H = timeSeriesPreparation.spectral.sfreqz([1 -0.5 0.2], [1 -1.2 0.6], w);
%
%   LIMITATIONS
%     Evaluates on a given grid only (no automatic grid, no plot). The
%     power accumulation loses accuracy for very high orders; factor
%     such filters into sections.
%
%   REFERENCES
%     A. V. Oppenheim, R. W. Schafer (2010), Discrete-Time Signal
%     Processing, 3rd ed. (z-transform and frequency response).
%     sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.sinvfreqz, timeSeriesPreparation.spectral.sstmcb, timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.spectral.psd2arma.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        b {mustBeNumeric}
        a {mustBeNumeric}
        w {mustBeNumeric}
        Fs {mustBeScalarOrEmpty, mustBeNumeric, mustBePositive, mustBeFinite} = []
    end

    w = w(:);
    if nargin >= 4 && ~isempty(Fs)
        w = 2*pi*w/Fs;
    end
    b = b(:).';  a = a(:).';
    z  = exp(-1i*w);                       % z^{-1} sample points
    B  = polyvalAsc(b, z);
    A  = polyvalAsc(a, z);
    A(abs(A) < 1e-300) = 1e-300;
    H  = B ./ A;
end

% ----------------------------------------------------------------------
function y = polyvalAsc(c, z)
% Evaluate c(1) + c(2)*z + ... + c(n+1)*z^n (ascending powers of z).
y  = zeros(size(z), 'like', z);
zp = ones(size(z), 'like', z);
for k = 1:numel(c)
    y  = y + c(k)*zp;
    zp = zp .* z;
end
end
