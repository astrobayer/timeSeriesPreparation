classdef TestExport < matlab.unittest.TestCase
%TESTEXPORT  CF-1.12/ACDD-1.3 NetCDF export with PROV-O provenance, its reader, and run's campaign formats.
%
%   DESCRIPTION
%     X-18 (CONCEPT 5.2; owner decisions 2026-09-26). The arc is a 600-s
%     1 Hz ACT1B-like day of GRACE-FO C: three sinusoids plus seeded white
%     noise, a spike of 1e-7 m/s^2 on y at sample 300 (so qc reports
%     events) and a user layer; run with the sinusoids as reference gives
%     the arc, its residual and events. exportNetcdf writes them and
%     readNetcdf reads them back. Fault injection: a missing creator, a
%     reserved or unsafe name, a residual on other epochs, a non-table
%     Events, 33 layers, an existing file, a missing and a foreign file
%     each refuse; a campaign asked for NetCDF without a creator refuses
%     before it writes anything.
%
%   COVERAGE
%     contract       - dimensions, variables and the CF/ACDD attributes; the
%                      time coordinate (int64 GPS ns, CF 1.12 leap_seconds
%                      none); the PROV-O graph in the file and the sidecar.
%     reference      - arc, residual and events round-trip (bit for bit,
%                      event epochs to 1 microsecond); a campaign writes
%                      NetCDF with sidecars, SHA-256 and a DataCite block,
%                      and "both" writes MAT and NetCDF of the same data.
%     robustness     - the refusals; a campaign without creator; an
%                      existing file kept unless Overwrite; NaN survives.
%     precision, speed, vectorisation, metamorphic - exempt: the export
%                      writes stored values and computes nothing.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function fileLayout(testCase)
            [f, res, info] = exported(testCase);
            nc = ncinfo(f);
            dims = dictionary(string({nc.Dimensions.Name}), [nc.Dimensions.Length]);
            testCase.verifyEqual(dims("time"), 600);
            testCase.verifyEqual(dims("event"), height(res.flags.events));
            testCase.verifyEqual(sort(string({nc.Variables.Name})), sort(info.variables));
            testCase.verifyEqual(info.variables(1:6), ["time" "lin_accl_x" "lin_accl_y" ...
                "lin_accl_z" "weights" "filled"]);
            testCase.verifyEqual(string(ncreadatt(f, "/", "Conventions")), "CF-1.12, ACDD-1.3");
            for a = ["title" "summary" "keywords" "id" "date_created" "creator_name" "license" ...
                    "time_coverage_start" "time_coverage_end" "prov_jsonld"]
                testCase.verifyNotEmpty(ncreadatt(f, "/", char(a)), a);
            end
            testCase.verifyEqual(string(ncreadatt(f, "/", "license")), "CC-BY-4.0");
            testCase.verifyEqual(string(ncreadatt(f, "/", "time_coverage_start")), "2020-01-02T00:00:00.000Z");
            testCase.verifyEqual(string(ncreadatt(f, "layers", "flag_meanings")), ...
                strjoin(string(fieldnames(res.arc.layers))', " "));
            testCase.verifyEqual(string(ncreadatt(f, "/", "id")), ...
                timeSeriesPreparation.internal.contentHash(struct("t", res.arc.t, "obs", res.arc.obs)));
        end

        function timeCoordinate(testCase)
            [f, res] = exported(testCase);
            testCase.verifyEqual(string(ncreadatt(f, "time", "units")), ...
                "nanoseconds since 2000-01-01 12:00:00");
            testCase.verifyEqual(string(ncreadatt(f, "time", "calendar")), "standard");
            testCase.verifyEqual(string(ncreadatt(f, "time", "units_metadata")), "leap_seconds: none");
            t = ncread(f, "time");
            testCase.verifyClass(t, "int64");
            testCase.verifyEqual(t, res.arc.t);
        end

        function provenanceGraph(testCase)
            [f, res, info] = exported(testCase);
            txt = string(fileread(info.prov));
            testCase.verifyEqual(txt, string(ncreadatt(f, "/", "prov_jsonld")));
            g = jsondecode(txt);
            testCase.verifyEqual(string(g.x_context.prov), "http://www.w3.org/ns/prov#");
            nodes = g.x_graph;
            if isstruct(nodes), nodes = num2cell(nodes); end
            types = string(cellfun(@(n) n.x_type, nodes, "UniformOutput", false));
            testCase.verifyEqual(nnz(types == "prov:Activity"), numel(res.arc.provenance) + 1);
            testCase.verifyEqual(nnz(types == "prov:Entity"), numel(res.arc.files) + 1);
            testCase.verifyGreaterThanOrEqual(nnz(types == "prov:SoftwareAgent"), 1);
            person = nodes{types == "prov:Person"};
            testCase.verifyEqual(string(person.x_id), "https://orcid.org/0000-0002-1825-0097");
            out = nodes{types == "prov:Entity" & cellfun(@(n) startsWith(string(n.x_id), ...
                "urn:timeSeriesPreparation:output:"), nodes)};
            testCase.verifyEqual(string(out.rdfs_label), "day.nc");
            testCase.verifyEqual(info.provSha256, timeSeriesPreparation.internal.fileSha256(info.prov));
        end
    end

    methods (Test, TestTags = {'reference'})
        function arcRoundTrip(testCase)
            [f, res] = exported(testCase);
            d = timeSeriesPreparation.readNetcdf(f);
            a = res.arc;
            testCase.verifyEqual(d.t, a.t);
            testCase.verifyEqual(d.obs, a.obs);
            testCase.verifyEqual([d.names; d.units], [a.names; a.units]);
            testCase.verifyEqual(d.weights, a.weights);
            testCase.verifyEqual(d.filled, a.filled);
            testCase.verifyEqual(d.layers, a.layers);
            testCase.verifyEqual(d.attributes.creator_name, "A. Author");
        end

        function residualAndEventsRoundTrip(testCase)
            [f, res] = exported(testCase);
            d = timeSeriesPreparation.readNetcdf(f);
            s = res.diagnostics.residual;
            testCase.verifyEqual(d.residual.obs, s.obs);
            testCase.verifyEqual([d.residual.names; d.residual.units], [s.names; s.units]);
            e = res.flags.events;
            testCase.assertGreaterThan(height(e), 0);
            testCase.verifyEqual(d.events(:, 3:8), e(:, 3:8));
            testCase.verifyLessThan(abs(seconds(d.events.tStart - e.tStart)), 1e-6);
            testCase.verifyLessThan(abs(seconds(d.events.tEnd - e.tEnd)), 1e-6);
        end

        function campaignNetcdf(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(2);
            cfg = configFor(arcs(1), folder, "netcdf");
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            testCase.verifyEqual(res.summary.status', ["ok" "ok"]);
            testCase.verifyEqual(res.summary.file', ["" ""]);
            m = jsondecode(fileread(fullfile(folder, "manifest.json")));
            for k = 1:2
                rel = strjoin([res.summary.mission(k) "C" "2020" res.summary.day(k)], "/");
                testCase.verifyEqual(res.summary.netcdf(k), rel + ".nc");
                nc = fullfile(folder, rel + ".nc");
                pj = fullfile(folder, rel + ".prov.jsonld");
                testCase.verifyTrue(isfile(nc) && isfile(pj), rel);
                testCase.verifyFalse(isfile(fullfile(folder, rel + ".mat")), rel);
                testCase.verifyEqual(res.summary.netcdfSha256(k), timeSeriesPreparation.internal.fileSha256(nc));
                testCase.verifyEqual(string(m.arcs(k).netcdfSha256), res.summary.netcdfSha256(k));
                testCase.verifyEqual(string(m.arcs(k).provSha256), timeSeriesPreparation.internal.fileSha256(pj));
                d = timeSeriesPreparation.readNetcdf(nc);
                testCase.verifyEqual(d.obs, res.results{k}.arc.obs);
            end
            testCase.verifyEqual(string(m.schemaVersion), "2");
            testCase.verifyEqual(string(m.datacite.creators(1).name), "A. Author");
            testCase.verifyEqual(string(m.datacite.creators(1).nameIdentifiers(1).nameIdentifier), ...
                "https://orcid.org/0000-0002-1825-0097");
            testCase.verifyEqual(string(m.datacite.types.resourceTypeGeneral), "Dataset");
            testCase.verifyEqual(string(m.datacite.rightsList(1).rightsIdentifier), "CC-BY-4.0");
        end

        function campaignBoth(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(2);
            cfg = configFor(arcs(1), folder, "both");
            res = timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg);
            for k = 1:2
                testCase.verifyNotEqual(res.summary.file(k), "");
                testCase.verifyNotEqual(res.summary.netcdf(k), "");
                S = load(fullfile(folder, res.summary.file(k)));
                d = timeSeriesPreparation.readNetcdf(fullfile(folder, res.summary.netcdf(k)));
                testCase.verifyEqual(d.obs, S.result.arc.obs);
                testCase.verifyEqual(d.t, S.result.arc.t);
                testCase.verifyEqual(d.residual.obs, S.result.diagnostics.residual.obs);
            end
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            folder = tempFolder(testCase);
            res = runDay();
            a = res.arc;
            p = "timeSeriesPreparation:exportNetcdf:";
            f = @(name, varargin) timeSeriesPreparation.exportNetcdf(fullfile(folder, name), varargin{:});
            testCase.verifyError(@() f("a.nc", a), p + "metadataMissing");
            testCase.verifyError(@() f("b.nc", a, Metadata = struct("creator", "")), p + "metadataMissing");
            testCase.verifyError(@() f("c.nc", named("weights"), Metadata = meta()), p + "inputName");
            testCase.verifyError(@() f("d.nc", named("residual_x"), Metadata = meta()), p + "inputName");
            testCase.verifyError(@() f("e.nc", a, Residual = named("lin_accl_x"), Metadata = meta()), p + "inputEpoch");
            testCase.verifyError(@() f("g.nc", a, Events = 1, Metadata = meta()), p + "inputEvents");
            many = a;
            for j = 1:33
                many = addLayer(many, "L" + j, false(numel(a.t), 1));
            end
            testCase.verifyError(@() f("h.nc", many, Metadata = meta()), p + "tooManyLayers");
            testCase.verifyEqual(numel(dir(fullfile(folder, "*.nc"))), 0, "a refused export left a file");
            r = "timeSeriesPreparation:readNetcdf:";
            testCase.verifyError(@() timeSeriesPreparation.readNetcdf(fullfile(folder, "none.nc")), r + "fileNotFound");
            foreign = fullfile(folder, "foreign.nc");
            nccreate(char(foreign), "x", "Dimensions", {'n', 3}, "Format", "netcdf4");
            testCase.verifyError(@() timeSeriesPreparation.readNetcdf(foreign), r + "schemaVersion");
        end

        function campaignRefusesWithoutCreator(testCase)
            folder = tempFolder(testCase);
            [arcs, refs] = days(2);
            cfg = set(set(timeSeriesPreparation.Config(arcs(1)), "run", "outDir", folder), ...
                "run", "format", "netcdf");
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, Reference = refs, Config = cfg), ...
                "timeSeriesPreparation:run:exportMetadata");
            files = dir(fullfile(folder, "**", "*"));
            testCase.verifyEmpty(files(~[files.isdir]), "files were written before the refusal");
            testCase.verifyError(@() timeSeriesPreparation.run(arcs, Reference = refs, ...
                Config = set(cfg, "run", "format", "xls")), "timeSeriesPreparation:run:inputFormat");
        end

        function existingFileKept(testCase)
            [f, res, info] = exported(testCase);
            testCase.verifyError(@() timeSeriesPreparation.exportNetcdf(f, res.arc, Metadata = meta()), ...
                "timeSeriesPreparation:exportNetcdf:fileExists");
            testCase.verifyEqual(timeSeriesPreparation.internal.fileSha256(f), info.sha256);
            again = timeSeriesPreparation.exportNetcdf(f, res.arc, Metadata = meta(), Overwrite = true, ...
                Created = "2026-09-26T19:00:00Z");
            testCase.verifyEqual(again.id, info.id);
            testCase.verifyEqual(string(ncreadatt(f, "/", "date_created")), "2026-09-26T19:00:00Z");
        end

        function nanSurvives(testCase)
            folder = tempFolder(testCase);
            arc = pairDay(1);
            x = arc.obs; x(100:110, 2) = NaN;
            arc = arcOf(arc.t, x, "2020-01-02");
            f = fullfile(folder, "nan.nc");
            timeSeriesPreparation.exportNetcdf(f, arc, Metadata = meta());
            d = timeSeriesPreparation.readNetcdf(f);
            testCase.verifyTrue(isequaln(d.obs, arc.obs));
            testCase.verifyTrue(all(isnan(d.obs(100:110, 2))));
            testCase.verifyEqual(double(ncreadatt(f, "/", "event_count")), -1);
            testCase.verifyEmpty(d.events);
            testCase.verifyEmpty(d.residual);
            testCase.verifyEqual(d.layers, struct());
        end
    end
end

% ------------------------------------------------------------------------

function [f, res, info] = exported(testCase)
% The standard day run and exported with residual and events to day.nc.
    folder = tempFolder(testCase);
    res = runDay();
    f = fullfile(folder, "day.nc");
    info = timeSeriesPreparation.exportNetcdf(f, res.arc, Residual = res.diagnostics.residual, ...
        Events = res.flags.events, Metadata = meta());
end

function res = runDay()
% run on the standard day: a spike on y at sample 300 and a user layer.
    [arc, ref] = pairDay(1);
    x = arc.obs; x(300, 2) = x(300, 2) + 1e-7;
    u = false(600, 1); u(50:60) = true;
    res = timeSeriesPreparation.run(arcOf(arc.t, x, "2020-01-02"), Reference = ref, User = u);
end

function m = meta()
    m = struct("creator", "A. Author", "creatorOrcid", "0000-0002-1825-0097", ...
        "institution", "Test Institute", "publisher", "Test Publisher");
end

function cfg = configFor(arc, folder, format)
    cfg = set(set(timeSeriesPreparation.Config(arc), "run", "outDir", folder), "run", "format", format);
    m = meta();
    for f = string(fieldnames(m))'
        cfg = set(cfg, "export", f, m.(f));
    end
end

function [arc, ref] = pairDay(k)
% Day k from 2020-01-02, 600 s at 1 Hz: sinusoids plus seeded noise; the sinusoids.
    s = (0:599)';
    sig = 1e-7 * [sin(2 * pi * s / 300), cos(2 * pi * s / 300), sin(2 * pi * s / 200)];
    t = int64(7306 + k - 1) * int64(86400e9) - int64(43200e9) + int64(18e9) + int64(s) * int64(1e9);
    day = string(datetime(2020, 1, 1 + k, "Format", "yyyy-MM-dd"));
    arc = arcOf(t, sig + 1e-9 * randn(RandStream("twister", "Seed", 20 + k), 600, 3), day);
    ref = arcOf(t, sig, day);
end

function [arcs, refs] = days(n)
    for k = 1:n
        [arcs(k), refs(k)] = pairDay(k); %#ok<AGROW>
    end
end

function arc = arcOf(t, obs, day)
% An ACT1B arc of GRACE-FO C, release 04, on epochs t.
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    units = struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2');
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", units, "fileName", "ACT1B_" + day + "_C_04.txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end

function arc = named(name)
% A 5-sample one-column arc whose column is called NAME (on other epochs).
    t = int64(7306 * 86400 - 43200 + 18) * int64(1e9) + int64(0:4)' * int64(1e9);
    aux = struct("obsNames", {{char(name)}}, "variableNames", {{char(name)}}, ...
        "variableFieldNames", {{char(name)}}, "variableUnits", struct(char(name), 'm/s2'), ...
        "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, zeros(5, 1), aux);
end

function folder = tempFolder(testCase)
    fx = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = string(fx.Folder);
end
