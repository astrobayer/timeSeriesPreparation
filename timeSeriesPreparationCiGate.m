function results = timeSeriesPreparationCiGate(options)
%TIMESERIESPREPARATIONCIGATE  The MATLAB gate: run every suite, report per tag, fail loudly.
%
%   SYNTAX
%     matlab -batch timeSeriesPreparationCiGate
%     results = timeSeriesPreparationCiGate(Name = Value)
%
%   DESCRIPTION
%     The gate command of GUIDE section 2. Puts the toolbox on the path
%     (and gracefoReading, when a checkout sits in deps/gracefoReading, as CI
%     provides it), runs every test class in tests/, writes JUnit XML and
%     Cobertura coverage of the package to artifacts/, and prints the verdict
%     as passed + failed + incomplete = total, overall and per test tag, so the
%     measured run can be compared with the prediction in the PR body (GUIDE
%     step 6). A failed test raises an error, which makes "matlab -batch" exit
%     non-zero and the CI job red. An empty suite is refused: a gate that ran
%     nothing has not passed.
%
%   INPUTS
%     (none)
%
%   OPTIONS
%     TestsFolder     (1,1) string   [""]    Folder of test classes; "" is
%                                            tests/ below the repository root.
%     OutputDir       (1,1) string   [""]    Folder for the reports; "" is
%                                            artifacts/ below the root.
%     Coverage        (1,1) logical  [true]  Collect statement coverage of
%                                            +timeSeriesPreparation.
%     SearchDatabase  (1,1) logical  [true]  Build the help search database
%                                            with html/buildSearchDatabase.m.
%
%   OUTPUTS
%     results  (1,:) matlab.unittest.TestResult   -   One element per test,
%                                                     returned when no test
%                                                     failed.
%
%   ACCURACY
%     Not applicable, because the function computes no number. The counts it
%     prints are those of the TestResult array, unrounded.
%
%   ERRORS
%     Gate verdict:
%       timeSeriesPreparation:timeSeriesPreparationCiGate:failed - at least
%           one test failed.
%       timeSeriesPreparation:timeSeriesPreparationCiGate:empty - the tests
%           folder yields no test.
%
%   EXAMPLE
%     % Exactly what the CI job runs:
%     %   matlab -batch timeSeriesPreparationCiGate
%     % A quick local run without coverage and search database:
%     %   results = timeSeriesPreparationCiGate(Coverage = false, SearchDatabase = false);
%
%   LIMITATIONS
%     An incomplete test (a failed assumption, e.g. gracefoReading absent)
%     does not fail the gate; it is counted and printed, and the PR body's
%     prediction is where it must have been expected.
%
%   REFERENCES
%     docs/GUIDE.md sections 1 and 2; docs/CONCEPT.md section 9.
%
%   See also setupTimeSeriesPreparation, runtests, matlab.unittest.TestRunner.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        options.TestsFolder (1,1) string = ""
        options.OutputDir (1,1) string = ""
        options.Coverage (1,1) logical = true
        options.SearchDatabase (1,1) logical = true
    end

    import matlab.unittest.TestRunner
    import matlab.unittest.TestSuite
    import matlab.unittest.plugins.XMLPlugin
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoberturaFormat

    root = string(fileparts(mfilename("fullpath")));
    deps = fullfile(root, "deps", "gracefoReading");
    if isfolder(fullfile(deps, "+gracefoReading"))
        setupTimeSeriesPreparation(GracefoReading = deps);
    else
        setupTimeSeriesPreparation();
    end
    fprintf("MATLAB %s\n", version);

    testsFolder = options.TestsFolder;
    if testsFolder == "", testsFolder = fullfile(root, "tests"); end
    outDir = options.OutputDir;
    if outDir == "", outDir = fullfile(root, "artifacts"); end
    if ~isfolder(outDir), mkdir(outDir); end

    suite = TestSuite.fromFolder(char(testsFolder));
    if isempty(suite)
        error("timeSeriesPreparation:timeSeriesPreparationCiGate:empty", ...
            "No test found in %s.", testsFolder);
    end

    runner = TestRunner.withTextOutput;
    runner.addPlugin(XMLPlugin.producingJUnitFormat(char(fullfile(outDir, "junit.xml"))));
    if options.Coverage
        runner.addPlugin(CodeCoveragePlugin.forPackage("timeSeriesPreparation", ...
            "IncludingSubpackages", true, ...
            "Producing", CoberturaFormat(char(fullfile(outDir, "coverage.xml")))));
    end
    results = runner.run(suite);

    printVerdict("all tests", results);
    tags = unique([suite.Tags]);
    for k = 1:numel(tags)
        has = arrayfun(@(s) any(strcmp(s.Tags, tags{k})), suite);
        printVerdict("tag " + tags{k}, results(has));
    end

    if options.SearchDatabase
        script = fullfile(root, "html", "buildSearchDatabase.m");
        run(script);
        fprintf("search database built by %s\n", script);
    end

    nFailed = nnz([results.Failed]);
    if nFailed > 0
        error("timeSeriesPreparation:timeSeriesPreparationCiGate:failed", ...
            "%d of %d tests failed.", nFailed, numel(results));
    end
end

function printVerdict(label, r)
    fprintf("%-22s %d passed + %d failed + %d incomplete = %d\n", label, ...
        nnz([r.Passed]), nnz([r.Failed]), nnz([r.Incomplete]), numel(r));
end
