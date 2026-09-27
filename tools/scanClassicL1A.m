function scanClassicL1A(root, days)
%SCANCLASSICL1A  THROWAWAY (X-13 scan): find and fetch classic GRACE Level-1A (ACC1A) days.
%
%   Never merged (owner decision 2026-09-27: fetch classic ACC1A to settle
%   the CRN span of classic ACC1B). Round 1:
%     1. ISDC listings, to learn where classic Level-1A lives: the grace/
%        root, grace/Level-1A/ and the JPL/INSTRUMENT RL02 and RL03 year
%        folders of the days' year (first 60 entries each);
%     2. for each of DAYS found in a listing: the archive(s) downloaded to
%        ROOT\GRACE\L1A\JPL\<release>\<yyyy>\<day>\ (kept; skipped when
%        present) and unpacked; the files and their sizes;
%     3. every ACC/AHK/CLK/TIM Level-1A file: its header up to END OF
%        HEADER (80-byte records, at most 60), the FILE FORMAT record, and
%        the number of bytes after the header.
%   Writes artifacts\classic_l1a_scan.txt.
%
%   Written with Claude Code (Anthropic), 2026-09-27.

    root = string(root);
    days = string(days);
    out = strings(0, 1);
    say = @(varargin) sprintf(varargin{:});
    opts = weboptions("Timeout", 600, "ContentType", "text");
    host = "https://isdc-data.gfz.de";
    yyyy = extractBefore(days(1), 5);
    probe = host + ["/grace/", "/grace/Level-1A/", "/grace/Level-1A/JPL/", ...
        "/grace/Level-1A/JPL/INSTRUMENT/", ...
        "/grace/Level-1A/JPL/INSTRUMENT/RL02/" + yyyy + "/", ...
        "/grace/Level-1A/JPL/INSTRUMENT/RL03/" + yyyy + "/", ...
        "/grace/Level-1B/JPL/INSTRUMENT/RL02/" + yyyy + "/"];
    listing = struct();
    for url = probe
        try
            hrefs = links(webread(url, opts));
            out(end+1, 1) = say("LIST %s: %d entries", url, numel(hrefs)); %#ok<AGROW>
            out = [out; "  " + hrefs(1:min(60, end))]; %#ok<AGROW>
            listing.(matlab.lang.makeValidName(url)) = hrefs;
        catch err
            out(end+1, 1) = say("LIST %s FAILED: %s", url, err.message); %#ok<AGROW>
        end
    end
    for rel = ["RL02" "RL03"]
        url = host + "/grace/Level-1A/JPL/INSTRUMENT/" + rel + "/" + yyyy + "/";
        key = matlab.lang.makeValidName(url);
        if ~isfield(listing, key), continue, end
        for day = days
            mine = listing.(key)(contains(listing.(key), day));
            out(end+1, 1) = say("DAY %s %s: %d entries", rel, day, numel(mine)); %#ok<AGROW>
            out = [out; "  " + mine(:)]; %#ok<AGROW>
            folder = fullfile(root, "GRACE", "L1A", "JPL", rel, yyyy, day);
            for h = mine(:)'
                name = extractAfter(h, max([0 strfind(h, "/")]));
                if ~isfolder(folder), mkdir(folder); end
                target = fullfile(folder, name);
                src = url + h;
                if startsWith(h, "http"), src = h; elseif startsWith(h, "/"), src = host + h; end
                try
                    if ~isfile(target)
                        tic; websave(target, src, weboptions("Timeout", 1800));
                        out(end+1, 1) = say("  downloaded %s: %.1f MB in %.0f s", name, dirBytes(target) / 1e6, toc); %#ok<AGROW>
                    else
                        out(end+1, 1) = say("  present %s: %.1f MB", name, dirBytes(target) / 1e6); %#ok<AGROW>
                    end
                    if endsWith(name, [".tgz" ".tar.gz" ".tar"]), untar(target, folder);
                    elseif endsWith(name, ".gz"), gunzip(target, folder); end
                catch err
                    out(end+1, 1) = say("  %s FAILED: %s", name, err.message); %#ok<AGROW>
                end
            end
            if isfolder(folder)
                d = dir(fullfile(folder, "**", "*"));
                d = d(~[d.isdir]);
                out(end+1, 1) = say("  %d files under %s", numel(d), folder); %#ok<AGROW>
                for k = 1:numel(d)
                    out(end+1, 1) = say("    %-45s %10d B", d(k).name, d(k).bytes); %#ok<AGROW>
                end
                for k = find(startsWith(string({d.name}), ["ACC1A" "AHK1A" "CLK1A" "TIM1A" "ACC" "CLK" "TIM"]))
                    out = [out; header(fullfile(d(k).folder, d(k).name))]; %#ok<AGROW>
                end
            end
        end
    end
    if ~isfolder("artifacts"), mkdir("artifacts"); end
    writelines(out, fullfile("artifacts", "classic_l1a_scan.txt"));
    fprintf("%s\n", out);
end

function h = links(html)
    tok = regexp(string(html), 'href="([^"?][^"]*)"', "tokens");
    h = unique(string(cellfun(@(c) c{1}, tok, "UniformOutput", false)));
end

function b = dirBytes(p)
    d = dir(p); b = sum([d.bytes]);
end

function out = header(p)
% The classic header: 80-byte ASCII records up to END OF HEADER.
    out = "  --- header of " + string(p) + " ---";
    fid = fopen(p, "r"); b = fread(fid, Inf, "*uint8")'; fclose(fid);
    txt = char(b(1:min(end, 80 * 60)));
    k = strfind(txt, "END OF HEADER");
    if isempty(k)
        out(end+1, 1) = "  | (no END OF HEADER in the first 60 records; first 400 bytes:) " ...
            + string(regexprep(txt(1:min(end, 400)), '[^\x20-\x7E]', '.'));
        return
    end
    hdr = txt(1:k(1) + 12);
    rec = strtrim(string(cellstr(reshape([hdr, repmat(' ', 1, mod(-numel(hdr), 80))], 80, [])')));
    out = [out; "  | " + rec];
    hEnd = ceil((k(1) + 12) / 80) * 80;
    out(end+1, 1) = sprintf("  | bytes after the header: %d (file %d)", numel(b) - hEnd, numel(b));
end
