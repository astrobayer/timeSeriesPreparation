function [events, info] = detectJumps(r, options)
%DETECTJUMPS  Change points in level or slope of whitened residuals by PELT with a BIC penalty; priors are assigned.
%
%   SYNTAX
%     [events, info] = timeSeriesPreparation.qc.detectJumps(r, Epoch = t)
%     [events, info] = timeSeriesPreparation.qc.detectJumps(r, Epoch = t, Model = "slope", Priors = ecl, Penalty = beta, MinSegment = 30)
%
%   DESCRIPTION
%     Minimises, per channel, the sum over segments of the least-squares
%     cost plus a penalty beta per change point, by Pruned Exact Linear
%     Time (Killick, Fearnhead and Eckley 2012), which equals the
%     exhaustive optimum. The segment cost is the residual sum of squares
%     about a constant ("level") or a straight line ("slope"). The
%     default penalty is the BIC value (p + 1) sigma^2 log K, p = 1
%     (level) or 2 (slope) parameters per segment plus one for the change
%     point's location, sigma the robust scale of the first differences
%     (1.4826 MAD / sqrt(2)); Penalty replaces it (squared residual
%     units). Each change point is a "jump" row: tStart = tEnd = first
%     sample of the new segment, amplitude = new minus old level at the
%     boundary (fitted lines for "slope"), sigma = sigma sqrt(1/n1 +
%     1/n2). A jump within PriorWindow_s of a prior row (eclipse, MAS1B
%     tank event) takes its source and confidence 1; the others are
%     "unassigned" with confidence erf(|amplitude|/sigma/sqrt(2)). Jumps
%     are never cut from the data. NaN samples are removed before the
%     segmentation and the indices mapped back. Ported from
%     NonGravForces.qc 0.12.0 (X-05); numbers unchanged (X-05b, X-16).
%
%   INPUTS
%     r  (K,M) double   -   Whitened residuals, M = 1 (axis "all") or 3.
%
%   OPTIONS
%     Epoch          (K,1) datetime   []         Sample epochs, UTC;
%                                                required.
%     Model          (1,1) string     ["level"]  "level" or "slope".
%     Penalty        (1,1) double     []         Per change point; [] =
%                                                BIC.
%     MinSegment     (1,1) double     []         Shortest segment in
%                                                samples; [] = 2 (level)
%                                                or 3 (slope).
%     Priors         (N,8) table      []         qc.eventTable rows to
%                                                assign.
%     PriorWindow_s  (1,1) double     [60]       Assignment window, s.
%
%   OUTPUTS
%     events  (N,8) table    -   qc.eventTable rows of class "jump",
%                                sorted by tStart.
%     info    (1,1) struct   -   Fields: changePoints (1,M cell, first
%                                sample of each new segment); penalty,
%                                sigma, cost (1,M); segments (1,M cell of
%                                [first last level|intercept slope]);
%                                model; provenance.
%
%   ACCURACY
%     Exact optimisation for the stated cost and penalty; the ported
%     tests hold it to the exhaustive optimum of an independent Python
%     oracle, bitwise in the indices. A step h in white noise sigma is
%     found when h^2 n1 n2/(n1 + n2) > beta. Coloured noise without
%     whitening gives spurious level changes: whiten first.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:detectJumps:inputShape - r is not Kx1 or
%           Kx3, or Epoch is not Kx1.
%       timeSeriesPreparation:detectJumps:inputEpoch - Epoch is missing,
%           not a datetime, or not UTC.
%       timeSeriesPreparation:detectJumps:inputRange - Penalty is not
%           positive, MinSegment is below 2 (3 for slope) or not an
%           integer, or PriorWindow_s is not positive.
%       timeSeriesPreparation:detectJumps:inputPriors - Priors is not a
%           qc.eventTable.
%     Data:
%       timeSeriesPreparation:detectJumps:dataEmpty - a channel has fewer
%           than 2 MinSegment finite samples.
%
%   EXAMPLE
%     % A 4-sigma step in 1000 white samples.
%     x = randn(RandStream("twister", "Seed", 5), 1000, 1); x(601:end) = x(601:end) + 4;
%     t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds((0:999)');
%     [events, info] = timeSeriesPreparation.qc.detectJumps(x, Epoch = t);
%
%   LIMITATIONS
%     Quadratic when pruning keeps many candidates, which happens on a
%     long series with few jumps (about 3 min for one day of three axes
%     at 1 Hz with the port). Each step is vectorised over the candidates,
%     whose cumulative sums and F(tau) are cached beside them (X-16).
%
%   REFERENCES
%     Killick, R., Fearnhead, P., Eckley, I. A. (2012). Optimal detection
%     of changepoints with a linear computational cost. J. Am. Stat.
%     Assoc. 107, 1590-1598. Schwarz, G. (1978). Estimating the dimension
%     of a model. Ann. Stat. 6, 461-464.
%
%   See also timeSeriesPreparation.qc.residuals, timeSeriesPreparation.qc.eventTable, timeSeriesPreparation.qc.screen.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-26 09:10 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    r double
    options.Epoch = []
    options.Model (1,1) string {mustBeMember(options.Model, ["level","slope"])} = "level"
    options.Penalty double = []
    options.MinSegment double = []
    options.Priors = []
    options.PriorWindow_s (1,1) double = 60
end
[K, M] = size(r);
if ~ismatrix(r) || ~(M == 1 || M == 3)
    error("timeSeriesPreparation:detectJumps:inputShape", "r must be Kx1 or Kx3 -> got %s (samples down the columns)", mat2str(size(r)));
end
t = options.Epoch;
if isempty(t) || ~isdatetime(t)
    error("timeSeriesPreparation:detectJumps:inputEpoch", "'Epoch' (Kx1 datetime, UTC) is required -> pass the sample epochs of r");
end
if ~isequal(size(t), [K 1])
    error("timeSeriesPreparation:detectJumps:inputShape", "Epoch must be Kx1 = %dx1 -> got %s", K, mat2str(size(t)));
end
if isempty(t.TimeZone) || ~strcmp(t.TimeZone, 'UTC')
    error("timeSeriesPreparation:detectJumps:inputEpoch", "Epoch must carry TimeZone UTC -> set t.TimeZone = 'UTC'");
end
slope = options.Model == "slope";
p = 1 + slope;
minSeg = options.MinSegment;
if isempty(minSeg), minSeg = 2 + slope; end
if ~isscalar(minSeg) || minSeg < 2 + slope || minSeg ~= fix(minSeg)
    error("timeSeriesPreparation:detectJumps:inputRange", "MinSegment must be an integer >= %d for %s -> got %s", 2 + slope, options.Model, mat2str(minSeg));
end
if ~isempty(options.Penalty) && ~(isscalar(options.Penalty) && options.Penalty > 0)
    error("timeSeriesPreparation:detectJumps:inputRange", "Penalty must be a positive scalar -> got %s", mat2str(options.Penalty));
end
if options.PriorWindow_s <= 0
    error("timeSeriesPreparation:detectJumps:inputRange", "PriorWindow_s must be > 0 -> got %g", options.PriorWindow_s);
end
priors = options.Priors;
if isempty(priors), priors = timeSeriesPreparation.qc.eventTable(); end
schema = timeSeriesPreparation.qc.eventTable().Properties.VariableNames;
if ~istable(priors) || ~isequal(priors.Properties.VariableNames, schema)
    error("timeSeriesPreparation:detectJumps:inputPriors", "Priors must be a qc.eventTable -> use qc.eventTable(...)");
end
axes = "all"; if M == 3, axes = ["x","y","z"]; end
cps = cell(1, M); segs = cell(1, M); pen = nan(1, M); sig = nan(1, M); cost = nan(1, M);
tS = datetime.empty(0, 1); tS.TimeZone = 'UTC'; ax = string.empty(0, 1); am = zeros(0, 1); sg = zeros(0, 1);
for m = 1:M
    idx = find(~isnan(r(:, m)));
    x = r(idx, m); n = numel(x);
    if n < 2 * minSeg
        error("timeSeriesPreparation:detectJumps:dataEmpty", "channel %d has %d finite samples, fewer than 2 MinSegment = %d -> pass a longer series", m, n, 2 * minSeg);
    end
    d = diff(x); s = 1.4826 * median(abs(d - median(d))) / sqrt(2);
    sig(m) = s;
    if isempty(options.Penalty)
        beta = (p + 1) * max(s, realmin)^2 * log(n);    % BIC: p segment parameters plus the change-point location
    else
        beta = options.Penalty;
    end
    pen(m) = beta;
    [cp, Fopt, seg] = localPelt(x, beta, minSeg, slope);
    cost(m) = Fopt;
    cps{m} = idx(cp)';                              % first sample (original index) of each new segment
    segs{m} = [idx(seg(:, 1)) idx(seg(:, 2)) seg(:, 3:end)];
    for q = 1:numel(cp)
        a = seg(q, :); b = seg(q + 1, :);           % old and new segment [first last intercept (slope)]
        n1 = a(2) - a(1) + 1; n2 = b(2) - b(1) + 1;
        if slope
            tb = b(1);                              % boundary sample (local index)
            levelOld = a(3) + a(4) * tb; levelNew = b(3) + b(4) * tb;
        else
            levelOld = a(3); levelNew = b(3);
        end
        tS(end + 1, 1) = t(idx(cp(q))); ax(end + 1, 1) = axes(m); %#ok<AGROW>
        am(end + 1, 1) = levelNew - levelOld; sg(end + 1, 1) = s * sqrt(1 / n1 + 1 / n2); %#ok<AGROW>
    end
end
n = numel(tS);
source = repmat("unassigned", n, 1);
conf = erf(abs(am) ./ max(sg, realmin) / sqrt(2));
for e = 1:n
    dt = abs(seconds(priors.tStart - tS(e)));
    [dmin, q] = min(dt);
    if ~isempty(dmin) && dmin <= options.PriorWindow_s
        source(e) = priors.source(q); conf(e) = 1;
    end
end
events = timeSeriesPreparation.qc.eventTable(tS, tS, repmat("jump", n, 1), ax, am, sg, source, conf);
events = sortrows(events, 'tStart');
info.changePoints = cps;
info.penalty = pen;
info.sigma = sig;
info.cost = cost;
info.segments = segs;
info.model = options.Model;
info.provenance = timeSeriesPreparation.internal.provenance("qc.detectJumps", 'Options', struct('Model', options.Model, 'Penalty', options.Penalty, 'MinSegment', minSeg, 'PriorWindow_s', options.PriorWindow_s, 'priors', height(priors)));
end

function [cp, Fopt, seg] = localPelt(x, beta, minSeg, slope)
%LOCALPELT Exact penalised segmentation (Killick 2012): F(t) = min_tau F(tau) + C(tau+1..t) + beta.
n = numel(x);
tt = (1:n)';
S1 = [0; cumsum(x)]; S2 = [0; cumsum(x.^2)];
if slope
    St = [0; cumsum(tt)]; Stt = [0; cumsum(tt.^2)]; Sxt = [0; cumsum(x .* tt)];
end
F = [-beta; inf(n, 1)];                              % F(tau) stored at index tau+1
prev = zeros(n + 1, 1);
% Candidate last change points tau (0-based), ascending. The admissible ones
% (the new segment tau+1..t has at least minSeg samples) sit in R with their
% cumulative sums and F(tau) cached beside them (X-16: no gathers per step);
% the too-recent ones wait in the queue Q(qh:qt), each moving to R once.
R = zeros(0, 1); A1 = R; A2 = R; FA = R;
if slope, At = R; Att = R; Axt = R; end
Q = zeros(n + 1, 1); qh = 1; qt = 1;                 % tau = 0 waits first
for t = minSeg:n
    while qh <= qt && t - Q(qh) >= minSeg
        tau = Q(qh); qh = qh + 1;
        R(end + 1, 1) = tau; A1(end + 1, 1) = S1(tau + 1); A2(end + 1, 1) = S2(tau + 1); FA(end + 1, 1) = F(tau + 1); %#ok<AGROW>
        if slope
            At(end + 1, 1) = St(tau + 1); Att(end + 1, 1) = Stt(tau + 1); Axt(end + 1, 1) = Sxt(tau + 1); %#ok<AGROW>
        end
    end
    if isempty(R), continue; end
    nn = t - R;                                      % segment lengths, column
    sx = S1(t + 1) - A1; sxx = S2(t + 1) - A2;
    if slope
        st = St(t + 1) - At; stt = Stt(t + 1) - Att; sxt = Sxt(t + 1) - Axt;
        det = nn .* stt - st.^2;
        bb = (nn .* sxt - st .* sx) ./ det;          % slope
        aa = (sx - bb .* st) ./ nn;                  % intercept
        c = sxx - 2 * aa .* sx - 2 * bb .* sxt + nn .* aa.^2 + 2 * aa .* bb .* st + bb.^2 .* stt;
    else
        c = sxx - sx.^2 ./ nn;
    end
    c = max(c, 0);
    vals = FA + c + beta;                            % F(tau) + C(tau+1..t) + beta, one value per candidate
    [Fmin, k] = min(vals);
    F(t + 1) = Fmin;
    prev(t + 1) = R(k);
    keep = vals - beta <= Fmin;                      % prune admissible tau with F(tau) + C > F(t)
    if ~all(keep)
        R = R(keep); A1 = A1(keep); A2 = A2(keep); FA = FA(keep);
        if slope, At = At(keep); Att = Att(keep); Axt = Axt(keep); end
    end
    qt = qt + 1; Q(qt) = t;
end
% backtrack
bounds = n; tau = prev(n + 1);
while tau > 0
    bounds(end + 1) = tau; %#ok<AGROW>
    tau = prev(tau + 1);
end
bounds = flip(bounds);                               % last sample of each segment
first = [1, bounds(1:end - 1) + 1];
cp = first(2:end);
Fopt = F(n + 1);
nseg = numel(bounds);
seg = zeros(nseg, 3 + slope);
for q = 1:nseg
    a = first(q); b = bounds(q); xs = x(a:b);
    if slope
        A = [ones(b - a + 1, 1) (a:b)']; coef = A \ xs; seg(q, :) = [a b coef'];
    else
        seg(q, :) = [a b mean(xs)];
    end
end
end
