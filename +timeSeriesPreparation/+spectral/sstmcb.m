function [b, a] = sstmcb(h, nb, na, maxIter)
%SSTMCB  Steiglitz-McBride IIR fit to an impulse response (base MATLAB).
%
%   SYNTAX
%     [b, a] = timeSeriesPreparation.spectral.sstmcb(h, nb, na)
%     [b, a] = timeSeriesPreparation.spectral.sstmcb(h, nb, na, maxIter)
%
%   DESCRIPTION
%     Fits B(z)/A(z), a(1) = 1, of orders nb and na so that
%     filter(b, a, delta) approximates the impulse response h. It replaces
%     the Signal Processing Toolbox stmcb (unit-impulse input, internal
%     initial denominator) and is psd2arma's Method "stmcb". The method is
%     the Steiglitz-McBride iteration: each pass prefilters the unit
%     impulse and the target h by 1/A_prev (filter), then re-estimates B
%     and A by linear least squares (backslash). This refines the
%     equation-error fit towards the output-error fit, which gives the
%     method its accuracy on rational systems. Exactly maxIter passes are
%     run; there is no convergence test.
%
%   INPUTS
%     h        (L,1) double   -   Target impulse response samples (real).
%     nb       (1,1) double   -   Numerator (zero) order, integer >= 0; b
%                                 has nb+1 coefficients.
%     na       (1,1) double   -   Denominator (pole) order, integer >= 0; a
%                                 has na+1 coefficients.
%     maxIter  (1,1) double   -   Optional number of SM passes, positive
%                                 integer; [] or omitted: 10.
%
%   OUTPUTS
%     b  (1,nb+1) double   -   Numerator coefficients [b0 ... b_nb].
%     a  (1,na+1) double   -   Denominator coefficients [1 a1 ... a_na].
%
%   ACCURACY
%     sigtools HANDOFF section 3 (NumPy re-derivation of the exact logic):
%     the generating filter is recovered exactly. Unchanged from sigtools
%     v1.3.1; TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none)
%     Non-numeric input, orders that are not non-negative integer scalars,
%     or a maxIter that is not a positive integer are refused by the
%     arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Recover the generating ARMA(2,2) filter from 61 impulse samples.
%     htrue = filter([1 -0.5 0.2], [1 -1.2 0.6], [1; zeros(60,1)]);
%     [b, a] = timeSeriesPreparation.spectral.sstmcb(htrue, 2, 2);
%
%   LIMITATIONS
%     Unit-impulse input only (no general input/output pair). No
%     stability enforcement. The regressor has L rows and nb+na+1 columns,
%     so h should be several times longer than the model order.
%
%   REFERENCES
%     K. Steiglitz, L. E. McBride (1965), IEEE Trans. Autom. Control 10(4),
%     461-464. sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.sfreqz, timeSeriesPreparation.spectral.sinvfreqz, timeSeriesPreparation.spectral.psd2arma.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        h {mustBeNumeric}
        nb (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
        na (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative}
        maxIter {mustBeScalarOrEmpty, mustBeNumeric, mustBeInteger, mustBePositive} = 10
    end

    if nargin < 4 || isempty(maxIter), maxIter = 10; end
    h = h(:);  N = numel(h);
    x = zeros(N,1);  x(1) = 1;              % unit impulse input
    a = [1; zeros(na,1)];
    b = [];
    for it = 1:maxIter
        xf = filter(1, a, x);              % prefiltered input
        yf = filter(1, a, h);             % prefiltered target
        % Regressor columns: xf shifted 0..nb (for b), -yf shifted 1..na (for a)
        M = zeros(N, nb+1+na);
        for j = 0:nb
            M(j+1:N, j+1) = xf(1:N-j);
        end
        for i = 1:na
            M(i+1:N, nb+1+i) = -yf(1:N-i);
        end
        sol = M \ yf;
        b = sol(1:nb+1);
        a = [1; sol(nb+2:end)];
    end
    b = b(:).';  a = a(:).';
end
