function requirePackage(name, caller)
%REQUIREPACKAGE  Refuse at the point of use when an optional dependency is missing.
%
%   SYNTAX
%     timeSeriesPreparation.internal.requirePackage(name, caller)
%
%   DESCRIPTION
%     gracefoReading is an optional dependency (CONCEPT 3.1): only the
%     L1B-specific functions call it, and the sigtools half runs in base
%     MATLAB. A function that needs it calls this first, so a missing reader
%     fails by name at the point of use, not as "Unable to resolve the name"
%     somewhere deeper. The layering test (tests/TestLayering.m) demands this
%     call in every package file that references gracefoReading.
%
%   INPUTS
%     name    (1,1) string   -   Namespace that must resolve, for example
%                                "gracefoReading".
%     caller  (1,1) string   -   Name of the calling function, without the
%                                package prefix; it becomes the middle part
%                                of the identifier.
%
%   OUTPUTS
%     (none)
%
%   ACCURACY
%     Not applicable, because the function computes no number. It decides
%     presence only: a namespace resolves when meta.package.fromName finds it
%     on the current path. It does not check a minimum version.
%
%   ERRORS
%     None of its own. When name does not resolve it raises
%     timeSeriesPreparation:<caller>:depMissing on the caller's behalf, and
%     the caller documents that identifier under its own ERRORS, where a user
%     looks it up. An invalid name or caller is refused by the arguments block
%     with a MATLAB: identifier.
%
%   EXAMPLE
%     % The toolbox itself always resolves, so this passes silently.
%     timeSeriesPreparation.internal.requirePackage("timeSeriesPreparation", "example");
%
%   LIMITATIONS
%     Presence only. A dependency present in a version too old for the caller
%     passes here and fails later; minimum versions are the release's
%     dependency table (GUIDE section 3).
%
%   REFERENCES
%     docs/CONCEPT.md section 3.1 (optional dependency, depMissing).
%
%   See also meta.package.fromName.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        name (1,1) string {mustBeTextScalar, mustBeNonzeroLengthText}
        caller (1,1) string {mustBeValidVariableName}
    end

    if isempty(meta.package.fromName(char(name)))
        error("timeSeriesPreparation:" + caller + ":depMissing", ...
            "%s needs the optional dependency %s, which is not on the " + ...
            "MATLAB path. Add it (for example with " + ...
            "setupTimeSeriesPreparation(GracefoReading=<folder>)) and retry.", ...
            caller, name);
    end
end
