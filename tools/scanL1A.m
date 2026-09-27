function scanL1A(root, days)
%SCANL1A  THROWAWAY (X-12 scan): fetch GRACE-FO Level-1A days into the DATAPOOL, compare CRN(ACC L1A) with ACT1B.
%
%   Never merged (owner decisions 2026-09-27: the CI runner downloads the
%   Level-1A days itself and keeps them in the DATAPOOL, same layout as L1B).
%   Round 2 (round 1 matched no epoch: its gap test caught the µs jitter of
%   the OBC tags; L1A tags are OBC time, not GPS). For each of DAYS:
%     1. the ISDC listing of Level-1A/JPL/INSTRUMENT/RL04/<yyyy>/: entries of
%        the day (and the count of all entries);
%     2. the day's archive(s) downloaded to
%        ROOT\GRACEFO\L1A\RL04\<yyyy>\<day>\ (kept; skipped when present) and
%        unpacked there; the files and their sizes;
%     3. every ACC/ACT Level-1A file: its header (to the end of the YAML
%        header, at most 160 lines) and the first 3 data lines; the L1A
%        files whose names mention TIM or CLK;
%     4. gracefoReading.readL1b on each of them: size, names, units, epoch
%        step statistics, or the error;
%     5. where a satellite has both a readable ACC/ACT L1A file and its
%        ACT1B day: the L1A columns filtered with crnKernel("ACC") and with
%        Tf = 70.7 s (the span GRACE handbook D-22027 v1.3 p. 20 prints),
%        sampled at the ACT1B epochs (nearest 10 Hz sample, time difference
%        reported, windows with a gap excluded); per ACT1B axis the best
%        matching L1A column, the correlation, the least-squares scale and
%        bias, the rms of the difference against the rms of ACT1B (means
%        removed), and the lag of the peak cross-correlation within +-5 s.
%   Writes artifacts\l1a_scan.txt.
%
%   Written with Claude Code (Anthropic), 2026-09-27.

    root = string(root);
    days = string(days);
    out = strings(0, 1);
    say = @(varargin) sprintf(varargin{:});
    base = "https://isdc-data.gfz.de/grace-fo/Level-1A/JPL/INSTRUMENT/RL04/";
    opts = weboptions("Timeout", 600, "ContentType", "text");
    try
    for day = days
        yyyy = extractBefore(day, 5);
        url = base + yyyy + "/";
        try
            html = string(webread(url, opts));
            tok = regexp(html, 'href="([^"?][^"]*)"', "tokens");
            hrefs = unique(string(cellfun(@(c) c{1}, tok, "UniformOutput", false)));
        catch err
            out(end+1, 1) = say("%s: listing %s failed: %s", day, url, err.message); %#ok<AGROW>
            continue
        end
        out(end+1, 1) = say("%s: listing %s has %d entries", day, url, numel(hrefs)); %#ok<AGROW>
        mine = hrefs(contains(hrefs, day));
        out = [out; "  " + mine(:)]; %#ok<AGROW>
        if isempty(mine)
            out = [out; "  first entries: " + strjoin(hrefs(1:min(10, end)), ", ")]; %#ok<AGROW>
            continue
        end
        if any(contains(mine, "noLRI")), mine = mine(contains(mine, "noLRI")); end
        folder = fullfile(root, "GRACEFO", "L1A", "RL04", yyyy, day);
        if ~isfolder(folder), mkdir(folder); end
        for h = mine(:)'
            name = extractAfter(h, max([0 strfind(h, "/")]));
            target = fullfile(folder, name);
            if ~isfile(target)
                tic;
                try
                    src = url + h;
                    if startsWith(h, "http"), src = h; elseif startsWith(h, "/"), src = "https://isdc-data.gfz.de" + h; end
                    websave(target, src, weboptions("Timeout", 1800));
                catch err
                    out(end+1, 1) = say("  download %s failed: %s", name, err.message); %#ok<AGROW>
                    continue
                end
                out(end+1, 1) = say("  downloaded %s: %.1f MB in %.0f s", name, dirSize(target) / 1e6, toc); %#ok<AGROW>
            else
                out(end+1, 1) = say("  present %s: %.1f MB", name, dirSize(target) / 1e6); %#ok<AGROW>
            end
            try
                if endsWith(name, [".tgz" ".tar.gz" ".tar"])
                    untar(target, folder);
                elseif endsWith(name, ".gz")
                    gunzip(target, folder);
                end
            catch err
                out(end+1, 1) = say("  unpack %s failed: %s", name, err.message); %#ok<AGROW>
            end
        end
        files = dir(fullfile(folder, "**", "*"));
        files = files(~[files.isdir]);
        out(end+1, 1) = say("  %d files in %s:", numel(files), folder); %#ok<AGROW>
        for f = files'
            out(end+1, 1) = say("    %s  %.1f MB", fullfile(erase(f.folder, folder), f.name), f.bytes / 1e6); %#ok<AGROW>
        end
        names = string({files.name});
        paths = string(fullfile({files.folder}, {files.name}));
        tc = paths(contains(names, ["TIM" "CLK"]));
        out = [out; "  time files: " + strjoin(names(contains(names, ["TIM" "CLK"])), ", ")]; %#ok<AGROW>
        acc = paths(startsWith(names, ["ACC1A" "ACT1A"]) & endsWith(names, ".txt"));
        for r = paths(startsWith(names, ["ACC1A" "ACT1A"]) & endsWith(names, ".rpt"))
            out(end+1, 1) = "  rpt " + r + ": " + strtrim(string(fileread(r))); %#ok<AGROW>
        end
        b1 = fullfile(root, "GRACEFO", "L1B", "RL04", yyyy, day);
        for pr = ["TIM1B" "CLK1B"]
            for sat = ["C" "D"]
                hit = dir(fullfile(b1, pr + "_" + day + "_" + sat + "_*.txt"));
                if isempty(hit)
                    out(end+1, 1) = "  L1B " + pr + " " + sat + ": none"; %#ok<AGROW>
                    continue
                end
                fp = string(fullfile(hit(1).folder, hit(1).name));
                hd = headerOf(fp);
                keep = contains(hd, ["long_name" "units" "comment" "- " "|   " "summary" "time"]);
                out = [out; hd(1); hd(keep & ~contains(hd, ["INPUT FILE" "CREATION TIME" "SOFTWARE VERSION" "BUILDTIME"]))]; %#ok<AGROW>
                [~, ~, ~, msg] = readIt(fp);
                out(end+1, 1) = "  read " + fp + ": " + msg; %#ok<AGROW>
            end
        end
        for p = acc(:)'
            out = [out; headerOf(p)]; %#ok<AGROW>
            [t, x, aux, msg] = readIt(p);
            out(end+1, 1) = "  read " + p + ": " + msg; %#ok<AGROW>
            if isempty(t), continue, end
            [~, fn] = fileparts(p);
            sat = extractBetween(fn, strlength(fn) - 3, strlength(fn) - 3);
            b = fullfile(root, "GRACEFO", "L1B", "RL04", yyyy, day);
            hit = dir(fullfile(b, "ACT1B_" + day + "_" + sat + "_*.txt"));
            if isempty(hit)
                out(end+1, 1) = "  no ACT1B for " + sat; %#ok<AGROW>
                continue
            end
            [tb, xb, auxb, msgb] = readIt(string(fullfile(hit(1).folder, hit(1).name)));
            out(end+1, 1) = "  ACT1B " + sat + ": " + msgb; %#ok<AGROW>
            if isempty(tb), continue, end
            out = [out; compareCrn(t, x, aux, tb, xb, auxb)]; %#ok<AGROW>
        end
        if ~isempty(tc)
            out = [out; "  (time-correction files present; round 2 applies them)"]; %#ok<AGROW>
        end
    end
    catch err
        out(end+1, 1) = "SCAN ERROR: " + err.identifier + ": " + err.message;
        for f = err.stack'
            out(end+1, 1) = sprintf("  at %s line %d", f.name, f.line);
        end
    end
    disp(join(out, newline));
    if ~isfolder("artifacts"), mkdir("artifacts"); end
    fid = fopen(fullfile("artifacts", "l1a_scan.txt"), "w");
    fprintf(fid, "%s\n", out);
    fclose(fid);
