function scanTemplateCandidates(root, months)
%SCANTEMPLATECANDIDATES  THROWAWAY (X-17): event stacks of ACT1B residuals per spike class.
%
%   Read-only; never merged (owner decisions 2026-09-26: empirical stacks on
%   ACT1B 1 Hz, scan first, heater by shape only; torquer left to N-11).
%   Round 2. For every day of MONTHS below ROOT\GRACEFO\L1B\RL04\<yyyy>\<day>\
%   and satellites C and D:
%     - first day: the distinct IHK1B sensorname values (first 60 MB) and
%       any naming a heater;
%     - residual r = ACT1B lin_accl - 301-s moving median, per axis; its
%       robust sigma (1.4826 MAD), the standard deviation where the MAD is
%       0; the fraction of the x residual that is exactly 0;
%     - thruster events: THR1B records with any on_time_* > 0;
%     - twang candidates on y and z: |r| > 8 sigma, peaks 60 s apart,
%       farther than 70 s from a THR1B record;
%     - windows of r at -60..+60 s around each event (twangs sign-aligned).
%   Prints per month, satellite, class and axis the event count and the
%   median stack, and the three strongest twang candidates. Writes
%   artifacts\template_scan.txt.
%
%   Written with Claude Code (Anthropic), 2026-09-26.

    root = string(root);
    months = string(months);
    L = 60; lags = -L:L;
    classes = ["thruster" "twang"];
    out = strings(0, 1);
    for mo = months
        year = extractBefore(mo, 5);
        base = fullfile(root, "GRACEFO", "L1B", "RL04", year);
        nDays = eomday(str2double(year), str2double(extractAfter(mo, 5)));
        for sat = ["C" "D"]
            W = struct("thruster", zeros(0, numel(lags), 3), "twang", zeros(0, numel(lags), 3));
            top = strings(0, 1); topA = zeros(0, 1);
            for d = 1:nDays
                day = sprintf("%s-%02d", mo, d);
                folder = fullfile(base, day);
                if d == 1
                    out = [out; ihkSensors(folder, day, sat)]; %#ok<AGROW>
                end
                [t, r, sig, zeroX] = residual(folder, day, sat);
                if isempty(t)
                    out(end+1, 1) = sprintf("%s %s: no ACT1B", day, sat); %#ok<AGROW>
                    continue
                end
                tThr = thrusterEvents(folder, day, sat);
                tTw = twangEvents(t, r, sig, tThr);
                ev = struct("thruster", tThr, "twang", tTw);
                for c = classes
                    [w, amp, ax, te] = windows(t, r, ev.(c), L, c == "twang");
                    W.(c) = [W.(c); w];
                    if c == "twang" && ~isempty(amp)
                        z = amp(:) ./ sig(ax(:))';
                        top = [top; compose("%.1f sigma on %s at %.0f s, axis %d", z, ...
                            repmat(string(day), numel(z), 1), double(te(:) - dayStart(day)) / 1e9, ax(:))]; %#ok<AGROW>
                        topA = [topA; z]; %#ok<AGROW>
                    end
                end
                out(end+1, 1) = sprintf("%s %s: sigma %s; x residual exactly zero %.2f; events thruster %d, twang %d", ...
                    day, sat, mat2str(sig, 3), zeroX, numel(tThr), numel(tTw)); %#ok<AGROW>
            end
            for c = classes
                w = W.(c);
                for a = 1:3
                    med = median(w(:, :, a), 1, "omitnan");
                    out(end+1, 1) = sprintf("STACK %s %s %s axis %d N %d: %s", mo, sat, c, a, size(w, 1), ...
                        strjoin(compose("%.3g", med), " ")); %#ok<AGROW>
                end
            end
            [~, o] = sort(topA, "descend");
            for k = o(1:min(3, end))'
                out(end+1, 1) = sprintf("BEST %s %s twang: %s", mo, sat, top(k)); %#ok<AGROW>
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
    s(end+1, 1) = sprintf("INVENTORY %s %s: %s", day, sat, strjoin(string({f.name}), " "));
    for p = ["THR1B" "MAG1B" "AHK1B" "IHK1B" "HRT1B"]
        g = dir(fullfile(folder, p + "_" + day + "_" + sat + "_*.txt"));
        if isempty(g)
            s(end+1, 1) = sprintf("COLUMNS %s: no file", p); %#ok<AGROW>
            continue
        end
        [names, heat] = headerNames(fullfile(g(1).folder, g(1).name));   % header only: IHK1B/HRT1B are large
        s(end+1, 1) = sprintf("COLUMNS %s: %s", p, strjoin(names, " ")); %#ok<AGROW>
        s(end+1, 1) = sprintf("HEATER %s: %s", p, strjoin(heat, " || ")); %#ok<AGROW>
    end
