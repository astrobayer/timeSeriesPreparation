classdef TestArcContract < matlab.unittest.TestCase
%TESTARCCONTRACT  Pins the gracefoReading aux fields Arc reads, on real files.
%
%   DESCRIPTION
%     Arc is built from gracefoReading's triple by field names (CONCEPT 5),
%     so a renamed or retyped aux field in the reader would break it
%     silently. This class reads real L1B files shipped in gracefoReading's
%     own tests/realdata (present wherever gracefoReading is checked out) and
%     pins, for readL1b and readL1bMulti, every aux field Arc reads, then
%     builds an Arc from each. Downstream-contract rule of CONCEPT 9: the
%     consumer pins what it reads. Every test assumes gracefoReading is on
%     the path and is incomplete, not passed, where it is not.
%
%     Files: MAS1B_2020-01-01_C_04.txt (GRACE-FO, YAML header, RL04) and
%     ACC1B_2008-01-01_A_02.dat (classic GRACE, binary, RL02), both present
%     in gracefoReading v1.1.0, the version CI checks out. Only the absence
%     of gracefoReading makes these tests incomplete; gracefoReading present
%     without these files is a failure, since the pinned version has them.
%
%   COVERAGE
%     contract   - readL1b and readL1bMulti return the aux fields Arc reads,
%                  with the classes it reads them as; Arc builds from both
%                  formats.
%     reference  - the release Arc takes from the file name equals the
%                  header's product_version (two independent statements in
%                  the file); Arc.obs equals the reader's obs bit for bit.
%     metamorphic - readL1bMulti over one file gives the same Arc data as
%                  readL1b.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Access = private)
        Fixtures
    end

    methods (TestClassSetup)
        function locateFixtures(testCase)
            testCase.assumeNotEmpty(meta.package.fromName('gracefoReading'), ...
                "gracefoReading is not on the path; the aux contract cannot be read.");
            root = fileparts(fileparts(which("gracefoReading.readL1b")));
            testCase.Fixtures = string(fullfile(root, "tests", "realdata"));
            for f = ["MAS1B_2020-01-01_C_04.txt" "ACC1B_2008-01-01_A_02.dat"]
                testCase.assertTrue(isfile(fullfile(testCase.Fixtures, f)), ...
                    "gracefoReading resolves, but its tests/realdata lacks " + f + ".");
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function readL1bAuxFields(testCase)
            [t, ~, aux] = gracefoReading.readL1b(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            testCase.verifyClass(t, "int64");
            testCase.verifyTrue(iscolumn(t));
            testCase.verifyAuxFields(aux, ["fileName" "product" "header"]);
        end

        function readL1bMultiAuxFields(testCase)
            [t, ~, aux] = gracefoReading.readL1bMulti(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            testCase.verifyClass(t, "int64");
            testCase.verifyAuxFields(aux, ["fileNames" "products" "headers"]);
        end

        function arcFromYamlProduct(testCase)
            [t, obs, aux] = gracefoReading.readL1b(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            arc = timeSeriesPreparation.Arc(t, obs, aux, Columns = ["mass_thr" "mass_tnk"]);
            testCase.verifyEqual([arc.product arc.satellite arc.mission arc.release], ...
                ["MAS1B" "C" "GRACE-FO" "04"]);
            testCase.verifyEqual(arc.units, ["kg" "kg"]);
        end

        function arcFromClassicBinary(testCase)
            [t, obs, aux] = gracefoReading.readL1b(testCase.file("ACC1B_2008-01-01_A_02.dat"), ...
                "TimeFormat", "gpsns");
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual([arc.product arc.satellite arc.mission arc.release], ...
                ["ACC1B" "A" "GRACE" "02"]);
            testCase.verifyEqual(size(arc.obs), size(obs));
        end
    end

    methods (Test, TestTags = {'reference'})
        function releaseAgreesWithHeader(testCase)
            [~, ~, aux] = gracefoReading.readL1b(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            v = regexp(strjoin(string(aux.header(:))', newline), ...
                "product_version:\s*(\d+)", "tokens", "once");
            testCase.assertNotEmpty(v, "The header states no product_version.");
            [t, obs] = gracefoReading.readL1b(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual(arc.release, string(v{1}));
        end

        function obsCopiedBitForBit(testCase)
            [t, obs, aux] = gracefoReading.readL1b(testCase.file("MAS1B_2020-01-01_C_04.txt"), ...
                "TimeFormat", "gpsns");
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyTrue(isequal(typecast(arc.obs(:), "uint64"), typecast(obs(:), "uint64")));
            testCase.verifyEqual(arc.t, t);
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function multiOfOneEqualsSingle(testCase)
            f = testCase.file("MAS1B_2020-01-01_C_04.txt");
            [t1, o1, a1] = gracefoReading.readL1b(f, "TimeFormat", "gpsns");
            [t2, o2, a2] = gracefoReading.readL1bMulti(f, "TimeFormat", "gpsns");
            s = timeSeriesPreparation.Arc(t1, o1, a1);
            m = timeSeriesPreparation.Arc(t2, o2, a2);
            testCase.verifyEqual(m.t, s.t);
            testCase.verifyTrue(isequaln(m.obs, s.obs), "obs differ (NaN = absent by prod_flag)");
            testCase.verifyEqual([m.names m.units m.product m.satellite m.release], ...
                [s.names s.units s.product s.satellite s.release]);
        end
    end

    methods
        function f = file(testCase, name)
            f = fullfile(testCase.Fixtures, name);
        end

        function verifyAuxFields(testCase, aux, fileFields)
            % The fields Arc reads, with the classes it reads them as.
            for f = ["obsNames" "variableNames" "variableFieldNames" "variableUnits" fileFields]
                testCase.assertTrue(isfield(aux, f), "aux lacks " + f);
            end
            testCase.verifyTrue(iscellstr(aux.obsNames) || isstring(aux.obsNames));
            testCase.verifyTrue(iscellstr(aux.variableNames) || isstring(aux.variableNames));
            testCase.verifyEqual(numel(aux.variableFieldNames), numel(aux.variableNames));
            testCase.verifyClass(aux.variableUnits, "struct");
            testCase.verifyTrue(all(ismember(string(aux.obsNames), string(aux.variableNames))), ...
                "every obsName must be a declared variable (units are looked up through it)");
        end
    end
end
