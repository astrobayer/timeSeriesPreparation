classdef Config
%CONFIG  Instrument settings in nine sections, strict about field names (skeleton).
%
%   SYNTAX
%     cfg = timeSeriesPreparation.Config()
%     cfg = timeSeriesPreparation.Config(arc)
%     cfg = set(cfg, section, field, value)
%     s   = toStruct(cfg)
%
%   DESCRIPTION
%     The settings of every stage, in the sections of CONCEPT 5: mask, qc,
%     crn, align, fill, noise, unc, drivers, run. Each section has a schema,
%     the list of fields it knows; set refuses a section or a field outside
%     it, so a misspelt option fails instead of being silently ignored.
%     Config(arc) records the arc's mission and product and returns the
%     preset for that product (CONCEPT 5).
%
%     Skeleton (X-03): every schema is empty and no product has a preset
%     yet. Each stage adds its fields, defaults and presets in its own work
%     package (crn at X-04, mask and qc at X-05, ...). An option whose default
%     would be an assumption defaults to empty (R5). Applications take a
%     Config as 'Preproc' and hash it with their own options; toStruct gives
%     them a plain struct to hash.
%
%   INPUTS
%     arc      (1,1) Arc      -   The arc whose product selects the preset.
%     section  (1,1) string   -   One of Config.Sections.
%     field    (1,1) string   -   A field of that section's schema.
%     value    (1,1) any      -   The setting.
%
%   OUTPUTS
%     cfg  (1,1) Config   -   Properties: mission, product, and one struct
%                             per section.
%     s    (1,1) struct   -   mission, product and the nine sections.
%
%   ACCURACY
%     Not applicable, because the class computes no number; values are
%     stored as given.
%
%   ERRORS
%     Settings:
%       timeSeriesPreparation:Config:unknownSection - section is not one of
%           the nine sections.
%       timeSeriesPreparation:Config:unknownField - field is not in the
%           section's schema.
%
%   EXAMPLE
%     % The empty skeleton as a plain struct, e.g. for hashing.
%     cfg = timeSeriesPreparation.Config();
%     s = toStruct(cfg);
%
%   LIMITATIONS
%     No schema field and no preset exist yet; set therefore refuses every
%     field until the stages define theirs.
%
%   REFERENCES
%     docs/CONCEPT.md section 5 (Config), R5 (no assumed defaults).
%
%   See also timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        Sections = ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run"]
    end

    properties (SetAccess = private)
        mission = ""
        product = ""
        mask = struct()
        qc = struct()
        crn = struct()
        align = struct()
        fill = struct()
        noise = struct()
        unc = struct()
        drivers = struct()
        run = struct()
    end

    methods
        function cfg = Config(arc)
            arguments
                arc timeSeriesPreparation.Arc = timeSeriesPreparation.Arc.empty
            end
            if isempty(arc)
                return
            end
            cfg.mission = arc(1).mission;
            cfg.product = arc(1).product;
            % Product presets are added by the stages that own the fields.
        end

        function cfg = set(cfg, section, field, value)
            arguments
                cfg (1,1) timeSeriesPreparation.Config
                section (1,1) string
                field (1,1) string
                value
            end
            if ~any(section == cfg.Sections)
                error("timeSeriesPreparation:Config:unknownSection", ...
                    "Unknown section ""%s""; sections are %s.", section, ...
                    strjoin(cfg.Sections, ", "));
            end
            known = schema(section);
            if ~any(field == known)
                list = "(none yet)";
                if ~isempty(known), list = strjoin(known, ", "); end
                error("timeSeriesPreparation:Config:unknownField", ...
                    "Section ""%s"" has no field ""%s""; known: %s.", ...
                    section, field, list);
            end
            cfg.(section).(field) = value;
        end

        function s = toStruct(cfg)
            arguments
                cfg (1,1) timeSeriesPreparation.Config
            end
            s = struct("mission", cfg.mission, "product", cfg.product);
            for sec = cfg.Sections
                s.(sec) = cfg.(sec);
            end
        end
    end
end

function known = schema(section) %#ok<INUSD>
% Fields SECTION accepts. Empty in the skeleton: each stage adds its own
% (a case per section) in the work package that defines the stage.
    known = strings(1, 0);
end