end

% ------------------------------------------------------------------------

function b = dirSize(f)
    d = dir(f);
    b = sum([d.bytes]);
end

function h = headerOf(p)
% The header to the end of the YAML block (at most 160 lines) and 3 data lines.
    h = "  --- header of " + p + " ---";
    fid = fopen(p, "r");
    if fid < 0, h(end+1, 1) = "  (cannot open)"; return, end
    c = onCleanup(@() fclose(fid));
    n = 0; inData = false; k = 0;
    while n < 200
        line = fgetl(fid);
        if ~ischar(line), break, end
        n = n + 1;
        if inData
            h(end+1, 1) = "  | " + string(line); %#ok<AGROW>
            k = k + 1;
            if k >= 3, break, end
        elseif n <= 160
            h(end+1, 1) = "  | " + string(line); %#ok<AGROW>
        end
        if contains(line, "End of YAML header", "IgnoreCase", true) || contains(line, "END OF HEADER")
            inData = true;
        end
    end
end

function [t, x, aux, msg] = readIt(p)
% gracefoReading.readL1b in gpsns, or the error.
    t = []; x = []; aux = struct();
    try
        [t, x, aux] = gracefoReading.readL1b(p, "TimeFormat", "gpsns");
        dt = double(diff(t)) * 1e-9;
        names = "";
        if isfield(aux, "obsNames"), names = strjoin(string(aux.obsNames), " "); end
        msg = sprintf("%d x %d, first %s, step median %.6g s min %.6g max %.6g, %d steps not median; obs: %s", ...
            size(x, 1), size(x, 2), string(t(1)), median(dt), min(dt), max(dt), ...
            nnz(abs(dt - median(dt)) > 1e-6), names);
        if isfield(aux, "variableUnits")
            u = aux.variableUnits;
            msg = msg + "; units: " + strjoin(string(fieldnames(u))' + "=" + string(struct2cell(u))', " ");
        end
    catch err
        msg = "FAILED: " + err.identifier + ": " + err.message;
        t = [];
    end
