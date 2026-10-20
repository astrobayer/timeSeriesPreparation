classdef TestArcSchema < matlab.unittest.TestCase
%TESTARCSCHEMA  The stored layout of Arc: schema version 2, saveobj/loadobj, and the migration of schema 1.
%
%   DESCRIPTION
%     X-18 (CONCEPT 5.2; HANDOVER X-18). Arc.SchemaVersion names the stored
%     layout; saveobj writes it with every property and loadobj restores
%     the arc. An arc saved by 1.1.0 or earlier reaches loadobj as an Arc
%     object (schema 1) and is kept. Fault injection: a struct with another
%     schema version, one without, and a value that is neither struct nor
%     Arc each refuse.
%
%   COVERAGE
%     contract       - the constant and the saveobj fields.
%     reference      - an array of two arcs with layers, fills and
%                      provenance survives save and load (MAT v7.3).
%     robustness     - schema 1 is taken as it is; unknown versions refuse.
%     precision, speed, vectorisation, metamorphic - exempt: storage
%                      copies values and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function schemaVersionConstant(testCase)
            testCase.verifyEqual(timeSeriesPreparation.Arc.SchemaVersion, "2");
            s = saveobj(sample(1));
            testCase.verifyEqual(string(fieldnames(s))', ["schemaVersion" "t" "obs" "names" ...
                "units" "mission" "product" "satellite" "release" "files" "frame" "frameSource" ...
                "weights" "layers" "filled" "provenance"]);
            testCase.verifyEqual(s.schemaVersion, "2");
        end
    end

    methods (Test, TestTags = {'reference'})
        function saveLoadRoundTrip(testCase)
            fx = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            arcs = [sample(1) sample(2)];
            f = fullfile(fx.Folder, "arcs.mat");
            save(f, "arcs", "-v7.3");
            S = load(f);
            testCase.verifyClass(S.arcs, "timeSeriesPreparation.Arc");
            testCase.verifyEqual(size(S.arcs), [1 2]);
            for k = 1:2
                testCase.verifyEqual(S.arcs(k), arcs(k));
                testCase.verifyEqual(S.arcs(k).provenance, arcs(k).provenance);
                testCase.verifyEqual(S.arcs(k).layers, arcs(k).layers);
            end
        end
    end

    methods (Test, TestTags = {'robustness'})
        function loadobjAcceptsV1Object(testCase)
            a = sample(1);
            testCase.verifyEqual(timeSeriesPreparation.Arc.loadobj(a), a);
        end

        function loadobjRefusesUnknownVersion(testCase)
            id = "timeSeriesPreparation:Arc:schemaVersion";
            s = saveobj(sample(1));
            later = s; later.schemaVersion = "3";
            testCase.verifyError(@() timeSeriesPreparation.Arc.loadobj(later), id);
            none = rmfield(s, "schemaVersion");
            testCase.verifyError(@() timeSeriesPreparation.Arc.loadobj(none), id);
            testCase.verifyError(@() timeSeriesPreparation.Arc.loadobj(42), id);
            testCase.verifyEqual(timeSeriesPreparation.Arc.loadobj(s), sample(1), ...
                "the unmodified struct must still load");
        end
    end
end

% ------------------------------------------------------------------------

function arc = sample(k)
% A 20-sample arc of day k with a layer, two filled samples and fixed
% provenance times (so two builds are equal).
    t = int64(7306 + k - 1) * int64(86400e9) - int64(43200e9) + int64(18e9) + int64(0:19)' * int64(1e9);
    names = {'lin_accl_x', 'lin_accl_y'};
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2'), ...
        "fileName", "ACT1B_2020-01-0" + (k + 1) + "_C_04.txt", "product", "ACT1B");
    x = reshape(1:40, 20, 2) * 1e-9;
    x(5, 1) = NaN;
    arc = timeSeriesPreparation.Arc(t, x, aux);
    arc = addLayer(arc, "user", (1:20)' > 17);
    mask = false(20, 2); mask(5, 1) = true;
    arc = fillSamples(arc, zeros(20, 2), mask, struct("method", "test"));
    s = saveobj(arc);
    for j = 1:numel(s.provenance)
        s.provenance(j).time = "2026-09-26T19:00:00Z";
    end
    arc = timeSeriesPreparation.Arc.loadobj(s);
end
