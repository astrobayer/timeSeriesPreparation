function info = setupTimeSeriesPreparation(options)
%SETUPTIMESERIESPREPARATION  Put the toolbox, and optionally gracefoReading, on the path.
%
%   SYNTAX
%     setupTimeSeriesPreparation()
%     info = setupTimeSeriesPreparation(GracefoReading = folder)
%
%   DESCRIPTION
%     Adds the repository root (the folder holding +timeSeriesPreparation)
%     and demos/ to the MATLAB path and reports whether the optional dependency
%     gracefoReading resolves (CONCEPT 3.1). With GracefoReading, that folder
%     is added first; it must hold +gracefoReading. Nothing else is changed,
%     and calling it twice is harmless.
%
%   INPUTS
%     (none)
%
%   OPTIONS
%     GracefoReading  (1,1) string   [""]   Folder holding +gracefoReading, or
%                                           "" to leave the path as it is.
%     Verbose         (1,1) logical  [true] Print the resolution.
%
%   OUTPUTS
%     info  (1,1) struct   -   Fields: root (1,1) string, the repository
%                              root; version (1,1) string, from Contents.m;
%                              gracefoReading (1,1) logical, true when the
%                              optional dependency resolves.
%
%   ACCURACY
%     Not applicable, because the function computes no number.
%
%   ERRORS
%     Input domain:
%       timeSeriesPreparation:setupTimeSeriesPreparation:noGracefoReading -
%           GracefoReading names a folder that does not hold +gracefoReading.
%
%   EXAMPLE
%     % Toolbox only; gracefoReading is resolved if it is already on the path.
%     info = setupTimeSeriesPreparation(Verbose = false);
%
%   LIMITATIONS
%     Does not save the path. Does not check gracefoReading's version.
%
%   REFERENCES
%     docs/CONCEPT.md section 3.1.
%
%   See also timeSeriesPreparation.internal.requirePackage, timeSeriesPreparationCiGate.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-22 21:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        options.GracefoReading (1,1) string = ""
        options.Verbose (1,1) logical = true
    end

    root = string(fileparts(mfilename("fullpath")));
    if options.GracefoReading ~= ""
        if ~isfolder(fullfile(options.GracefoReading, "+gracefoReading"))
            error("timeSeriesPreparation:setupTimeSeriesPreparation:noGracefoReading", ...
                "%s does not hold +gracefoReading.", options.GracefoReading);
        end
        addpath(char(options.GracefoReading));
    end
    addpath(char(root), char(fullfile(root, "demos")));

    head = regexp(fileread(fullfile(root, "+timeSeriesPreparation", "Contents.m")), ...
        "% Version (\d+\.\d+\.\d+)", "tokens", "once");
    info = struct("root", root, "version", string(head{1}), ...
        "gracefoReading", ~isempty(meta.package.fromName('gracefoReading')));

    if options.Verbose
        fprintf("timeSeriesPreparation v%s at %s\n", info.version, root);
        if info.gracefoReading
            fprintf("  gracefoReading: resolves (%s)\n", ...
                fileparts(fileparts(which("gracefoReading.findGaps"))));
        else
            fprintf("  gracefoReading: not on the path (optional; L1B-specific functions refuse)\n");
        end
    end
end
