classdef Arc
%ARC  One instrument time series on int64 GPS-ns epochs, with weights, layers and provenance.
%
%   SYNTAX
%     arc = timeSeriesPreparation.Arc(t, obs, aux)
%     arc = timeSeriesPreparation.Arc(t, obs, aux, Columns = names, Frame = frame)
%     arc = addLayer(arc, name, remove)
%     arc = fillSamples(arc, values, mask, detail)
%     arc = appendProvenance(arc, stage, detail)
%     out = derive(arc, t, obs, stage, detail, Units = units)
%     timeSeriesPreparation.Arc.requireOneRelease(arcs)
%     s = saveobj(arc)
%     arc = timeSeriesPreparation.Arc.loadobj(s)
%
%   DESCRIPTION
%     The container every stage of this toolbox reads and returns (CONCEPT
%     5). It is built from gracefoReading's triple [t, obs, aux] by FIELD
%     NAMES - aux.obsNames, variableNames, variableFieldNames, variableUnits
%     and fileName/product (readL1b) or fileNames/products (readL1bMulti) -
%     and calls no gracefoReading function, so it works without the reader
%     installed. Time must be int64 GPS nanoseconds ('TimeFormat' "gpsns"):
%     a double cannot hold 2020-era GPS nanoseconds (about 6.3e17 > 2^53)
%     without rounding. Columns are selected by name; there is no positional
%     fallback.
%
%     Release rule (CONCEPT 5.2): the L1B release of every file is read from
%     its name (<PRODUCT>_<date>_<sat>_<RR>), or from the header line
%     "product_version:" when the name does not carry it, and stored in
%     release and provenance. An arc whose files come from more than one
%     release refuses unless AllowMixedRelease is true; requireOneRelease
%     applies the same rule to a campaign (an array of arcs).
%
%     Weights and layers: a layer is a named N x 1 logical, true = remove.
%     Layers are additive and can only remove: addLayer refuses to replace a
%     layer, and weights = min over all layers (1 kept, 0 removed). filled
%     is set by the gap stage (X-08) through fillSamples, which writes
%     values into obs where mask is true on the same epochs, flags those rows
%     in filled and appends a "fill" provenance entry; it is all false
%     otherwise. provenance is
%     append-only, one entry per stage: stage, toolbox version, UTC time,
%     detail.
%
%     derive is how a stage returns data on new epochs (crnApply, later
%     align): the result keeps names, mission, product, satellite, release,
%     files and frame, carries the provenance and appends the stage's entry;
%     weights, layers and filled start afresh, because they belong to the old
%     epochs.
%
%     Schema version (X-18, CONCEPT 5.2): Arc.SchemaVersion names the layout
%     of the stored arc, "2" since release 1.2.0. save stores the struct of
%     saveobj (every property and schemaVersion); load calls loadobj, which
%     restores it. An arc saved by 1.1.0 or earlier (schema "1", saved as
%     the object itself, same properties) reaches loadobj as an Arc and is
%     taken unchanged. A struct of any other schemaVersion refuses, so a
%     file of a later release is never read with the wrong layout.
%
%   INPUTS
%     t       (N,1) int64    -   GPS nanoseconds past 2000-01-01 12:00:00,
%                                strictly increasing.
%     obs     (N,M) double   -   Observations, column j named aux.obsNames{j}.
%                                Real double; NaN is the only missing value,
%                                Inf refuses.
%     aux     (1,1) struct   -   gracefoReading's metadata; the fields named
%                                in DESCRIPTION are required.
%     name    (1,1) string   -   Layer name, a valid MATLAB field name.
%     remove  (N,1) logical  -   Layer mask, true = sample removed.
%     stage   (1,1) string   -   Name of the stage writing provenance.
%     detail  (1,1) struct   -   Stage-specific provenance detail.
%     arcs    (1,:) Arc      -   A campaign: an array of arcs.
%     units   (1,:) string   -   derive: units of the new obs columns.
%     values  (N,M) double   -   fillSamples: filled observations; only the
%                                entries under mask are used, finite.
%     mask    (N,M) logical  -   fillSamples: true = entry filled.
%     s       (1,1) struct   -   loadobj: the struct saveobj made (or an
%                                Arc saved by schema 1).
%
%   OPTIONS
%     Columns            (1,:) string   [all]     Observation names to keep,
%                                                 in this order.
%     Frame              (1,1) string   [""]      Frame of obs, stated by the
%                                                 caller; "" = not stated.
%     AllowMixedRelease  (1,1) logical  [false]   Accept files from more than
%                                                 one L1B release.
%
%   OUTPUTS
%     arc  (1,1) Arc   -   Properties: t, obs, names, units, mission,
%                          product, satellite, release, files, frame,
%                          frameSource, weights, layers, filled, provenance;
%                          the constant SchemaVersion ("2").
%     s    (1,1) struct  -   saveobj: schemaVersion and every property.
%
%   ACCURACY
%     Exact: t and obs are stored as given, bit for bit, and selecting
%     columns copies them without arithmetic. Weights are exactly 0 or 1.
%
%   ERRORS
%     Time:
%       timeSeriesPreparation:Arc:timeFormat - t is not an int64 column
%           vector (read with 'TimeFormat', "gpsns").
%       timeSeriesPreparation:Arc:timeNotIncreasing - t is not strictly
%           increasing.
%     Observations:
%       timeSeriesPreparation:Arc:sizeMismatch - obs is not a real double, or
%           its rows differ from numel(t) or its columns from
%           numel(aux.obsNames); for fillSamples, values or mask is not the
%           size of obs, or not double and logical.
%       timeSeriesPreparation:Arc:notFinite - obs holds Inf (NaN is allowed);
%           for fillSamples, a value under mask is NaN or Inf.
%       timeSeriesPreparation:Arc:unknownColumn - Columns names an observation
%           the file does not have, or names one twice.
%     Metadata:
%       timeSeriesPreparation:Arc:auxField - aux lacks a required field.
%       timeSeriesPreparation:Arc:mixedProduct - the files hold different
%           products or satellites.
%       timeSeriesPreparation:Arc:mixedRelease - the files, or the arcs of a
%           campaign, come from more than one L1B release.
%     Layers:
%       timeSeriesPreparation:Arc:badLayer - the layer is not N x 1 logical,
%           its name is not a field name, or a layer of that name exists.
%     Storage:
%       timeSeriesPreparation:Arc:schemaVersion - loadobj got a struct whose
%           schemaVersion is not "2", or no Arc and no struct.
%
%   EXAMPLE
%     % A ten-sample ACT1B-like arc from a hand-made aux struct.
%     t = int64(0:9)' * int64(1e9);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'gps_time', 'lin_accl_x'}}, "variableFieldNames", {{'gps_time', 'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     arc = timeSeriesPreparation.Arc(t, zeros(10, 1), aux);
%     arc = addLayer(arc, "demo", (1:10)' > 8);
%
%   LIMITATIONS
%     The frame is never inferred: it stays "" unless Frame states it, and a
%     stage that needs a frame refuses (v3 F5). The release is read from the
%     file name or header only; a file stating neither gets release "".
%
%   REFERENCES
%     docs/CONCEPT.md sections 5, 5.1, 5.2; gracefoReading.readL1b help
%     (the aux fields).
%
%   See also timeSeriesPreparation.Config, gracefoReading.readL1b, gracefoReading.readL1bMulti.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.2 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        SchemaVersion = "2"
    end

    properties (SetAccess = private)
        t = int64.empty(0, 1)
        obs = zeros(0, 0)
        names = strings(1, 0)
        units = strings(1, 0)
        mission = ""
        product = ""
        satellite = ""
        release = ""
        files = strings(0, 1)
        frame = ""
        frameSource = ""
        weights = zeros(0, 1)
        layers = struct()
        filled = false(0, 1)
        provenance = struct("stage", {}, "version", {}, "time", {}, "detail", {})
    end

    methods
        function arc = Arc(t, obs, aux, options)
            arguments
                t = int64.empty(0, 1)
                obs = zeros(0, 0)
                aux (1,1) struct = struct()
                options.Columns (1,:) string = strings(1, 0)
                options.Frame (1,1) string = ""
                options.AllowMixedRelease (1,1) logical = false
            end
            if nargin == 0
                return                                  % empty arc, for arrays
            end

            checkTime(t);
            required = ["obsNames" "variableNames" "variableFieldNames" "variableUnits"];
            for f = required
                if ~isfield(aux, f)
                    error("timeSeriesPreparation:Arc:auxField", ...
                        "aux lacks the field %s (gracefoReading readL1b/readL1bMulti).", f);
                end
            end
            [fileList, products, headers] = fileMetadata(aux);

            obsNames = string(aux.obsNames(:)');
            if ~isa(obs, "double") || ~isreal(obs) || size(obs, 1) ~= numel(t) ...
                    || size(obs, 2) ~= numel(obsNames)
                error("timeSeriesPreparation:Arc:sizeMismatch", ...
                    "obs is %s %s; expected real double %d x %d " + ...
                    "(numel(t) x numel(aux.obsNames)).", ...
                    mat2str(size(obs)), class(obs), numel(t), numel(obsNames));
            end
            if any(isinf(obs), "all")
                error("timeSeriesPreparation:Arc:notFinite", ...
                    "obs holds Inf; NaN is the only missing value (CONCEPT 5.2).");
            end

            if isempty(options.Columns)
                idx = 1:numel(obsNames);
            else
                [found, idx] = ismember(options.Columns, obsNames);
                if ~all(found) || numel(unique(options.Columns)) < numel(options.Columns)
                    error("timeSeriesPreparation:Arc:unknownColumn", ...
                        "Columns must name distinct observations of the file; " + ...
                        "unknown or repeated: %s. Available: %s.", ...
                        strjoin(options.Columns(~found | duplicated(options.Columns)), ", "), ...
                        strjoin(obsNames, ", "));
                end
            end

            [sats, releases] = parseFileNames(fileList, headers);
            if numel(unique(string(products))) > 1 || numel(unique(sats)) > 1
                error("timeSeriesPreparation:Arc:mixedProduct", ...
                    "The files hold more than one product or satellite: %s.", ...
                    strjoin(row(unique(string(products) + "/" + sats)), ", "));
            end
            rel = unique(releases);
            if numel(rel) > 1 && ~options.AllowMixedRelease
                error("timeSeriesPreparation:Arc:mixedRelease", ...
                    "The files come from more than one L1B release (%s); " + ...
                    "pass AllowMixedRelease = true to accept that (CONCEPT 5.2).", ...
                    strjoin(row(rel), ", "));
            end

            arc.t = t;
            arc.obs = obs(:, idx);
            arc.names = obsNames(idx);
            arc.units = unitsOf(arc.names, aux);
            arc.product = string(products(1));
            arc.satellite = sats(1);
            arc.mission = missionOf(arc.satellite);
            arc.release = strjoin(row(rel), "+");
            arc.files = fileList;
            arc.frame = options.Frame;
            if options.Frame ~= ""
                arc.frameSource = "option";
            end
            arc.weights = ones(numel(t), 1);
            arc.filled = false(numel(t), 1);
            arc = appendProvenance(arc, "Arc", struct( ...
                "files", fileList, "releases", releases, "columns", arc.names, ...
                "allowMixedRelease", options.AllowMixedRelease));
        end

        function out = derive(arc, t, obs, stage, detail, options)
            arguments
                arc (1,1) timeSeriesPreparation.Arc
                t
                obs
                stage (1,1) string
                detail (1,1) struct = struct()
                options.Units (1,:) string = arc.units
            end
            checkTime(t);
            if ~isa(obs, "double") || ~isreal(obs) || size(obs, 1) ~= numel(t) ...
                    || size(obs, 2) ~= numel(arc.names) ...
                    || numel(options.Units) ~= numel(arc.names)
                error("timeSeriesPreparation:Arc:sizeMismatch", ...
                    "obs is %s %s and Units has %d entries; expected real " + ...
                    "double %d x %d and %d units.", mat2str(size(obs)), ...
                    class(obs), numel(options.Units), numel(t), ...
                    numel(arc.names), numel(arc.names));
            end
            if any(isinf(obs), "all")
                error("timeSeriesPreparation:Arc:notFinite", ...
                    "obs holds Inf; NaN is the only missing value (CONCEPT 5.2).");
            end
            out = arc;
            out.t = t;
            out.obs = obs;
            out.units = options.Units;
            out.weights = ones(numel(t), 1);
            out.layers = struct();
            out.filled = false(numel(t), 1);
            out = appendProvenance(out, stage, detail);
        end

        function arc = addLayer(arc, name, remove)
            arguments
                arc (1,1) timeSeriesPreparation.Arc
                name (1,1) string
                remove
            end
            if ~isvarname(name) || isfield(arc.layers, name) || ~islogical(remove) ...
                    || ~isequal(size(remove), [numel(arc.t) 1])
                error("timeSeriesPreparation:Arc:badLayer", ...
                    "A layer needs a new field name and an %d x 1 logical mask; " + ...
                    "got ""%s"" and %s %s.", numel(arc.t), name, ...
                    mat2str(size(remove)), class(remove));
            end
            arc.layers.(name) = remove;
            arc.weights = min(arc.weights, double(~remove));
            arc = appendProvenance(arc, "addLayer", struct( ...
                "layer", name, "removed", nnz(remove)));
        end

        function arc = fillSamples(arc, values, mask, detail)
            arguments
                arc (1,1) timeSeriesPreparation.Arc
                values
                mask
                detail (1,1) struct = struct()
            end
            if ~isa(values, "double") || ~isreal(values) || ~isequal(size(values), size(arc.obs)) ...
                    || ~islogical(mask) || ~isequal(size(mask), size(arc.obs))
                error("timeSeriesPreparation:Arc:sizeMismatch", ...
                    "fillSamples needs real double values and a logical mask, " + ...
                    "both %d x %d; got %s %s and %s %s.", size(arc.obs, 1), ...
                    size(arc.obs, 2), mat2str(size(values)), class(values), ...
                    mat2str(size(mask)), class(mask));
            end
            if ~all(isfinite(values(mask)))
                error("timeSeriesPreparation:Arc:notFinite", ...
                    "A filled value is NaN or Inf; a fill must be finite.");
            end
            arc.obs(mask) = values(mask);
            arc.filled = arc.filled | any(mask, 2);
            arc = appendProvenance(arc, "fill", detail);
        end

        function arc = appendProvenance(arc, stage, detail)
            arguments
                arc (1,1) timeSeriesPreparation.Arc
                stage (1,1) string
                detail (1,1) struct = struct()
            end
            arc.provenance(end+1) = struct("stage", stage, ...
                "version", timeSeriesPreparation.internal.toolboxVersion(), ...
                "time", string(datetime("now", "TimeZone", "UTC", ...
                    "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'")), ...
                "detail", detail);
        end
    end

    methods
        function s = saveobj(arc)
            s = struct("schemaVersion", timeSeriesPreparation.Arc.SchemaVersion);
            for f = storedFields()
                s.(f) = arc.(f);
            end
        end
    end

    methods (Static)
        function arc = loadobj(s)
            if isa(s, "timeSeriesPreparation.Arc")
                arc = s;                                % schema 1: saved as the object
                return
            end
            if ~isstruct(s) || ~isfield(s, "schemaVersion") ...
                    || ~isequal(string(s.schemaVersion), timeSeriesPreparation.Arc.SchemaVersion)
                v = "none";
                if isstruct(s) && isfield(s, "schemaVersion"), v = string(s.schemaVersion); end
                error("timeSeriesPreparation:Arc:schemaVersion", ...
                    "Stored arc has schema version %s; this release reads %s " + ...
                    "(and objects of schema 1).", v, timeSeriesPreparation.Arc.SchemaVersion);
            end
            arc = timeSeriesPreparation.Arc();
            for f = storedFields()
                arc.(f) = s.(f);
            end
        end

        function requireOneRelease(arcs, options)
            arguments
                arcs (1,:) timeSeriesPreparation.Arc
                options.AllowMixedRelease (1,1) logical = false
            end
            rel = unique([arcs.release]);
            if numel(rel) > 1 && ~options.AllowMixedRelease
                error("timeSeriesPreparation:Arc:mixedRelease", ...
                    "The campaign mixes L1B releases (%s); pass " + ...
                    "AllowMixedRelease = true to accept that (CONCEPT 5.2).", ...
                    strjoin(row(rel), ", "));
            end
        end
    end
end

% ------------------------------------------------------------------------

function f = storedFields()
% The properties saveobj stores, in declaration order.
    f = ["t" "obs" "names" "units" "mission" "product" "satellite" "release" ...
        "files" "frame" "frameSource" "weights" "layers" "filled" "provenance"];
end

function checkTime(t)
% int64 GPS ns, a column, strictly increasing.
    if ~isa(t, "int64") || ~iscolumn(t)
        error("timeSeriesPreparation:Arc:timeFormat", ...
            "t must be an int64 column vector of GPS nanoseconds " + ...
            "(gracefoReading 'TimeFormat', ""gpsns""), not %s %s.", ...
            mat2str(size(t)), class(t));
    end
    if any(diff(t) <= 0)
        error("timeSeriesPreparation:Arc:timeNotIncreasing", ...
            "t is not strictly increasing (first at sample %d).", ...
            find(diff(t) <= 0, 1) + 1);
    end
end

function [files, products, headers] = fileMetadata(aux)
% File names, products and headers from readL1b (single) or readL1bMulti.
    if isfield(aux, "fileNames") && isfield(aux, "products")
        files = string(aux.fileNames(:));
        products = string(aux.products(:));
        headers = cell(numel(files), 1);
        if isfield(aux, "headers"), headers = aux.headers(:); end
    elseif isfield(aux, "fileName") && isfield(aux, "product")
        files = string(aux.fileName);
        products = string(aux.product);
        headers = {[]};
        if isfield(aux, "header"), headers = {aux.header}; end
    else
        error("timeSeriesPreparation:Arc:auxField", ...
            "aux lacks fileName/product (readL1b) or fileNames/products (readL1bMulti).");
    end
end

function [sats, releases] = parseFileNames(files, headers)
% Satellite letter and two-digit release per file, from the name, else header.
    n = numel(files);
    sats = strings(n, 1); releases = strings(n, 1);
    for k = 1:n
        [~, base] = fileparts(files(k));
        tok = regexp(base, "^[A-Z0-9]{3}1[AB]_\d{4}-\d{2}-\d{2}_([A-Z])_(\d{2})", ...
            "tokens", "once");
        if ~isempty(tok)
            sats(k) = tok{1}; releases(k) = tok{2};
        elseif ~isempty(headers{k})
            v = regexp(strjoin(row(string(headers{k})), newline), ...
                "product_version:\s*(\d+)", "tokens", "once");
            if ~isempty(v), releases(k) = v{1}; end
        end
    end
end

function u = unitsOf(names, aux)
% Unit of each observation, through variableFieldNames; "" when not stated.
    u = strings(1, numel(names));
    vn = string(aux.variableNames);
    fn = string(aux.variableFieldNames);
    for k = 1:numel(names)
        j = find(vn == names(k), 1);
        if ~isempty(j) && isfield(aux.variableUnits, fn(j))
            u(k) = string(aux.variableUnits.(fn(j)));
        end
    end
end

function m = missionOf(sat)
% Satellite letter -> mission; "" when the letter says nothing.
    switch sat
        case {"A", "B", "X"}
            m = "GRACE";
        case {"C", "D", "Y"}
            m = "GRACE-FO";
        otherwise
            m = "";
    end
end

function r = row(s)
% S as a 1 x N row, which strjoin requires.
    r = reshape(s, 1, []);
end

function tf = duplicated(s)
% True for every element of S that occurs more than once.
    [~, ~, j] = unique(s);
    counts = accumarray(j(:), 1);
    tf = reshape(counts(j) > 1, size(s));
end
