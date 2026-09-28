function res = run(arc, options)
%RUN  The instrument stages on one arc or a campaign, each run when its input is given.
%
%   SYNTAX
%     res = timeSeriesPreparation.run(arc)
%     res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg)
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
%       templates     cfg.qc.templates true, qc run on 3 columns and the
%                     arc's satellite in the bank: qc.detectTemplates on
%                     the qc residual (UTC epochs) with the THR1B firings
%                     of Thrusters as priors; each class adds its layer
%                     (info.layers, "tplThruster") and its events join
%                     flags.events (X-17).
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
%     Campaign mode (X-15, CONCEPT 6.6 and 5.2; owner decisions
%     2026-09-26). An Arc array of two or more arcs is a campaign: every
%     arc runs the stages above, and a stage that refuses on one arc stops
%     only that arc; its MException is kept and the campaign continues.
%       inputs      Reference and Thrusters may be an Arc array, QualFlags,
%                   Eclipse, User and Design a cell, with one entry per
%                   arc; any other value is shared by all arcs.
%       seeds       arc k runs with cfg.run.seed + k - 1: it equals the
%                   single run of arcs(k) with that seed. Without a Config,
%                   arc k takes Config(arcs(k)); the campaign settings come
%                   from Config(arcs(1)).
%       release     the arcs share one L1B release unless
%                   cfg.run.mixedRelease is true (Arc.requireOneRelease).
%       parallel    cfg.run.parallel = true runs the arcs in parfor when
%                   canUseParallelPool is true, else serially; the seeds
%                   make both equal. res.parallel says which ran.
%       storage     with cfg.run.outDir set, each arc's result goes to the
%                   MAT v7.3 file outDir/<mission>/<satellite>/<yyyy>/
%                   <yyyy-mm-dd>.mat (GPS date of its first epoch) as
%                   result, with schemaVersion "2" (Arc.SchemaVersion);
%                   an existing file is kept unless cfg.run.overwrite is
%                   true (status "unsaved"), and a file this campaign
%                   wrote is never overwritten. outDir/manifest.json
%                   records the campaign (software, dates, config hash and
%                   seed, a DataCite 4.7 block from cfg.export, and per
%                   arc its source files, content hash, files, SHA-256,
%                   status). "" (the default) keeps everything in memory
%                   (R5).
%       format      cfg.run.format (X-18): "mat" (default) writes the MAT
%                   day file, "netcdf" the CF/ACDD file <yyyy-mm-dd>.nc of
%                   exportNetcdf (arc, residual, events) with its PROV-O
%                   sidecar <yyyy-mm-dd>.prov.jsonld, "both" all three.
%                   NetCDF needs cfg.export.creator; without one the
%                   campaign refuses before any arc runs.
%
%   INPUTS
%     arc  (1,:) Arc   -   The observation, or two or more arcs for a
%                          campaign; the product selects the preset.
%
%   OPTIONS
%     Config     (1,1) Config            [Config(arc)]  Settings.
%     Reference  (1,:) Arc               []   Reference with arc's columns
%                                             and units (a model, a second
%                                             instrument); in a campaign
%                                             one per arc, or one shared.
%     QualFlags  (1,1) struct            []   As mask; in a campaign a
%                                             cell, one per arc, or shared.
%     Thrusters  (1,:) Arc               []   As mask (THR1B); in a
%                                             campaign one per arc, or
%                                             shared.
%     Eclipse    (1,1) struct            []   As mask; a cell per arc in a
%                                             campaign, or shared.
%     Events     (:,4) table             []   As mask.
%     Soe        (:,:) table             []   As mask.
%     User       (N,1) logical           []   As mask; a cell per arc in a
%                                             campaign, or shared.
%     Response   (L,1) double            []   Pulse template of qc.screen;
%                                             [] skips its impulse step.
%     Bias       (1,M) double            []   Preliminary bias of the
%                                             residual, as qc.residuals.
%     Scale      (M,M) double            []   Preliminary scale, as
%                                             qc.residuals.
%     Design     (N,P) double            []   Regressors for the gate; a
%                                             cell per arc in a campaign,
%                                             or shared.
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
%                                   templates (struct of events and info
%                                   of qc.detectTemplates);
%                                   residual (Arc); noise (noise's model);
%                                   gate (observability's report);
%                                   bootstrap, crossval (struct of the
%                                   result and info); fill (fill's info);
%                                   cache (K,4) table of stage, key,
%                                   status and reason. A field of a
%                                   skipped stage is [].
%       correlation  struct or []   correlate's result.
%       flags        (1,1) struct   events (N,8) qc.eventTable of the
%                                   qc and templates detections, sorted
%                                   by tStart; alignment (1,M) string,
%                                   checkAlignment's verdicts (empty if
%                                   not run); weightFraction, the mean of
%                                   arc.weights; nFilled, the rows filled.
%       config       (1,1) struct   toStruct of the settings used.
%       provenance   (1,:) struct   arc's provenance, ending with the
%                                   "run" entry (stages, skipped, cache,
%                                   configHash).
%                             A campaign returns instead:
%       results      (N,1) cell     Each arc's result as above; [] where
%                                   the arc refused.
%       summary      (N,11) table   index, day, mission, satellite, status
%                                   ("ok", "error", "unsaved"),
%                                   identifier, message, file (the MAT
%                                   file, relative to outDir), sha256,
%                                   netcdf (the .nc file), netcdfSha256.
%       errors       (N,1) cell     The MException of each refused arc, or
%                                   [].
%       manifest     struct or []   What manifest.json holds ([] without
%                                   outDir).
%       parallel     (1,1) logical  True if the arcs ran in parfor.
%
%   ACCURACY
%     Each stage's own; run adds no arithmetic but the residual, obs minus
%     (Bias + reference x Scale'), qc.residuals' formula. A stage's result
%     equals the direct call of that stage on the same inputs, bit for bit
%     (TestRun).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:run:inputCount - arc is empty; a per-arc
%           option has another count than the campaign's arcs; one arc
%           gets more than one Reference.
%       timeSeriesPreparation:run:inputFormat - cfg.run.format is not
%           "mat", "netcdf" or "both".
%       timeSeriesPreparation:run:exportMetadata - a campaign would write
%           NetCDF and cfg.export.creator is empty.
%     State:
%       timeSeriesPreparation:run:fileExists - outDir holds a manifest and
%           cfg.run.overwrite is false (the campaign refuses before any
%           arc runs); in a campaign's summary, a day file that exists.
%     The identifiers of the stages propagate; a stage that refuses stops
%     the run, or in a campaign that arc. Arc:mixedRelease propagates
%     from Arc.requireOneRelease.
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
%     qc.screen gets no impulse or jump priors from run. A campaign keeps
%     all results in memory besides writing them; the day files are not
%     locked against a second process. The report (X-11) does not exist
%     yet. The cache has no eviction and no locking (internal.stageCache).
%
%   REFERENCES
%     docs/CONCEPT.md sections 4 (result fields), 5.2 (storage), 6.1
%     (stages), 6.5 (gaps), 6.6 (campaigns); HANDOVER X-10 and X-15.
%
%   See also timeSeriesPreparation.Config, timeSeriesPreparation.internal.stageCache, timeSeriesPreparation.internal.fileSha256, timeSeriesPreparation.mask, timeSeriesPreparation.align, timeSeriesPreparation.qc.screen, timeSeriesPreparation.noise, timeSeriesPreparation.fill, timeSeriesPreparation.correlate.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc timeSeriesPreparation.Arc
        options.Config timeSeriesPreparation.Config {mustBeScalarOrEmpty} = timeSeriesPreparation.Config.empty
        options.Reference = timeSeriesPreparation.Arc.empty
        options.QualFlags = []
        options.Thrusters = []
        options.Eclipse = []
        options.Events = []
        options.Soe = []
        options.User = []
        options.Response double = []
        options.Bias double = []
        options.Scale double = []
        options.Design = []
        options.Names string = strings(1, 0)
        options.Statistic {mustBeScalarOrEmpty} = []
        options.Loss {mustBeScalarOrEmpty} = []
        options.Drivers struct = struct([])
    end

    if isempty(arc)
        error("timeSeriesPreparation:run:inputCount", "run needs at least one arc; got an empty Arc array.");
    end
    if numel(arc) > 1
        res = campaign(reshape(arc, 1, []), options);
        return
    end
    if numel(options.Reference) > 1
        error("timeSeriesPreparation:run:inputCount", ...
            "One arc takes one Reference; got %d. Pass an Arc array as arc for a campaign.", ...
            numel(options.Reference));
    end
    res = runArc(arc, options);
end

% ------------------------------------------------------------------------

function res = runArc(arc, options)
% The stages on one arc (CONCEPT 6.1): the single run, and each arc of a
% campaign.
    cfg = options.Config;
    if isempty(cfg)
        cfg = timeSeriesPreparation.Config(arc);
    end
    ref = options.Reference;
    hasRef = ~isempty(ref);

    stages = strings(1, 0);
    skipped = table(strings(0, 1), strings(0, 1), 'VariableNames', ["stage" "reason"]);
    dg = struct("stages", [], "skipped", [], "mask", [], "alignment", [], "qc", [], ...
        "templates", [], "residual", [], "noise", [], "gate", [], "bootstrap", [], "crossval", [], "fill", [], ...
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

    % 2b templates (X-17)
    bank = timeSeriesPreparation.qc.templateBank();
    if ~cfg.qc.templates
        skipped = skip(skipped, "templates", "cfg.qc.templates is false");
    elseif ~any(stages == "qc") || M ~= 3
        skipped = skip(skipped, "templates", "needs the qc stage on 3 columns");
    elseif ~all(structfun(@(b) isfield(b, arc.satellite), bank))
        skipped = skip(skipped, "templates", sprintf("the bank has no templates for satellite '%s'", arc.satellite));
    else
        [tev, tinfo] = timeSeriesPreparation.qc.detectTemplates(qinfo.residual, ...
            Epoch = utcOf(arc.t), Satellite = arc.satellite, Bank = bank, ...
            Priors = thrusterPriors(options.Thrusters));
        dg.templates = struct("events", tev, "info", tinfo);
        flags.events = sortrows([flags.events; tev], 'tStart');
        for k = 1:numel(tinfo.classes)
            arc = addLayer(arc, tinfo.layers(k), tinfo.(tinfo.classes(k)).mask);
        end
        stages(end+1) = "templates";
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

function res = campaign(arcs, options)
% Campaign mode (X-15, CONCEPT 6.6 and 5.2; owner decisions 2026-09-26).
    n = numel(arcs);
    for name = perArcOptions()
        v = options.(name);
        if (iscell(v) || (isa(v, "timeSeriesPreparation.Arc") && numel(v) > 1)) && numel(v) ~= n
            error("timeSeriesPreparation:run:inputCount", ...
                "%s has %d entries for %d arcs; pass one per arc or one shared value.", ...
                name, numel(v), n);
        end
    end
    cfg = options.Config;
    if isempty(cfg)
        cfg = timeSeriesPreparation.Config(arcs(1));
    end
    r = cfg.run;
    timeSeriesPreparation.Arc.requireOneRelease(arcs, AllowMixedRelease = logical(r.mixedRelease));
    outDir = string(r.outDir);
    overwrite = logical(r.overwrite);
    if outDir ~= "" && isfile(fullfile(outDir, "manifest.json")) && ~overwrite
        error("timeSeriesPreparation:run:fileExists", ...
            "%s already holds a campaign manifest; set cfg.run.overwrite or choose another outDir.", outDir);
    end
    fmt = string(r.format);
    if ~isscalar(fmt) || ~any(fmt == ["mat" "netcdf" "both"])
        error("timeSeriesPreparation:run:inputFormat", ...
            "cfg.run.format must be ""mat"", ""netcdf"" or ""both"".");
    end
    writeMat = fmt ~= "netcdf";
    writeNc = fmt ~= "mat";
    if outDir ~= "" && writeNc && string(cfg.export.creator) == ""
        error("timeSeriesPreparation:run:exportMetadata", ...
            "NetCDF export needs a creator; set cfg.export.creator (none is invented).");
    end

    results = cell(n, 1);
    errs = cell(n, 1);
    useParallel = logical(r.parallel) && canUseParallelPool();
    if useParallel
        parfor k = 1:n
            [results{k}, errs{k}] = tryArc(arcs(k), arcOptions(options, arcs(k), k));
        end
    else
        for k = 1:n
            [results{k}, errs{k}] = tryArc(arcs(k), arcOptions(options, arcs(k), k));
        end
    end

    day = strings(n, 1); mission = day; satellite = day; status = day;
    identifier = day; message = day; file = day; sha = day;
    ncFile = day; ncSha = day; provFile = day; provSha = day;
    written = strings(0, 1);
    for k = 1:n
        a = arcs(k);
        day(k) = gpsDay(a.t);
        mission(k) = orUnknown(a.mission);
        satellite(k) = orUnknown(a.satellite);
        if isempty(errs{k})
            status(k) = "ok";
        else
            status(k) = "error";
            identifier(k) = string(errs{k}.identifier);
            message(k) = string(errs{k}.message);
            continue
        end
        if outDir == ""
            continue
        end
        stem = strjoin([mission(k), satellite(k), extractBefore(day(k), 5), day(k)], "/");
        rels = strings(1, 0);
        if writeMat, rels(end+1) = stem + ".mat"; end %#ok<AGROW>
        if writeNc, rels = [rels, stem + ".nc", stem + ".prov.jsonld"]; end %#ok<AGROW>
        targets = fullfile(outDir, rels);
        clash = ismember(targets, written) | (isfile(targets) & ~overwrite);
        if any(clash)
            status(k) = "unsaved";
            identifier(k) = "timeSeriesPreparation:run:fileExists";
            message(k) = "the day file " + rels(find(clash, 1)) + " exists; set cfg.run.overwrite (a file this campaign wrote is never overwritten)";
            continue
        end
        try
            folder = fileparts(targets(1));
            if ~isfolder(folder)
                mkdir(folder);
            end
            if writeMat
                result = results{k}; %#ok<NASGU> saved by name
                schemaVersion = timeSeriesPreparation.Arc.SchemaVersion; %#ok<NASGU>
                save(targets(1), "result", "schemaVersion", "-v7.3");
                written(end+1, 1) = targets(1); %#ok<AGROW>
                file(k) = rels(1);
                sha(k) = timeSeriesPreparation.internal.fileSha256(targets(1));
            end
            if writeNc
                nc = timeSeriesPreparation.exportNetcdf(targets(end - 1), results{k}.arc, ...
                    Residual = results{k}.diagnostics.residual, Events = results{k}.flags.events, ...
                    Metadata = cfg.export, Overwrite = overwrite);
                written = [written; targets(end - 1); targets(end)]; %#ok<AGROW>
                ncFile(k) = rels(end - 1); ncSha(k) = nc.sha256;
                provFile(k) = rels(end); provSha(k) = nc.provSha256;
            end
        catch err
            status(k) = "unsaved";
            identifier(k) = string(err.identifier);
            message(k) = string(err.message);
        end
    end
    summary = table((1:n)', day, mission, satellite, status, identifier, message, file, sha, ...
        ncFile, ncSha, 'VariableNames', ["index" "day" "mission" "satellite" "status" ...
        "identifier" "message" "file" "sha256" "netcdf" "netcdfSha256"]);

    manifest = [];
    if outDir ~= ""
        manifest = campaignManifest(arcs, summary, cfg, useParallel, provFile, provSha);
        if ~isfolder(outDir)
            mkdir(outDir);
        end
        fid = fopen(fullfile(outDir, "manifest.json"), "w", "n", "UTF-8");
        fwrite(fid, jsonencode(manifest, PrettyPrint = true), "char");
        fclose(fid);
    end
    res = struct("results", {results}, "summary", summary, "errors", {errs}, ...
        "manifest", manifest, "parallel", useParallel);
end

function names = perArcOptions()
% Options that may carry one value per arc of a campaign.
    names = ["Reference" "Thrusters" "QualFlags" "Eclipse" "User" "Design"];
end

function o = arcOptions(options, arc, k)
% The options of arc k: its entry of each per-arc option, and the seed
% cfg.run.seed + k - 1.
    o = options;
    for name = perArcOptions()
        v = o.(name);
        if iscell(v)
            o.(name) = v{k};
        elseif isa(v, "timeSeriesPreparation.Arc") && numel(v) > 1
            o.(name) = v(k);
        end
    end
    c = o.Config;
    if isempty(c)
        c = timeSeriesPreparation.Config(arc);
    end
    o.Config = set(c, "run", "seed", c.run.seed + k - 1);
end

function [r, e] = tryArc(arc, o)
% One arc of a campaign; a refusal is kept, not raised.
    r = [];
    e = [];
    try
        r = runArc(arc, o);
    catch err
        e = err;
    end
end

function d = gpsDay(t)
% yyyy-mm-dd of the first epoch in GPS time (L1B files are GPS days).
    if isempty(t)
        d = "undated";
        return
    end
    g = datetime(2000, 1, 1, 12, 0, 0) + seconds(double(t(1)) * 1e-9);
    d = string(g, "yyyy-MM-dd");
end

function v = orUnknown(v)
    v = string(v);
    if v == ""
        v = "unknown";
    end
end

function m = campaignManifest(arcs, summary, cfg, useParallel, provFile, provSha)
% The per-campaign data-management record (CONCEPT 5.2): DataCite 4.7
% identification (X-18), PROV-style inputs, one entry per arc.
    n = numel(arcs);
    dated = summary.day(summary.day ~= "undated");
    first = ""; last = "";
    if ~isempty(dated)
        dated = sort(dated);                             % yyyy-mm-dd sorts as it counts
        first = dated(1); last = dated(end);
    end
    rows = cell(n, 1);
    for k = 1:n
        a = arcs(k);
        rows{k} = struct("index", k, "day", summary.day(k), "mission", summary.mission(k), ...
            "satellite", summary.satellite(k), "product", string(a.product), ...
            "release", string(a.release), "files", {cellstr(a.files(:)')}, ...
            "contentHash", timeSeriesPreparation.internal.contentHash(arcContent(a)), ...
            "file", summary.file(k), "sha256", summary.sha256(k), ...
            "netcdf", summary.netcdf(k), "netcdfSha256", summary.netcdfSha256(k), ...
            "prov", provFile(k), "provSha256", provSha(k), "status", summary.status(k), ...
            "identifier", summary.identifier(k), "message", summary.message(k));
    end
    title = "timeSeriesPreparation campaign, " + first + " to " + last;
    m = struct("schemaVersion", "2", ...
        "title", title, ...
        "software", struct("name", "timeSeriesPreparation", ...
            "version", timeSeriesPreparation.internal.toolboxVersion()), ...
        "created", string(datetime("now", "TimeZone", "UTC", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
        "firstDay", first, "lastDay", last, ...
        "config", struct("hash", timeSeriesPreparation.internal.contentHash(toStruct(cfg)), ...
            "seed", cfg.run.seed, "parallel", useParallel), ...
        "datacite", datacite(cfg.export, title, first, last), ...
        "arcs", vertcat(rows{:}));
end

function d = datacite(e, title, first, last)
% The DataCite Metadata Schema 4.7 properties of the campaign (mandatory:
% identifier left to the publisher, creators, titles, publisher,
% publicationYear, resourceType; plus version, rights, formats, dates).
% Arrays are cells, so one element still encodes as a JSON array.
    creator = struct("name", string(e.creator), "nameType", "Personal");
    if string(e.creatorOrcid) ~= ""
        orcid = string(e.creatorOrcid);
        if ~startsWith(orcid, "https://"), orcid = "https://orcid.org/" + orcid; end
        creator.nameIdentifiers = {struct("nameIdentifier", orcid, ...
            "nameIdentifierScheme", "ORCID", "schemeUri", "https://orcid.org")};
    end
    if string(e.institution) ~= ""
        creator.affiliation = {struct("name", string(e.institution))};
    end
    if string(e.title) ~= "", title = string(e.title); end
    d = struct("creators", {{creator}}, ...
        "titles", {{struct("title", title)}}, ...
        "publisher", struct("name", string(e.publisher)), ...
        "publicationYear", string(year(datetime("now", "TimeZone", "UTC"))), ...
        "types", struct("resourceTypeGeneral", "Dataset", ...
            "resourceType", "Prepared GRACE-FO instrument time series"), ...
        "version", timeSeriesPreparation.internal.toolboxVersion(), ...
        "rightsList", {{struct("rights", string(e.license), "rightsIdentifier", string(e.license), ...
            "rightsIdentifierScheme", "SPDX")}}, ...
        "formats", {{'application/x-matlab-data', 'application/x-netcdf', 'application/ld+json'}}, ...
        "dates", {{struct("date", first + "/" + last, "dateType", "Collected")}});
end

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

function T = thrusterPriors(thr)
% The THR1B firings (records with a positive on_time_*) as qc.eventTable
% rows, source "THR1B", from the record epoch to the end of the longest
% on-time; the empty table without Thrusters.
    T = timeSeriesPreparation.qc.eventTable();
    if isempty(thr), return, end
    on = startsWith(thr.names, "on_time_");
    onTime = thr.obs(:, on) / 1000;
    fired = any(onTime > 0, 2);
    n = nnz(fired);
    t0 = utcOf(thr.t(fired));
    T = timeSeriesPreparation.qc.eventTable(t0, t0 + seconds(max(onTime(fired, :), [], 2)), ...
        repmat("impulse", n, 1), repmat("all", n, 1), NaN(n, 1), NaN(n, 1), ...
        repmat("THR1B", n, 1), ones(n, 1));
end

function e = utcOf(t)
% UTC datetimes of int64 GPS nanoseconds past 2000-01-01 12:00:00 GPS. GPS
% was 13 s ahead of UTC then; counting in UTCLeapSeconds adds every leap
% second since, so the result is GPS minus the leap seconds of each date.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end
