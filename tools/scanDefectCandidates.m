function scanDefectCandidates(root, month)
%SCANDEFECTCANDIDATES  THROWAWAY (D-9 / V-12): per-day defect indicators of the GRACE-FO L1B month.
%
%   Read-only. For every day of MONTH below ROOT\GRACEFO\L1B\RL04\<yyyy>\<day>\
%   it reads ACT1B (C, D), THR1B (C, D), KBR1B (Y) and LRI1B (Y) with
%   gracefoReading.readL1b and prints one line per file with the indicators
%   a defect class needs: epochs, gaps, duplicates, first and last epoch of
%   the day (day boundary), ACT1B spike counts and the largest 10-min median
%   step per axis, THR1B record count, KBR1B/LRI1B SNR minima and 1st
%   percentiles, and qualflg counts. The column names of each product are
%   printed once. It writes artifacts/defect_scan.csv. It writes nothing
%   into the DATAPOOL. Not to be merged (GUIDE D-9: chosen by a Session).
%
%   Written with Claude Code (Anthropic), 2026-09-24.

    if nargin < 2
        month = "2020-01";
    end
    root = string(root);
    year = extractBefore(month, 5);
    base = fullfile(root, "GRACEFO", "L1B", "RL04", year);
    fprintf("scan root %s\n", base);
    nDays = eomday(str2double(year), str2double(extractAfter(month, 5)));
    products = ["ACT1B" "C"; "ACT1B" "D"; "THR1B" "C"; "THR1B" "D"; "KBR1B" "Y"; "LRI1B" "Y"];
    shown = strings(0, 1);
    rows = strings(0, 1);
    header = "day,product,sat,file,n,gaps,maxGapS,dups,firstS,lastS,metrics";
    rows(end+1) = header;
    for d = 1:nDays
        day = sprintf("%s-%02d", month, d);
        dayDir = fullfile(base, day);
        for p = 1:size(products, 1)
            prod = products(p, 1);
            sat = products(p, 2);
            files = dir(fullfile(dayDir, prod + "_" + day + "_" + sat + "_*.txt"));
            if isempty(files)
                rows(end+1) = sprintf("%s,%s,%s,MISSING,,,,,,,", day, prod, sat); %#ok<AGROW>
                continue
            end
            f = fullfile(files(1).folder, files(1).name);
            try
                [t, obs, aux] = gracefoReading.readL1b(f, "TimeFormat", "gpsns");
            catch err
                rows(end+1) = sprintf("%s,%s,%s,%s,ERROR %s,,,,,,", day, prod, sat, files(1).name, ...
                    strrep(err.identifier, ",", ";")); %#ok<AGROW>
                continue
            end
            names = string(aux.obsNames(:))';
            if ~any(shown == prod)
                shown(end+1) = prod; %#ok<AGROW>
                fprintf("%s columns: %s\n", prod, strjoin(names, " "));
                fprintf("%s aux fields: %s\n", prod, strjoin(string(fieldnames(aux))', " "));
                fprintf("%s obs class %s size %s\n", prod, class(obs), mat2str(size(obs)));
            end
            dayStart = int64(round((datenum(day) - datenum("2000-01-01 12:00:00")) * 86400)) * int64(1e9);
            ts = double(t - dayStart) / 1e9;
            dt = diff(ts);
            nominal = median(dt);
            gaps = nnz(dt > 1.5 * nominal);
            maxGap = max([0; dt]);
            dups = nnz(dt <= 0);
            m = strings(0, 1);
            if isnumeric(obs)
                for c = 1:numel(names)
                    x = double(obs(:, c));
                    nm = names(c);
                    if startsWith(nm, "lin_accl")
                        r = x - movmedian(x, 61, "omitnan");
                        s = 1.4826 * median(abs(r - median(r, "omitnan")), "omitnan");
                        k = floor(numel(x) / 600);
                        blocks = median(reshape(x(1:600 * k), 600, k), 1, "omitnan");
                        m(end+1) = sprintf("%s:spikes10=%d;maxStep10min=%.3g;mad=%.3g", nm, ...
                            nnz(abs(r) > 10 * s), max(abs(diff(blocks))), s); %#ok<AGROW>
                    elseif contains(lower(nm), "snr")
                        m(end+1) = sprintf("%s:min=%.3g;p01=%.3g;med=%.3g", nm, min(x), ...
                            prctile(x, 1), median(x, "omitnan")); %#ok<AGROW>
                    elseif contains(lower(nm), "qualflg")
                        m(end+1) = sprintf("%s:nonzero=%d;bit0=%d", nm, nnz(x ~= 0), ...
                            nnz(mod(x, 2) == 1)); %#ok<AGROW>
                    end
                end
            end
            rows(end+1) = sprintf("%s,%s,%s,%s,%d,%d,%.3f,%d,%.3f,%.3f,%s", day, prod, sat, ...
                files(1).name, numel(t), gaps, maxGap, dups, ts(1), ts(end), strjoin(m, " | ")); %#ok<AGROW>
        end
        fprintf("%s done\n", day);
    end
    if ~isfolder("artifacts")
        mkdir("artifacts");
    end
    writelines(rows, fullfile("artifacts", "defect_scan.csv"));
    fprintf("%s\n", rows);
end
