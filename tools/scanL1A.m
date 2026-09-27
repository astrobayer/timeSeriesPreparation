function scanL1A(root, days)
%SCANL1A  THROWAWAY (X-12 scan): fetch GRACE-FO Level-1A days into the DATAPOOL, compare CRN(ACC L1A) with ACT1B.
%
%   Never merged (owner decisions 2026-09-27: the CI runner downloads the
%   Level-1A days itself and keeps them in the DATAPOOL, same layout as L1B).
%   Round 1, for each of DAYS:
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
    for day = days
        yyyy = extractBefore(day, 5);
        url = base + yyyy + "/";
        try
            html = string(webread(url, opts));
            tok = regexp(html, 'href="([^"?][^"]*)"', "tokens");
            hrefs = unique(string(cellfun(@(c) c{1}, tok, "UniformOutput", false)));
        catch err
            out(end+1) = say("%s: listing %s failed: %s", day, url, err.message); %#ok<AGROW>
            continue
        end
        out(end+1) = say("%s: listing %s has %d entries", day, url, numel(hrefs)); %#ok<AGROW>
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
                    out(end+1) = say("  download %s failed: %s", name, err.message); %#ok<AGROW>
                    continue
                end
                out(end+1) = say("  downloaded %s: %.1f MB in %.0f s", name, dirSize(target) / 1e6, toc); %#ok<AGROW>
            else
                out(end+1) = say("  present %s: %.1f MB", name, dirSize(target) / 1e6); %#ok<AGROW>
            end
            try
                if endsWith(name, [".tgz" ".tar.gz" ".tar"])
                    untar(target, folder);
                elseif endsWith(name, ".gz")
                    gunzip(target, folder);
                end
            catch err
                out(end+1) = say("  unpack %s failed: %s", name, err.message); %#ok<AGROW>
            end
        end
        files = dir(fullfile(folder, "**", "*"));
        files = files(~[files.isdir]);
        out(end+1) = say("  %d files in %s:", numel(files), folder); %#ok<AGROW>
        for f = files'
            out(end+1) = say("    %s  %.1f MB", fullfile(erase(f.folder, folder), f.name), f.bytes / 1e6); %#ok<AGROW>
        end
        names = string({files.name});
        paths = string(fullfile({files.folder}, {files.name}));
        tc = paths(contains(names, ["TIM" "CLK"]));
        out = [out; "  time files: " + strjoin(names(contains(names, ["TIM" "CLK"])), ", ")]; %#ok<AGROW>
        acc = paths(startsWith(names, ["ACC1A" "ACT1A"]) & ~endsWith(names, [".tgz" ".gz" ".tar"]));
        for p = acc(:)'
            out = [out; headerOf(p)]; %#ok<AGROW>
            [t, x, aux, msg] = readIt(p);
            out(end+1) = "  read " + p + ": " + msg; %#ok<AGROW>
            if isempty(t), continue, end
            [~, fn] = fileparts(p);
            sat = extractBetween(fn, strlength(fn) - 3, strlength(fn) - 3);
            b = fullfile(root, "GRACEFO", "L1B", "RL04", yyyy, day);
            hit = dir(fullfile(b, "ACT1B_" + day + "_" + sat + "_*.txt"));
            if isempty(hit)
                out(end+1) = "  no ACT1B for " + sat; %#ok<AGROW>
                continue
            end
            [tb, xb, auxb, msgb] = readIt(string(fullfile(hit(1).folder, hit(1).name)));
            out(end+1) = "  ACT1B " + sat + ": " + msgb; %#ok<AGROW>
            if isempty(tb), continue, end
            out = [out; compareCrn(t, x, aux, tb, xb, auxb)]; %#ok<AGROW>
        end
        if ~isempty(tc)
            out = [out; "  (time-correction files present; round 2 applies them)"]; %#ok<AGROW>
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
    if fid < 0, h(end+1) = "  (cannot open)"; return, end
    c = onCleanup(@() fclose(fid));
    n = 0; inData = false; k = 0;
    while n < 200
        line = fgetl(fid);
        if ~ischar(line), break, end
        n = n + 1;
        if inData
            h(end+1) = "  | " + string(line); %#ok<AGROW>
            k = k + 1;
            if k >= 3, break, end
        elseif n <= 160
            h(end+1) = "  | " + string(line); %#ok<AGROW>
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
% CRN(L1A columns) at the ACT1B epochs against the ACT1B linear accelerations.
    o = strings(0, 1);
    na = string(aux.obsNames); nb = string(auxb.obsNames);
    ia = find(startsWith(na, "lin_accl"));
    ib = find(startsWith(nb, "lin_accl"));
    if isempty(ia), ia = 1:min(3, size(x, 2)); end
    o(end+1) = "  L1A columns used: " + strjoin(na(ia), " ") + "; ACT1B: " + strjoin(nb(ib), " ");
    dt = double(diff(t)) * 1e-9;
    step = median(dt);
    o(end+1) = sprintf("  L1A step %.6g s (%d irregular steps)", step, nnz(abs(dt - step) > 1e-6));
    gap = [false; abs(dt - step) > 1e-6];                   % sample k follows a gap
    for Tf = [140.7 70.7]
        k = timeSeriesPreparation.crnKernel("ACC", Tf = Tf);
        Nh = k.Nh;
        % index of the nearest L1A sample to each ACT1B epoch
        idx = round(double(tb - t(1)) * 1e-9 / step) + 1;
        ok = idx > Nh & idx <= numel(t) - Nh;
        idx = idx(ok);
        tdiff = double(tb(ok) - t(idx)) * 1e-9;
        % windows touching a gap or a NaN
        bad = conv(double(gap | any(isnan(x(:, ia)), 2)), ones(2 * Nh + 1, 1), "same") > 0;
        use = ~bad(idx);
        idx = idx(use); tdiff = tdiff(use);
        B = xb(ok, ib); B = B(use, :);
        A = zeros(numel(idx), numel(ia));
        for c = 1:numel(ia)
            y = conv(x(:, ia(c)), k.F, "same");
            A(:, c) = y(idx);
        end
        o(end+1) = sprintf("  Tf %.1f s (Nf %d, NB %d): %d epochs compared, |t(ACT1B) - t(L1A nearest)| max %.3g s median %.3g s", ...
            Tf, k.Nf, k.NB, numel(idx), max(abs(tdiff)), median(abs(tdiff)));
        Am = A - mean(A, 1); Bm = B - mean(B, 1);
        R = (Bm' * Am) ./ sqrt(sum(Bm .^ 2, 1)' * sum(Am .^ 2, 1));
        for j = 1:size(B, 2)
            [~, c] = max(abs(R(j, :)));
            s = (Am(:, c)' * Bm(:, j)) / (Am(:, c)' * Am(:, c));
            bias = mean(B(:, j)) - s * mean(A(:, c));
            d = Bm(:, j) - s * Am(:, c);
            lags = -50:50;                                   % samples of ACT1B (1 s)
            r = zeros(size(lags));
            for q = 1:numel(lags)
                L = lags(q);
                if L >= 0
                    r(q) = corr1(Bm(1 + L:end, j), Am(1:end - L, c));
                else
                    r(q) = corr1(Bm(1:end + L, j), Am(1 - L:end, c));
                end
            end
            [~, qm] = max(r);
            o(end+1) = sprintf("    %s <- %s: r %.9f, scale %.9f, bias %.6g, rms(diff)/rms(ACT1B) %.3g, rms(diff) %.3g, peak lag %+d s (r %.9f)", ...
                nb(ib(j)), na(ia(c)), R(j, c), s, bias, rmsOf(d) / rmsOf(Bm(:, j)), rmsOf(d), lags(qm), r(qm)); %#ok<AGROW>
        end
    end
end

function v = rmsOf(d)
    v = sqrt(mean(d .^ 2));
end

function r = corr1(a, b)
    a = a - mean(a); b = b - mean(b);
    r = (a' * b) / sqrt((a' * a) * (b' * b));
end
