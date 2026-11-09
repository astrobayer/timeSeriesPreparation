function [mask, events, info] = screen(y_meas, y_model, epoch, options)
%SCREEN  Quality-control orchestrator: residuals, outliers, impulses, jumps, then the mask and the event table.
%
%   SYNTAX
%     [mask, events, info] = timeSeriesPreparation.qc.screen(y_meas, y_model, epoch)
%     [mask, events, info] = timeSeriesPreparation.qc.screen(y_meas, y_model, epoch, Response = crn, Thrusters = thr, Priors = ecl)
%
%   DESCRIPTION
%     1. r = qc.residuals(y_meas, y_model, Bias, Scale, Whitening, Window).
%     2. Outliers: qc.hampel(r, HampelWindow, HampelThreshold).
%     3. Impulses, skipped (and said so in info) without a Response, since
%        no pulse shape is assumed: qc.detectImpulses on the residual with
%        only the isolated outliers (runs of at most 2 samples) replaced by
%        the local median. Hampel also flags the peaks of a strong pulse,
%        in runs of several samples; replacing those would destroy the
%        pulse, while a one- or two-sample spike must not reach the matched
%        filter. Detected pulses claim their samples (their outlier flags
%        are withdrawn) and are blanked before the jump search.
%     4. Jumps: qc.detectJumps with JumpModel, JumpPenalty, JumpMinSegment
%        and Priors, on the residual with outliers replaced and pulses
%        blanked.
%     mask marks outliers and the samples spanned by impulses; jumps are
%     reported, never masked. events is the three detectors' event table,
%     sorted by tStart. Ported from NonGravForces.qc 0.12.0 (X-05); numbers
%     unchanged (X-05b, X-16).
%
%   INPUTS
%     y_meas   (K,M) double     -   Measured observable, M = 1 or 3.
%     y_model  (K,M) double     -   Modelled observable.
%     epoch    (K,1) datetime   -   Sample epochs, UTC.
%
%   OPTIONS
%     Bias              (1,M) double   [zeros]    As qc.residuals.
%     Scale             (M,M) double   [eye]      As qc.residuals.
%     Whitening         (1,1) string   ["none"]   As qc.residuals.
%     Window            (1,1) double   []         As qc.residuals.
%     HampelWindow      (1,1) double   [61]       Samples.
%     HampelThreshold   (1,1) double   [4]        Sigma.
%     Response          (L,1) double   []         Pulse template; [] skips
%                                                 the impulse step.
%     Thrusters         (N,8) table    []         Impulse priors
%                                                 (qc.eventTable).
%     ImpulseThreshold  (1,1) double   [5]        Sigma.
%     Priors            (N,8) table    []         Jump priors (eclipse,
%                                                 MAS1B).
%     JumpModel         (1,1) string   ["level"]  "level" or "slope".
%     JumpPenalty       (1,1) double   []         Default BIC.
%     JumpMinSegment    (1,1) double   [30]       Samples: the CRN width;
%                                                 shorter level changes are
%                                                 pulses or outliers.
%
%   OUTPUTS
%     mask    (K,M) logical   -   True = do not use the sample.
%     events  (N,8) table     -   qc.eventTable of all detections.
%     info    (1,1) struct    -   Fields: residual (whitened, untouched);
%                                 residualClean (outliers replaced, pulses
%                                 NaN); residualInfo; outliers (after the
%                                 pulses claimed theirs); isolatedOutliers;
%                                 impulses, jumps (detector infos, or
%                                 "skipped: ..."); counts (outlier,
%                                 impulse, jump); provenance.
%
%   ACCURACY
%     The composition of the four units; see theirs. A level step may
%     register once as an impulse candidate at its edge; the jump is then
%     located at the end of that window, up to L samples late. On the
%     ported tests' synthetic day (2 pulses, 1 step, 1 spike in 3000 white
%     samples) the spike and both pulses are masked and the step is
%     reported once.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:screen:inputShape - y_meas and y_model are
%           not Kx1 or Kx3 of one size, or epoch is not a Kx1 datetime.
%       timeSeriesPreparation:screen:inputEpoch - epoch is not UTC.
%     The identifiers of qc.residuals, qc.hampel, qc.detectImpulses and
%     qc.detectJumps propagate.
%
%   EXAMPLE
%     % A spike and a step in white noise, no pulse template.
%     x = 1e-9 * randn(RandStream("twister", "Seed", 4), 3000, 1);
%     x(700) = 3e-8; x(2500:end) = x(2500:end) + 5e-9;
%     t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds((0:2999)');
%     [mask, events] = timeSeriesPreparation.qc.screen(x, zeros(3000, 1), t);
%
%   LIMITATIONS
%     One arc at a time; the order of the steps is fixed.
%
%   REFERENCES
%     NonGravForces.qc 0.12.0 (3cc0123); docs/CONCEPT.md 6.1, row 2.
%
%   See also timeSeriesPreparation.qc.residuals, timeSeriesPreparation.qc.hampel, timeSeriesPreparation.qc.detectImpulses, timeSeriesPreparation.qc.detectJumps, timeSeriesPreparation.qc.eventTable, timeSeriesPreparation.mask.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-26 07:45 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    y_meas double
    y_model double
    epoch
    options.Bias double = []
    options.Scale double = []
    options.Whitening (1,1) string = "none"
    options.Window double = []
    options.HampelWindow (1,1) double = 61
    options.HampelThreshold (1,1) double = 4
    options.Response double = []
    options.Thrusters = []
    options.ImpulseThreshold (1,1) double = 5
    options.Priors = []
    options.JumpModel (1,1) string = "level"
    options.JumpPenalty double = []
    options.JumpMinSegment (1,1) double = 30
end
[K, M] = size(y_meas);
if ~ismatrix(y_meas) || ~isequal(size(y_meas), size(y_model)) || ~(M == 1 || M == 3)
    error("timeSeriesPreparation:screen:inputShape", "y_meas and y_model must be Kx1 or Kx3 of the same size -> got %s and %s", mat2str(size(y_meas)), mat2str(size(y_model)));
end
if ~isdatetime(epoch) || ~isequal(size(epoch), [K 1])
    error("timeSeriesPreparation:screen:inputShape", "epoch must be a Kx1 datetime -> got %s", class(epoch));
end
if isempty(epoch.TimeZone) || ~strcmp(epoch.TimeZone, 'UTC')
    error("timeSeriesPreparation:screen:inputEpoch", "epoch must carry TimeZone UTC -> set epoch.TimeZone = 'UTC'");
end
[r, rinfo] = timeSeriesPreparation.qc.residuals(y_meas, y_model, 'Bias', options.Bias, 'Scale', options.Scale, 'Whitening', options.Whitening, 'Window', options.Window);
[outl, hinfo] = timeSeriesPreparation.qc.hampel(r, 'Window', options.HampelWindow, 'Threshold', options.HampelThreshold);
% isolated outliers: flagged runs of at most 2 samples (a spike); longer runs may be the peaks of a pulse
isolated = false(K, M);
for m = 1:M
    d = diff([false; outl(:, m); false]); starts = find(d == 1); ends = find(d == -1) - 1;
    for q = reshape(find(ends - starts + 1 <= 2), 1, [])
        isolated(starts(q):ends(q), m) = true;
    end
end
rc = r; rc(outl) = hinfo.median(outl);              % all outliers replaced: the jump search sees no spikes and no pulse peaks
ri = r; ri(isolated) = hinfo.median(isolated);      % only spikes replaced: the matched filter sees the pulses intact
axes = "all"; if M == 3, axes = ["x","y","z"]; end
pulseMask = false(K, M);
info.isolatedOutliers = isolated;
if isempty(options.Response)
    evI = timeSeriesPreparation.qc.eventTable(); info.impulses = "skipped: no Response given";
else
    L = numel(options.Response);
    [evI, iinfo] = timeSeriesPreparation.qc.detectImpulses(ri, 'Epoch', epoch, 'Response', options.Response, 'Priors', options.Thrusters, 'Threshold', options.ImpulseThreshold);
    info.impulses = iinfo;
    [~, first] = ismember(evI.tStart, epoch);       % the first sample of each pulse (lowest index, as find(.., 1))
    for e = 1:height(evI)
        q = first(e);
        cols = 1:M; if M == 3, cols = find(axes == evI.axis(e)); end
        span = q:min(K, q + L - 1);
        pulseMask(span, cols) = true;
        outl(span, cols) = false;                     % the pulse owns its samples
        rc(span, cols) = r(span, cols);               % restore, then blank for the jump search
        rc(span, cols) = NaN;
    end
end
mask = outl | pulseMask;
% outlier events: one row per flagged sample
[iK, iM] = find(outl);
tO = epoch(iK); amO = r(outl) - hinfo.median(outl); sgO = hinfo.sigma(outl);
evO = timeSeriesPreparation.qc.eventTable(tO, tO, repmat("outlier", numel(iK), 1), axes(iM)', amO, sgO, repmat("unassigned", numel(iK), 1), min(1, abs(amO) ./ max(sgO, realmin) / options.HampelThreshold));
jargs = {'Epoch', epoch, 'Model', options.JumpModel, 'Priors', options.Priors, 'MinSegment', options.JumpMinSegment};
if ~isempty(options.JumpPenalty), jargs = [jargs, {'Penalty', options.JumpPenalty}]; end
[evJ, jinfo] = timeSeriesPreparation.qc.detectJumps(rc, jargs{:});
info.jumps = jinfo;
events = sortrows([evO; evI; evJ], 'tStart');
info.residual = r;
info.residualClean = rc;
info.residualInfo = rinfo;
info.outliers = outl;
info.counts = struct('outlier', height(evO), 'impulse', height(evI), 'jump', height(evJ));
info.provenance = timeSeriesPreparation.internal.provenance("qc.screen", 'Options', struct('Whitening', options.Whitening, 'Window', options.Window, 'HampelWindow', options.HampelWindow, 'HampelThreshold', options.HampelThreshold, 'ImpulseThreshold', options.ImpulseThreshold, 'JumpModel', options.JumpModel, 'JumpMinSegment', options.JumpMinSegment, 'responseGiven', ~isempty(options.Response)));
end
