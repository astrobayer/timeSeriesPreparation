function [events, info] = detectTemplates(r, options)
%DETECTTEMPLATES  Events of the template bank in a 3-axis residual, one mask per class.
%
%   SYNTAX
%     [events, info] = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "D")
%     [events, info] = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "C", Priors = thr, Threshold = 8)
%
%   DESCRIPTION
%     The labelled template bank of QC (CONCEPT 6.1 row 2, X-17; owner
%     decisions 2026-09-26). The residual is high-passed as the bank was
%     measured, r minus its 301-s moving median; NaN samples count as 0 and
%     a window touching one is not evaluated. For each class of the bank
%     and the given satellite, a 3-axis matched filter with the unit-norm
%     template h gives c(t) = sum over axes and lags of h(l) r(t + l); its
%     robust sigma s is 1.4826 times the MAD of c over the evaluable
%     samples. Peaks of |c/s| at or above Threshold, at least one
%     template length apart (largest first), each claim their
%     neighbourhood; the positive ones are events (a negative peak, the
%     inverted shape, is none, but blocks its sidelobes, which reach 15 to
%     26 sigma for a median event) of class "impulse", axis
%     "all": amplitude (c/g) hp, the event's size at the template's
%     largest sample hp (signed, m/s^2; g = the filter output of the
%     template itself, so c/g = 1 is the bank's median event), sigma
%     (s/g) |hp|. An event
%     whose peak (lag 0, the THR1B record the bank is stacked on) lies
%     within PriorWindow_s of a prior's tStart takes its source and
%     confidence 1; the others are "unassigned" with confidence erf(score/sqrt(2)).
%     Each class has a mask over its template's support (the lags where
%     the template reaches 5 % of its peak) around every event; run adds
%     it as layer "tpl" + the class name capitalised.
%
%   INPUTS
%     r  (K,3) double   -   Residuals on x, y, z at 1 Hz, m/s^2.
%
%   OPTIONS
%     Epoch          (K,1) datetime   []    Sample epochs, UTC; required.
%     Satellite      (1,1) string     ""    Satellite of the bank ("C",
%                                           "D"); required.
%     Bank           (1,1) struct     []    A template bank; [] =
%                                           qc.templateBank().
%     Threshold      (1,1) double     [8]   Score threshold, robust sigma.
%     Priors         (N,8) table      []    qc.eventTable rows (THR1B
%                                           firings) to assign.
%     PriorWindow_s  (1,1) double     [5]   Assignment window, s.
%
%   OUTPUTS
%     events  (N,8) table    -   qc.eventTable rows of class "impulse",
%                                sorted by tStart; tStart and tEnd span
%                                the template support around the peak.
%     info    (1,1) struct   -   Fields: classes (1,C) string; layers
%                                (1,C) string, the layer names; eventClass
%                                (N,1) string, the class of each event;
%                                satellite; per class a struct with score
%                                (K,1), mask (K,1) logical, sigma (the
%                                filter's robust sigma), gain, peak (hp,
%                                m/s^2), support
%                                (1,2) s and nDetected; provenance.
%
%   ACCURACY
%     For white noise the score is standard normal away from gaps, so a
%     threshold of 8 gives about 1e-15 false peaks per sample. A planted
%     median-size thruster event in noise of 1.5e-10 m/s^2 scores about
%     100 (TestTemplates).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:detectTemplates:inputShape - r is not K x 3,
%           or Epoch is not K x 1.
%       timeSeriesPreparation:detectTemplates:inputEpoch - Epoch is missing,
%           not a datetime or not UTC.
%       timeSeriesPreparation:detectTemplates:unknownSatellite - the bank
%           has no template for Satellite.
%       timeSeriesPreparation:detectTemplates:inputRange - Threshold or
%           PriorWindow_s is not positive.
%       timeSeriesPreparation:detectTemplates:inputPriors - Priors is not a
%           qc.eventTable.
%
%   EXAMPLE
%     % A median thruster event planted in white noise is found at its epoch.
%     b = timeSeriesPreparation.qc.templateBank();
%     r = 1.5e-10 * randn(RandStream("twister", "Seed", 3), 3000, 3);
%     r(1440:1560, :) = r(1440:1560, :) + b.thruster.D;
%     t = datetime(2020, 1, 4, "TimeZone", "UTC") + seconds((0:2999)');
%     events = timeSeriesPreparation.qc.detectTemplates(r, Epoch = t, Satellite = "D");
%
%   LIMITATIONS
%     1 Hz epochs are assumed (the bank's lags are samples of 1 s). One
%     class so far, thruster; the x column is 0 on C (HANDOVER X-17).
%
%   REFERENCES
%     Turin, G. L. (1960). An introduction to matched filters. IRE Trans.
%     Inf. Theory 6, 311-329. HANDOVER X-17 (scan PR #62); docs/CONCEPT.md
%     6.1 row 2.
%
%   See also timeSeriesPreparation.qc.templateBank, timeSeriesPreparation.qc.detectImpulses, timeSeriesPreparation.qc.eventTable, timeSeriesPreparation.run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-26 19:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    r double
    options.Epoch = []
    options.Satellite (1,1) string = ""
    options.Bank = []
    options.Threshold (1,1) double = 8
    options.Priors = []
    options.PriorWindow_s (1,1) double = 5
end
[K, M] = size(r);
if ~ismatrix(r) || M ~= 3
    error("timeSeriesPreparation:detectTemplates:inputShape", "r must be K x 3 (x, y, z) -> got %s", mat2str(size(r)));
end
t = options.Epoch;
if isempty(t) || ~isdatetime(t)
    error("timeSeriesPreparation:detectTemplates:inputEpoch", "'Epoch' (K x 1 datetime, UTC) is required -> pass the sample epochs of r");
end
if ~isequal(size(t), [K 1])
    error("timeSeriesPreparation:detectTemplates:inputShape", "Epoch must be K x 1 = %d x 1 -> got %s", K, mat2str(size(t)));
end
if isempty(t.TimeZone) || ~strcmp(t.TimeZone, 'UTC')
    error("timeSeriesPreparation:detectTemplates:inputEpoch", "Epoch must carry TimeZone UTC -> set t.TimeZone = 'UTC'");
end
bank = options.Bank;
if isempty(bank), bank = timeSeriesPreparation.qc.templateBank(); end
classes = string(fieldnames(bank))';
sat = options.Satellite;
for c = classes
    if sat == "" || ~isfield(bank.(c), sat)
        error("timeSeriesPreparation:detectTemplates:unknownSatellite", "the bank has no %s template for satellite '%s' -> pass Satellite as in the bank (C, D)", c, sat);
    end
end
if ~(options.Threshold > 0) || ~(options.PriorWindow_s > 0)
    error("timeSeriesPreparation:detectTemplates:inputRange", "Threshold and PriorWindow_s must be > 0 -> got %g, %g", options.Threshold, options.PriorWindow_s);
end
priors = options.Priors;
if isempty(priors), priors = timeSeriesPreparation.qc.eventTable(); end
schema = timeSeriesPreparation.qc.eventTable().Properties.VariableNames;
if ~istable(priors) || ~isequal(priors.Properties.VariableNames, schema)
    error("timeSeriesPreparation:detectTemplates:inputPriors", "Priors must be a qc.eventTable -> build it with qc.eventTable(...)");
end

y = r - movmedian(r, 301, 1, "omitnan");
bad = any(isnan(y), 2);
y(isnan(y)) = 0;
tS = datetime.empty(0, 1); tS.TimeZone = 'UTC'; tE = tS; tP = tS;
am = zeros(0, 1); sg = zeros(0, 1); sc = zeros(0, 1); cl = strings(0, 1);
layers = strings(1, 0);
for c = classes
    h = bank.(c).(sat);
    L = size(h, 1); half = (L - 1) / 2;
    hn = h / norm(h, "fro");
    gain = sum(hn .* h, "all");
    [~, iPk] = max(abs(h(:)));
    hp = h(iPk);
    f = zeros(K, 1);
    for a = 1:3
        f = f + conv(y(:, a), flipud(hn(:, a)), "same");
    end
    blind = movmax(double(bad), [half half]) > 0;
    blind([1:min(K, half), max(1, K - half + 1):K]) = true;
    f(blind) = 0;
    s = 1.4826 * median(abs(f(~blind) - median(f(~blind))));
    if ~(s > 0), s = NaN; end
    score = f / s;
    lag = find(max(abs(h), [], 2) >= 0.05 * max(abs(h), [], "all"));
    support = [lag(1) lag(end)] - half - 1;
    cand = find(abs(score) >= options.Threshold);
    [~, o] = sort(abs(score(cand)), "descend"); cand = cand(o);
    taken = false(K, 1);
    peak = false(numel(cand), 1);
    for k = 1:numel(cand)
        q = cand(k);
        if taken(q), continue, end
        taken(max(1, q - L + 1):min(K, q + L - 1)) = true;
        peak(k) = score(q) > 0;             % an inverted shape blocks its sidelobes
    end
    q = sort(cand(peak));
    mask = false(K, 1);
    for k = 1:numel(q)
        mask(max(1, q(k) + support(1)):min(K, q(k) + support(2))) = true;
    end
    tS = [tS; t(max(1, q + support(1)))]; tE = [tE; t(min(K, q + support(2)))]; %#ok<AGROW>
    tP = [tP; t(q)]; %#ok<AGROW>
    am = [am; f(q) / gain * hp]; sg = [sg; repmat(s / gain * abs(hp), numel(q), 1)]; %#ok<AGROW>
    sc = [sc; score(q)]; cl = [cl; repmat(c, numel(q), 1)]; %#ok<AGROW>
    name = "tpl" + upper(extractBefore(c, 2)) + extractAfter(c, 1);
    layers(end+1) = name; %#ok<AGROW>
    info.(c) = struct("score", score, "mask", mask, "sigma", s, "gain", gain, "peak", hp, ...
        "support", support, "nDetected", numel(q));
end
n = numel(tS);
source = repmat("unassigned", n, 1);
conf = erf(sc / sqrt(2));
for e = 1:n
    dt = abs(seconds(priors.tStart - tP(e)));
    [dmin, p] = min(dt);
    if ~isempty(dmin) && dmin <= options.PriorWindow_s
        source(e) = priors.source(p); conf(e) = 1;
    end
end
events = timeSeriesPreparation.qc.eventTable(tS, tE, repmat("impulse", n, 1), repmat("all", n, 1), am, sg, source, conf);
[events, o] = sortrows(events, 'tStart');
info.classes = classes;
info.layers = layers;
info.eventClass = cl(o);
info.satellite = sat;
info.provenance = timeSeriesPreparation.internal.provenance("qc.detectTemplates", 'Options', struct('Satellite', sat, 'Threshold', options.Threshold, 'PriorWindow_s', options.PriorWindow_s, 'priors', height(priors), 'classes', classes));
end
