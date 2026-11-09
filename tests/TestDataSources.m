classdef TestDataSources < matlab.unittest.TestCase
%TESTDATASOURCES  tests/data/SOURCES.json lists the pool files the real-data tests read.
%
%   DESCRIPTION
%     tests/data/SOURCES.json is this repository's list of the third-party
%     files its real-data tests read from the DATAPOOL (dataPoolRoot):
%     per source an id, the url it is fetched from, the files it yields
%     (paths relative to the DATAPOOL root), its size in MB, its SHA-256,
%     licence, licenceText and description. toolboxInstaller reads the
%     list from this file (until 1.6.0 it lived only in the installer's
%     registry, and nothing tied it to the tests).
%     This class ties it to the tests, without a pool and without a
%     download. Four findings, each read from the file and from the code
%     (comment lines removed) of the test classes that call dataPoolRoot:
%       entry     - a field missing or of the wrong kind, a duplicate id, a
%                   url that is not https, an absolute path or "..";
%       layout    - a file outside the folders the pool tests look in:
%                   GRACEFO\L1A|L1B\RL04\<yyyy>\<date>\ (poolFile, dayFile,
%                   readDay, realDayAgainstItsg), GRACE\L1B\JPL\RL02\<yyyy>\
%                   (classicFile) and GRACEFO-1|2\ (findItsgFiles);
%       unread    - a listed file whose product and date no pool test names;
%       unlisted  - a day a pool test names with literal product, date and
%                   satellite (readDay / dayFile) that the list lacks.
%     Pool names a test computes in a loop (poolFile's satellites, the DC-3
%     cases table) are covered by the unread direction only.
%
%   COVERAGE
%     contract    - the repository's file parses at schema 1 and has none of
%                   the four findings.
%     robustness  - each finding fires on a planted manifest or test text,
%                   and the healthy planted case is silent.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-11-09 09:30 (CET, UTC+01:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties
        Manifest
        PoolTexts
    end

    methods (TestClassSetup)
        function readManifestAndTests(testCase)
            here = fileparts(mfilename("fullpath"));
            f = fullfile(here, "data", "SOURCES.json");
            testCase.assertTrue(isfile(f), f + " is missing.");
            testCase.Manifest = jsondecode(fileread(f));
            testCase.PoolTexts = poolTestTexts(here);
        end
    end

    methods (Test, TestTags = {'contract'})
        function manifestParsesAtSchemaOne(testCase)
            m = testCase.Manifest;
            testCase.assertTrue(isfield(m, "schema") && isfield(m, "sources"));
            testCase.verifyEqual(m.schema, 1);
            testCase.verifyNotEmpty(sourceList(m));
        end

        function everyEntryIsComplete(testCase)
            testCase.verifyEmpty(entryFindings(sourceList(testCase.Manifest)));
        end

        function everyFileSitsWhereThePoolTestsLook(testCase)
            testCase.verifyEmpty(layoutFindings(sourceList(testCase.Manifest)));
        end

        function everyFileIsReadByAPoolTest(testCase)
            testCase.assertNotEmpty(testCase.PoolTexts, ...
                "No test class in tests/ calls dataPoolRoot - the derivation is broken.");
            testCase.verifyEmpty(unreadFindings(sourceList(testCase.Manifest), ...
                testCase.PoolTexts));
        end

        function everyLiteralPoolDayIsListed(testCase)
            testCase.assertNotEmpty(literalDays(testCase.PoolTexts), ...
                "No readDay / dayFile call with literal arguments found - the derivation is broken.");
            testCase.verifyEmpty(unlistedFindings(sourceList(testCase.Manifest), ...
                testCase.PoolTexts));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function entryDefectsFire(testCase)
            testCase.verifyEmpty(entryFindings(healthySources()));
            s = healthySources();
            s{2}.id = s{1}.id;
            testCase.verifyEqual(numel(entryFindings(s)), 1, "duplicate id");
            s = healthySources();
            s{1} = rmfield(s{1}, "url");
            testCase.verifyEqual(numel(entryFindings(s)), 1, "missing url");
            s = healthySources();
            s{1}.files{1} = "C:\pool\" + s{1}.files{1};
            testCase.verifyEqual(numel(entryFindings(s)), 1, "absolute path");
            s = healthySources();
            s{2}.sha256 = 'ABC';
            testCase.verifyEqual(numel(entryFindings(s)), 1, "malformed sha256");
        end

        function misplacedFileFires(testCase)
            testCase.verifyEmpty(layoutFindings(healthySources()));
            s = healthySources();
            s{1}.files{1} = 'GRACEFO/L1B/RL04/2020/ACT1B_2020-01-02_C_04.txt';  % no day folder
            testCase.verifyEqual(numel(layoutFindings(s)), 1);
        end

        function unreadFileFires(testCase)
            texts = healthyTexts();
            testCase.verifyEmpty(unreadFindings(healthySources(), texts));
            s = healthySources();
            s{1}.files{end + 1} = 'GRACEFO/L1B/RL04/2021/2021-03-03/KBR1B_2021-03-03_Y_04.txt';
            testCase.verifyEqual(numel(unreadFindings(s, texts)), 1);
        end

        function unlistedDayFires(testCase)
            texts = healthyTexts();
            testCase.verifyEmpty(unlistedFindings(healthySources(), texts));
            texts(end + 1) = "t = readDay(testCase, ""THR1B"", ""2020-01-04"", ""C"");";
            testCase.verifyEqual(numel(unlistedFindings(healthySources(), texts)), 1);
        end
    end
end

% ---- the four findings ------------------------------------------------------

function findings = entryFindings(sources)
% One string per defective field of an entry, and one per duplicate id.
    required = ["id" "url" "files" "MB" "licence" "licenceText" "description"];
    findings = strings(0, 1);
    ids = strings(0, 1);
    for k = 1:numel(sources)
        e = sources{k};
        missing = required(~isfield(e, cellstr(required)));
        if ~isempty(missing)
            findings(end + 1, 1) = sprintf("source %d: no %s", k, strjoin(missing, ", ")); %#ok<AGROW>
            continue
        end
        name = string(e.id);
        ids(end + 1, 1) = name; %#ok<AGROW>
        if ~startsWith(string(e.url), "https://")
            findings(end + 1, 1) = name + ": url is not https"; %#ok<AGROW>
        end
        if ~(isnumeric(e.MB) && isscalar(e.MB) && e.MB > 0)
            findings(end + 1, 1) = name + ": MB is not a positive number"; %#ok<AGROW>
        end
        for t = ["licence" "licenceText" "description"]
            if ~(ischar(e.(t)) && ~isempty(e.(t)))
                findings(end + 1, 1) = name + ": " + t + " is empty"; %#ok<AGROW>
            end
        end
        if isfield(e, "sha256") && isempty(regexp(string(e.sha256), "^[0-9a-f]{64}$", "once"))
            findings(end + 1, 1) = name + ": sha256 is not 64 lowercase hex digits"; %#ok<AGROW>
        end
        files = fileList(e);
        if isempty(files)
            findings(end + 1, 1) = name + ": no files"; %#ok<AGROW>
        end
        for f = files'
            if startsWith(f, ["/" "\"]) || ~isempty(regexp(f, "^[A-Za-z]:", "once")) || ...
                    any(split(f, ["/" "\"]) == "..")
                findings(end + 1, 1) = name + ": " + f + " is not relative to the pool root"; %#ok<AGROW>
            end
        end
    end
    dup = unique(ids(arrayfun(@(i) nnz(ids == i) > 1, ids)));
    for d = dup'
        findings(end + 1, 1) = "duplicate id " + d; %#ok<AGROW>
    end
end

function findings = layoutFindings(sources)
% One string per listed file outside the folders the pool tests look in.
    layouts = ["^GRACEFO/L1[AB]/RL04/(\d{4})/\1-\d\d-\d\d/[A-Z0-9]{5}_\1-\d\d-\d\d_[A-Z]_\d\d\.txt$"
               "^GRACE/L1B/JPL/RL02/(\d{4})/([^/]+/)*[A-Z0-9]{5}_\1-\d\d-\d\d_[AB]_02\.dat$"
               "^GRACEFO-[12]/[^/]+/(\d{4})/GRACEFO-[12]_[A-Za-z]+_\1-\d\d-\d\d\.txt(\.gz)?$"];
    findings = strings(0, 1);
    for f = allFiles(sources)'
        g = replace(f, "\", "/");
        if ~any(arrayfun(@(p) ~isempty(regexp(g, p, "once")), layouts))
            findings(end + 1, 1) = f + ": not in a folder the pool tests look in"; %#ok<AGROW>
        end
    end
end

function findings = unreadFindings(sources, texts)
% One string per listed file whose product (a string literal) and date no
% pool test names.
    findings = strings(0, 1);
    for f = allFiles(sources)'
        [product, day] = productAndDay(f);
        if product == ""
            findings(end + 1, 1) = f + ": file name gives no product and date"; %#ok<AGROW>
            continue
        end
        if ~any(contains(texts, """" + product + """") & contains(texts, day))
            findings(end + 1, 1) = f + ": no pool test names " + product + " and " + day; %#ok<AGROW>
        end
    end
end

function findings = unlistedFindings(sources, texts)
% One string per literal pool day (readDay / dayFile) the list lacks.
    listed = strings(0, 1);
    for f = allFiles(sources)'
        [~, stem] = fileparts(f);
        listed(end + 1, 1) = regexprep(stem, "_\d\d$", ""); %#ok<AGROW>
    end
    findings = strings(0, 1);
    for d = literalDays(texts)'
        if ~any(listed == d)
            findings(end + 1, 1) = d + ": read by a pool test, not in tests/data/SOURCES.json"; %#ok<AGROW>
        end
    end
end

% ---- helpers ----------------------------------------------------------------

function days = literalDays(texts)
% "<product>_<date>_<sat>" of every readDay / dayFile call with literal arguments.
    days = strings(0, 1);
    for t = texts(:)'
        tok = regexp(t, "(?:readDay|dayFile)\(testCase,\s*""([A-Z0-9]{5})"",\s*" + ...
            """(\d{4}-\d\d-\d\d)"",\s*""([A-Z])""\)", "tokens");
        for k = 1:numel(tok)
            days(end + 1, 1) = strjoin(string(tok{k}), "_"); %#ok<AGROW>
        end
    end
    days = unique(days);
end

function [product, day] = productAndDay(f)
% Product and date from a pool file name; "" when it follows neither pattern.
    [~, stem] = fileparts(regexprep(f, "\.gz$", ""));
    product = "";
    day = "";
    tok = regexp(stem, "^([A-Z0-9]{5})_(\d{4}-\d\d-\d\d)_[A-Z]_\d\d$", "tokens", "once");
    if isempty(tok)
        tok = regexp(stem, "^GRACEFO-[12]_([A-Za-z]+)_(\d{4}-\d\d-\d\d)$", "tokens", "once");
    end
    if ~isempty(tok)
        product = string(tok{1});
        day = string(tok{2});
    end
end

function texts = poolTestTexts(here)
% Code (comment lines removed) of every test class in tests/ that calls
% dataPoolRoot, apart from the helper itself and this class.
    texts = strings(0, 1);
    d = dir(fullfile(here, "*.m"));
    for k = 1:numel(d)
        if any(d(k).name == ["dataPoolRoot.m" "TestDataSources.m"])
            continue
        end
        lines = readlines(fullfile(d(k).folder, d(k).name));
        code = strjoin(lines(~startsWith(strtrim(lines), "%")), newline);
        if contains(code, "dataPoolRoot(")
            texts(end + 1, 1) = code; %#ok<AGROW>
        end
    end
end

function s = sourceList(m)
% jsondecode gives a struct array when every entry has the same fields and a
% cell array when they differ (sha256 is optional); both become a cell column.
    s = m.sources;
    if isstruct(s)
        s = num2cell(s);
    end
    s = s(:);
end

function files = fileList(e)
    files = string(e.files(:));
end

function files = allFiles(sources)
    files = strings(0, 1);
    for k = 1:numel(sources)
        if isfield(sources{k}, "files")
            files = [files; fileList(sources{k})]; %#ok<AGROW>
        end
    end
end

function s = healthySources()
% Two planted sources in two of the three layouts, as jsondecode gives them.
    s = {struct("id", 'a', "url", 'https://example.org/a.tgz', ...
                "files", {{'GRACEFO/L1B/RL04/2020/2020-01-02/ACT1B_2020-01-02_C_04.txt'}}, ...
                "MB", 1, "sha256", repmat('0', 1, 64), "licence", 'x', ...
                "licenceText", 'x', "description", 'x')
         struct("id", 'b', "url", 'https://example.org/b.gz', ...
                "files", {{'GRACEFO-1/nonConservativeForces/2020/GRACEFO-1_nonConservativeForces_2020-01-02.txt'}}, ...
                "MB", 0.5, "sha256", repmat('f', 1, 64), "licence", 'x', ...
                "licenceText", 'x', "description", 'x')};
end

function texts = healthyTexts()
% A planted pool test that names both healthy files, one by a literal readDay.
    texts = "pool = dataPoolRoot(testCase, ""X"");" + newline + ...
        "t = readDay(testCase, ""ACT1B"", ""2020-01-02"", ""C"");" + newline + ...
        "f = gracefoReading.findItsgFiles(pool, ""nonConservativeForces"", DateRange = d);";
end
