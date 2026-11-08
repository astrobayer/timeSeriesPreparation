function [outs, status] = stageCache(cacheDir, stage, key, nOut, compute)
%STAGECACHE  A stage's outputs from the cache, or computed and stored.
%
%   SYNTAX
%     [outs, status] = timeSeriesPreparation.internal.stageCache(cacheDir, stage, key, nOut, compute)
%
%   DESCRIPTION
%     The stage cache of run (X-14, CONCEPT 6.6; owner decisions
%     2026-09-25). The outputs of a stage live in one MAT file per key,
%     cacheDir/<stage>/<key>.mat, holding the variable outs (a 1 x nOut
%     cell). The status says what happened, so a hit is never silent:
%       "off"        cacheDir is "": compute, store nothing;
%       "hit"        the file exists and loads: its outputs are returned,
%                    compute is not called;
%       "miss"       no file: compute, then store;
%       "rewritten"  the file exists but does not load, or holds no 1 x
%                    nOut cell outs: compute, then store over it;
%       "unsaved"    computed, but storing failed (e.g. no write access);
%                    the outputs are still returned.
%     There is no eviction; the caller deletes the folder to clear it.
%
%   INPUTS
%     cacheDir  (1,1) string            -   Cache root; "" = off.
%     stage     (1,1) string            -   Stage name, a subfolder.
%     key       (1,1) string            -   Hex key (internal.contentHash).
%     nOut      (1,1) double            -   Outputs of compute, >= 1.
%     compute   (1,1) function_handle   -   () -> nOut outputs.
%
%   OUTPUTS
%     outs    (1,nOut) cell     -   The stage's outputs.
%     status  (1,1) string      -   "off", "hit", "miss", "rewritten" or
%                                   "unsaved".
%
%   ACCURACY
%     Exact: a hit returns what save stored (MAT-file version 7), bit for
%     bit.
%
%   ERRORS
%     (none) The errors of compute propagate.
%
%   EXAMPLE
%     % The cache off: compute runs and nothing is stored.
%     [outs, status] = timeSeriesPreparation.internal.stageCache("", "demo", "0", 1, @() magic(3));
%
%   LIMITATIONS
%     No locking: two processes writing one key at the same moment may
%     leave a file the next reader rewrites. Campaign mode (X-15) runs
%     each arc once per key.
%
%   REFERENCES
%     docs/CONCEPT.md 6.6 (stage cache); HANDOVER X-14.
%
%   See also timeSeriesPreparation.internal.contentHash, timeSeriesPreparation.run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.2 | 2026-09-25 23:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        cacheDir (1,1) string
        stage (1,1) string
        key (1,1) string
        nOut (1,1) double {mustBeInteger, mustBePositive}
        compute (1,1) function_handle
    end

    outs = cell(1, nOut);
    if cacheDir == ""
        [outs{:}] = compute();
        status = "off";
        return
    end

    folder = fullfile(cacheDir, stage);
    file = fullfile(folder, key + ".mat");
    status = "miss";
    if isfile(file)
        try
            S = load(file, "outs");
            if isfield(S, "outs") && iscell(S.outs) && isequal(size(S.outs), [1 nOut])
                outs = S.outs;
                status = "hit";
                return
            end
        catch
        end
        status = "rewritten";
    end

    [outs{:}] = compute();
    try
        if ~isfolder(folder)
            mkdir(folder);
        end
        save(file, "outs", "-v7");
    catch
        status = "unsaved";
    end
end
