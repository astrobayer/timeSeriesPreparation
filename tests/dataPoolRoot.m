function pool = dataPoolRoot(testCase, need)
%DATAPOOLROOT  The data pool root of a real-data test: DATAPOOL, else READING_DATA_POOL.
%
%   DESCRIPTION
%     pool = dataPoolRoot(testCase, need) is the one place the tests read
%     the data pool location (the owner's data pool rule of 2026-11-08,
%     toolboxInstaller docs/DATA_POOL.md): getenv("DATAPOOL"), which the
%     installer's startup.m sets, or, when that is unset or empty,
%     getenv("READING_DATA_POOL"), the older name that CI passes. The first
%     variable that is set decides. With neither, the calling test is
%     incomplete (an assumption, never a pass), and the message names both
%     variables and NEED, the work package that reads the pool (e.g.
%     "D-9"). pool is a string scalar; that it holds the file is checked
%     by the caller, as before.
%
%   COVERAGE
%     None of its own: a helper of TestCrnVerification, TestDefectCatalogue,
%     TestIntegration and TestTemplates, which exercise it whenever they run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-11-08 23:00 (CET, UTC+01:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        testCase (1,1) matlab.unittest.TestCase
        need (1,1) string
    end
    pool = string(getenv("DATAPOOL"));
    if strlength(pool) == 0
        pool = string(getenv("READING_DATA_POOL"));
    end
    testCase.assumeNotEmpty(char(pool), ...
        "Neither DATAPOOL nor READING_DATA_POOL is set (" + need + " needs the DATAPOOL).");
end
