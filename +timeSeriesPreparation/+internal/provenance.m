function p = provenance(unit, options)
%PROVENANCE  Metadata record that travels with every result of the qc units.
%
%   SYNTAX
%     p = timeSeriesPreparation.internal.provenance(unit)
%     p = timeSeriesPreparation.internal.provenance(unit, Options=s, Files=f)
%
%   DESCRIPTION
%     The port of NonGravForces.provenance (0.12.0, 3cc0123) for the units
%     of +qc (X-05). It keeps the original's fields: which unit, which
%     toolbox version, which dependencies, which option hash, which files,
%     which warnings, a note and when. Two things differ, each for a reason:
%       - dependencies is empty: the qc units call no other toolbox, and
%         timeSeriesPreparation has no dependency report to ask;
%       - optionHash is the exact 32-bit FNV-1a of jsonencode(Options)
%         (internal.stageSeed). The original multiplies in double, which
%         is inexact above 2^53, so the two hashes can differ.
%
%   INPUTS
%     unit  (1,1) string   -   Producing unit, e.g. "qc.hampel".
%
%   OPTIONS
%     Files     (1,:) string   -   Data files consumed. Default: none.
%     Options   (1,1) struct   -   Resolved options, hashed. Default: struct().
%     Warnings  (1,:) string   -   Warning identifiers issued. Default: none.
%     Note      (1,1) string   -   Free text. Default: "".
%
%   OUTPUTS
%     p  (1,1) struct   -   unit, toolboxVersion, dependencies (0x0 struct
%                           with name and version), optionHash (8 hex
%                           digits, "00000000" for no options), files,
%                           warnings, note, created (datetime, UTC).
%
%   ACCURACY
%     Exact: the hash is integer arithmetic on the UTF-8 bytes of the JSON
%     text.
%
%   ERRORS
%     (none)
%
%   EXAMPLE
%     % The record of a hampel call with its window.
%     p = timeSeriesPreparation.internal.provenance("qc.hampel", Options=struct("Window", 61));
%
%   LIMITATIONS
%     The hash follows jsonencode's text, so two structs with the same
%     values in another field order hash differently.
%
%   REFERENCES
%     NonGravForces provenance.m at 3cc0123 (0.12.0); HANDOVER X-05 PR-A.
%
%   See also timeSeriesPreparation.internal.stageSeed, timeSeriesPreparation.internal.toolboxVersion.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-24 16:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        unit (1,1) string
        options.Files (1,:) string = string.empty(1, 0)
        options.Options struct = struct()
        options.Warnings (1,:) string = string.empty(1, 0)
        options.Note (1,1) string = ""
    end

    p.unit = unit;
    p.toolboxVersion = timeSeriesPreparation.internal.toolboxVersion();
    p.dependencies = struct("name", {}, "version", {});
    if isempty(fieldnames(options.Options))
        p.optionHash = "00000000";
    else
        h = timeSeriesPreparation.internal.stageSeed(string(jsonencode(options.Options)), 0);
        p.optionHash = string(lower(dec2hex(h, 8)));
    end
    p.files = options.Files;
    p.warnings = options.Warnings;
    p.note = options.Note;
    p.created = datetime("now", "TimeZone", "UTC");
end
