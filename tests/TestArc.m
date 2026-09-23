classdef TestArc < matlab.unittest.TestCase
%TESTARC  timeSeriesPreparation.Arc on hand-made triples: rules, layers, releases.
%
%   DESCRIPTION
%     Exercises every documented behaviour of Arc without gracefoReading:
%     the int64-only time rule, selection by name, the one-release rule per
%     arc and per campaign, layers that can only remove, and append-only
%     provenance. The real-file half is TestArcContract.
%
%   COVERAGE
%     contract       - properties from aux; mission and release from the file
%                      name; header fallback; derive keeps metadata and
%                      provenance and resets weights and layers.
%     precision      - t and obs are stored bit for bit.
%     robustness     - each refusal, of the constructor and of derive, fires
%                      on its planted defect and the healthy triple passes.
%     metamorphic    - permuting Columns permutes names, units and obs.
%     vectorisation  - one 3-column arc equals three 1-column arcs, bitwise.
%     speed          - exempt: Arc runs no numerical kernel, only O(N)
%                      checks and copies; budgets start with the kernels (X-04).
%     reference      - exempt here: real files are TestArcContract's.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function propertiesFromAux(testCase)
            [t, obs, aux] = triple(5);
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual(arc.names, ["lin_accl_x" "lin_accl_y" "lin_accl_z"]);
            testCase.verifyEqual(arc.units, ["m/s2" "m/s2" ""]);
            testCase.verifyEqual([arc.product arc.satellite arc.mission arc.release], ...
                ["ACT1B" "C" "GRACE-FO" "04"]);
            testCase.verifyEqual(arc.weights, ones(5, 1));
            testCase.verifyEqual(arc.filled, false(5, 1));
            testCase.verifyEqual(arc.frame, "");
            testCase.verifyEqual(arc.provenance(1).stage, "Arc");
            testCase.verifyEqual(arc.provenance(1).version, ...
                timeSeriesPreparation.internal.toolboxVersion());
        end

        function classicNameGivesGrace(testCase)
            [t, obs, aux] = triple(5);
            aux.fileName = "ACC1B_2008-01-01_A_02.dat"; aux.product = "ACC1B";
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual([arc.satellite arc.mission arc.release], ["A" "GRACE" "02"]);
        end

        function headerGivesReleaseWhenNameDoesNot(testCase)
            [t, obs, aux] = triple(5);
            aux.fileName = "renamed.txt";
            aux.header = {'header:'; '    product_version: 04'};
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual([arc.release arc.satellite arc.mission], ["04" "" ""]);
        end

        function frameOnlyWhenStated(testCase)
            [t, obs, aux] = triple(5);
            arc = timeSeriesPreparation.Arc(t, obs, aux, Frame = "SRF");
            testCase.verifyEqual([arc.frame arc.frameSource], ["SRF" "option"]);
        end

        function layersOnlyRemove(testCase)
            [t, obs, aux] = triple(5);
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            arc = addLayer(arc, "a", logical([1 0 0 0 0]'));
            arc = addLayer(arc, "b", logical([0 0 1 0 0]'));
            testCase.verifyEqual(arc.weights, [0 1 0 1 1]');
            testCase.verifyEqual(string(fieldnames(arc.layers))', ["a" "b"]);
            testCase.verifyEqual([arc.provenance.stage], ["Arc" "addLayer" "addLayer"]);
        end

        function campaignOfOneReleasePasses(testCase)
            [t, obs, aux] = triple(5);
            arcs = [timeSeriesPreparation.Arc(t, obs, aux), timeSeriesPreparation.Arc(t, obs, aux)];
            testCase.verifyWarningFree(@() timeSeriesPreparation.Arc.requireOneRelease(arcs));
        end

        function deriveKeepsMetadataAndProvenance(testCase)
            [t, obs, aux] = triple(6);
            arc = addLayer(timeSeriesPreparation.Arc(t, obs, aux), "a", [true; false(5, 1)]);
            out = derive(arc, t(1:3), obs(1:3, :), "stage", struct("x", 1), ...
                Units = ["a" "b" "c"]);
            testCase.verifyEqual([out.product out.satellite out.release out.mission], ...
                [arc.product arc.satellite arc.release arc.mission]);
            testCase.verifyEqual(out.names, arc.names);
            testCase.verifyEqual(out.units, ["a" "b" "c"]);
            testCase.verifyEqual(out.weights, ones(3, 1));
            testCase.verifyEqual(fieldnames(out.layers), cell(0, 1));
            testCase.verifyEqual([out.provenance.stage], ["Arc" "addLayer" "stage"]);
        end

        function mixedReleaseAcceptedOnRequest(testCase)
            [t, obs, aux] = multiTriple(["ACT1B_2020-01-01_C_04.txt" "ACT1B_2020-01-02_C_05.txt"]);
            arc = timeSeriesPreparation.Arc(t, obs, aux, AllowMixedRelease = true);
            testCase.verifyEqual(arc.release, "04+05");
            testCase.verifyEqual(arc.provenance(1).detail.releases, ["04"; "05"]);
        end
    end

    methods (Test, TestTags = {'precision'})
        function storedBitForBit(testCase)
            [t, obs, aux] = triple(7);
            obs(3, 2) = NaN; obs(4, 1) = realmin / 3;      % a gap and a subnormal
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyEqual(arc.t, t);
            testCase.verifyTrue(isequaln(typecast(arc.obs(:), "uint64"), typecast(obs(:), "uint64")));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function doubleTimeRefused(testCase)
            [t, obs, aux] = triple(5);
            testCase.verifyError(@() timeSeriesPreparation.Arc(double(t), obs, aux), ...
                "timeSeriesPreparation:Arc:timeFormat");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t', obs, aux), ...
                "timeSeriesPreparation:Arc:timeFormat");
        end

        function repeatedEpochRefused(testCase)
            [t, obs, aux] = triple(5);
            t(3) = t(2);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux), ...
                "timeSeriesPreparation:Arc:timeNotIncreasing");
        end

        function sizeAndTypeRefused(testCase)
            [t, obs, aux] = triple(5);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs(1:4, :), aux), ...
                "timeSeriesPreparation:Arc:sizeMismatch");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs(:, 1:2), aux), ...
                "timeSeriesPreparation:Arc:sizeMismatch");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, single(obs), aux), ...
                "timeSeriesPreparation:Arc:sizeMismatch");
        end

        function infRefused(testCase)
            [t, obs, aux] = triple(5);
            obs(2, 2) = Inf;
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux), ...
                "timeSeriesPreparation:Arc:notFinite");
        end

        function unknownOrRepeatedColumnRefused(testCase)
            [t, obs, aux] = triple(5);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux, Columns = "lin_accl_q"), ...
                "timeSeriesPreparation:Arc:unknownColumn");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux, ...
                Columns = ["lin_accl_x" "lin_accl_x"]), "timeSeriesPreparation:Arc:unknownColumn");
        end

        function missingAuxFieldRefused(testCase)
            [t, obs, aux] = triple(5);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, rmfield(aux, "variableUnits")), ...
                "timeSeriesPreparation:Arc:auxField");
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, rmfield(aux, "product")), ...
                "timeSeriesPreparation:Arc:auxField");
        end

        function mixedProductOrSatelliteRefused(testCase)
            [t, obs, aux] = multiTriple(["ACT1B_2020-01-01_C_04.txt" "ACT1B_2020-01-02_D_04.txt"]);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux), ...
                "timeSeriesPreparation:Arc:mixedProduct");
            [t, obs, aux] = multiTriple(["ACT1B_2020-01-01_C_04.txt" "ACT1B_2020-01-02_C_04.txt"]);
            aux.products = {'ACT1B'; 'ACH1B'};
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux), ...
                "timeSeriesPreparation:Arc:mixedProduct");
        end

        function mixedReleaseRefused(testCase)
            [t, obs, aux] = multiTriple(["ACT1B_2020-01-01_C_04.txt" "ACT1B_2020-01-02_C_05.txt"]);
            testCase.verifyError(@() timeSeriesPreparation.Arc(t, obs, aux), ...
                "timeSeriesPreparation:Arc:mixedRelease");
        end

        function mixedReleaseCampaignRefused(testCase)
            [t, obs, aux] = triple(5);
            a = timeSeriesPreparation.Arc(t, obs, aux);
            aux.fileName = "ACT1B_2020-01-02_C_05.txt";
            b = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyError(@() timeSeriesPreparation.Arc.requireOneRelease([a b]), ...
                "timeSeriesPreparation:Arc:mixedRelease");
            testCase.verifyWarningFree(@() timeSeriesPreparation.Arc.requireOneRelease([a b], ...
                AllowMixedRelease = true));
        end

        function deriveRefusesBadData(testCase)
            [t, obs, aux] = triple(6);
            arc = timeSeriesPreparation.Arc(t, obs, aux);
            testCase.verifyError(@() derive(arc, double(t), obs, "s"), ...
                "timeSeriesPreparation:Arc:timeFormat");
            testCase.verifyError(@() derive(arc, flipud(t), obs, "s"), ...
                "timeSeriesPreparation:Arc:timeNotIncreasing");
            testCase.verifyError(@() derive(arc, t, obs(:, 1:2), "s"), ...
                "timeSeriesPreparation:Arc:sizeMismatch");
            testCase.verifyError(@() derive(arc, t, obs, "s", Units = "m"), ...
                "timeSeriesPreparation:Arc:sizeMismatch");
            bad = obs; bad(1) = -Inf;
            testCase.verifyError(@() derive(arc, t, bad, "s"), ...
                "timeSeriesPreparation:Arc:notFinite");
        end

        function badLayerRefused(testCase)
            [t, obs, aux] = triple(5);
            arc = addLayer(timeSeriesPreparation.Arc(t, obs, aux), "a", false(5, 1));
            testCase.verifyError(@() addLayer(arc, "a", false(5, 1)), ...
                "timeSeriesPreparation:Arc:badLayer");            % replacing
            testCase.verifyError(@() addLayer(arc, "b", false(4, 1)), ...
                "timeSeriesPreparation:Arc:badLayer");            % wrong size
            testCase.verifyError(@() addLayer(arc, "b", zeros(5, 1)), ...
                "timeSeriesPreparation:Arc:badLayer");            % not logical
            testCase.verifyError(@() addLayer(arc, "1b", false(5, 1)), ...
                "timeSeriesPreparation:Arc:badLayer");            % not a field name
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function permutedColumnsPermute(testCase)
            [t, obs, aux] = triple(6);
            order = ["lin_accl_z" "lin_accl_x" "lin_accl_y"];
            a = timeSeriesPreparation.Arc(t, obs, aux);
            b = timeSeriesPreparation.Arc(t, obs, aux, Columns = order);
            testCase.verifyEqual(b.names, order);
            testCase.verifyEqual(b.units, a.units([3 1 2]));
            testCase.verifyEqual(b.obs, a.obs(:, [3 1 2]));
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function batchedEqualsPerColumn(testCase)
            [t, obs, aux] = triple(6);
            all3 = timeSeriesPreparation.Arc(t, obs, aux);
            for k = 1:3
                one = timeSeriesPreparation.Arc(t, obs, aux, Columns = all3.names(k));
                testCase.verifyEqual(one.obs, all3.obs(:, k));
                testCase.verifyEqual(one.units, all3.units(k));
            end
        end
    end
end

% ------------------------------------------------------------------------

function [t, obs, aux] = triple(n)
% A readL1b-shaped triple: 1 Hz ACT1B, GRACE-C, release 04, z without unit.
    t = int64(631152000) * int64(1e9) + int64(0:n-1)' * int64(1e9);
    obs = reshape(1:3*n, n, 3) * 1e-8;
    aux = struct();
    aux.obsNames = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    aux.variableNames = {'gps_time', 'GRACEFO_id', 'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    aux.variableFieldNames = aux.variableNames;
    aux.variableUnits = struct("gps_time", "second", "lin_accl_x", "m/s2", "lin_accl_y", "m/s2");
    aux.fileName = "ACT1B_2020-01-01_C_04.txt";
    aux.product = "ACT1B";
    aux.header = {'header:'};
end

function [t, obs, aux] = multiTriple(files)
% A readL1bMulti-shaped triple over FILES, 3 samples each.
    [t, obs, aux] = triple(3 * numel(files));
    aux = rmfield(aux, ["fileName" "product" "header"]);
    aux.fileNames = cellstr(files(:));
    aux.products = repmat({'ACT1B'}, numel(files), 1);
    aux.headers = repmat({{'header:'}}, numel(files), 1);
end
