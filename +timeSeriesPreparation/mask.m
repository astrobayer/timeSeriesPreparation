function [arc, info] = mask(arc, options)
%MASK  Named removal layers from flags, event lists, thrusters, eclipse, SNR and the caller.
%
%   SYNTAX
%     [arc, info] = timeSeriesPreparation.mask(arc)
%     [arc, info] = timeSeriesPreparation.mask(arc, QualFlags = aux, Thrusters = thr, Events = ev)
%     [arc, info] = timeSeriesPreparation.mask(arc, Soe = soe, Eclipse = ecl, User = remove)
%
%   DESCRIPTION
%     Stage 1 of CONCEPT 6.1. Each source below becomes one named layer of
%     the arc (true = remove, Arc.addLayer), so a sample's weight is 0 as
%     soon as one layer removes it and every removal keeps its reason. A
%     source that is not given adds no layer. Product defaults come from
%     Config(arc).mask (owner decisions 2026-09-24):
%       - qualflg: aux of the same file(s) (readL1b / readL1bMulti) is
%         decoded with gracefoReading.decodeQualFlags, whose bit meanings
%         are the file header's own. Each bit in RemoveBits becomes a layer
%         "qualflg_b<k>". The presets remove the phase break (KBR1B and
%         LRI1B bit 0) and the L1B fill flags, "interpolated data point
%         (due to gap)" (ACT1B and ACH1B bits 5-7, KBR1B and LRI1B bits 6-7; classic
%         GRACE ACC1B bits 5-7, "filled data", JPL D-22027 4.3.2). Every
%         other bit is reported in info.qualflg and removes nothing: the
%         ACT1B clock-offset extrapolation (bits 3/4), the KBR1B time-tag
%         bias correction (bit 5), the ACT1B Vp and residual bits (0, 2).
%       - snr: every observation whose name contains "SNR" and whose
%         median is positive; a sample is removed where one of them is
%         below SnrFraction times its median over the arc (layer "snr";
%         preset 0.5 for KBR1B and LRI1B, provisional).
%       - Thrusters: a THR1B Arc; every record with a positive on_time_*
%         removes [t - ThrMargin, t + max on-time + ThrMargin] (layer
%         "thr"). The default margin is half the fit interval Tf of the
%         product's CRN preset (crnKernel: 70.35 s ACC, 35.35 s KBR), the
%         reach of a filtered firing.
%       - Eclipse: a driver series (t, value in [0, 1], the illuminated
%         fraction). Every sample of it strictly inside (0, 1), and every
%         step between two samples whose values differ, is a transition;
%         the transitions widened by EclipseMargin (default as ThrMargin)
%         are removed (layer "eclipse").
%       - Events and Soe: official event lists (G-05). Events is a table
%         of windows the caller states (tStart, tEnd int64 GPS ns, source,
%         text), for instance a TN-01a entry, whose prose is never parsed
%         here. Soe is gracefoReading.readEventList's TN-01 table
%         (TimeFormat "mjd"): its enabled MANV rows of the arc's
%         satellite (both for "Y") become windows [epoch, epoch +
%         values(1) s]. That values(1) is the duration was measured: the
%         first GRACE-C MANV row (2018-05-24, 127 s) is TN-01a's
%         "calibration maneuver from 06:19:26 to 06:21:33" to the second.
%         All windows remove (layer "events") and are returned as
%         calibration windows in info.windows.
%       - CrnEdge: samples within half the CRN fit interval of a gap
%         (a step above 1.5 median steps) are removed (layer "crnEdge").
%         Off by default: an L1B product already stops where its filter
%         window runs out.
%       - User: an N x 1 logical of the caller (layer "user").
%     Jumps are never masked here; they are qc's (CONCEPT 6.1, row 2).
%
%   INPUTS
%     arc  (1,1) Arc   -   The arc to mask; its product selects the preset.
%
%   OPTIONS
%     QualFlags      (1,1) struct   [none]     aux of readL1b/readL1bMulti
%                                              for the same rows as arc.
%     RemoveBits     (1,:) double   [preset]   qualflg bits that remove;
%                                              [] removes none.
%     SnrFraction    (1,1) double   [preset]   Threshold as a fraction of
%                                              the median SNR; NaN = no
%                                              "snr" layer.
%     Thrusters      (1,1) Arc      [none]     THR1B arc (on_time_* in
%                                              milliseconds).
%     ThrMargin      (1,1) double   [preset]   Seconds added on each side
%                                              of a firing.
%     Eclipse        (1,1) struct   [none]     Fields t (int64 GPS ns,
%                                              increasing) and value.
%     EclipseMargin  (1,1) double   [preset]   Seconds added on each side
%                                              of a transition.
%     Events         (K,4) table    [none]     tStart, tEnd, source, text.
%     Soe            (J,8) table    [none]     TN-01 rows, TimeFormat "mjd".
%     CrnEdge        (1,1) logical  [preset]   Add the "crnEdge" layer.
%     User           (N,1) logical  [none]     The caller's layer.
%
%   OUTPUTS
%     arc   (1,1) Arc      -   The arc with the new layers and a "mask"
%                              provenance entry.
%     info  (1,1) struct   -   Fields: layers (table: name, removed,
%                              source); qualflg (table from decodeQualFlags
%                              plus removes, or empty); snr (table: column,
%                              median, threshold, removed); thrusters
%                              (firings, margin); eclipse (transitions,
%                              margin); windows (table: tStart, tEnd,
%                              source, text); settings (struct of the
%                              values used).
%
%   ACCURACY
%     Exact: layers are comparisons of int64 epochs and of the stored
%     values; margins are rounded to whole nanoseconds.
%
%   ERRORS
%     Inputs:
%       timeSeriesPreparation:mask:sizeMismatch - QualFlags or User does not
%           have one row per epoch of arc.
%       timeSeriesPreparation:mask:badThrusters - Thrusters has no
%           on_time_* column or its unit is not milliseconds.
%       timeSeriesPreparation:mask:badEclipse - Eclipse lacks t or value, t
%           is not an increasing int64 column, or value is outside [0, 1].
%       timeSeriesPreparation:mask:badEvents - Events or Soe lacks a
%           variable, or a window ends before it starts.
%       timeSeriesPreparation:mask:marginMissing - a margin is needed but
%           the product has no CRN preset to derive it from; give it.
%     QualFlags without gracefoReading on the path is refused by
%     internal.requirePackage on mask's behalf (depMissing). A layer name that already exists (mask run twice on one arc) is
%     refused by Arc.addLayer with timeSeriesPreparation:Arc:badLayer.
%
%   EXAMPLE
%     % A user layer on a ten-sample arc; weights follow the layers.
%     t = int64(0:9)' * int64(1e9);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'gps_time', 'lin_accl_x'}}, "variableFieldNames", {{'gps_time', 'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     arc = timeSeriesPreparation.Arc(t, zeros(10, 1), aux);
%     [arc, info] = timeSeriesPreparation.mask(arc, User = (1:10)' > 8);
%
%   LIMITATIONS
%     Classic GRACE qualflg is decoded as GRACE-FO's (a byte read as a bit
%     string; meanings from gracefoReading >= 1.3.0, D-22027 chapter 6).
%     The THR1B margin of classic ACC1B uses the "ACC" preset, whose span
%     is open for classic L1B (V-1). LRI has no CRN preset (V-2), so its
%     margins must be given. TN-01a windows are the caller's reading of
%     the list.
%
%   REFERENCES
%     docs/CONCEPT.md 6.1 row 1; GRACE-FO L1 Data Product User Handbook,
%     JPL D-56935 (R-2), PDF pp. 18, 20 (L1B gap filling); the qualflg
%     meanings printed in the RL04 file headers; GRACE Level-1B Data
%     Product User Handbook, JPL D-22027 v1.3, 4.3.2 and 6.2 (classic
%     ACC1B); TN-01, TN-01a (D-4);
%     HANDOVER X-05 (D-9, owner decisions 2026-09-24).
%
%   See also timeSeriesPreparation.Arc, timeSeriesPreparation.Config, timeSeriesPreparation.qc.screen, gracefoReading.decodeQualFlags, gracefoReading.readEventList.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-10-20 12:40 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        options.QualFlags = []
        options.RemoveBits double = NaN
        options.SnrFraction (1,1) double = -1
        options.Thrusters = []
        options.ThrMargin (1,1) double = NaN
        options.Eclipse = []
        options.EclipseMargin (1,1) double = NaN
        options.Events = []
        options.Soe = []
        options.CrnEdge logical {mustBeScalarOrEmpty} = logical.empty
        options.User = []
    end

    cfg = timeSeriesPreparation.Config(arc).mask;
    N = numel(arc.t);
    used = struct();
    layerNames = strings(0, 1); removed = zeros(0, 1); sources = strings(0, 1);
    info = struct("layers", [], "qualflg", table(), "snr", table(), ...
        "thrusters", struct("firings", 0, "margin", NaN), ...
        "eclipse", struct("transitions", 0, "margin", NaN), ...
        "windows", emptyWindows(), "settings", []);

    % qualflg
    if ~isempty(options.QualFlags)
        timeSeriesPreparation.internal.requirePackage("gracefoReading", "mask");
        [bits, report] = gracefoReading.decodeQualFlags(options.QualFlags);
        if size(bits, 1) ~= N
            error("timeSeriesPreparation:mask:sizeMismatch", ...
                "QualFlags holds %d records, the arc %d epochs; pass the aux of the same file(s).", ...
                size(bits, 1), N);
        end
        rb = options.RemoveBits;
        if isscalar(rb) && isnan(rb), rb = cfg.removeBits; end
        rb = reshape(rb, 1, []);
        report.removes = ismember(report.bit, rb);
        for b = rb(rb + 1 <= size(bits, 2))
            [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
                "qualflg_b" + b, bits(:, b + 1), "qualflg bit " + b + ": " + report.meaning(b + 1));
        end
        info.qualflg = report;
        used.removeBits = rb;
    end

    % snr
    f = options.SnrFraction;
    if f == -1, f = cfg.snrFraction; end
    if isempty(f), f = NaN; end
    used.snrFraction = f;
    cols = find(contains(arc.names, "SNR", "IgnoreCase", true));
    if ~isnan(f) && ~isempty(cols)
        low = false(N, 1);
        rows = struct("column", strings(0, 1), "median", zeros(0, 1), "threshold", zeros(0, 1), "removed", zeros(0, 1));
        for c = cols
            x = arc.obs(:, c);
            m = median(x, "omitnan");
            if ~(m > 0), continue; end
            hit = x < f * m;
            low = low | hit;
            rows.column(end+1, 1) = arc.names(c); rows.median(end+1, 1) = m;
            rows.threshold(end+1, 1) = f * m; rows.removed(end+1, 1) = nnz(hit);
        end
        info.snr = struct2table(rows);
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "snr", low, sprintf("SNR below %.3g of its median", f));
    end

    % thrusters
    if ~isempty(options.Thrusters)
        thr = options.Thrusters;
        if ~isa(thr, "timeSeriesPreparation.Arc")
            error("timeSeriesPreparation:mask:badThrusters", "Thrusters must be a THR1B Arc.");
        end
        on = startsWith(thr.names, "on_time_");
        if ~any(on) || ~all(ismember(lower(thr.units(on)), ["milliseconds" "ms"]))
            error("timeSeriesPreparation:mask:badThrusters", ...
                "Thrusters needs on_time_* columns in milliseconds; got %s.", ...
                strjoin(thr.names(on) + " [" + thr.units(on) + "]", ", "));
        end
        margin = resolveMargin(options.ThrMargin, cfg.thrMargin, arc, "ThrMargin");
        onTime = thr.obs(:, on) / 1000;
        fired = any(onTime > 0, 2);
        lo = thr.t(fired) - ns(margin);
        hi = thr.t(fired) + ns(max(onTime(fired, :), [], 2)) + ns(margin);
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "thr", inWindows(arc.t, lo, hi), sprintf("THR1B firing +- %.4g s", margin));
        info.thrusters = struct("firings", nnz(fired), "margin", margin);
        used.thrMargin = margin;
    end

    % eclipse transitions
    if ~isempty(options.Eclipse)
        e = options.Eclipse;
        if ~isstruct(e) || ~all(isfield(e, ["t" "value"])) || ~isa(e.t, "int64") || ~iscolumn(e.t) ...
                || any(diff(e.t) <= 0) || ~isequal(size(e.value), size(e.t)) ...
                || any(e.value < 0 | e.value > 1)
            error("timeSeriesPreparation:mask:badEclipse", ...
                "Eclipse must have an increasing int64 column t and a value of its size in [0, 1].");
        end
        margin = resolveMargin(options.EclipseMargin, cfg.eclipseMargin, arc, "EclipseMargin");
        v = double(e.value);
        part = find(v > 0 & v < 1);
        step = find(diff(v) ~= 0);
        lo = [e.t(part); e.t(step)] - ns(margin);
        hi = [e.t(part); e.t(step + 1)] + ns(margin);
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "eclipse", inWindows(arc.t, lo, hi), sprintf("eclipse transition +- %.4g s", margin));
        info.eclipse = struct("transitions", numel(part) + numel(step), "margin", margin);
        used.eclipseMargin = margin;
    end

    % official event lists
    windows = emptyWindows();
    if ~isempty(options.Events)
        ev = options.Events;
        if ~istable(ev) || ~all(ismember(["tStart" "tEnd" "source" "text"], ev.Properties.VariableNames)) ...
                || ~isa(ev.tStart, "int64") || ~isa(ev.tEnd, "int64") || any(ev.tEnd < ev.tStart)
            error("timeSeriesPreparation:mask:badEvents", ...
                "Events must be a table with int64 tStart <= tEnd (GPS ns), source and text.");
        end
        windows = [windows; table(ev.tStart, ev.tEnd, string(ev.source), string(ev.text), ...
            'VariableNames', ["tStart" "tEnd" "source" "text"])];
    end
    if ~isempty(options.Soe)
        windows = [windows; soeWindows(options.Soe, arc.satellite)];
    end
    if height(windows) > 0
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "events", inWindows(arc.t, windows.tStart, windows.tEnd), ...
            sprintf("%d official event window(s)", height(windows)));
    end
    inside = windows.tEnd >= arc.t(1) & windows.tStart <= arc.t(end);
    info.windows = windows(inside, :);

    % CRN edges at gaps
    edge = options.CrnEdge;
    if isempty(edge), edge = cfg.crnEdge; end
    used.crnEdge = edge;
    if edge && N > 1
        margin = resolveMargin(NaN, [], arc, "CrnEdge half span");
        dt = diff(arc.t);
        g = find(double(dt) > 1.5 * median(double(dt)));
        lo = [arc.t(g) - ns(margin); arc.t(g + 1)];
        hi = [arc.t(g); arc.t(g + 1) + ns(margin)];
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "crnEdge", inWindows(arc.t, lo, hi), sprintf("within %.4g s of a gap", margin));
    end

    % user
    if ~isempty(options.User)
        u = options.User;
        if ~islogical(u) || ~isequal(size(u), [N 1])
            error("timeSeriesPreparation:mask:sizeMismatch", ...
                "User must be an %d x 1 logical; got %s %s.", N, class(u), mat2str(size(u)));
        end
        [arc, layerNames, removed, sources] = add(arc, layerNames, removed, sources, ...
            "user", u, "caller");
    end

    info.layers = table(layerNames, removed, sources, 'VariableNames', ["name" "removed" "source"]);
    info.settings = used;
    arc = appendProvenance(arc, "mask", struct("layers", layerNames', "settings", used));
end

% ------------------------------------------------------------------------

function [arc, names, removed, sources] = add(arc, names, removed, sources, name, remove, source)
% One layer onto the arc and into the summary.
    arc = addLayer(arc, name, remove);
    names(end+1, 1) = name;
    removed(end+1, 1) = nnz(remove);
    sources(end+1, 1) = source;
end

function remove = inWindows(t, lo, hi)
% True for every epoch of t inside one of the closed windows [lo(k), hi(k)].
% t is sorted, so each window is two binary searches over it.
    remove = false(size(t));
    for k = 1:numel(lo)
        a = find(t >= lo(k), 1, "first");
        b = find(t <= hi(k), 1, "last");
        if ~isempty(a) && ~isempty(b) && a <= b
            remove(a:b) = true;
        end
    end
end

function n = ns(seconds)
% Seconds as int64 nanoseconds, rounded.
    n = int64(round(seconds * 1e9));
end

function margin = resolveMargin(given, preset, arc, what)
% The margin in seconds: given, else the preset, else half the CRN fit
% interval of the product's CRN preset.
    margin = given;
    if isnan(margin) && ~isempty(preset), margin = preset; end
    if isnan(margin)
        crn = timeSeriesPreparation.Config(arc).crn.preset;
        if crn == ""
            error("timeSeriesPreparation:mask:marginMissing", ...
                "%s: product %s has no CRN preset to derive the margin from; give it in seconds.", ...
                what, arc.product);
        end
        margin = timeSeriesPreparation.crnKernel(crn).Tf / 2;
    end
end

function w = emptyWindows()
    w = table(int64.empty(0, 1), int64.empty(0, 1), strings(0, 1), strings(0, 1), ...
        'VariableNames', ["tStart" "tEnd" "source" "text"]);
end

function w = soeWindows(soe, satellite)
% Windows of the enabled TN-01 MANV rows of the arc's satellite(s).
    need = ["time" "satellite" "key" "values" "text" "disabled"];
    if ~istable(soe) || ~all(ismember(need, soe.Properties.VariableNames)) ...
            || ~isnumeric(soe.time) || size(soe.time, 2) ~= 2
        error("timeSeriesPreparation:mask:badEvents", ...
            "Soe must be gracefoReading.readEventList's TN-01 table read with TimeFormat ""mjd"".");
    end
    sats = "GRACE" + satellite;
    if satellite == "Y", sats = ["GRACEC" "GRACED"]; end
    keep = soe.key == "MANV" & ~soe.disabled & ismember(upper(soe.satellite), sats);
    rows = soe(keep, :);
    n = height(rows);
    dur = zeros(n, 1);
    for k = 1:n
        v = rows.values{k};
        if isempty(v) || ~(v(1) >= 0)
            error("timeSeriesPreparation:mask:badEvents", ...
                "TN-01 MANV row %d (line %d) has no duration.", k, rows.line(k));
        end
        dur(k) = v(1);
    end
    % GPS ns past 2000-01-01 12:00 = MJD 51544.5 on the GPS scale.
    t0 = int64(rows.time(:, 1) - 51544) * int64(86400e9) + int64(round((rows.time(:, 2) - 43200) * 1e9));
    w = table(t0, t0 + ns(dur), repmat("TN-01 MANV", n, 1), string(rows.text), ...
        'VariableNames', ["tStart" "tEnd" "source" "text"]);
end
