function map = binnedMap(value, a, b, edgesA, edgesB)
%BINNEDMAP  Mean, standard deviation and count of a value in bins of two coordinates.
%
%   SYNTAX
%     map = timeSeriesPreparation.binnedMap(value, a, b, edgesA, edgesB)
%
%   DESCRIPTION
%     The binned map of CONCEPT 7, e.g. a residual over (beta', u). Each
%     sample falls in the bin of its a and b by discretize's rule: bins
%     are [e_i, e_(i+1)), the last one closed [e_(n-1), e_n]. Samples with
%     NaN in value, a or b, and samples outside the edges, are ignored.
%     Per bin: the mean, the standard deviation (normalised by n - 1; NaN
%     below two samples) and the count. Empty bins have mean NaN (owner
%     decision 2026-09-24). The edges are the caller's: a bin width is
%     physics, not a default (R5).
%
%   INPUTS
%     value   (N,1) double   -   The mapped quantity, e.g. a residual.
%     a       (N,1) double   -   First coordinate, e.g. beta' in deg.
%     b       (N,1) double   -   Second coordinate, e.g. u in deg.
%     edgesA  (1,:) double   -   Bin edges of a, strictly increasing,
%                                at least two.
%     edgesB  (1,:) double   -   Bin edges of b, likewise.
%
%   OUTPUTS
%     map  (1,1) struct   -   Fields: mean, sd, count (numel(edgesA) - 1,
%                             numel(edgesB) - 1), rows along a; edgesA,
%                             edgesB; centresA, centresB (bin midpoints);
%                             nUsed, the samples inside the edges.
%
%   ACCURACY
%     Exact accumulation per bin (accumarray); TestBinnedMap holds it
%     against an explicit loop over the bins to 1e-12.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:binnedMap:sizeMismatch - value, a and b are
%           not vectors of one length.
%       timeSeriesPreparation:binnedMap:badEdges - an edge vector has
%           fewer than two entries, is not strictly increasing, or is not
%           finite.
%
%   EXAMPLE
%     % A residual over beta' and u in 10 x 30 degree bins.
%     rs = RandStream("twister", "Seed", 23);
%     beta = 180 * rand(rs, 5000, 1) - 90;
%     u = 360 * rand(rs, 5000, 1);
%     r = 1e-9 * sind(u) .* cosd(beta) + 1e-10 * randn(rs, 5000, 1);
%     map = timeSeriesPreparation.binnedMap(r, beta, u, -90:10:90, 0:30:360);
%
%   LIMITATIONS
%     No wrap-around: an angle such as u must be mapped into the edges'
%     range by the caller (u = 360 falls in the last bin, 0 in the first).
%     No weighting and no robust statistics.
%
%   REFERENCES
%     docs/CONCEPT.md section 7.
%
%   See also timeSeriesPreparation.drivers, timeSeriesPreparation.regressDrivers, discretize, accumarray.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        value double
        a double
        b double
        edgesA double
        edgesB double
    end

    if ~isvector(value) || ~isequal(numel(a), numel(value)) || ~isequal(numel(b), numel(value)) ...
            || ~isvector(a) || ~isvector(b)
        error("timeSeriesPreparation:binnedMap:sizeMismatch", ...
            "value, a and b must be vectors of one length.");
    end
    checkEdges(edgesA);
    checkEdges(edgesB);
    ia = discretize(a(:), edgesA);
    ib = discretize(b(:), edgesB);
    v = value(:);
    use = ~isnan(ia) & ~isnan(ib) & isfinite(v);
    shape = [numel(edgesA) - 1, numel(edgesB) - 1];
    subs = [ia(use), ib(use)];
    count = accumarray(subs, 1, shape);
    total = accumarray(subs, v(use), shape);
    mu = total ./ count;
    mu(count == 0) = NaN;
    dev = v(use) - mu(sub2ind(shape, ia(use), ib(use)));
    sd = sqrt(accumarray(subs, dev.^2, shape) ./ (count - 1));
    sd(count < 2) = NaN;
    map = struct("mean", mu, "sd", sd, "count", count, ...
        "edgesA", edgesA(:)', "edgesB", edgesB(:)', ...
        "centresA", (edgesA(1:end-1) + edgesA(2:end)) / 2, ...
        "centresB", (edgesB(1:end-1) + edgesB(2:end)) / 2, ...
        "nUsed", nnz(use));
    map.centresA = map.centresA(:)';
    map.centresB = map.centresB(:)';
end

% ------------------------------------------------------------------------

function checkEdges(e)
% At least two finite, strictly increasing edges in a vector.
    if ~isvector(e) || numel(e) < 2 || ~all(isfinite(e)) || any(diff(e) <= 0)
        error("timeSeriesPreparation:binnedMap:badEdges", ...
            "Edges must be a finite, strictly increasing vector of at least two entries.");
    end
end
