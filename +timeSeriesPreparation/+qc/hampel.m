function [mask, info] = hampel(x, options)
%HAMPEL  Robust point-outlier detector: moving median and scaled MAD, per column.
%
%   SYNTAX
%     mask = timeSeriesPreparation.qc.hampel(x)
%     [mask, info] = timeSeriesPreparation.qc.hampel(x, Window = 61, Threshold = 4, MinSigma = 0)
%
%   DESCRIPTION
%     Flags sample i of column j when |x(i,j) - med(i,j)| > t * 1.4826 *
%     MAD(i,j), with med and MAD over a centred window of W samples,
%     truncated at the edges. Median and MAD tolerate up to about half the
%     window contaminated, which is why this, not a moving mean and std,
%     is the first pass on residuals with thruster spikes and twangs.
%     NaN samples are never flagged and never enter the window
%     statistics; a window with fewer than three finite samples flags
%     nothing. A row vector is one channel. Ported from NonGravForces.qc
%     0.12.0 (X-05); numbers unchanged (X-05b).
%
%   INPUTS
%     x  (K,M) double   -   K samples of M channels.
%
%   OPTIONS
%     Window     (1,1) double   [61]  Odd window >= 3 in samples (1 min at
%                                     1 Hz: longer than a CRN-filtered
%                                     impulse, shorter than an orbit).
%     Threshold  (1,1) double   [4]   Multiple of the robust sigma
%                                     (Gaussian false-alarm rate 6e-5 per
%                                     sample).
%     MinSigma   (1,1) double   [0]   Floor on the robust sigma, units of
%                                     x, so that a flat window cannot flag
%                                     quantisation.
%
%   OUTPUTS
%     mask  (K,M) logical   -   True = outlier.
%     info  (1,1) struct    -   Fields: median, sigma (robust), score
%                               (|x - med|/sigma), all (K,M); nFlagged
%                               (1,M); provenance.
%
%   ACCURACY
%     1.4826 makes the MAD consistent with sigma for Gaussian noise; for
%     1/f accelerometer noise it overestimates sigma by up to about 10 %
%     inside a 61-sample window, which is conservative. Impulses wider
%     than Window/2 are not outliers here by design; they go to
%     detectImpulses.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:hampel:inputShape - x is not a real 2-D
%           array.
%       timeSeriesPreparation:hampel:inputWindow - Window is even, below 3
%           or not an integer.
%
%   EXAMPLE
%     % One planted outlier in white noise.
%     x = randn(RandStream("twister", "Seed", 2), 1000, 1); x(500) = 12;
%     mask = timeSeriesPreparation.qc.hampel(x);
%
%   LIMITATIONS
%     An interpreted loop, O(K W) per channel; X-16 moves it onto
%     movmedian with an exact window MAD.
%
%   REFERENCES
%     Hampel, F. R. (1974). The influence curve and its role in robust
%     estimation. J. Am. Stat. Assoc. 69, 383-393. Pearson (2002), cited
%     as the port cites it ("EURASIP JASP"), not re-read.
%
%   See also timeSeriesPreparation.qc.screen, timeSeriesPreparation.qc.detectImpulses, movmedian.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    x double
    options.Window (1,1) double = 61
    options.Threshold (1,1) double {mustBePositive} = 4
    options.MinSigma (1,1) double {mustBeNonnegative} = 0
end
if ~ismatrix(x) || ~isreal(x)
    error("timeSeriesPreparation:hampel:inputShape", "x must be a real KxM matrix -> got %s", mat2str(size(x)));
end
W = options.Window;
if W < 3 || mod(W, 2) ~= 1 || W ~= round(W)
    error("timeSeriesPreparation:hampel:inputWindow", "Window must be an odd integer >= 3 -> got %g", W);
end
if isrow(x), x = x(:); end
[K, M] = size(x);
h = (W - 1) / 2;
med = nan(K, M); sig = nan(K, M);
for j = 1:M
    xj = x(:, j);
    for i = 1:K
        lo = max(1, i - h); hi = min(K, i + h);
        w = xj(lo:hi); w = w(isfinite(w));
        if numel(w) < 3, continue; end
        m = median(w);
        med(i, j) = m;
        sig(i, j) = 1.4826 * median(abs(w - m));
    end
end
sig = max(sig, options.MinSigma);
score = abs(x - med) ./ sig;                     % NaN where sig is 0 or x NaN
mask = score > options.Threshold;                % NaN > t is false
mask(~isfinite(x)) = false;
info.median = med; info.sigma = sig; info.score = score;
info.nFlagged = sum(mask, 1);
info.provenance = timeSeriesPreparation.internal.provenance("qc.hampel", 'Options', options);
end
