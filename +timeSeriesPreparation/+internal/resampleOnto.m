function [yq, info] = resampleOnto(t, y, valid, tq, method, maxGap)
%RESAMPLEONTO  Interpolate a series onto new epochs, never across a hole.
%
%   SYNTAX
%     [yq, info] = timeSeriesPreparation.internal.resampleOnto(t, y, valid, tq, method, maxGap)
%
%   DESCRIPTION
%     The one resampling rule of align and checkAlignment (CONCEPT 6.1, row
%     3). The usable samples (valid) split into stretches: a stretch ends at
%     an unusable sample and wherever two usable samples lie more than
%     maxGap apart. Interpolation runs inside each stretch on its own, so no
%     value is made from samples on both sides of a hole and nothing is
%     extrapolated. An epoch equal to a usable epoch takes that sample bit
%     for bit. Every other epoch gets NaN.
%
%     Splitting the series makes the result independent of what interp1
%     does with NaN. v2 records that R2026a's interp1 drops NaN points and
%     interpolates across them. Its remedy, a finiteness mask interpolated
%     linearly, covers only the two intervals next to a NaN, but pchip's
%     slopes reach one interval further, so a pchip value there still uses
%     the far side of the hole.
%
%     Times become double seconds from t(1), once per call (CONCEPT 5.1):
%     the resolution is about 6e-10 s over a month.
%
%   INPUTS
%     t       (N,1) int64    ns        Sample epochs, strictly increasing.
%     y       (N,M) double   -         Samples; rows of unusable samples are
%                                      ignored.
%     valid   (N,1) logical  -         true = usable sample.
%     tq      (K,1) int64    ns        Query epochs, strictly increasing.
%     method  (1,1) string   -         interp1 method: "pchip", "makima",
%                                      "spline" or "linear".
%     maxGap  (1,1) double   s         Widest spacing interpolated across;
%                                      [] = 1.5 x the median step of t.
%
%   OUTPUTS
%     yq    (K,M) double   -   Values on tq; NaN rows where no stretch covers
%                              the epoch.
%     info  (1,1) struct   -   maxGap (s, as applied), exact (K,1) logical
%                              (taken bit for bit), stretches (number of
%                              stretches with at least two samples).
%
%   ACCURACY
%     Exact at coinciding epochs. Elsewhere the method's interpolation
%     error. pchip at 5 s spacing, evaluated at 1 s, errs by 3.8e-6 of the
%     amplitude on a 1/rev plus 2/rev signal (orbit 5640 s). A NumPy
%     transcription of MATLAB's pchip measured this on 2026-09-23.
%
%   ERRORS
%     (none)
%
%   EXAMPLE
%     % A 5 s series with one NaN, resampled at 1 s; the hole stays NaN.
%     t = int64(0:5:60)' * int64(1e9);
%     y = sin((0:5:60)' / 20); y(7) = NaN;
%     tq = int64(0:60)' * int64(1e9);
%     yq = timeSeriesPreparation.internal.resampleOnto(t, y, isfinite(y), tq, "pchip", []);
%
%   LIMITATIONS
%     A stretch of one sample yields only its own epoch. The rows are
%     joint: a caller that wants per-column validity calls once per column.
%
%   REFERENCES
%     docs/CONCEPT.md sections 5.1, 6.1; v3 WP-11 item 1
%     (docs/inputs/HANDOVER_AccelCal_v3.md); v2 alignAccelSeries.
%
%   See also timeSeriesPreparation.align, timeSeriesPreparation.checkAlignment, interp1.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.2 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    M = size(y, 2);
    yq = NaN(numel(tq), M);
    info = struct("maxGap", maxGap, "exact", false(numel(tq), 1), "stretches", 0);
    if isempty(maxGap)
        if numel(t) >= 2
            maxGap = 1.5 * median(double(diff(t))) / 1e9;
        else
            maxGap = 0;
        end
    end
    info.maxGap = maxGap;
    idx = find(valid(:));
    if isempty(idx) || isempty(tq)
        return
    end

    tu = t(idx);
    yu = y(idx, :);
    [hit, loc] = ismember(tq, tu);
    yq(hit, :) = yu(loc(hit), :);
    info.exact = hit;

    % Stretch boundaries: an unusable sample between, or a spacing > maxGap.
    x = double(tu - t(1)) * 1e-9;
    xq = double(tq - t(1)) * 1e-9;
    cut = diff(idx) > 1 | diff(x) > maxGap;
    stretch = cumsum([1; cut]);
    n = numel(x);
    if n < 2
        return
    end
    prev = interp1(x, (1:n)', xq, "previous");      % usable sample before
    inner = ~hit & ~isnan(prev) & prev < n;
    inner(inner) = stretch(prev(inner)) == stretch(prev(inner) + 1);
    s = stretch(prev(inner));
    q = find(inner);
    first = [1; find(cut) + 1];
    last = [first(2:end) - 1; n];
    for k = unique(s)'
        in = first(k):last(k);
        rows = q(s == k);
        for j = 1:M
            yq(rows, j) = interp1(x(in), yu(in, j), xq(rows), method);
        end
    end
    info.stretches = nnz(last > first);
end
