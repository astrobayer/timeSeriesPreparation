classdef TestQcPort < matlab.unittest.TestCase
%TESTQCPORT  The frozen qc port equals NonGravForces.qc 0.12.0 but for the namespace.
%
%   DESCRIPTION
%     X-05 moved NonGravForces.qc (3cc0123, 0.12.0) in unchanged (CONCEPT
%     10.1, 12.9). X-05b then brought +qc to this repository's conventions
%     and gated its numbers by TestQcEquivalence against a frozen copy of
%     that port: tests/qc/frozen/*.m.txt, loaded as the package qcPort.
%     This test holds the copy to the originals. The namespace edits are
%     undone, the specific ones first,
%       qcPort.fail(            -> NonGravForces.fail(
%       qcPort.provenance(      -> NonGravForces.provenance(
%       qcPort.                 -> NonGravForces.qc.
%       timeSeriesPreparation:  -> NonGravForces:
%     none of which occurs in the originals, and each frozen unit must then
%     have the SHA-256 of its original, taken from the NonGravForces
%     repository at 3cc0123 on 2026-09-24. The chain is: +qc equals the
%     frozen port in every output (TestQcEquivalence), and the frozen port
%     equals NonGravForces 0.12.0 in every byte (here). The ported test
%     classes in tests/qc changed only in their readers (X-05) and in their
%     help and tag spelling (X-05b); git history keeps both states. The
%     oracles in tests/tools/pyxcheck and the ACT1B sample in
%     tests/data/samples are byte copies. The THR1B priors come from
%     gracefoReading's tests/realdata, which must be byte-identical to
%     NonGravForces' copy. Carriage returns are dropped before hashing,
%     because a Windows checkout may add them; the originals have none. A
%     changed byte is fault-injected: it must break the equality.
%
%   COVERAGE
%     reference   - every frozen unit, oracle and sample equals its
%                   original; gracefoReading's THR1B equals NonGravForces'.
%     robustness  - one changed character in a frozen unit breaks the
%                   equality.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        % Frozen unit (relative to the repository), SHA-256 of the original.
        Ported = [ ...
            "tests/qc/frozen/residuals.m.txt",      "594d3825233a259ccebbb16cac0c5eddefedd45c3a5141204b54c40a680d8f93"
            "tests/qc/frozen/hampel.m.txt",         "8c37659e068dbec45f15758264077b0f649d6437c6a3c48a3df842e8ad457587"
            "tests/qc/frozen/detectImpulses.m.txt", "cc1151bd3c6e0657fc4daa37114a863c04810315fe13d7d77444eb1c9e87218f"
            "tests/qc/frozen/detectJumps.m.txt",    "4e199f78cdd3ecf124e07775f723284f45eabb7182084bba11b0a5389b8b2980"
            "tests/qc/frozen/eventTable.m.txt",     "567f1b5e339001cbe7832c06908e7a6bb38cfe37fb9870dd559daa982771ede1"
            "tests/qc/frozen/screen.m.txt",         "1ef3bb0a184d19c2f1bd2caf62c810b35d1308fb7050a2129a31d68a9b5cf32d"]
        % Byte copies, SHA-256 of the original.
        Copied = [ ...
            "tests/tools/pyxcheck/hampel_check.py",          "7700585412dbe91857de9e5633af7fe765de83f4b9d61128d421d2f17ea89216"
            "tests/tools/pyxcheck/hampel_oracle.csv",        "1b933120d075aa8bee0f2d937d344424a8559c40c760d7fad12c4e92e344d3da"
            "tests/tools/pyxcheck/pelt_check.py",            "c38cf656a2286365c2650f2fe0041dd03b77d24cfeeab0304acee2580fd81ca9"
            "tests/tools/pyxcheck/pelt_oracle.csv",          "b04c258c997cb862675917671102e2a8440d70b05f959a7b837dd8289cd18bdd"
            "tests/tools/pyxcheck/pelt_series.csv",          "f27451edb32433cfef9f6995f0c493f0ee7994feba4563126b435c038a18c4b5"
            "tests/data/samples/ACT1B_2020-01-01_C_04.txt",  "5584c0df127f2f4e4adc113c34e773e9d4bfdf6e5fcb056ea07d38e2f5e18ea9"]
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
        function frozenUnitsEqualOriginals(testCase)
            for k = 1:size(testCase.Ported, 1)
                f = testCase.Ported(k, 1);
                testCase.verifyEqual(sha256(unport(readText(fullfile(testCase.Root, f)))), ...
                    testCase.Ported(k, 2), f + " differs from NonGravForces 3cc0123 beyond the namespace.");
            end
            n = numel(dir(fullfile(testCase.Root, "tests", "qc", "frozen", "*.m.txt")));
            testCase.verifyEqual(n, 8, "The frozen port is the six units plus fail and provenance.");
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
% Undo the four namespace substitutions of the frozen port, the specific
% qcPort.fail( and qcPort.provenance( before the general qcPort.
    map = ["NonGravForces.fail(",        "qcPort.fail("
           "NonGravForces.provenance(",  "qcPort.provenance("
           "NonGravForces.qc.",          "qcPort."
           "NonGravForces:",             "timeSeriesPreparation:"];
    text = string(text);
    for k = 1:size(map, 1)
        text = replace(text, map(k, 2), map(k, 1));
    end
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
