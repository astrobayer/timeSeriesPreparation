function scanTemplateCandidates(root, months)
%SCANTEMPLATECANDIDATES  THROWAWAY (X-17): event stacks of ACT1B residuals per spike class.
%
%   Read-only; never merged (owner decisions 2026-09-26: empirical stacks on
%   ACT1B 1 Hz, scan first, heater by shape only). For every day of MONTHS
%   below ROOT\GRACEFO\L1B\RL04\<yyyy>\<day>\ and satellites C and D:
%     - inventory (first day only): the product files, and the obsNames of
%       THR1B, MAG1B, AHK1B, IHK1B, HRT1B, with any column naming a heater;
%     - residual r = ACT1B lin_accl - 301-s moving median, per axis; its
%       robust sigma (1.4826 MAD);
%     - thruster events: THR1B records with any on_time_* > 0;
%     - magnetic-torquer events: steps of a MAG1B current column (names
%       with "curr", "torq" or "mt") larger than half its range;
%     - twang candidates: |r| > 8 sigma, local maxima 60 s apart, farther
%       than 70 s from a THR1B record and 10 s from a torquer step;
%     - windows of r at -60..+60 s around each event (twangs sign-aligned).
%   Prints per month, satellite, class and axis the event count and the
%   median stack; per class the strongest single event (day, second of the
%   GPS day, axis, amplitude in sigma). Writes artifacts\template_scan.txt.
%
%   Written with Claude Code (Anthropic), 2026-09-26.

    root = string(root);
    months = string(months);
    L = 60; lags = -L:L;
    classes = ["thruster" "magnetorquer" "twang"];
    out = strings(0, 1);
    for mo = months
        year = extractBefore(mo, 5);
        base = fullfile(root, "GRACEFO", "L1B", "RL04", year);
        nDays = eomday(str2double(year), str2double(extractAfter(mo, 5)));
        for sat = ["C" "D"]
            W = struct("thruster", zeros(0, numel(lags), 3), "magnetorquer", zeros(0, numel(lags), 3), ...
                "twang", zeros(0, numel(lags), 3));
            best = struct("thruster", [0 "" 0 0], "magnetorquer", [0 "" 0 0], "twang", [0 "" 0 0]);
            for d = 1:nDays
                day = sprintf("%s-%02d", mo, d);
                folder = fullfile(base, day);
                if d == 1
                    out = [out; inventory(folder, day, sat)]; %#ok<AGROW>
                end
                [t, r, sig] = residual(folder, day, sat);
                if isempty(t)
                    out(end+1) = sprintf("%s %s: no ACT1B", day, sat); %#ok<AGROW>
                    continue
                end
                tThr = thrusterEvents(folder, day, sat);
                tMtq = torquerEvents(folder, day, sat);
                tTw = twangEvents(t, r, sig, tThr, tMtq);
                ev = struct("thruster", tThr, "magnetorquer", tMtq, "twang", tTw);
                for c = classes
                    [w, amp, ax, te] = windows(t, r, ev.(c), L, c == "twang");
                    W.(c) = [W.(c); w];
                    if ~isempty(amp)
                        [a, k] = max(amp ./ sig(ax));
                        if a > str2double(best.(c)(1))
                            best.(c) = [string(a), day, string(double(te(k) - dayStart(day)) / 1e9), string(ax(k))];
                        end
                    end
                end
                out(end+1) = sprintf("%s %s: sigma %s; events thruster %d, magnetorquer %d, twang %d", ...
                    day, sat, mat2str(sig, 3), numel(tThr), numel(tMtq), numel(tTw)); %#ok<AGROW>
            end
            for c = classes
                w = W.(c);
                for a = 1:3
                    med = median(w(:, :, a), 1, "omitnan");
                    out(end+1) = sprintf("STACK %s %s %s axis %d N %d: %s", mo, sat, c, a, size(w, 1), ...
                        strjoin(compose("%.3g", med), " ")); %#ok<AGROW>
                end
                out(end+1) = sprintf("BEST %s %s %s: %s sigma on %s at %s s, axis %s", mo, sat, c, ...
                    best.(c)(1), best.(c)(2), best.(c)(3), best.(c)(4)); %#ok<AGROW>
            end
        end
    end
    if ~isfolder("artifacts"), mkdir("artifacts"); end
    writelines(out, fullfile("artifacts", "template_scan.txt"));
    fprintf("%s\n", out);
end

