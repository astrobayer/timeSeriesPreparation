function info = exportNetcdf(file, arc, options)
%EXPORTNETCDF  One arc, its residual and QC events as a CF-1.12/ACDD-1.3 NetCDF-4 file with PROV-O provenance.
%
%   SYNTAX
%     info = timeSeriesPreparation.exportNetcdf(file, arc, Metadata = m)
%     info = timeSeriesPreparation.exportNetcdf(file, arc, Residual = s, Events = T, Metadata = m, Overwrite = true)
%
%   DESCRIPTION
%     The exchange format of a prepared day (X-18, CONCEPT 5.2; owner
%     decisions 2026-09-26). The file is NetCDF-4 (deflate 4, shuffle) and
%     states Conventions "CF-1.12, ACDD-1.3". Variables:
%       time              int64 GPS nanoseconds, arc.t bit for bit: units
%                         "nanoseconds since 2000-01-01 12:00:00", calendar
%                         "standard", units_metadata "leap_seconds: none"
%                         (GPS counts no leap seconds; CF 1.12 section 4.4,
%                         kept by the owner although CF 1.13 withdrew the
%                         attribute in favour of the calendar "tai").
%       <name>            each observation column, double, named and with
%                         the units of arc.names and arc.units; NaN is the
%                         _FillValue.
%       weights           arc.weights, units "1".
%       filled            byte 0/1 (flag_values, flag_meanings "measured
%                         filled").
%       layers            uint32, bit j-1 set where layer j removes the
%                         sample; flag_masks and flag_meanings give the
%                         bits and the layer names (absent without layers).
%       residual_<name>   with Residual: its columns, same epochs.
%       event_*           with Events, on dimension "event": event_start,
%                         event_end (int64 GPS ns, as time), event_class,
%                         event_axis, event_source (byte codes with
%                         flag_values and flag_meanings), event_amplitude,
%                         event_sigma, event_confidence.
%     Global attributes: the ACDD 1.3 set (title, summary, keywords, id, history,
%     source, platform, instrument, processing_level, product_version,
%     date_created, creator_name/_email/_url/_type/_institution,
%     institution, publisher_name, license, project, time_coverage_start/
%     _end/_duration/_resolution), l1b_release, frame, schema_version
%     ("1", the layout above), observation_variables and
%     residual_variables (the names in column order), event_count (-1
%     without Events, else their number), and
%     prov_jsonld, the PROV-O graph of the arc's provenance
%     (internal.provJsonLd). The same graph is written to the sidecar
%     <file name>.prov.jsonld beside the file. id is the SHA-256 of t and
%     obs (internal.contentHash), so equal data give equal ids.
%
%   INPUTS
%     file  (1,1) string   -   Path of the .nc file to write.
%     arc   (1,1) Arc      -   The prepared arc.
%
%   OPTIONS
%     Residual   (1,1) Arc      []       The residual on arc.t (run's
%                                        diagnostics.residual).
%     Events     (N,8) table    []       qc.eventTable rows (run's
%                                        flags.events).
%     Metadata   (1,1) struct   -        Config.export: creator
%                                        (required), creatorOrcid,
%                                        creatorEmail, institution,
%                                        publisher, license, title,
%                                        project.
%     Overwrite  (1,1) logical  [false]  Replace an existing file and
%                                        sidecar.
%     Created    (1,1) string   [now]    date_created, ISO 8601 UTC.
%
%   OUTPUTS
%     info  (1,1) struct   -   Fields: file, prov (the sidecar path),
%                              sha256 and provSha256 (internal.fileSha256),
%                              id, variables (1,:) string.
%
%   ACCURACY
%     time, the observations, weights, filled, layers and the residual
%     are written as stored: readNetcdf returns them bit for bit
%     (TestExport). Event epochs are UTC datetimes; their GPS nanoseconds
%     come from a duration and are exact to about 1 microsecond.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:exportNetcdf:metadataMissing - Metadata has
%           no creator; none is invented.
%       timeSeriesPreparation:exportNetcdf:inputName - an observation name
%           is not a NetCDF-safe identifier or collides with a reserved
%           variable (time, weights, filled, layers, residual_*, event_*).
%       timeSeriesPreparation:exportNetcdf:inputEpoch - Residual is not on
%           arc.t.
%       timeSeriesPreparation:exportNetcdf:inputEvents - Events is not a
%           qc.eventTable.
%       timeSeriesPreparation:exportNetcdf:tooManyLayers - the arc has
%           more than 32 layers.
%     State:
%       timeSeriesPreparation:exportNetcdf:fileExists - file or its
%           sidecar exists and Overwrite is false.
%
%   EXAMPLE
%     % A ten-sample arc with one layer to a temporary file, and back.
%     t = int64(7306 * 86400 - 43200 + 18) * int64(1e9) + int64(0:9)' * int64(1e9);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-02_C_04.txt", "product", "ACT1B");
%     arc = addLayer(timeSeriesPreparation.Arc(t, (1:10)' * 1e-9, aux), "user", (1:10)' > 8);
%     f = tempname + ".nc";
%     info = timeSeriesPreparation.exportNetcdf(f, arc, Metadata = struct("creator", "A. Author"));
%     back = timeSeriesPreparation.readNetcdf(f);
%     delete(f, info.prov);
%
%   LIMITATIONS
%     Global attributes are written as NetCDF char; keep the metadata
%     ASCII. The events are a plain table on dimension "event", not a CF
%     discrete-sampling geometry. At most 32 layers.
%
%   REFERENCES
%     CF Conventions 1.12 (2024-12-04), sections 2, 3.5 (flags) and 4.4
%     (time, units_metadata); CF 1.13 (2025-12-17) Appendix M. ACDD 1.3
%     (ESIP, 2015). W3C PROV-O (2013). docs/CONCEPT.md 5.2; HANDOVER X-18.
%
%   See also timeSeriesPreparation.readNetcdf, timeSeriesPreparation.internal.provJsonLd, timeSeriesPreparation.run, timeSeriesPreparation.Config.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        file (1,1) string
        arc (1,1) timeSeriesPreparation.Arc
        options.Residual = []
        options.Events = []
        options.Metadata (1,1) struct = struct()
        options.Overwrite (1,1) logical = false
        options.Created (1,1) string = ""
    end
    m = metadata(options.Metadata);
    names = arc.names;
    reserved = ["time" "weights" "filled" "layers"];
    bad = cellfun(@isempty, regexp(cellstr(names), '^[A-Za-z]\w*$', 'once')) ...
        | ismember(names, reserved) | startsWith(names, ["residual_" "event_"]);
    if any(bad)
        error("timeSeriesPreparation:exportNetcdf:inputName", ...
            "observation name '%s' is not a NetCDF-safe identifier or is reserved -> rename the column", ...
            names(find(bad, 1)));
    end
    res = options.Residual;
    if ~isempty(res) && (~isa(res, "timeSeriesPreparation.Arc") || ~isequal(res.t, arc.t))
        error("timeSeriesPreparation:exportNetcdf:inputEpoch", ...
            "Residual must be an Arc on arc.t -> pass run's diagnostics.residual");
    end
    ev = options.Events;
    given = ~(isnumeric(ev) && isempty(ev));               % [] = not given; a 0-row table is given
    schema = timeSeriesPreparation.qc.eventTable().Properties.VariableNames;
    if given && (~istable(ev) || ~isequal(ev.Properties.VariableNames, schema))
        error("timeSeriesPreparation:exportNetcdf:inputEvents", ...
            "Events must be a qc.eventTable -> pass run's flags.events");
    end
    layerNames = string(fieldnames(arc.layers))';
    if numel(layerNames) > 32
        error("timeSeriesPreparation:exportNetcdf:tooManyLayers", ...
            "the arc has %d layers; the layers variable holds 32 -> merge layers before export", numel(layerNames));
    end
    [folder, stem, ext] = fileparts(file);
    prov = fullfile(folder, stem + ".prov.jsonld");
    if (isfile(file) || isfile(prov)) && ~options.Overwrite
        error("timeSeriesPreparation:exportNetcdf:fileExists", ...
            "%s or its sidecar exists -> pass Overwrite = true or choose another name", file);
    end
    if isfile(file), delete(file); end
    if folder ~= "" && ~isfolder(folder), mkdir(folder); end

    created = options.Created;
    if created == ""
        created = string(datetime("now", "TimeZone", "UTC", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'"));
    end
    here = timeSeriesPreparation.internal.toolboxVersion();
    K = numel(arc.t);
    f = char(file);
    variables = strings(1, 0);

    put(f, "time", arc.t, "int64", {'time', K}, [], true);
    att(f, "time", "units", "nanoseconds since 2000-01-01 12:00:00");
    att(f, "time", "calendar", "standard");
    att(f, "time", "units_metadata", "leap_seconds: none");
    att(f, "time", "standard_name", "time");
    att(f, "time", "long_name", "GPS time");
    att(f, "time", "axis", "T");
    variables(end+1) = "time";
    for k = 1:numel(names)
        put(f, names(k), arc.obs(:, k), "double", {'time', K}, NaN, false);
        att(f, names(k), "units", arc.units(k));
        att(f, names(k), "long_name", names(k) + " (" + arc.product + ")");
        variables(end+1) = names(k); %#ok<AGROW>
    end
    put(f, "weights", arc.weights, "double", {'time', K}, [], false);
    att(f, "weights", "units", "1");
    att(f, "weights", "long_name", "sample weight, the minimum over the layers (1 kept, 0 removed)");
    put(f, "filled", int8(arc.filled), "int8", {'time', K}, [], false);
    att(f, "filled", "flag_values", int8([0 1]));
    att(f, "filled", "flag_meanings", "measured filled");
    att(f, "filled", "long_name", "sample filled by the gap stage");
    variables = [variables "weights" "filled"];
    if ~isempty(layerNames)
        bits = zeros(K, 1, "uint32");
        for j = 1:numel(layerNames)
            bits = bitor(bits, uint32(arc.layers.(layerNames(j))) * uint32(2^(j - 1)));
        end
        put(f, "layers", bits, "uint32", {'time', K}, [], false);
        att(f, "layers", "flag_masks", uint32(2 .^ (0:numel(layerNames) - 1)));
        att(f, "layers", "flag_meanings", strjoin(layerNames, " "));
        att(f, "layers", "long_name", "removal layers, one bit each");
        variables(end+1) = "layers";
    end
    resNames = strings(1, 0);
    if ~isempty(res)
        for k = 1:numel(res.names)
            v = "residual_" + res.names(k);
            put(f, v, res.obs(:, k), "double", {'time', K}, NaN, false);
            att(f, v, "units", res.units(k));
            att(f, v, "long_name", "residual of " + res.names(k) + ": obs - (bias + scale x reference)");
            resNames(end+1) = v; %#ok<AGROW>
        end
        variables = [variables resNames];
    end
    nEvents = -1;                                       % -1: no Events given
    if given
        nEvents = height(ev);
    end
    if nEvents > 0
        N = nEvents;
        put(f, "event_start", gpsOf(ev.tStart), "int64", {'event', N}, [], false);
        put(f, "event_end", gpsOf(ev.tEnd), "int64", {'event', N}, [], false);
        for v = ["event_start" "event_end"]
            att(f, v, "units", "nanoseconds since 2000-01-01 12:00:00");
            att(f, v, "calendar", "standard");
            att(f, v, "units_metadata", "leap_seconds: none");
        end
        codes = eventCodes();
        for c = ["class" "axis" "source"]
            [~, code] = ismember(ev.(c), codes.(c));
            v = "event_" + c;
            put(f, v, int8(code), "int8", {'event', N}, [], false);
            att(f, v, "flag_values", int8(1:numel(codes.(c))));
            att(f, v, "flag_meanings", strjoin(codes.(c), " "));
        end
        put(f, "event_amplitude", ev.amplitude, "double", {'event', N}, NaN, false);
        put(f, "event_sigma", ev.sigma, "double", {'event', N}, NaN, false);
        put(f, "event_confidence", ev.confidence, "double", {'event', N}, [], false);
        att(f, "event_confidence", "units", "1");
        variables = [variables "event_start" "event_end" "event_class" "event_axis" ...
            "event_source" "event_amplitude" "event_sigma" "event_confidence"];
    end

    id = timeSeriesPreparation.internal.contentHash(struct("t", arc.t, "obs", arc.obs));
    txt = timeSeriesPreparation.internal.provJsonLd(arc.provenance, Inputs = arc.files, ...
        Output = stem + ext, Creator = m.creator, CreatorOrcid = m.creatorOrcid, Created = created);
    utc = utcOf(arc.t([1 end]));
    utc.Format = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    platform = strtrim(strjoin([arc.mission arc.satellite], " "));
    title = m.title;
    if title == ""
        title = strjoin([arc.product platform string(utc(1), "yyyy-MM-dd")], " ") + ", prepared";
    end
    g = struct( ...
        "Conventions", "CF-1.12, ACDD-1.3", ...
        "title", title, ...
        "summary", "Instrument time series prepared by timeSeriesPreparation " + here + ...
            ": observations with weights, removal layers and fills" + ...
            ternary(isempty(res), "", ", the residual to the reference") + ...
            ternary(~given, "", " and the QC events") + ".", ...
        "keywords", keywords(arc.product), ...
        "id", id, ...
        "history", created + " timeSeriesPreparation " + here + " exportNetcdf; stages: " + ...
            strjoin(string({arc.provenance.stage}), ", "), ...
        "source", strjoin(reshape(arc.files, 1, []), ", "), ...
        "platform", platform, ...
        "instrument", arc.product, ...
        "processing_level", "L1B, prepared (timeSeriesPreparation)", ...
        "product_version", here, ...
        "date_created", created, ...
        "creator_name", m.creator, ...
        "creator_email", m.creatorEmail, ...
        "creator_url", orcidUrl(m.creatorOrcid), ...
        "creator_type", "person", ...
        "creator_institution", m.institution, ...
        "institution", m.institution, ...
        "publisher_name", m.publisher, ...
        "license", m.license, ...
        "project", m.project, ...
        "time_coverage_start", string(utc(1)), ...
        "time_coverage_end", string(utc(2)), ...
        "time_coverage_duration", sprintf("PT%.9gS", double(arc.t(end) - arc.t(1)) * 1e-9), ...
        "time_coverage_resolution", sprintf("PT%.9gS", median(double(diff(arc.t))) * 1e-9), ...
        "l1b_release", arc.release, ...
        "frame", arc.frame, ...
        "schema_version", "1", ...
        "observation_variables", strjoin(names, " "), ...
        "residual_variables", strjoin(resNames, " "), ...
        "event_count", int32(nEvents), ...
        "prov_jsonld", txt);
    for a = string(fieldnames(g))'
        value = g.(a);
        if isstring(value)
            if value == "", continue, end
            value = char(value);
        end
        ncwriteatt(f, '/', char(a), value);
    end

    fid = fopen(prov, "w", "n", "UTF-8");
    fwrite(fid, char(txt), "char");
    fclose(fid);
    info = struct("file", file, "prov", string(prov), ...
        "sha256", timeSeriesPreparation.internal.fileSha256(file), ...
        "provSha256", timeSeriesPreparation.internal.fileSha256(prov), ...
        "id", id, "variables", variables);
end

% ------------------------------------------------------------------------

function m = metadata(s)
% Config.export with defaults; a missing creator refuses.
    m = struct("creator", "", "creatorOrcid", "", "creatorEmail", "", "institution", "", ...
        "publisher", "", "license", "CC-BY-4.0", "title", "", "project", "");
    for f = string(fieldnames(s))'
        m.(f) = string(s.(f));
    end
    if m.creator == ""
        error("timeSeriesPreparation:exportNetcdf:metadataMissing", ...
            "Metadata has no creator -> set cfg.export.creator (none is invented)");
    end
end

function put(f, name, data, type, dims, fill, first)
% Create a variable (the first one creates the NetCDF-4 file) and write it.
    args = {'Dimensions', dims, 'Datatype', type, 'DeflateLevel', 4, 'Shuffle', true};
    if isempty(fill)
        args = [args, {'FillValue', 'disable'}];
    else
        args = [args, {'FillValue', fill}];
    end
    if first
        args = [args, {'Format', 'netcdf4'}];
    end
    nccreate(f, char(name), args{:});
    ncwrite(f, char(name), data);
end

function att(f, var, name, value)
% A variable attribute; an empty text (a unit not stated) is left out.
    if isstring(value), value = char(value); end
    if ischar(value) && isempty(value), return, end
    ncwriteatt(f, char(var), char(name), value);
end

function c = eventCodes()
% The code lists of the event variables: qc.eventTable's admissible sets.
    c = struct("class", ["outlier" "impulse" "jump"], "axis", ["x" "y" "z" "all"], ...
        "source", ["THR1B" "MAS1B" "eclipse" "heater" "magnetorquer" "unassigned"]);
end

function n = gpsOf(t)
% int64 GPS nanoseconds of UTC datetimes: the inverse of utcOf.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    t.TimeZone = "UTCLeapSeconds";
    n = int64(round(milliseconds(t - t0) * 1e6));
end

function e = utcOf(t)
% UTC datetimes of int64 GPS nanoseconds, as run: GPS minus the leap seconds.
    t0 = datetime(2000, 1, 1, 11, 59, 47, "TimeZone", "UTCLeapSeconds");
    e = t0 + seconds(double(t) * 1e-9);
    e.TimeZone = "UTC";
end

function u = orcidUrl(orcid)
    u = orcid;
    if u ~= "" && ~startsWith(u, "https://")
        u = "https://orcid.org/" + u;
    end
end

function k = keywords(product)
% ACDD keywords: the mission family, the product (when known), the topic.
    k = ["GRACE-FO" product "satellite gravimetry" "time series preparation"];
    k = strjoin(k(k ~= ""), ", ");
end

function v = ternary(c, a, b)
    if c, v = a; else, v = b; end
end
