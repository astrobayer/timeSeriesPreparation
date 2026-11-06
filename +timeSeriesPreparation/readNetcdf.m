function d = readNetcdf(file)
%READNETCDF  A file of exportNetcdf back as a struct: time, observations, weights, layers, residual, events, attributes.
%
%   SYNTAX
%     d = timeSeriesPreparation.readNetcdf(file)
%
%   DESCRIPTION
%     The reader of the X-18 exchange format (CONCEPT 5.2; HANDOVER X-18).
%     It reads the layout that exportNetcdf writes, schema_version "1":
%     the observation and residual variables named by the global
%     attributes observation_variables and residual_variables, in that
%     order; layers decoded from their bits by flag_masks and
%     flag_meanings; the events, when event_count is not -1, rebuilt as a
%     qc.eventTable with UTC epochs (GPS minus the leap seconds, as run).
%     It returns a struct, not an Arc: an Arc is built from the L1B reader's
%     metadata, which the file keeps only as attributes.
%
%   INPUTS
%     file  (1,1) string   -   A NetCDF file written by exportNetcdf.
%
%   OUTPUTS
%     d  (1,1) struct   -   Fields: t (K,1) int64 GPS ns; obs (K,M)
%                           double; names, units (1,M) string; weights
%                           (K,1) double; filled (K,1) logical; layers
%                           (1,1) struct of (K,1) logical; residual, []
%                           or a struct with obs, names (without the
%                           prefix) and units; events, [] or an (N,8)
%                           qc.eventTable; attributes (1,1) struct, the
%                           global attributes.
%
%   ACCURACY
%     Exact for t, obs, weights, filled, layers and the residual (the
%     values are read as stored). Event epochs to about 1 microsecond (see
%     exportNetcdf).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:readNetcdf:fileNotFound - file does not
%           exist.
%       timeSeriesPreparation:readNetcdf:schemaVersion - the file's
%           schema_version is not "1", or it has none (not written by
%           exportNetcdf).
%
%   EXAMPLE
%     % Export a five-sample arc and read its time and observations back.
%     t = int64(7306 * 86400 - 43200 + 18) * int64(1e9) + int64(0:4)' * int64(1e9);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
%     f = tempname + ".nc";
%     info = timeSeriesPreparation.exportNetcdf(f, timeSeriesPreparation.Arc(t, zeros(5, 1), aux), Metadata = struct("creator", "A. Author"));
%     d = timeSeriesPreparation.readNetcdf(f);
%     delete(f, info.prov);
%
%   LIMITATIONS
%     Reads schema_version "1" only; files of other writers refuse.
%
%   REFERENCES
%     docs/CONCEPT.md 5.2; HANDOVER X-18; CF Conventions 1.12 section 3.5
%     (flags).
%
%   See also timeSeriesPreparation.exportNetcdf, timeSeriesPreparation.qc.eventTable.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        file (1,1) string
    end
    if ~isfile(file)
        error("timeSeriesPreparation:readNetcdf:fileNotFound", "%s does not exist -> check the path", file);
    end
    f = char(file);
    info = ncinfo(f);
    a = struct();
    for g = info.Attributes
        name = matlab.lang.makeValidName(g.Name);
        v = g.Value;
        if ischar(v), v = string(v); end
        a.(name) = v;
    end
    if ~isfield(a, "schema_version") || a.schema_version ~= "1"
        error("timeSeriesPreparation:readNetcdf:schemaVersion", ...
            "%s has no schema_version 1 -> only files of exportNetcdf are read", file);
    end
    vars = string({info.Variables.Name});

    d = struct("t", [], "obs", [], "names", [], "units", [], "weights", [], "filled", [], ...
        "layers", struct(), "residual", [], "events", [], "attributes", a);
    d.t = ncread(f, "time");
    names = words(a, "observation_variables");
    K = numel(d.t);
    d.obs = zeros(K, numel(names));
    d.units = strings(1, numel(names));
    for k = 1:numel(names)
        d.obs(:, k) = ncread(f, char(names(k)));
        d.units(k) = string(ncreadatt(f, char(names(k)), "units"));
    end
    d.names = names;
    d.weights = ncread(f, "weights");
    d.filled = logical(ncread(f, "filled"));
    if any(vars == "layers")
        bits = ncread(f, "layers");
        masks = ncreadatt(f, "layers", "flag_masks");
        meanings = split(string(ncreadatt(f, "layers", "flag_meanings")))';
        for j = 1:numel(meanings)
            d.layers.(meanings(j)) = bitand(bits, masks(j)) ~= 0;
        end
    end
    rnames = words(a, "residual_variables");
    if ~isempty(rnames)
        r = struct("obs", zeros(K, numel(rnames)), "names", erase(rnames, "residual_"), ...
            "units", strings(1, numel(rnames)));
        for k = 1:numel(rnames)
            r.obs(:, k) = ncread(f, char(rnames(k)));
            r.units(k) = string(ncreadatt(f, char(rnames(k)), "units"));
        end
        d.residual = r;
    end
    n = double(a.event_count);
    if n == 0
        d.events = timeSeriesPreparation.qc.eventTable();
    elseif n > 0
        cols = cell(1, 3);
        c = ["class" "axis" "source"];
        for k = 1:3
            v = "event_" + c(k);
            meanings = split(string(ncreadatt(f, char(v), "flag_meanings")));
            cols{k} = meanings(double(ncread(f, char(v))));
        end
        d.events = timeSeriesPreparation.qc.eventTable(utcOf(ncread(f, "event_start")), ...
            utcOf(ncread(f, "event_end")), cols{1}, cols{2}, ncread(f, "event_amplitude"), ...
            ncread(f, "event_sigma"), cols{3}, ncread(f, "event_confidence"));
    end
end

% ------------------------------------------------------------------------

function w = words(a, name)
% A space-separated name list of a global attribute; empty if absent.
    w = strings(1, 0);
    if isfield(a, name) && strlength(a.(name)) > 0
        w = split(a.(name))';
    end
end

function e = utcOf(t)
% UTC datetimes of int64 GPS nanoseconds, as run.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end
