function out = report(res, options)
%REPORT  Figures and a self-contained HTML page of a run result; for a campaign, one page per day and an index.
%
%   SYNTAX
%     out = timeSeriesPreparation.report(res)
%     out = timeSeriesPreparation.report(res, Visible = "off", ExportTo = folder)
%     out = timeSeriesPreparation.report(campaignRes, ExportTo = folder)
%
%   DESCRIPTION
%     The instrument report (X-11, CONCEPT 10.1; owner decisions
%     2026-09-26). It reads what run returned and computes nothing but the
%     spectra it plots; it never calls run. Four figures:
%       series     per axis the observation and the reference, each with
%                  its mean removed, and the residual; below, a timeline of
%                  every layer, the missing (NaN) samples and the filled
%                  ones.
%       events     flags.events over time, one row per class, coloured by
%                  source, marked by axis.
%       noise      per axis the PSD of the residual (spectral.powerSpectrum,
%                  Welch, on the longest stretch without NaN) against the
%                  fitted model's PSD (spectral.arma2psd of
%                  diagnostics.noise), and the squared reference ASD of
%                  noiseReference when the product has one: ACT1B and
%                  ACC1B ("ACC", axis from the column name), KBR1B and
%                  LRI1B (range, rate and acceleration columns).
%       alignment  checkAlignment's r(lag) per axis with the refined lag,
%                  and correlate's r(lag) with its interval per axis and
%                  driver, when those stages ran.
%     A panel whose stage did not run shows why (diagnostics.skipped),
%     and out.notes says the same.
%
%     With ExportTo, the figures go to series.png, events.png, noise.png
%     and alignment.png at 200 dpi (exportgraphics), and report.html is
%     written: one page with no outside references. It holds the summary
%     (mission, satellite, product, release, files, epochs, stages,
%     weight fraction, filled samples, events, alignment verdicts, config
%     hash, toolbox version), the skipped stages, the events (the first
%     200), the provenance and the four PNGs as data URIs.
%
%     A campaign result (run on an Arc array) needs ExportTo. Each arc that
%     ran is reported into ExportTo/<day>/ with Visible "off" and its
%     figures are closed. index.html holds the campaign summary (status,
%     identifier, weight fraction, events, files, SHA-256), each day linked.
%
%   INPUTS
%     res  (1,1) struct   -   A result of run: a single run (fields arc,
%                             reference, diagnostics, correlation, flags,
%                             config, provenance) or a campaign (results,
%                             summary, errors, manifest, parallel).
%
%   OPTIONS
%     Visible   (1,1) string   ["on"]   "on" or "off", the figures'
%                                       visibility.
%     ExportTo  (1,1) string   [""]     Folder for the PNGs and the HTML
%                                       page; "" writes nothing (a single
%                                       run only).
%
%   OUTPUTS
%     out  (1,1) struct   -   Fields: figures (1,1) struct with series,
%                             events, noise, alignment (figure handles; a
%                             campaign returns an empty struct); notes (1,1)
%                             struct of the same names, "" or why the panel
%                             is empty; files (1,:) string, the files
%                             written; html (1,1) string, the page (or
%                             index) written, "" without ExportTo.
%
%   ACCURACY
%     The figures show the stored values. The spectra are estimates:
%     Welch with up to 16 averages (Hann, 50 % overlap) on the longest
%     finite stretch, the model PSD on 1024 frequencies.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:report:inputResult - res is neither a run
%           result nor a campaign result.
%       timeSeriesPreparation:report:exportToRequired - a campaign result
%           without ExportTo.
%
%   EXAMPLE
%     % Report a ten-minute three-axis run without showing the figures.
%     t = int64(7306 * 86400 - 43200 + 18) * int64(1e9) + int64(0:599)' * int64(1e9);
%     names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
%     aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, "variableUnits", struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2'), "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
%     s = 1e-7 * sin(2 * pi * (0:599)' / 300) * [1 1 1];
%     arc = timeSeriesPreparation.Arc(t, s + 1e-9 * randn(RandStream("twister", "Seed", 1), 600, 3), aux);
%     res = timeSeriesPreparation.run(arc, Reference = timeSeriesPreparation.Arc(t, s, aux));
%     out = timeSeriesPreparation.report(res, Visible = "off");
%     close([out.figures.series out.figures.events out.figures.noise out.figures.alignment]);
%
%   LIMITATIONS
%     No pixel reference is kept (renderers differ between MATLAB
%     updates), so the figures are tested for their content contract and
%     speed only. The page embeds the PNGs, about 0.1 to 0.5 MB each.
%
%   REFERENCES
%     docs/CONCEPT.md 10.1 (X-11), docs/inputs/HANDOVER_AccelCal_v3.md
%     WP-20; HANDOVER X-11.
%
%   See also timeSeriesPreparation.run, timeSeriesPreparation.spectral.powerSpectrum, timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.noiseReference.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-26 23:15 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        res (1,1) struct
        options.Visible (1,1) string {mustBeMember(options.Visible, ["on" "off"])} = "on"
        options.ExportTo (1,1) string = ""
    end
    if all(isfield(res, ["results" "summary"]))
        out = campaignReport(res, options.ExportTo);
    elseif all(isfield(res, ["arc" "reference" "diagnostics" "correlation" "flags" "config" "provenance"]))
        out = runReport(res, options.Visible, options.ExportTo);
    else
        error("timeSeriesPreparation:report:inputResult", ...
            "res is neither a run result nor a campaign result -> pass what run returned");
    end
end

% ------------------------------------------------------------------------

function out = runReport(res, vis, folder)
% The four figures of one run and, with a folder, the PNGs and the page.
    dg = res.diagnostics;
    arc = res.arc;
    t = utcOf(arc.t);
    notes = struct("series", "", "events", "", "noise", "", "alignment", "");
    figs = struct();
    figs.series = seriesFigure(arc, res.reference, dg.residual, t, vis);
    if any(dg.skipped.stage == "qc")
        notes.events = "qc: " + reason(dg, "qc");
    elseif height(res.flags.events) == 0
        notes.events = "no QC events";
    end
    figs.events = eventsFigure(res.flags.events, t, notes.events, vis);
    if isempty(dg.noise)
        notes.noise = "noise: " + reason(dg, "noise");
    end
    figs.noise = noiseFigure(arc, dg, notes.noise, vis);
    if isempty(dg.alignment) && isempty(res.correlation)
        notes.alignment = "align: " + reason(dg, "align") + "; correlation: " + reason(dg, "correlation");
    end
    figs.alignment = alignmentFigure(dg.alignment, res.correlation, notes.alignment, vis);

    files = strings(1, 0);
    html = "";
    if folder ~= ""
        if ~isfolder(folder), mkdir(folder); end
        png = strings(1, 0);
        for name = ["series" "events" "noise" "alignment"]
            p = fullfile(folder, name + ".png");
            exportgraphics(figs.(name), p, "Resolution", 200);
            png(end+1) = p; %#ok<AGROW>
        end
        html = fullfile(folder, "report.html");
        writeText(html, runPage(res, t, notes, png));
        files = [png html];
    end
    out = struct("figures", figs, "notes", notes, "files", files, "html", html);
end

function out = campaignReport(res, folder)
% One report per arc that ran, and the index page.
    if folder == ""
        error("timeSeriesPreparation:report:exportToRequired", ...
            "a campaign report needs ExportTo -> pass the folder for the day pages and the index");
    end
    if ~isfolder(folder), mkdir(folder); end
    S = res.summary;
    n = height(S);
    link = strings(n, 1);
    files = strings(1, 0);
    for k = 1:n
        r = res.results{k};
        if isempty(r), continue, end
        sub = S.day(k);
        if sub == "undated" || sum(S.day == S.day(k)) > 1
            sub = sprintf("%s_%d", S.day(k), k);
        end
        o = runReport(r, "off", fullfile(folder, sub));
        close([o.figures.series o.figures.events o.figures.noise o.figures.alignment]);
        link(k) = sub + "/report.html";
        files = [files o.files]; %#ok<AGROW>
    end
    html = fullfile(folder, "index.html");
    writeText(html, indexPage(res, link));
    out = struct("figures", struct(), "notes", struct(), "files", [files html], "html", html);
end

% ------------------------------------------------------------------------
% figures

function f = seriesFigure(arc, ref, resid, t, vis)
    M = size(arc.obs, 2);
    f = figure("Visible", vis, "Name", "series", "Color", "w", "Position", [100 100 1100 250 * (M + 1)]);
    tl = tiledlayout(f, M + 1, 1, "TileSpacing", "compact");
    title(tl, pageTitle(arc));
    for k = 1:M
        ax = nexttile(tl);
        hold(ax, "on");
        plot(ax, t, arc.obs(:, k) - mean(arc.obs(:, k), "omitnan"), "DisplayName", "observation");
        if ~isempty(ref)
            plot(ax, t, ref.obs(:, k) - mean(ref.obs(:, k), "omitnan"), "DisplayName", "reference");
        end
        if ~isempty(resid)
            plot(ax, t, resid.obs(:, k), "DisplayName", "residual");
        end
        ylabel(ax, arc.names(k) + " [" + arc.units(k) + "]", "Interpreter", "none");
        legend(ax, "Location", "best");
        grid(ax, "on");
    end
    ax = nexttile(tl);
    hold(ax, "on");
    plot(ax, t([1 end]), [0 0], "LineStyle", "none", "HandleVisibility", "off");  % a datetime ruler
    names = string(fieldnames(arc.layers))';
    rows = [names "missing" "filled"];
    masks = [cellfun(@(n) arc.layers.(n), cellstr(names), "UniformOutput", false), ...
        {any(isnan(arc.obs), 2), arc.filled}];
    for j = 1:numel(rows)
        idx = find(masks{j});
        if isempty(idx), continue, end
        plot(ax, t(idx), j * ones(numel(idx), 1), ".", "MarkerSize", 6);
    end
    yticks(ax, 1:numel(rows));
    yticklabels(ax, rows);
    set(ax, "TickLabelInterpreter", "none");
    ylim(ax, [0.5 numel(rows) + 0.5]);
    xlim(ax, t([1 end]));
    title(ax, "layers (samples removed), missing and filled samples");
    grid(ax, "on");
end

function f = eventsFigure(ev, t, note, vis)
    f = figure("Visible", vis, "Name", "events", "Color", "w", "Position", [100 100 1100 400]);
    ax = axes(f);
    if note ~= "" && height(ev) == 0
        noteOn(ax, note);
        return
    end
    hold(ax, "on");
    plot(ax, t([1 end]), [0 0], "LineStyle", "none", "HandleVisibility", "off");  % a datetime ruler
    classes = ["outlier" "impulse" "jump"];
    markers = dictionary(["x" "y" "z" "all"], ["^" "s" "v" "o"]);
    for src = unique(ev.source)'
        in = ev.source == src;
        [~, row] = ismember(ev.class(in), classes);
        axs = ev.axis(in);
        for a = unique(axs)'
            sel = axs == a;
            tt = ev.tStart(in);
            plot(ax, tt(sel), row(sel), markers(a), "DisplayName", src + " (" + a + ")", ...
                "MarkerSize", 7, "LineStyle", "none");
        end
    end
    yticks(ax, 1:3);
    yticklabels(ax, classes);
    ylim(ax, [0.5 3.5]);
    xlim(ax, t([1 end]));
    legend(ax, "Location", "bestoutside", "Interpreter", "none");
    title(ax, sprintf("QC events: %d", height(ev)));
    grid(ax, "on");
end

function f = noiseFigure(arc, dg, note, vis)
    f = figure("Visible", vis, "Name", "noise", "Color", "w", "Position", [100 100 1100 700]);
    if note ~= ""
        noteOn(axes(f), note);
        return
    end
    nm = dg.noise;
    s = arc;
    if ~isempty(dg.residual), s = dg.residual; end
    M = numel(nm.axes);
    tl = tiledlayout(f, M, 1, "TileSpacing", "compact");
    title(tl, "Residual PSD and noise model");
    fs = 1 / nm.dt;
    for i = 1:M
        ax = nexttile(tl);
        k = find(s.names == nm.axes(i), 1);
        if isempty(k), k = i; end
        x = longestFinite(s.obs(:, k));
        nav = max(1, min(16, floor(numel(x) / 256)));
        spec = timeSeriesPreparation.spectral.powerSpectrum(fs, x, NAvg = nav);
        loglog(ax, spec.frequency(2:end), spec.power(2:end), "DisplayName", "residual (Welch)");
        hold(ax, "on");
        [S, fm] = timeSeriesPreparation.spectral.arma2psd(nm.b(i, :), nm.a(i, :), fs, ...
            NoiseVariance = nm.sigma2(i), NFreq = 1024);
        loglog(ax, fm(2:end), S(2:end), "LineWidth", 1.5, "DisplayName", ...
            sprintf("ARMA(%d,%d) model", nm.order(1), nm.order(2)));
        [asd, label] = referenceAsd(arc.product, s.names(k), fm(2:end));
        if ~isempty(asd)
            loglog(ax, fm(2:end), asd .^ 2, "--", "DisplayName", label);
        end
        ylabel(ax, nm.axes(i) + " [" + s.units(k) + "^2/Hz]", "Interpreter", "none");
        legend(ax, "Location", "best", "Interpreter", "none");
        grid(ax, "on");
    end
    xlabel(ax, "frequency [Hz]");
end

function f = alignmentFigure(al, cr, note, vis)
    f = figure("Visible", vis, "Name", "alignment", "Color", "w", "Position", [100 100 1100 700]);
    if note ~= ""
        noteOn(axes(f), note);
        return
    end
    n = ~isempty(al) + ~isempty(cr);
    tl = tiledlayout(f, n, 1, "TileSpacing", "compact");
    if ~isempty(al)
        ax = nexttile(tl);
        hold(ax, "on");
        for k = 1:numel(al.names)
            h = plot(ax, al.lags, al.corr(:, k), "DisplayName", al.names(k) + ": " + al.verdict(k));
            if isfinite(al.lag(k))
                xline(ax, al.lag(k), ":", "Color", h.Color, "HandleVisibility", "off");
            end
        end
        xlabel(ax, "lag [s]");
        ylabel(ax, "r");
        title(ax, "checkAlignment: correlation over lag (dotted: refined lag)");
        legend(ax, "Location", "best", "Interpreter", "none");
        grid(ax, "on");
    end
    if ~isempty(cr)
        ax = nexttile(tl);
        hold(ax, "on");
        for m = 1:numel(cr.axes)
            for d = 1:numel(cr.drivers)
                lo = squeeze(cr.ci(1, :, m, d))';
                hi = squeeze(cr.ci(2, :, m, d))';
                h = plot(ax, cr.lagSeconds, cr.r(:, m, d), "DisplayName", cr.axes(m) + " vs " + cr.drivers(d));
                fill(ax, [cr.lagSeconds; flipud(cr.lagSeconds)], [lo; flipud(hi)], h.Color, ...
                    "FaceAlpha", 0.15, "EdgeColor", "none", "HandleVisibility", "off");
            end
        end
        xlabel(ax, "lag [s]");
        ylabel(ax, "r");
        title(ax, sprintf("correlate: pre-whitened correlation with %g %% interval", 100 * cr.level));
        legend(ax, "Location", "best", "Interpreter", "none");
        grid(ax, "on");
    end
end

function noteOn(ax, note)
    axis(ax, "off");
    text(ax, 0.5, 0.5, "not run - " + note, "HorizontalAlignment", "center", ...
        "Interpreter", "none", "FontSize", 12);
end

function [asd, label] = referenceAsd(product, name, f)
% noiseReference's ASD for this product and column, [] when it has none.
    asd = []; label = "";
    try
        if any(product == ["ACT1B" "ACC1B"])
            a = extractAfter(name, strlength(name) - 1);
            if ~any(a == ["x" "y" "z"]), return, end
            asd = timeSeriesPreparation.noiseReference("ACC", f, Axis = a);
            label = "noiseReference ACC " + a + " (squared)";
        elseif any(product == ["KBR1B" "LRI1B"])
            order = find([contains(name, "range") && ~contains(name, ["rate" "accl"]), ...
                contains(name, "rate"), contains(name, "accl")], 1) - 1;
            if isempty(order), return, end
            model = extractBefore(product, 4);
            asd = timeSeriesPreparation.noiseReference(model, f, Derivative = order);
            label = "noiseReference " + model + " (squared)";
        end
    catch
        asd = []; label = "";
    end
end

function x = longestFinite(x)
% The longest run of finite samples of x.
    ok = isfinite(x);
    if all(ok), return, end
    d = diff([false; ok; false]);
    starts = find(d == 1); stops = find(d == -1) - 1;
    [~, j] = max(stops - starts);
    x = x(starts(j):stops(j));
end

% ------------------------------------------------------------------------
% pages

function h = runPage(res, t, notes, png)
    arc = res.arc; dg = res.diagnostics; fl = res.flags;
    cfgHash = "";
    last = res.provenance(end);
    if isfield(last.detail, "configHash"), cfgHash = string(last.detail.configHash); end
    utc = t([1 end]); utc.Format = "yyyy-MM-dd HH:mm:ss 'UTC'";
    rows = { ...
        "Mission", arc.mission; "Satellite", arc.satellite; "Product", arc.product; ...
        "L1B release", arc.release; "Files", strjoin(reshape(arc.files, 1, []), ", "); ...
        "First epoch", string(utc(1)); "Last epoch", string(utc(2)); ...
        "Samples", string(numel(arc.t)); "Columns", strjoin(arc.names, ", "); ...
        "Stages", strjoin(dg.stages, ", "); "Weight fraction", sprintf("%.4f", fl.weightFraction); ...
        "Filled samples", string(fl.nFilled); "QC events", string(height(fl.events)); ...
        "Alignment verdicts", strjoin(fl.alignment, ", "); "Config hash", cfgHash; ...
        "Toolbox", "timeSeriesPreparation " + timeSeriesPreparation.internal.toolboxVersion()};
    h = [pageHead(pageTitle(arc)); "<h1>" + esc(pageTitle(arc)) + "</h1>"; ...
        "<h2>Summary</h2>"; table2html(["Item" "Value"], string(rows))];
    if height(dg.skipped) > 0
        h = [h; "<h2>Stages not run</h2>"; table2html(["Stage" "Reason"], [dg.skipped.stage dg.skipped.reason])];
    end
    names = ["series" "events" "noise" "alignment"];
    for k = 1:4
        h = [h; "<h2>" + names(k) + "</h2>"]; %#ok<AGROW>
        if notes.(names(k)) ~= ""
            h = [h; "<p class=""note"">" + esc(notes.(names(k))) + "</p>"]; %#ok<AGROW>
        end
        h = [h; "<img alt=""" + names(k) + """ src=""data:image/png;base64," + ...
            string(matlab.net.base64encode(readBytes(png(k)))) + """>"]; %#ok<AGROW>
    end
    ev = fl.events;
    if height(ev) > 0
        m = min(height(ev), 200);
        e = ev(1:m, :);
        ts = e.tStart; ts.Format = "yyyy-MM-dd HH:mm:ss.SSS";
        body = [string(ts) e.class e.axis e.source compose("%.4g", e.amplitude) ...
            compose("%.4g", e.sigma) compose("%.3f", e.confidence)];
        h = [h; sprintf("<h2>QC events (%d of %d)</h2>", m, height(ev)); ...
            table2html(["tStart (UTC)" "class" "axis" "source" "amplitude" "sigma" "confidence"], body)];
    end
    p = res.provenance;
    h = [h; "<h2>Provenance</h2>"; table2html(["Stage" "Version" "Time"], ...
        [string({p.stage})' string({p.version})' string({p.time})'])];
    h = [h; pageFoot()];
end

function h = indexPage(res, link)
    S = res.summary;
    n = height(S);
    wf = strings(n, 1); ne = strings(n, 1);
    for k = 1:n
        r = res.results{k};
        if ~isempty(r)
            wf(k) = sprintf("%.4f", r.flags.weightFraction);
            ne(k) = string(height(r.flags.events));
        end
    end
    day = S.day;
    has = link ~= "";
    day(has) = "<a href=""" + link(has) + """>" + esc(S.day(has)) + "</a>";
    day(~has) = esc(S.day(~has));
    cols = ["#" "day" "mission" "satellite" "status" "identifier" "weight fraction" "events" "file" "sha256"];
    body = [string(S.index) day esc(S.mission) esc(S.satellite) esc(S.status) esc(S.identifier) ...
        wf ne esc(S.file) esc(S.sha256)];
    if any(S.Properties.VariableNames == "netcdf")
        cols = [cols "netcdf" "netcdfSha256"];
        body = [body esc(S.netcdf) esc(S.netcdfSha256)];
    end
    title = sprintf("Campaign report, %d arcs", n);
    h = [pageHead(title); "<h1>" + esc(title) + "</h1>"; table2html(cols, body, false); pageFoot()];
end

function h = pageHead(title)
    h = ["<!DOCTYPE html>"; "<html lang=""en"">"; "<head>"; "<meta charset=""utf-8"">"; ...
        "<title>" + esc(title) + "</title>"; ...
        "<style>body{font-family:sans-serif;margin:2em;max-width:1200px}" + ...
        "table{border-collapse:collapse;margin:1em 0}td,th{border:1px solid #bbb;padding:3px 8px;" + ...
        "text-align:left;font-size:13px}th{background:#eee}img{max-width:100%}" + ...
        ".note{color:#a40}</style>"; "</head>"; "<body>"];
end

function h = pageFoot()
    h = ["<p><small>timeSeriesPreparation " + timeSeriesPreparation.internal.toolboxVersion() + ...
        ", " + string(datetime("now", "TimeZone", "UTC", "Format", "yyyy-MM-dd HH:mm 'UTC'")) + ...
        "</small></p>"; "</body>"; "</html>"];
end

function h = table2html(cols, body, escapeBody)
    if nargin < 3, escapeBody = true; end
    if escapeBody, body = esc(body); end
    h = "<table><tr><th>" + strjoin(esc(cols), "</th><th>") + "</th></tr>";
    for i = 1:size(body, 1)
        h = h + "<tr><td>" + strjoin(body(i, :), "</td><td>") + "</td></tr>";
    end
    h = h + "</table>";
end

function s = esc(s)
    s = string(s);
    s(ismissing(s)) = "";
    s = replace(s, ["&" "<" ">" """"], ["&amp;" "&lt;" "&gt;" "&quot;"]);
end

function t = pageTitle(arc)
    t = strtrim(strjoin([arc.product arc.mission arc.satellite], " "));
    if ~isempty(arc.t)
        d = utcOf(arc.t(1)); d.Format = "yyyy-MM-dd";
        t = strtrim(t + " " + string(d));
    end
end

function writeText(file, lines)
    fid = fopen(file, "w", "n", "UTF-8");
    fprintf(fid, "%s\n", lines);
    fclose(fid);
end

function b = readBytes(file)
    fid = fopen(file, "r");
    b = fread(fid, Inf, "*uint8")';
    fclose(fid);
end

function r = reason(dg, stage)
    k = find(dg.skipped.stage == stage, 1);
    r = "ran";
    if ~isempty(k), r = dg.skipped.reason(k); end
end

function e = utcOf(t)
% UTC datetimes of int64 GPS nanoseconds, as run.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end
