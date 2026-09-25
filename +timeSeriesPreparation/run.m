function res = run(arc, options)
%RUN  The instrument stages on one arc, each run when its input is given.
%
%   SYNTAX
%     res = timeSeriesPreparation.run(arc)
%     res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg)
%     res = timeSeriesPreparation.run(arc, QualFlags = aux, Thrusters = thr, Eclipse = ecl, Events = ev, Soe = soe, User = remove)
%     res = timeSeriesPreparation.run(arc, Reference = ref, Response = h, Bias = b, Scale = S, Design = X, Statistic = f, Loss = g, Drivers = series)
%
%   DESCRIPTION
%     The single point of access at instrument level (CONCEPT 4). The
%     stages of CONCEPT 6.1 run on one arc, and each runs only when its
%     input exists (owner decision 2026-09-24). A stage without its input
%     is skipped and listed with the reason in diagnostics.skipped; no input
%     is assumed. Each stage is the L2 function of the same name, called
%     with the settings of Config (default Config(arc), the preset of the
%     arc's product).
%
%     Execution order. The 6.1 table lists QC before align and align before
%     the CRN consistency stage. QC needs the reference on the observation
%     epochs, and the CRN filter needs the reference on its own raw grid, so
%     run executes those three in data order: crn, align, qc. Every other
%     stage keeps its 6.1 position. The order actually run is
%     diagnostics.stages.
%       mask          always: mask(arc, ...) with the sources given
%                     (QualFlags, Thrusters, Eclipse, Events, Soe, User)
%                     and cfg.mask. Without a source it adds only what the
%                     arc itself implies (the SNR layer of a KBR1B/LRI1B
%                     preset).
%       crn           Reference given and cfg.run.filterReference true:
%                     crnApply(ref, crnKernel(cfg.crn.preset),
%                     OutputEpochs = arc.t). A reference that is not
%                     CRN-filtered is filtered like the L1B data; whether it
%                     is, is the caller's statement ([] = not stated,
%                     skipped).
%       align         Reference given: align(arc, ref) with cfg.align (the
%                     filtered reference if crn ran), and checkAlignment
%                     with cfg.align; its lag verdicts go to flags.
%                     align's layer "alignGap" is added to arc.
%       qc            Reference given and arc with 1 or 3 columns:
%                     qc.screen on arc and the aligned reference, with
%                     Bias, Scale, Response and cfg.qc; the rows it masks
%                     on any axis form the layer "qc". Epochs are passed
%                     as UTC: GPS minus the leap seconds of the date.
%       noise         cfg.noise.order given: noise(s, order) with
%                     cfg.noise, s the residual arc (arc minus Bias + Scale
%                     x reference, with arc's layers) when a Reference is
%                     given, else arc.
%       gate          Design given: observability(arc, X) with
%                     cfg.unc.minWeightFraction. Its minimum-data refusal
%                     stops the run.
%       bootstrap     Statistic given: bootstrap(x, Statistic) with
%                     cfg.unc, x = s.obs with removed rows NaN.
%       crossval      Loss given: crossval(x, Loss) with cfg.unc.folds.
%       fill          always: fill(arc, ...) with cfg.fill. "none" reports
%                     the gaps. "collocation" fills arc with the noise
%                     model, so it needs the noise stage, and a model of
%                     arc itself: with a Reference the model is the
%                     residual's, and filling arc from it is fill's
%                     deferred method "reference", so it is skipped.
%       correlation   Drivers given, the noise stage run and
%                     cfg.drivers.maxLag given: drivers(arc, Drivers) with
%                     cfg.drivers, then correlate(s, drv, model, maxLag)
%                     with cfg.unc (NBoot, BlockLength, Level).
%     Seeds: noise, bootstrap and correlate take cfg.run.seed.
%
%     Stage cache (X-14, CONCEPT 6.6; owner decisions 2026-09-25). With
%     cfg.run.cacheDir set, the expensive stages crn, qc, noise and
%     correlation keep their outputs in cacheDir/<stage>/<key>.mat. The
%     key is the SHA-256 (internal.contentHash) of the stage, the toolbox
%     version, the stage's inputs (arcs by content, not provenance) and its
%     settings. A stored key is loaded instead of computed. Each cacheable
%     stage run gets a row in diagnostics.cache (hit, miss, rewritten,
%     unsaved, or off), and the run entry of provenance carries the table.
%     bootstrap and crossval take a function handle, which cannot be
%     hashed, so they are never cached; their row says so. The cheap
%     stages (mask, align, gate, fill) always compute. "" (the default)
%     is off (R5).
%
%   INPUTS
%     arc  (1,1) Arc   -   The observation; its product selects the preset.
%
%   OPTIONS
%     Config     (1,1) Config            [Config(arc)]  Settings.
%     Reference  (1,1) Arc               []   Reference with arc's columns
%                                             and units (a model, a second
%                                             instrument).
%     QualFlags  (1,1) struct            []   As mask.
%     Thrusters  (1,1) Arc               []   As mask (THR1B).
%     Eclipse    (1,1) struct            []   As mask.
%     Events     (:,4) table             []   As mask.
%     Soe        (:,:) table             []   As mask.
%     User       (N,1) logical           []   As mask.
%     Response   (L,1) double            []   Pulse template of qc.screen;
%                                             [] skips its impulse step.
%     Bias       (1,M) double            []   Preliminary bias of the
%                                             residual, as qc.residuals.
%     Scale      (M,M) double            []   Preliminary scale, as
%                                             qc.residuals.
%     Design     (N,P) double            []   Regressors for the gate.
%     Names      (1,P) string            []   Their names.
%     Statistic  (1,1) function_handle   []   statFcn of bootstrap.
%     Loss       (1,1) function_handle   []   lossFcn of crossval.
%     Drivers    (1,K) struct            []   series of drivers.
%
%   OUTPUTS
%     res  (1,1) struct   -   Exactly these fields, in this order (CONCEPT
%                             4; pinned by TestRun):
%       arc          (1,1) Arc      The observation with its layers,
%                                   weights and fills.
%       reference    Arc or []      The reference on arc.t ([] without one).
%       diagnostics  (1,1) struct   stages (1,:) string, the stages run in
%                                   order; skipped (K,2) table of stage and
%                                   reason; mask (mask's info); alignment
%                                   (checkAlignment's report); qc (struct
%                                   of mask, events and info of qc.screen);
%                                   residual (Arc); noise (noise's model);
%                                   gate (observability's report);
%                                   bootstrap, crossval (struct of the
%                                   result and info); fill (fill's info);
%                                   cache (K,4) table of stage, key,
%                                   status and reason. A field of a
%                                   skipped stage is [].
%       correlation  struct or []   correlate's result.
%       flags        (1,1) struct   events (N,8) qc.eventTable of the
%                                   qc detections; alignment (1,M) string,
%                                   checkAlignment's verdicts (empty if
%                                   not run); weightFraction, the mean of
%                                   arc.weights; nFilled, the rows filled.
%       config       (1,1) struct   toStruct of the settings used.
%       provenance   (1,:) struct   arc's provenance, ending with the
%                                   "run" entry (stages, skipped, cache,
%                                   configHash).
%
%   ACCURACY
%     Each stage's own; run adds no arithmetic but the residual, obs minus
%     (Bias + reference x Scale'), qc.residuals' formula. A stage's result
%     equals the direct call of that stage on the same inputs, bit for bit
%     (TestRun).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:run:campaignDeferred - arc is an array of
%           arcs; campaign mode (CONCEPT 6.6) is a later work package.
%     The identifiers of the stages propagate; a stage that refuses stops
%     the run.
%
%   EXAMPLE
%     % A 1 Hz ACT1B-like arc against its signal: mask, align, QC, gaps.
%     t = int64(0:599)' * int64(1e9);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
%     s = 1e-7 * sin(2 * pi * (0:599)' / 300);
%     x = s + 1e-9 * randn(RandStream("twister", "Seed", 1), 600, 1);
%     arc = timeSeriesPreparation.Arc(t, x, aux);
%     ref = timeSeriesPreparation.Arc(t, s, aux);
%     res = timeSeriesPreparation.run(arc, Reference = ref);
%     res.diagnostics.stages
%
%   LIMITATIONS
%     One arc per call; campaigns follow (CONCEPT 6.6). qc.screen gets no
%     impulse or jump priors from run. The report (X-11) does not exist
%     yet. The cache has no eviction and no locking (internal.stageCache).
%
%   REFERENCES
%     docs/CONCEPT.md sections 4 (result fields), 6.1 (stages), 6.5 (gaps);
%     HANDOVER X-10 (owner decisions 2026-09-24).
%
%   See also timeSeriesPreparation.Config, timeSeriesPreparation.internal.stageCache, timeSeriesPreparation.mask, timeSeriesPreparation.align, timeSeriesPreparation.qc.screen, timeSeriesPreparation.noise, timeSeriesPreparation.fill, timeSeriesPreparation.correlate.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-25 23:55 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc timeSeriesPreparation.Arc
        options.Config timeSeriesPreparation.Config {mustBeScalarOrEmpty} = timeSeriesPreparation.Config.empty
        options.Reference timeSeriesPreparation.Arc {mustBeScalarOrEmpty} = timeSeriesPreparation.Arc.empty
        options.QualFlags = []
        options.Thrusters = []
        options.Eclipse = []
        options.Events = []
        options.Soe = []
        options.User = []
        options.Response double = []
        options.Bias double = []
        options.Scale double = []
        options.Design double = []
        options.Names string = strings(1, 0)
        options.Statistic {mustBeScalarOrEmpty} = []
        options.Loss {mustBeScalarOrEmpty} = []
        options.Drivers struct = struct([])
    end

    if numel(arc) ~= 1
        error("timeSeriesPreparation:run:campaignDeferred", ...
            "run takes one arc; got %d. Campaign mode (CONCEPT 6.6) follows in a later work package.", ...
            numel(arc));
    end
    cfg = options.Config;
    if isempty(cfg)
        cfg = timeSeriesPreparation.Config(arc);
    end
    ref = options.Reference;
    hasRef = ~isempty(ref);

    stages = strings(1, 0);
    skipped = table(strings(0, 1), strings(0, 1), 'VariableNames', ["stage" "reason"]);
    dg = struct("stages", [], "skipped", [], "mask", [], "alignment", [], "qc", [], ...
        "residual", [], "noise", [], "gate", [], "bootstrap", [], "crossval", [], "fill", [], ...
        "cache", []);
    cache = struct("dir", string(cfg.run.cacheDir), "table", table(strings(0, 1), strings(0, 1), ...
        strings(0, 1), strings(0, 1), 'VariableNames', ["stage" "key" "status" "reason"]));
    flags = struct("events", timeSeriesPreparation.qc.eventTable(), ...
        "alignment", strings(1, 0), "weightFraction", NaN, "nFilled", 0);
    reference = [];
    correlation = [];

    % 1 mask
    m = cfg.mask;
    [arc, dg.mask] = timeSeriesPreparation.mask(arc, QualFlags = options.QualFlags, ...
        RemoveBits = m.removeBits, SnrFraction = orNaN(m.snrFraction), ...
        Thrusters = options.Thrusters, ThrMargin = orNaN(m.thrMargin), ...
        Eclipse = options.Eclipse, EclipseMargin = orNaN(m.eclipseMargin), ...
        Events = options.Events, Soe = options.Soe, CrnEdge = m.crnEdge, User = options.User);
    stages(end+1) = "mask";

    % 4 crn (before align: the filter needs the reference on its raw grid)
    if ~hasRef
        skipped = skip(skipped, "crn", "no Reference");
    elseif isempty(cfg.run.filterReference)
        skipped = skip(skipped, "crn", "cfg.run.filterReference not stated");
    elseif ~cfg.run.filterReference
        skipped = skip(skipped, "crn", "cfg.run.filterReference is false");
    else
        kernelPreset = cfg.crn.preset;
        refIn = ref;
        [outs, cache] = cached(cache, "crn", 1, @() timeSeriesPreparation.crnApply(refIn, ...
            timeSeriesPreparation.crnKernel(kernelPreset), OutputEpochs = arc.t), ...
            refIn, kernelPreset, arc.t);
        ref = outs{1};
        stages(end+1) = "crn";
    end

    % 3 align
    if hasRef
        a = cfg.align;
        reference = timeSeriesPreparation.align(arc, ref, Method = a.method, MaxGap = a.maxGap);
        dg.alignment = timeSeriesPreparation.checkAlignment(arc, ref, MaxLag = a.maxLag, ...
            Threshold = a.threshold, Method = a.method, MaxGap = a.maxGap);
        flags.alignment = dg.alignment.verdict;
        arc = addLayer(arc, "alignGap", reference.layers.alignGap);
        stages(end+1) = "align";
    else
        skipped = skip(skipped, "align", "no Reference");
    end

    % 2 qc
    M = size(arc.obs, 2);
    if ~hasRef
        skipped = skip(skipped, "qc", "no Reference");
    elseif ~(M == 1 || M == 3)
        skipped = skip(skipped, "qc", sprintf("qc.screen takes 1 or 3 columns; the arc has %d", M));
    else
        q = cfg.qc;
        y = arc.obs; ym = reference.obs; tq = arc.t;
        [outs, cache] = cached(cache, "qc", 3, @() timeSeriesPreparation.qc.screen(y, ym, ...
            utcOf(tq), Bias = options.Bias, Scale = options.Scale, ...
            Whitening = q.whitening, Window = q.window, HampelWindow = q.hampelWindow, ...
            HampelThreshold = q.hampelThreshold, Response = options.Response, ...
            ImpulseThreshold = q.impulseThreshold, JumpModel = q.jumpModel, ...
            JumpPenalty = q.jumpPenalty, JumpMinSegment = q.jumpMinSegment), ...
            y, ym, tq, options.Bias, options.Scale, options.Response, q);
        [qmask, events, qinfo] = outs{:};
        dg.qc = struct("mask", qmask, "events", events, "info", qinfo);
        flags.events = events;
        arc = addLayer(arc, "qc", any(qmask, 2));
        stages(end+1) = "qc";
    end

    % the series the noise model describes: the residual, or the arc itself
    if hasRef
        r = timeSeriesPreparation.qc.residuals(arc.obs, reference.obs, ...
            Bias = options.Bias, Scale = options.Scale);
        s = derive(arc, arc.t, r, "residual", struct("biasGiven", ~isempty(options.Bias), ...
            "scaleGiven", ~isempty(options.Scale)));
        for name = string(fieldnames(arc.layers))'
            s = addLayer(s, name, arc.layers.(name));
        end
        dg.residual = s;
    else
        s = arc;
    end

    % 5 noise
    nm = [];
    n = cfg.noise;
    if isempty(n.order)
        skipped = skip(skipped, "noise", "cfg.noise.order not stated");
    else
        seed = cfg.run.seed;
        sIn = s;
        [outs, cache] = cached(cache, "noise", 1, @() timeSeriesPreparation.noise(sIn, n.order, ...
            Method = n.method, MaxLag = n.maxLag, Lags = n.lags, ...
            WelchAverages = n.welchAverages, Seed = seed), sIn, n, seed);
        nm = outs{1};
        dg.noise = nm;
        stages(end+1) = "noise";
    end

    % 6 gate
    u = cfg.unc;
    if isempty(options.Design)
        skipped = skip(skipped, "gate", "no Design");
    else
        dg.gate = timeSeriesPreparation.observability(arc, options.Design, ...
            Names = options.Names, MinWeightFraction = u.minWeightFraction);
        stages(end+1) = "gate";
    end

    % 7 uncertainty
    x = s.obs;
    x(s.weights == 0 | s.filled, :) = NaN;
    if isempty(options.Statistic)
        skipped = skip(skipped, "bootstrap", "no Statistic");
    else
        [stat, binfo] = timeSeriesPreparation.bootstrap(x, options.Statistic, NBoot = u.nBoot, ...
            BlockLength = u.blockLength, Seed = cfg.run.seed, Level = u.level);
        dg.bootstrap = struct("stat", stat, "info", binfo);
        cache = uncached(cache, "bootstrap");
        stages(end+1) = "bootstrap";
    end
    if isempty(options.Loss)
        skipped = skip(skipped, "crossval", "no Loss");
    else
        [loss, cinfo] = timeSeriesPreparation.crossval(x, options.Loss, Folds = u.folds);
        dg.crossval = struct("loss", loss, "info", cinfo);
        cache = uncached(cache, "crossval");
        stages(end+1) = "crossval";
    end

    % 8 fill
    f = cfg.fill;
    if f.method == "collocation" && isempty(nm)
        skipped = skip(skipped, "fill", "collocation needs the noise stage (cfg.noise.order)");
    elseif f.method == "collocation" && hasRef
        skipped = skip(skipped, "fill", "the noise model is the residual's; filling arc " + ...
            "from it is fill's deferred method ""reference""");
    else
        [arc, dg.fill] = timeSeriesPreparation.fill(arc, Method = f.method, Model = nm, ...
            MaxGap = f.maxGap, Window = f.window);
        stages(end+1) = "fill";
    end

    % 9 correlation
    d = cfg.drivers;
    if isempty(options.Drivers)
        skipped = skip(skipped, "correlation", "no Drivers");
    elseif isempty(nm)
        skipped = skip(skipped, "correlation", "pre-whitening needs the noise stage (cfg.noise.order)");
    elseif isempty(d.maxLag)
        skipped = skip(skipped, "correlation", "cfg.drivers.maxLag not stated");
    else
        seed = cfg.run.seed;
        sIn = s; tc = arc.t; series = options.Drivers;
        [outs, cache] = cached(cache, "correlation", 1, @() correlationStage(arc, sIn, ...
            series, nm, d, u, seed), sIn, tc, series, nm, d, u, seed);
        correlation = outs{1};
        stages(end+1) = "correlation";
    end

    dg.stages = stages;
    dg.skipped = skipped;
    dg.cache = cache.table;
    flags.weightFraction = mean(arc.weights);
    flags.nFilled = nnz(arc.filled);
    c = toStruct(cfg);
    arc = appendProvenance(arc, "run", struct("stages", stages, "skipped", skipped.stage', ...
        "cache", cache.table, ...
        "configHash", string(lower(dec2hex(timeSeriesPreparation.internal.stageSeed( ...
        string(jsonencode(c)), 0), 8)))));

    res = struct("arc", arc, "reference", [], "diagnostics", dg, "correlation", [], ...
        "flags", flags, "config", c, "provenance", arc.provenance);
    res.reference = reference;
    res.correlation = correlation;
end

% ------------------------------------------------------------------------

function [outs, cache] = cached(cache, stage, nOut, compute, varargin)
% One cacheable stage (X-14): with cache.dir "" it only computes; otherwise
% its key is the SHA-256 of stage, toolbox version and the given inputs
% and settings, and internal.stageCache loads or computes and stores.
    if cache.dir == ""
        outs = cell(1, nOut);
        [outs{:}] = compute();
        cache.table(end+1, :) = {stage, "", "off", "cfg.run.cacheDir is empty"};
        return
    end
    for k = 1:numel(varargin)
        if isa(varargin{k}, "timeSeriesPreparation.Arc")
            varargin{k} = arcContent(varargin{k});
        end
    end
    key = timeSeriesPreparation.internal.contentHash(stage, ...
        timeSeriesPreparation.internal.toolboxVersion(), varargin{:});
    [outs, status] = timeSeriesPreparation.internal.stageCache(cache.dir, stage, key, nOut, compute);
    reasons = dictionary(["hit" "miss" "rewritten" "unsaved"], ["loaded from " + stage + "/" + key + ".mat", ...
        "computed and stored", "unreadable file recomputed and stored", "computed; storing failed"]);
    cache.table(end+1, :) = {stage, key, status, reasons(status)};
end

function c = arcContent(arc)
% An Arc as the struct its cache key is built from: the content, without
% the provenance (it carries creation times). internal.contentHash is L0
% and refuses objects (CONCEPT 3.2).
    c = struct("class", "timeSeriesPreparation.Arc", "arcs", {cell(size(arc))});
    for k = 1:numel(arc)
        a = arc(k);
        c.arcs{k} = struct("t", a.t, "obs", a.obs, "names", a.names, "units", a.units, ...
            "weights", a.weights, "layers", a.layers, "filled", a.filled);
    end
end

function cache = uncached(cache, stage)
% bootstrap and crossval take a caller's function handle; its behaviour
% cannot be hashed, so they always compute (owner decision 2026-09-25).
    cache.table(end+1, :) = {string(stage), "", "not cached", "function-handle input"};
end

function res = correlationStage(arc, s, series, nm, d, u, seed)
% drivers onto arc.t, then correlate: the correlation stage as one unit.
    drv = timeSeriesPreparation.drivers(arc, series, Method = d.method, MaxGap = d.maxGap);
    res = timeSeriesPreparation.correlate(s, drv, nm, d.maxLag, NBoot = u.nBoot, ...
        BlockLength = u.blockLength, Seed = seed, Level = u.level);
end

function v = orNaN(v)
% mask's sentinel for "the preset": NaN where the Config leaves a value empty.
    if isempty(v), v = NaN; end
end

function T = skip(T, stage, reason)
    T(end+1, :) = {string(stage), string(reason)};
end

function e = utcOf(t)
% UTC datetimes of int64 GPS nanoseconds past 2000-01-01 12:00:00 GPS. GPS
% was 13 s ahead of UTC then; counting in UTCLeapSeconds adds every leap
% second since, so the result is GPS minus the leap seconds of each date.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end
