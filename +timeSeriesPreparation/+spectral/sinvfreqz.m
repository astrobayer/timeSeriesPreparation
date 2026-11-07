function [b, a] = sinvfreqz(Hd, w, nb, na, maxIter)
%SINVFREQZ  Fit an IIR filter to a complex frequency response (base MATLAB).
%
%   SYNTAX
%     [b, a] = timeSeriesPreparation.spectral.sinvfreqz(Hd, w, nb, na)
%     [b, a] = timeSeriesPreparation.spectral.sinvfreqz(Hd, w, nb, na, maxIter)
%
%   DESCRIPTION
%     Fits B(z)/A(z), z = exp(-1i w), a(1) = 1, of orders nb and na to a
%     target complex response Hd on the angular frequencies w. It replaces
%     the Signal Processing Toolbox invfreqz (unweighted, no user weights)
%     and is the default fitting engine of psd2arma. The method is the
%     Sanathanan-Koerner (SK) iteration: each pass solves the linearised
%     least-squares problem
%
%       min sum_k |W_k (A(z_k) Hd_k - B(z_k))|^2,   W_k = 1/|A_prev(z_k)|,
%
%     in the real domain (real and imaginary parts stacked, backslash).
%     The first pass is the Levy equation-error solution; as the weights
%     converge the fit approaches the output-error (true magnitude and
%     phase) fit. The iteration stops after maxIter passes or when the
%     weights change by <= 1e-9 relative. A rational Hd is recovered to
%     machine precision, and smooth non-rational targets are fitted to a
%     fraction of a dB.
%
%   INPUTS
%     Hd       (M,1) double   -        Target complex response, one value
%                                      per frequency in w.
%     w        (M,1) double   rad/sa   Angular frequencies, typically in
%                                      [0, pi].
%     nb       (1,1) double   -        Numerator (zero) order, integer >= 0;
%                                      b has nb+1 coefficients.
%     na       (1,1) double   -        Denominator (pole) order, integer
%                                      >= 0; a has na+1 coefficients.
%     maxIter  (1,1) double   -        Optional maximum number of SK passes,
%                                      positive integer; [] or omitted: 30.
%
%   OUTPUTS
%     b  (1,nb+1) double   -   Numerator coefficients [b0 ... b_nb].
%     a  (1,na+1) double   -   Denominator coefficients [1 a1 ... a_na].
%
%   ACCURACY
%     sigtools HANDOFF section 3 (NumPy re-derivation of the exact logic):
%     a known ARMA is recovered to about 1e-15, and a smooth 4th-order
%     low-pass target is fitted to 0.0075 dB RMS, stable and minimum-phase.
%     Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence holds it bit
%     for bit.
%
%   ERRORS
%     (none)
%     Non-numeric input, orders that are not non-negative integer scalars,
%     or a maxIter that is not a positive integer are refused by the
%     arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Recover a known ARMA(2,2) from its response.
%     w  = linspace(0, pi, 400)';
%     Hd = timeSeriesPreparation.spectral.sfreqz([1 -0.5 0.2], [1 -1.2 0.6], w);
%     [b, a] = timeSeriesPreparation.spectral.sinvfreqz(Hd, w, 2, 2);
%
%   LIMITATIONS
%     No user weights and no stability enforcement: an unstable or
%     non-minimum-phase result is possible, and psd2arma reflects such
%     roots afterwards. The least-squares matrix is ill-conditioned for
%     high orders.
%
%   REFERENCES
%     C. K. Sanathanan, J. Koerner (1963), IEEE Trans. Autom. Control 8(1),
%     56-58. E. C. Levy (1959), IRE Trans. Autom. Control 4(1), 37-44.
%     sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.sfreqz, timeSeriesPreparation.spectral.sstmcb, timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.arma2psd.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        Hd {mustBeNumeric}
        w {mustBeNumeric}
        nb (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
        na (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
        maxIter {mustBeScalarOrEmpty, mustBeNumeric, mustBeInteger, mustBePositive} = 30
    end

    if nargin < 5 || isempty(maxIter), maxIter = 30; end
    w  = w(:);  Hd = Hd(:);
    m  = numel(w);  z = exp(-1i*w);

    Zb = zeros(m, nb+1);                    % columns z^0 .. z^nb  (for B)
    zp = ones(m,1);
    for k = 0:nb, Zb(:,k+1) = zp; zp = zp .* z; end
    Za = zeros(m, na);                      % columns z^1 .. z^na  (for A, a0=1)
    zp = z;
    for k = 1:na, Za(:,k) = zp; zp = zp .* z; end

    Wk = ones(m,1);
    a  = [1; zeros(na,1)];
    b  = zeros(nb+1,1);
    for it = 1:maxIter
        % rows:  Wk*( Zb*b - (Za.*Hd)*a(2:end) ) = Wk*Hd
        M   = [Zb, -(Za .* Hd)];            % m x (nb+1+na)
        Wc  = Wk;
        Als = [real(Wc).*real(M) - imag(Wc).*imag(M); ...
               real(Wc).*imag(M) + imag(Wc).*real(M)];
        rhs = Wk .* Hd;
        bls = [real(rhs); imag(rhs)];
        x   = Als \ bls;                    % base-MATLAB least squares
        b   = x(1:nb+1);
        a   = [1; x(nb+2:end)];
        Az  = 1 + Za*a(2:end);
        newWk = 1 ./ max(abs(Az), 1e-12);
        if norm(newWk - Wk) <= 1e-9*max(norm(Wk), 1e-12)
            Wk = newWk; break;
        end
        Wk = newWk;
    end
    b = b(:).';  a = a(:).';
end
