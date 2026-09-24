function scanDefectCandidates(root, month)
%SCANDEFECTCANDIDATES  THROWAWAY (D-9 / V-12): per-day defect indicators of the GRACE-FO L1B month.
%
%   Read-only; pass 3 (second month, owner decision 2026-09-24). For every day of MONTH below
%   ROOT\GRACEFO\L1B\RL04\<yyyy>\<day>\ it reads ACT1B (C, D), KBR1B (Y) and
%   LRI1B (Y) with gracefoReading.readL1b and prints one line per file:
%     - epochs, gaps (> 1.5 x the median step) with the start second of up
%       to four of them, first and last second of the day;
%     - qualflg: the count of samples with each bit set (aux.qualflg);
%     - ACT1B lin_accl_*: the number of distinct values (resolution), a
%       spike count |r| > 8 sigma with r the residual to a 61-s moving
%       mean and sigma its standard deviation, and the largest step of
%       10-min block medians after a 3-h moving median is removed, over
%       the robust scale of all such steps, with its second;
%     - KBR1B/LRI1B SNR: minimum and its second.
%   Writes artifacts/defect_scan.csv; writes nothing into the DATAPOOL.
%   Not to be merged (GUIDE D-9: chosen by a Session).
%
%   Written with Claude Code (Anthropic), 2026-09-24.

    root = string(root);
    year = extractBefore(month, 5);
    base = fullfile(root, "GRACEFO", "L1B", "RL04", year);
    nDays = eomday(str2double(year), str2double(extractAfter(month, 5)));
    products = ["ACT1B" "C"; "ACT1B" "D"; "KBR1B" "Y"; "LRI1B" "Y"];
    shown = strings(0, 1);
    rows = "day,product,sat,n,gaps,gapStarts,firstS,lastS,qualflgBits,metrics";
    for d = 1:nDays
        day = sprintf("%s-%02d", month, d);
        for p = 1:size(products, 1)
            prod = products(p, 1);
            sat = products(p, 2);
            files = dir(fullfile(base, day, prod + "_" + day + "_" + sat + "_*.txt"));
            if isempty(files)
                rows(end+1) = sprintf("%s,%s,%s,MISSING", day, prod, sat); %#ok<AGROW>
                continue
            end
            try
                [t, obs, aux] = gracefoReading.readL1b(fullfile(files(1).folder, files(1).name), ...
                    "TimeFormat", "gpsns");
            catch err
                rows(end+1) = sprintf("%s,%s,%s,ERROR %s", day, prod, sat, err.identifier); %#ok<AGROW>
                continue
            end
            names = string(aux.obsNames(:))';
            if ~any(shown == prod)
                shown(end+1) = prod; %#ok<AGROW>
                fprintf("%s qualflg class %s size %s; qualflgBits class %s size %s\n", prod, ...
                    class(aux.qualflg), mat2str(size(aux.qualflg)), class(aux.qualflgBits), ...
                    mat2str(size(aux.qualflgBits)));
                try
                    h = splitlines(strjoin(string(aux.header), newline));
                    h = h(contains(h, ["qualflg" "bit"], "IgnoreCase", true));
                    fprintf("%s header: %s\n", prod, strjoin(h(1:min(40, end))', " || "));
                catch err
                    fprintf("%s header display failed: %s\n", prod, err.message);
                end
            end
            dayStart = int64(round((datenum(day) - datenum("2000-01-01 12:00:00")) * 86400)) * int64(1e9);
            ts = double(t - dayStart) / 1e9;
            dt = diff(ts);
            gapIdx = find(dt > 1.5 * median(dt));
            gapText = strjoin(compose("%.0f+%.0f", [ts(gapIdx(1:min(4, end))), dt(gapIdx(1:min(4, end)))]), ";");
            bits = bitCounts(aux.qualflg);
            m = strings(0, 1);
            for c = 1:numel(names)
                x = double(obs(:, c));
                nm = names(c);
                if startsWith(nm, "lin_accl")
                    r = x - movmean(x, 61, "omitnan");
                    s = std(r, "omitnan");
                    [~, iMax] = max(abs(r));
                    k = floor(numel(x) / 600);
                    y = x - movmedian(x, 10801, "omitnan");      % 3-h trend removed
                    steps = diff(median(reshape(y(1:600 * k), 600, k), 1, "omitnan"));
                    sc = 1.4826 * median(abs(steps - median(steps)));
                    [big, iStep] = max(abs(steps));
                    m(end+1) = sprintf("%s:spikes8=%d;maxAt=%.0f;jump=%.1f;jumpAt=%.0f", ...
                        nm, nnz(abs(r) > 8 * s), ts(iMax), big / sc, ts(600 * iStep)); %#ok<AGROW>
                elseif contains(lower(nm), "snr")
                    [lo, iLo] = min(x);
                    m(end+1) = sprintf("%s:min=%.0f;at=%.0f;med=%.0f", nm, lo, ts(iLo), median(x)); %#ok<AGROW>
                end
            end
            rows(end+1) = sprintf("%s,%s,%s,%d,%d,%s,%.0f,%.0f,%s,%s", day, prod, sat, numel(t), ...
                numel(gapIdx), gapText, ts(1), ts(end), bits, strjoin(m, " | ")); %#ok<AGROW>
        end
    end
    if ~isfolder("artifacts")
        mkdir("artifacts");
    end
    writelines(rows, fullfile("artifacts", "defect_scan.csv"));
    fprintf("%s\n", rows);
end

function text = bitCounts(q)
% Samples with each qualflg bit set, "b0=..;b1=..", whatever the storage.
    if iscell(q)
        q = char(q);
    end
    if (islogical(q) || isnumeric(q)) && size(q, 2) == 8
        B = fliplr(q ~= 0);                      % assumed bit 7 first; see qualflgBits in the log
    elseif ischar(q) || isstring(q)
        q = char(q);
        if size(q, 2) == 8 && all(ismember(q(:), '01'))
            B = fliplr(q == '1');                % char string: bit 7 first
        else
            text = "unreadable";
            return
        end
    elseif isnumeric(q) && size(q, 2) == 1
        v = double(q(:));
        B = false(numel(v), 8);
        for b = 0:7
            B(:, b + 1) = bitget(uint8(v), b + 1) == 1;
        end
    else
        text = "unreadable";
        return
    end
    counts = sum(B, 1);
    used = find(counts > 0);
    if isempty(used)
        text = "none";
    else
        text = strjoin(compose("b%d=%d", [used' - 1, counts(used)']), ";");
    end
end
