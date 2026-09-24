function [events, info] = detectImpulses(r, options)
%DETECTIMPULSES  Matched-filter detection of pulses of a known shape in whitened residuals; thruster priors are assigned first.
%
%   SYNTAX
%     [events, info] = timeSeriesPreparation.qc.detectImpulses(r, Epoch = t, Response = h)
%     [events, info] = timeSeriesPreparation.qc.detectImpulses(r, Epoch = t, Response = h, Priors = thr, Threshold = 5, PriorWindow_s = 5)
%
%   DESCRIPTION
%     Each channel is correlated with the zero-mean, unit-norm template
%     hz = (h - mean h)/|h - mean h| (L samples, the pulse starting at its
%     first sample): c(t) = sum_i r(t+i-1) hz(i), score = c/sigma_c, with
%     sigma_c the robust (1.4826 MAD) scale of c. The zero-mean template is
%     blind to an offset or a level jump inside the window; only a step's
%     edge can register, once at most. The last L-1 samples are not
%     evaluable. Local maxima of |score| above Threshold, at least L
%     samples apart (the strongest wins), are pulses with amplitude
%     a = c/(hz.h), sigma_a = sigma_c/(hz.h), tStart at the peak and tEnd
%     L-1 samples later. A pulse within PriorWindow_s of a prior row (e.g.
%     THR1B firings) takes the prior's source and confidence 1; the others
%     are "unassigned" with confidence erf(|score|/sqrt(2)). NaN samples
%     count as zero in the correlation and are reported. Ported from
%     NonGravForces.qc 0.12.0 (X-05); numbers unchanged (X-05b).
%
%   INPUTS
%     r  (K,M) double   -   Whitened residuals (qc.residuals), M = 1 (axis
%                           "all") or 3 (x, y, z).
%
%   OPTIONS
%     Epoch          (K,1) datetime   []    Sample epochs, UTC; required.
%     Response       (L,1) double     []    Pulse template, 2 <= L <= K,
%                                           finite, not constant; required
%                                           (no shape is assumed).
%     Priors         (N,8) table      []    qc.eventTable rows to assign.
%     Threshold      (1,1) double     [5]   On |score|, in sigma (Gaussian
%                                           false alarm 6e-7 per sample).
%     PriorWindow_s  (1,1) double     [5]   Assignment window around a
%                                           prior epoch, s.
%
%   OUTPUTS
%     events  (N,8) table    -   qc.eventTable rows of class "impulse",
%                                sorted by tStart.
%     info    (1,1) struct   -   Fields: score, amplitude (K,M); sigmaCorr,
%                                nanCount (1,M); templateGain (hz.h);
%                                templateLength; unmatchedPriors (rows of
%                                Priors without a detection); provenance.
%
%   ACCURACY
%     Planted pulses are recovered to +-1 sample and their amplitude to
%     3 sigma_a above Threshold (measured in the ported tests). Two pulses
%     closer than L samples merge into the stronger one. A template that
%     does not match the true shape lowers the score by the cosine between
%     the shapes, never raises it.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:detectImpulses:inputShape - r is not Kx1 or
%           Kx3, or Epoch is not Kx1.
%       timeSeriesPreparation:detectImpulses:inputEpoch - Epoch is missing,
%           not a datetime, or not UTC.
%       timeSeriesPreparation:detectImpulses:inputResponse - Response is
%           missing, shorter than 2, longer than K, not finite or constant.
%       timeSeriesPreparation:detectImpulses:inputPriors - Priors is not a
%           qc.eventTable.
%       timeSeriesPreparation:detectImpulses:inputRange - Threshold or
%           PriorWindow_s is not positive.
%
%   EXAMPLE
%     % One raised-cosine pulse of 8 sigma in white noise.
%     x = 1e-9 * randn(RandStream("twister", "Seed", 3), 3000, 1);
%     h = sin(pi * (0:29)' / 30).^2; x(1000:1029) = x(1000:1029) + 8e-9 * h;
%     t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds((0:2999)');
%     events = timeSeriesPreparation.qc.detectImpulses(x, Epoch = t, Response = h);
%
%   LIMITATIONS
%     Pulses shorter than the template are unresolvable in L1B. The
%     template is the caller's; the CRN impulse response is crnKernel's.
%
%   REFERENCES
%     Turin, G. L. (1960). An introduction to matched filters. IRE Trans.
%     Inf. Theory 6, 311-329. Bandikova, T. et al. (2019) and Meyer, U. et
%     al. (2012), cited as the port cites them, not re-read.
%
%   See also timeSeriesPreparation.qc.residuals, timeSeriesPreparation.qc.eventTable, timeSeriesPreparation.qc.screen, timeSeriesPreparation.crnKernel.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    r double
    options.Epoch = []
    options.Response double = []
    options.Priors = []
    options.Threshold (1,1) double = 5
    options.PriorWindow_s (1,1) double = 5
end
[K, M] = size(r);
if ~ismatrix(r) || ~(M == 1 || M == 3)
    error("timeSeriesPreparation:detectImpulses:inputShape", "r must be Kx1 or Kx3 -> got %s (samples down the columns)", mat2str(size(r)));
end
t = options.Epoch;
if isempty(t) || ~isdatetime(t)
    error("timeSeriesPreparation:detectImpulses:inputEpoch", "'Epoch' (Kx1 datetime, UTC) is required -> pass the sample epochs of r");
end
if ~isequal(size(t), [K 1])
    error("timeSeriesPreparation:detectImpulses:inputShape", "Epoch must be Kx1 = %dx1 -> got %s", K, mat2str(size(t)));
end
if isempty(t.TimeZone) || ~strcmp(t.TimeZone, 'UTC')
    error("timeSeriesPreparation:detectImpulses:inputEpoch", "Epoch must carry TimeZone UTC -> set t.TimeZone = 'UTC'");
end
h = options.Response(:);
if numel(h) < 2 || numel(h) > K || any(~isfinite(h)) || ~any(h - h(1))
    error("timeSeriesPreparation:detectImpulses:inputResponse", "'Response' must be a finite, non-constant template of 2..K samples -> pass the CRN impulse response at the sample rate");
end
if options.Threshold <= 0 || options.PriorWindow_s <= 0
    error("timeSeriesPreparation:detectImpulses:inputRange", "Threshold and PriorWindow_s must be > 0 -> got %g, %g", options.Threshold, options.PriorWindow_s);
end
priors = options.Priors;
if isempty(priors), priors = timeSeriesPreparation.qc.eventTable(); end
schema = timeSeriesPreparation.qc.eventTable().Properties.VariableNames;
if ~istable(priors) || ~isequal(priors.Properties.VariableNames, schema)
    error("timeSeriesPreparation:detectImpulses:inputPriors", "Priors must be a qc.eventTable -> use io.readTHR1B or qc.eventTable(...)");
end
L = numel(h);
hz = h - mean(h);
hn = hz / norm(hz);                                 % zero-mean, unit-norm matched filter
hnorm = dot(hn, h);                                 % gain: a pulse a*h gives c = a * hnorm
axes = "all"; if M == 3, axes = ["x","y","z"]; end
score = zeros(K, M); amp = zeros(K, M); sigC = nan(1, M); nanCount = zeros(1, M);
tS = datetime.empty(0, 1); tS.TimeZone = 'UTC'; tE = tS; ax = string.empty(0, 1); am = zeros(0, 1); sg = zeros(0, 1); sc = zeros(0, 1);
for m = 1:M
    x = r(:, m); bad = isnan(x); nanCount(m) = nnz(bad); x(bad) = 0;
    c = zeros(K, 1);
    for i = 1:L                                     % c(t) = sum_i x(t+i-1) hz(i), zero beyond the end
        c(1:K - i + 1) = c(1:K - i + 1) + hn(i) * x(i:K);
    end
    c(K - L + 2:K) = 0;                             % a window running past the end sees the zero padding as a step: not evaluable
    fin = c(~bad);
    s = 1.4826 * median(abs(fin - median(fin)));
    if ~(s > 0), s = NaN; end
    sigC(m) = s;
    score(:, m) = c / s;
    amp(:, m) = c / hnorm;
    % local maxima of |score| above the threshold, greedy suppression within L samples
    a = abs(score(:, m)); a(bad) = 0;
    cand = find(a >= options.Threshold);
    [~, order] = sort(a(cand), 'descend'); cand = cand(order);
    taken = false(K, 1);
    for q = cand'
        if taken(q), continue; end
        lo = max(1, q - L + 1); hi = min(K, q + L - 1);
        taken(lo:hi) = true;
        tS(end + 1, 1) = t(q); tE(end + 1, 1) = t(min(K, q + L - 1)); %#ok<AGROW>
        ax(end + 1, 1) = axes(m); am(end + 1, 1) = amp(q, m); sg(end + 1, 1) = s / hnorm; sc(end + 1, 1) = a(q); %#ok<AGROW>
    end
end
n = numel(tS);
source = repmat("unassigned", n, 1);
conf = erf(sc / sqrt(2));
matched = false(height(priors), 1);
for e = 1:n
    dt = abs(seconds(priors.tStart - tS(e)));
    [dmin, p] = min(dt);
    if ~isempty(dmin) && dmin <= options.PriorWindow_s
        source(e) = priors.source(p); conf(e) = 1; matched(p) = true;
    end
end
events = timeSeriesPreparation.qc.eventTable(tS, tE, repmat("impulse", n, 1), ax, am, sg, source, conf);
events = sortrows(events, 'tStart');
info.score = score;
info.amplitude = amp;
info.sigmaCorr = sigC;
info.templateGain = hnorm;
info.templateLength = L;
info.nanCount = nanCount;
info.unmatchedPriors = priors(~matched, :);
info.provenance = timeSeriesPreparation.internal.provenance("qc.detectImpulses", 'Options', struct('Threshold', options.Threshold, 'PriorWindow_s', options.PriorWindow_s, 'L', L, 'priors', height(priors)));
end
