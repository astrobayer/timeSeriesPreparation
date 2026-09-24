classdef TestQcPort < matlab.unittest.TestCase
%TESTQCPORT  The qc port equals NonGravForces.qc 0.12.0 but for the namespace.
%
%   DESCRIPTION
%     X-05 moves NonGravForces.qc (3cc0123, 0.12.0) in unchanged (CONCEPT
%     10.1, 12.9). The only edits a namespace forces are four text
%     substitutions, undone here in reverse order:
%       timeSeriesPreparation:                     <- NonGravForces:
%       timeSeriesPreparation.internal.provenance( <- NonGravForces.provenance(
%       timeSeriesPreparation.internal.fail(       <- NonGravForces.fail(
%       timeSeriesPreparation.qc.                  <- NonGravForces.qc.
%     None of the replacements occurs in the originals, so the map is
%     invertible. After it is undone, each ported file must have the
%     SHA-256 of its original, taken from the NonGravForces repository at
%     3cc0123 on 2026-09-24. tests/qc/tNgfQcScreen.m has one more edit:
%     NonGravForces.io.readTHR1B and readACC1B do not exist here, so two
%     static readers on gracefoReading.readL1b replace them (owner decision
%     2026-09-24); the test removes that block and restores the two
%     original lines before hashing. The oracles in tests/tools/pyxcheck
%     and the ACT1B sample in tests/data/samples are byte copies. The
%     THR1B priors come from gracefoReading's tests/realdata, which must be
%     byte-identical to NonGravForces' copy. Carriage returns are dropped
%     before hashing, because a Windows checkout may add them; the originals
%     have none. A changed byte is fault-injected: it must break the
%     equality.
%
%   COVERAGE
%     reference   - every ported file, oracle and sample equals its
%                   original; gracefoReading's THR1B equals NonGravForces'.
%     robustness  - one changed character in a ported file breaks the
%                   equality.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-24 16:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        % Ported file (relative to the repository), SHA-256 of the original.
        Ported = [ ...
            "+timeSeriesPreparation/+qc/residuals.m",      "594d3825233a259ccebbb16cac0c5eddefedd45c3a5141204b54c40a680d8f93"
            "+timeSeriesPreparation/+qc/hampel.m",         "8c37659e068dbec45f15758264077b0f649d6437c6a3c48a3df842e8ad457587"
            "+timeSeriesPreparation/+qc/detectImpulses.m", "cc1151bd3c6e0657fc4daa37114a863c04810315fe13d7d77444eb1c9e87218f"
            "+timeSeriesPreparation/+qc/detectJumps.m",    "4e199f78cdd3ecf124e07775f723284f45eabb7182084bba11b0a5389b8b2980"
            "+timeSeriesPreparation/+qc/eventTable.m",     "567f1b5e339001cbe7832c06908e7a6bb38cfe37fb9870dd559daa982771ede1"
            "+timeSeriesPreparation/+qc/screen.m",         "1ef3bb0a184d19c2f1bd2caf62c810b35d1308fb7050a2129a31d68a9b5cf32d"
            "tests/qc/NgfTestCase.m",                      "83dd67faa50671cd2bd8182eb3ec5e7a0fe427b5183e83ebe972fbb91df6ed03"
            "tests/qc/tNgfQc.m",                           "944c98699e4ec095603949ba6e6b30d61a4b28d838d35aedafe9ca33e912be9c"]
        % Byte copies, SHA-256 of the original.
        Copied = [ ...
            "tests/tools/pyxcheck/hampel_check.py",          "7700585412dbe91857de9e5633af7fe765de83f4b9d61128d421d2f17ea89216"
            "tests/tools/pyxcheck/hampel_oracle.csv",        "1b933120d075aa8bee0f2d937d344424a8559c40c760d7fad12c4e92e344d3da"
            "tests/tools/pyxcheck/pelt_check.py",            "c38cf656a2286365c2650f2fe0041dd03b77d24cfeeab0304acee2580fd81ca9"
            "tests/tools/pyxcheck/pelt_oracle.csv",          "b04c258c997cb862675917671102e2a8440d70b05f959a7b837dd8289cd18bdd"
            "tests/tools/pyxcheck/pelt_series.csv",          "f27451edb32433cfef9f6995f0c493f0ee7994feba4563126b435c038a18c4b5"
            "tests/data/samples/ACT1B_2020-01-01_C_04.txt",  "5584c0df127f2f4e4adc113c34e773e9d4bfdf6e5fcb056ea07d38e2f5e18ea9"]
        ScreenTest = "tests/qc/tNgfQcScreen.m"
        ScreenSha = "2ea74d72528d1df20109222db7a1df6f2afb729bb9f6bd1cbacf47815ca738f7"
        % NonGravForces data/samples/THR1B_2020-01-01_C_04.txt at 3cc0123.
        ThrSha = "634445b9b36fabcb1b9c6baee4a5ac0a971e3824d15a80b1cf17793dbbee0da9"
    end

    properties (Access = private)
        Root
    end

    methods (TestClassSetup)
        function findRoot(testCase)
            testCase.Root = string(fileparts(fileparts(mfilename("fullpath"))));
        end
    end

    methods (Test, TestTags = {'reference'})
        function portedFilesEqualOriginals(testCase)
            for k = 1:size(testCase.Ported, 1)
                f = testCase.Ported(k, 1);
                testCase.verifyEqual(sha256(unport(readText(fullfile(testCase.Root, f)))), ...
                    testCase.Ported(k, 2), f + " differs from NonGravForces 3cc0123 beyond the namespace.");
            end
        end

        function screenTestDiffersOnlyInTheReaders(testCase)
            text = readText(fullfile(testCase.Root, testCase.ScreenTest));
            testCase.verifyEqual(sha256(unport(unreader(text))), testCase.ScreenSha, ...
                "tNgfQcScreen differs from NonGravForces 3cc0123 beyond the namespace and the two readers.");
        end

        function copiesEqualOriginals(testCase)
            for k = 1:size(testCase.Copied, 1)
                f = testCase.Copied(k, 1);
                bytes = readBytes(fullfile(testCase.Root, f));
                testCase.verifyEqual(sha256(bytes), testCase.Copied(k, 2), f + " is not a byte copy.");
            end
        end

        function thrPriorsEqualNonGravForcesSample(testCase)
            testCase.assumeNotEmpty(meta.package.fromName('gracefoReading'), ...
                "gracefoReading is not on the path.");
            root = fileparts(fileparts(which("gracefoReading.readL1b")));
            f = fullfile(root, "tests", "realdata", "THR1B_2020-01-01_C_04.txt");
            testCase.assertTrue(isfile(f), "gracefoReading resolves, but its tests/realdata lacks the THR1B day.");
            testCase.verifyEqual(sha256(readBytes(f)), testCase.ThrSha);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function changedCharacterBreaksEquality(testCase)
            text = readText(fullfile(testCase.Root, testCase.Ported(2, 1)));
            k = strfind(text, "1.4826 * median");
            testCase.assertNotEmpty(k);
            text(k(1) + 2) = '5';   % 1.4826 -> 1.5826
            testCase.verifyNotEqual(sha256(unport(text)), testCase.Ported(2, 2));
            testCase.verifyEqual(sha256(unport(readText(fullfile(testCase.Root, testCase.Ported(2, 1))))), ...
                testCase.Ported(2, 2), "The unmodified file must still match.");
        end
    end
end

% ------------------------------------------------------------------------

function text = readText(file)
% The file's text as a char row, decoded from UTF-8.
    text = native2unicode(readBytes(file), "UTF-8");
end

function bytes = readBytes(file)
    fid = fopen(file, "r");
    assert(fid > 0, "Cannot open " + file);
    closer = onCleanup(@() fclose(fid));
    bytes = fread(fid, Inf, "*uint8")';
    % A Windows checkout may turn LF into CRLF (core.autocrlf). Every original
    % holds LF only (counted 2026-09-24), so dropping CR restores its bytes.
    bytes(bytes == 13) = [];
end

function text = unport(text)
% Undo the four namespace substitutions, the last one first.
    map = ["NonGravForces.qc.",          "timeSeriesPreparation.qc."
           "NonGravForces.fail(",        "timeSeriesPreparation.internal.fail("
           "NonGravForces.provenance(",  "timeSeriesPreparation.internal.provenance("
           "NonGravForces:",             "timeSeriesPreparation:"];
    text = string(text);
    for k = size(map, 1):-1:1
        text = replace(text, map(k, 2), map(k, 1));
    end
    text = char(text);
end

function text = unreader(text)
% Remove the X-05 reader block of tNgfQcScreen and restore the two lines.
    text = string(text);
    first = "    methods (Static)" + newline + "        % X-05 port:";
    last = "    methods" + newline + "        function t = epochs(~, K)";
    i = strfind(text, first);
    j = strfind(text, last);
    assert(isscalar(i) && isscalar(j) && j > i, "The X-05 reader block is not where the port put it.");
    text = extractBefore(text, i) + extractAfter(text, j - 1);
    text = replace(text, ...
        "            thr = tNgfQcScreen.readThrPriors(tc);   % X-05: was NonGravForces.io.readTHR1B(<its data/samples copy>)", ...
        "            thr = NonGravForces.io.readTHR1B(fullfile(tc.root, 'data', 'samples', 'THR1B_2020-01-01_C_04.txt'));");
    text = replace(text, ...
        "            [ep, a] = tNgfQcScreen.readAct1b(tc, fullfile(tc.root, 'data', 'samples', 'ACT1B_2020-01-01_C_04.txt'));   % X-05: was NonGravForces.io.readACC1B", ...
        "            [ep, a] = NonGravForces.io.readACC1B(fullfile(tc.root, 'data', 'samples', 'ACT1B_2020-01-01_C_04.txt'));");
    text = char(text);
end

function h = sha256(data)
% Lowercase hex SHA-256 of a char row (hashed as UTF-8) or of uint8 bytes.
    if ischar(data)
        data = unicode2native(data, "UTF-8");
    end
    md = java.security.MessageDigest.getInstance("SHA-256");
    md.update(typecast(uint8(data(:)), "int8"));
    h = string(sprintf("%02x", typecast(md.digest(), "uint8")));
end
