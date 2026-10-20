function txt = provJsonLd(provenance, options)
%PROVJSONLD  W3C PROV-O graph of an arc's provenance, as JSON-LD text.
%
%   SYNTAX
%     txt = timeSeriesPreparation.internal.provJsonLd(provenance, Inputs = files, Output = name, Creator = who)
%     txt = timeSeriesPreparation.internal.provJsonLd(provenance, Inputs = files, Output = name, Creator = who, CreatorOrcid = orcid, Created = when)
%
%   DESCRIPTION
%     The provenance record of an exported day (X-18, CONCEPT 5.2; owner
%     decisions 2026-09-26), written into the NetCDF file and its sidecar.
%     The graph uses the PROV-O classes and properties only:
%       prov:Entity         each input L1B file (Inputs), and the output
%                           file (Output), which prov:wasGeneratedBy the
%                           export activity, prov:wasDerivedFrom every
%                           input and prov:wasAttributedTo the creator;
%       prov:Activity       each provenance entry of the arc in order
%                           (rdfs:label = its stage, prov:startedAtTime =
%                           its time), then "export" at Created; the first
%                           prov:used the inputs, each later one
%                           prov:wasInformedBy the one before;
%       prov:SoftwareAgent  timeSeriesPreparation, one per toolbox version
%                           in the entries, associated with each activity
%                           by prov:wasAssociatedWith;
%       prov:Person         the creator, identified by the ORCID URL when
%                           CreatorOrcid is given.
%     A stage's detail is kept as the JSON string tsp:detail when it
%     encodes (jsonencode) to at most 4096 characters; otherwise tsp:detail
%     states its length only. Node identifiers are URNs under
%     "urn:timeSeriesPreparation:". Objects are written by containers.Map,
%     whose keys jsonencode sorts, so equal inputs give equal text.
%
%   INPUTS
%     provenance  (1,K) struct   -   Arc.provenance: stage, version, time,
%                                    detail.
%
%   OPTIONS
%     Inputs        (N,1) string   []   Input file names (Arc.files).
%     Output        (1,1) string   ""   Name of the exported file; required.
%     Creator       (1,1) string   ""   The dataset's creator; required.
%     CreatorOrcid  (1,1) string   ""   ORCID iD, 0000-0000-0000-0000
%                                       or its https://orcid.org/ URL.
%     Created       (1,1) string   [now] Export time, ISO 8601 UTC.
%
%   OUTPUTS
%     txt  (1,1) string   -   JSON-LD: "@context" (prov, rdfs, xsd, tsp)
%                             and "@graph".
%
%   ACCURACY
%     Not applicable, because the function computes no number; the entries
%     are copied as given.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:provJsonLd:inputMissing - Output or Creator
%           is empty.
%       timeSeriesPreparation:provJsonLd:inputProvenance - provenance lacks
%           a field stage, version, time or detail.
%
%   EXAMPLE
%     % The graph of a two-stage provenance, decoded again.
%     p = struct("stage", {"mask", "fill"}, "version", "1.2.0", "time", "2026-09-26T17:00:00Z", "detail", struct());
%     txt = timeSeriesPreparation.internal.provJsonLd(p, Inputs = "ACT1B_2020-01-02_C_04.txt", Output = "2020-01-02.nc", Creator = "A. Author", Created = "2026-09-26T18:00:00Z");
%     g = jsondecode(txt);
%
%   LIMITATIONS
%     The graph records what the arc's provenance says; stages that write
%     no provenance entry are not in it. No PROV-O qualified terms
%     (prov:qualifiedUsage and the like) are written.
%
%   REFERENCES
%     W3C (2013). PROV-O: The PROV Ontology, Recommendation 30 April 2013,
%     https://www.w3.org/TR/prov-o/. W3C (2020). JSON-LD 1.1,
%     Recommendation 16 July 2020. docs/CONCEPT.md 5.2; HANDOVER X-18.
%
%   See also timeSeriesPreparation.exportNetcdf, timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-26 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        provenance struct
        options.Inputs string = strings(0, 1)
        options.Output (1,1) string = ""
        options.Creator (1,1) string = ""
        options.CreatorOrcid (1,1) string = ""
        options.Created (1,1) string = ""
    end
    if options.Output == "" || options.Creator == ""
        error("timeSeriesPreparation:provJsonLd:inputMissing", ...
            "Output and Creator are required -> pass the file name and the dataset's creator");
    end
    need = ["stage" "version" "time" "detail"];
    if ~isempty(provenance) && ~all(isfield(provenance, need))
        error("timeSeriesPreparation:provJsonLd:inputProvenance", ...
            "provenance must have the fields %s -> pass Arc.provenance", strjoin(need, ", "));
    end
    created = options.Created;
    if created == ""
        created = string(datetime("now", "TimeZone", "UTC", "Format", "yyyy-MM-dd'T'HH:mm:ss'Z'"));
    end
    ns = "urn:timeSeriesPreparation:";
    here = timeSeriesPreparation.internal.toolboxVersion();

    graph = {};
    versions = unique([string({provenance.version}) here], "stable");
    for v = versions
        graph{end+1} = node(ns + "software:" + v, "prov:SoftwareAgent", ...
            "rdfs:label", "timeSeriesPreparation " + v); %#ok<AGROW>
    end
    person = ns + "person:creator";
    orcid = options.CreatorOrcid;
    if orcid ~= ""
        if ~startsWith(orcid, "https://")
            orcid = "https://orcid.org/" + orcid;
        end
        person = orcid;
    end
    graph{end+1} = node(person, "prov:Person", "rdfs:label", options.Creator);
    inputs = reshape(string(options.Inputs), 1, []);
    inIds = ns + "input:" + inputs;
    for k = 1:numel(inputs)
        graph{end+1} = node(inIds(k), "prov:Entity", "rdfs:label", inputs(k)); %#ok<AGROW>
    end

    previous = "";
    for k = 1:numel(provenance)
        p = provenance(k);
        id = ns + "activity:" + k + ":" + string(p.stage);
        a = node(id, "prov:Activity", "rdfs:label", string(p.stage), ...
            "prov:startedAtTime", stamp(string(p.time)), ...
            "prov:wasAssociatedWith", ref(ns + "software:" + string(p.version)), ...
            "tsp:detail", detailText(p.detail));
        if previous == ""
            a('prov:used') = refs(inIds);
        else
            a('prov:wasInformedBy') = ref(previous);
        end
        graph{end+1} = a; %#ok<AGROW>
        previous = id;
    end
    exportId = ns + "activity:" + (numel(provenance) + 1) + ":export";
    e = node(exportId, "prov:Activity", "rdfs:label", "export", ...
        "prov:startedAtTime", stamp(created), ...
        "prov:wasAssociatedWith", {ref(ns + "software:" + here), ref(person)});
    if previous == ""
        e('prov:used') = refs(inIds);
    else
        e('prov:wasInformedBy') = ref(previous);
    end
    graph{end+1} = e;
    graph{end+1} = node(ns + "output:" + options.Output, "prov:Entity", ...
        "rdfs:label", options.Output, "prov:wasGeneratedBy", ref(exportId), ...
        "prov:generatedAtTime", stamp(created), "prov:wasDerivedFrom", refs(inIds), ...
        "prov:wasAttributedTo", ref(person));

    context = containers.Map( ...
        {'prov', 'rdfs', 'xsd', 'tsp'}, ...
        {'http://www.w3.org/ns/prov#', 'http://www.w3.org/2000/01/rdf-schema#', ...
         'http://www.w3.org/2001/XMLSchema#', char(ns)}, "UniformValues", false);
    doc = containers.Map({'@context', '@graph'}, {context, graph}, "UniformValues", false);
    txt = string(jsonencode(doc));
end

% ------------------------------------------------------------------------

function m = node(id, type, varargin)
% A JSON-LD node: @id, @type and the given key-value pairs.
    m = containers.Map({'@id', '@type'}, {char(id), char(type)}, "UniformValues", false);
    for k = 1:2:numel(varargin)
        m(char(varargin{k})) = value(varargin{k + 1});
    end
end

function v = value(v)
    if isstring(v) && isscalar(v)
        v = char(v);
    end
end

function r = ref(id)
    r = containers.Map({'@id'}, {char(id)}, "UniformValues", false);
end

function c = refs(ids)
% A JSON array of references (a cell, so one element stays an array).
    c = cell(1, numel(ids));
    for k = 1:numel(ids)
        c{k} = ref(ids(k));
    end
end

function s = stamp(t)
    s = containers.Map({'@value', '@type'}, {char(t), 'xsd:dateTime'}, "UniformValues", false);
end

function d = detailText(detail)
% The stage detail as JSON, when it encodes and is short.
    try
        d = string(jsonencode(detail));
    catch
        d = "(detail not JSON-encodable)";
        return
    end
    if strlength(d) > 4096
        d = sprintf("(detail omitted: %d characters)", strlength(d));
    end
end