function s = inventory(folder, day, sat)
    s = strings(0, 1);
    f = dir(fullfile(folder, "*_" + day + "_" + sat + "_*.txt"));
    s(end+1) = sprintf("INVENTORY %s %s: %s", day, sat, strjoin(string({f.name}), " "));
    for p = ["THR1B" "MAG1B" "AHK1B" "IHK1B" "HRT1B"]
        g = dir(fullfile(folder, p + "_" + day + "_" + sat + "_*.txt"));
        if isempty(g)
            s(end+1) = sprintf("COLUMNS %s: no file", p); %#ok<AGROW>
            continue
        end
        try
            [~, ~, aux] = gracefoReading.readL1b(fullfile(g(1).folder, g(1).name), "TimeFormat", "gpsns");
            n = string(aux.obsNames(:))';
            s(end+1) = sprintf("COLUMNS %s: %s", p, strjoin(n, " ")); %#ok<AGROW>
            h = n(contains(lower(n), ["heat" "htr"]));
            s(end+1) = sprintf("HEATER %s: %s", p, strjoin(h, " ")); %#ok<AGROW>
        catch err
            s(end+1) = sprintf("COLUMNS %s: ERROR %s %s", p, err.identifier, err.message); %#ok<AGROW>
        end
    end
end

function t0 = dayStart(day)
    t0 = int64(round((datenum(day) - datenum("2000-01-01 12:00:00")) * 86400)) * int64(1e9);
end

function [t, r, sig] = residual(folder, day, sat)
    t = []; r = []; sig = [];
    f = dir(fullfile(folder, "ACT1B_" + day + "_" + sat + "_*.txt"));
    if isempty(f), return, end
    try
        [t, obs, aux] = gracefoReading.readL1b(fullfile(f(1).folder, f(1).name), "TimeFormat", "gpsns");
    catch
        t = []; return
    end
    n = string(aux.obsNames(:))';
    x = double(obs(:, startsWith(n, "lin_accl_")));
    r = x - movmedian(x, 301, 1, "omitnan");
    sig = 1.4826 * median(abs(r - median(r, 1, "omitnan")), 1, "omitnan");
end

function te = thrusterEvents(folder, day, sat)
    te = int64.empty(0, 1);
    f = dir(fullfile(folder, "THR1B_" + day + "_" + sat + "_*.txt"));
    if isempty(f), return, end
    try
        [t, obs, aux] = gracefoReading.readL1b(fullfile(f(1).folder, f(1).name), "TimeFormat", "gpsns");
    catch
        return
    end
    on = startsWith(string(aux.obsNames(:))', "on_time_");
    te = t(any(double(obs(:, on)) > 0, 2));
end

function te = torquerEvents(folder, day, sat)
    te = int64.empty(0, 1);
    f = dir(fullfile(folder, "MAG1B_" + day + "_" + sat + "_*.txt"));
    if isempty(f), return, end
    try
        [t, obs, aux] = gracefoReading.readL1b(fullfile(f(1).folder, f(1).name), "TimeFormat", "gpsns");
    catch
        return
    end
    n = lower(string(aux.obsNames(:))');
    cols = find(contains(n, ["curr" "torq"]) | startsWith(n, "mt"));
    for c = cols
        I = double(obs(:, c));
        rng = max(I) - min(I);
        if ~(rng > 0), continue, end
        k = find(abs(diff(I)) > 0.5 * rng) + 1;
        te = [te; t(k)]; %#ok<AGROW>
    end
    te = unique(te);
end

function te = twangEvents(t, r, sig, tThr, tMtq)
    te = int64.empty(0, 1);
    z = max(abs(r) ./ sig, [], 2);
    cand = find(z > 8);
    [~, o] = sort(z(cand), "descend"); cand = cand(o);
    taken = false(size(z));
    for q = cand'
        if taken(q), continue, end
        taken(max(1, q - 60):min(numel(z), q + 60)) = true;
        near = @(ev, s) ~isempty(ev) && min(abs(double(ev - t(q)))) / 1e9 < s;
        if near(tThr, 70) || near(tMtq, 10), continue, end
        te(end+1, 1) = t(q); %#ok<AGROW>
    end
end

function [w, amp, ax, te] = windows(t, r, ev, L, align)
    w = zeros(0, 2 * L + 1, 3); amp = []; ax = []; te = int64.empty(0, 1);
    step = median(double(diff(t)));
    for e = ev(:)'
        i = round(double(e - t(1)) / step) + 1;
        if i - L < 1 || i + L > numel(t) || abs(double(t(i) - e)) > step / 2, continue, end
        seg = r(i - L:i + L, :);
        if any(isnan(seg), "all"), continue, end
        [a, k] = max(abs(seg(L + 1, :)));
        if align
            seg = seg * sign(seg(L + 1, k));
        end
        w(end+1, :, :) = reshape(seg, 1, 2 * L + 1, 3); %#ok<AGROW>
        amp(end+1) = a; ax(end+1) = k; te(end+1, 1) = e; %#ok<AGROW>
    end
end