end

function [names, heat] = headerNames(file)
% Variable names and every header line mentioning a heater, from the YAML
% header only (up to the end-of-header marker or 3000 lines).
    names = strings(1, 0); heat = strings(1, 0);
    fid = fopen(file, "r");
    if fid < 0, names = "UNREADABLE"; return, end
    for k = 1:3000
        l = fgetl(fid);
        if ~ischar(l), break, end
        l = string(strtrim(l));
        if contains(lower(l), ["end of header" "end_of_header" "# end of yaml"])
            break
        end
        tok = regexp(l, "^-\s*([^:]+):\s*$", "tokens", "once");   % YAML "- <variable>:" items
        if ~isempty(tok), names(end+1) = string(tok{1}); end %#ok<AGROW>
        if contains(lower(l), ["heat" "htr"]), heat(end+1) = l; end %#ok<AGROW>
    end
    fclose(fid);
end

function s = ihkSensors(folder, day, sat)
% The distinct IHK1B sensorname values of the first 60 MB, with counts,
% and those naming a heater.
    s = strings(0, 1);
    g = dir(fullfile(folder, "IHK1B_" + day + "_" + sat + "_*.txt"));
    if isempty(g)
        s(end+1, 1) = sprintf("IHK1B %s %s: no file", day, sat);
        return
    end
    fid = fopen(fullfile(g(1).folder, g(1).name), "r");
    txt = fread(fid, 60e6, "*char")';
    fclose(fid);
    k = strfind(txt, "End of YAML header");
    if ~isempty(k), txt = txt(k(1):end); end
    rows = splitlines(string(txt));
    rows = rows(2:end - 1);                        % the last row may be cut
    tok = regexp(strtrim(rows), "\S+$", "match", "once");
    [u, ~, j] = unique(tok(tok ~= ""));
    n = accumarray(j, 1);
    s(end+1, 1) = sprintf("IHK1B %s %s: %d distinct sensorname in %d rows: %s", day, sat, numel(u), ...
        numel(tok), strjoin(compose("%s(%d)", u, n), " "));
    h = u(contains(lower(u), ["heat" "htr" "hte"]));
    s(end+1, 1) = sprintf("HEATER IHK1B %s %s: %s", day, sat, strjoin(h, " "));
end

function t0 = dayStart(day)
    t0 = int64(round((datenum(day) - datenum("2000-01-01 12:00:00")) * 86400)) * int64(1e9);
end

function [t, r, sig, zeroX] = residual(folder, day, sat)
% ACT1B residual to a 301-s moving median; robust sigma per axis with the
% standard deviation as floor where more than half the residual is 0.
    t = []; r = []; sig = []; zeroX = NaN;
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
    sd = std(r, 0, 1, "omitnan");
    sig(~(sig > 0)) = sd(~(sig > 0));
    zeroX = mean(r(:, 1) == 0);
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

function te = twangEvents(t, r, sig, tThr)
% Peaks above 8 sigma on y or z, 60 s apart, farther than 70 s from THR1B.
    te = int64.empty(0, 1);
    z = max(abs(r(:, 2:3)) ./ sig(2:3), [], 2);
    cand = find(z > 8);
    [~, o] = sort(z(cand), "descend"); cand = cand(o);
    taken = false(size(z));
    for q = cand'
        if taken(q), continue, end
        taken(max(1, q - 60):min(numel(z), q + 60)) = true;
        if ~isempty(tThr) && min(abs(double(tThr - t(q)))) / 1e9 < 70, continue, end
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
        [a, k] = max(abs(seg(L + 1, :)) .* [~align, 1, 1]);
        if align
            seg = seg * sign(seg(L + 1, k));
        end
        w(end+1, :, :) = reshape(seg, 1, 2 * L + 1, 3); %#ok<AGROW>
        amp(end+1) = a; ax(end+1) = k; te(end+1, 1) = e; %#ok<AGROW>
    end
end
