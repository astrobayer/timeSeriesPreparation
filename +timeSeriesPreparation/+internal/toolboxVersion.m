function v = toolboxVersion()
%TOOLBOXVERSION  The toolbox version, read from its one authority, Contents.m.
%
%   SYNTAX
%     v = timeSeriesPreparation.internal.toolboxVersion()
%
%   DESCRIPTION
%     Returns the version stated in +timeSeriesPreparation/Contents.m, the
%     single version source of GUIDE section 3, which the shared audit also
%     checks every help footer against. Provenance records (Arc) cite it, so
%     a result names the release that produced it without a second literal
%     that could drift.
%
%   INPUTS
%     (none)
%
%   OUTPUTS
%     v  (1,1) string   -   Version as MAJOR.MINOR.PATCH, e.g. "0.0.0".
%
%   ACCURACY
%     Not applicable, because the function computes no number; it returns
%     the text of the Version line verbatim.
%
%   ERRORS
%     Version source:
%       timeSeriesPreparation:toolboxVersion:noVersion - Contents.m holds no
%           "% Version x.y.z" line.
%
%   EXAMPLE
%     % The version this checkout reports.
%     v = timeSeriesPreparation.internal.toolboxVersion();
%
%   LIMITATIONS
%     Reads the file on every call; callers that need it per sample should
%     read it once.
%
%   REFERENCES
%     docs/GUIDE.md section 3 (one version source).
%
%   See also setupTimeSeriesPreparation, timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    file = fullfile(fileparts(fileparts(mfilename("fullpath"))), "Contents.m");
    tok = regexp(fileread(file), "% Version (\d+\.\d+\.\d+)", "tokens", "once");
    if isempty(tok)
        error("timeSeriesPreparation:toolboxVersion:noVersion", ...
            "%s holds no ""%% Version x.y.z"" line.", file);
    end
    v = string(tok{1});
end