end

function o = compareCrn(t, x, aux, tb, xb, auxb)
% CRN(L1A) against ACT1B with an empirical OBC -> GPS offset (round 2).
% L1A time tags are OBC time (time_ref R); ACT1B is GPS time. The offset
% tau(t) = t_GPS - t_OBC is estimated per hour as the shift maximising the
% correlation of the filtered L1A with ACT1B on the axis pair with the most
% signal, then fitted as a + b t; the comparison uses the fitted mapping
% and linear interpolation of the filtered 10 Hz series (smooth, band-
% limited to ~0.035 Hz, so the interpolation error is negligible).
    o = strings(0, 1);
    na = string(aux.obsNames); nb = string(auxb.obsNames);
    ia = find(startsWith(na, "lin_accl")); ib = find(startsWith(nb, "lin_accl"));
    day0 = double(tb(1)) * 1e-9;
    tO = double(t) * 1e-9 - day0;                        % OBC seconds of the day
    tB = double(tb) * 1e-9 - day0;                       % GPS seconds of the day
    keep = [true; diff(tO) > 0];                          % interp1 needs increasing tags
    o(end+1, 1) = sprintf("  %d non-increasing L1A tags dropped", nnz(~keep));
    tO = tO(keep); x = x(keep, :);
    dt = diff(tO);
    step = median(dt);
    gap = [false; dt > 1.5 * step | dt <= 0];
    o(end+1, 1) = sprintf("  L1A step median %.9f s mean %.9f s, %d gaps (> 1.5 steps), OBC span %.3f .. %.3f s", ...
        step, mean(dt(dt < 1.5 * step)), nnz(gap), tO(1), tO(end));
    B = xb(:, ib);
    for Tf = [140.7 70.7]
        k = timeSeriesPreparation.crnKernel("ACC", Tf = Tf);
        Nh = k.Nh;
        bad = conv(double(gap | any(isnan(x(:, ia)), 2)), ones(2 * Nh + 1, 1), "same") > 0;
        bad(1:Nh) = true; bad(end - Nh + 1:end) = true;
        Y = zeros(size(x, 1), numel(ia));
        for c = 1:numel(ia)
            Y(:, c) = conv(x(:, ia(c)), k.F, "same");
        end
        Y(bad, :) = NaN;
        % axis pairing on the whole day at tau = 0 (drift of seconds is harmless at these periods)
        A0 = interp1(tO, Y, tB, "linear");
        okAll = all(isfinite(A0), 2);
        R = corr2m(B(okAll, :), A0(okAll, :));
        [~, pair] = max(abs(R), [], 2);
        [~, jm] = max(var(B(okAll, :)));                 % ACT1B axis with most signal
        cm = pair(jm);
        sgn = sign(R(jm, cm));
        hp = @(v) v - movmean(v, 301, "omitnan");        % keep periods below ~5 min, where the spans differ
        % hourly offsets
        taus = -20:0.1:20;
        hours = 0:23;
        tau = NaN(size(hours)); rmax = NaN(size(hours));
        for h = hours
            sel = tB >= h * 3600 & tB < (h + 1) * 3600;
            win = tO >= h * 3600 - 60 & tO < (h + 1) * 3600 + 60;
            if nnz(win) < 1000, continue, end
            tw = tO(win); yw = Y(win, cm);
            rr = NaN(size(taus));
            for q = 1:numel(taus)
                a = interp1(tw, yw, tB(sel) - taus(q), "linear");
                g = isfinite(a);
                if nnz(g) > 600
                    rr(q) = sgn * corr1(hp(B(sel, jm)), hp(a), g);
                end
            end
            [rmax(h + 1), qm] = max(rr);
            if isfinite(rmax(h + 1)), tau(h + 1) = taus(qm); end
        end
        g = isfinite(tau) & rmax > 0.5;
        pfit = [NaN NaN];
        if nnz(g) >= 3
            pfit = polyfit((hours(g) + 0.5) * 3600, tau(g), 1);
        end
        o(end+1, 1) = sprintf("  Tf %.1f s (Nf %d, NB %d): pairing %s; hourly tau [s] %s; r %s", ...
            Tf, k.Nf, k.NB, strjoin(nb(ib) + "<-" + na(ia(pair))', " "), ...
            mat2str(tau, 4), mat2str(rmax, 4)); %#ok<AGROW>
        o(end+1, 1) = sprintf("    fit tau = %.6g + %.6g * t  (drift %.3f s/day)", pfit(2), pfit(1), pfit(1) * 86400); %#ok<AGROW>
        if any(isnan(pfit)), continue, end
        A = interp1(tO, Y, tB - polyval(pfit, tB), "linear");
        ok = all(isfinite(A), 2);
        Am = A(ok, :) - mean(A(ok, :), 1); Bm = B(ok, :) - mean(B(ok, :), 1);
        for j = 1:numel(ib)
            c = pair(j);
            s = (Am(:, c)' * Bm(:, j)) / (Am(:, c)' * Am(:, c));
            d = Bm(:, j) - s * Am(:, c);
            dh = hp(Bm(:, j)) - s * hp(Am(:, c));
            sj = sign(R(j, c));
            % residual lag on a 0.05 s grid, +-2 s, around the fitted mapping
            lags = -2:0.05:2; rl = NaN(size(lags));
            tq = tB(ok);
            for q = 1:numel(lags)
                a = interp1(tO, Y(:, c), tq - polyval(pfit, tq) - lags(q), "linear");
                gg = isfinite(a);
                rl(q) = sj * corr1(hp(B(ok, j)), hp(a), gg);
            end
            [rlm, ql] = max(rl);
            o(end+1, 1) = sprintf("    %s <- %s: n %d, r %.9f, scale %.9f, rms(diff)/rms(ACT1B) %.4g (rms diff %.4g, ACT1B %.4g); high-passed (301 s): rms(diff)/rms %.4g (ACT1B %.4g); residual lag %+.2f s (hp r %.6f)", ...
                nb(ib(j)), na(ia(c)), nnz(ok), corr1(Bm(:, j), Am(:, c), true(nnz(ok), 1)), s, ...
                rmsOf(d) / rmsOf(Bm(:, j)), rmsOf(d), rmsOf(Bm(:, j)), rmsOf(dh) / rmsOf(hp(Bm(:, j))), ...
                rmsOf(hp(Bm(:, j))), lags(ql), rlm); %#ok<AGROW>
        end
    end
end

function R = corr2m(B, A)
    Bm = B - mean(B, 1); Am = A - mean(A, 1);
    R = (Bm' * Am) ./ sqrt(sum(Bm .^ 2, 1)' * sum(Am .^ 2, 1));
end

function v = rmsOf(d)
    v = sqrt(mean(d .^ 2));
end

function r = corr1(a, b, g)
    a = a(g); b = b(g);
    a = a - mean(a); b = b - mean(b);
    r = (a' * b) / sqrt((a' * a) * (b' * b));
end
