function out = crnApply(arc, kernel, options)
%CRNAPPLY  Apply a CRN kernel to an arc, evaluated only at the output epochs.
%
%   SYNTAX
%     out = timeSeriesPreparation.crnApply(arc, kernel)
%     out = timeSeriesPreparation.crnApply(arc, kernel, OutputEpochs = t1Hz, Derivative = 1)
%
%   DESCRIPTION
%     Computes out_i = sum_{n=-Nh..Nh} K_n x_{i-n}, the filter of the GRACE
%     L1B ATBD App. B with K the kernel's F, dF or ddF (crnKernel), on the
%     raw-rate grid of the arc, and evaluates the sum ONLY at the requested
%     output epochs (CONCEPT 6.1, item 11). ACC1B at 1 Hz from 10 Hz input
%     needs a tenth of the multiply-adds of convolving at the full rate and
%     sampling afterwards - about 3.6e8 instead of 3.6e9 per day for three
%     axes - and the numbers are the same bit for bit, because every output
%     is the same sum over n in the same order whichever epochs are asked
%     for. For the same reason a long arc evaluated in pieces with half-span
%     overlap equals the arc evaluated whole, bit for bit. The output is
%     sampled, never averaged.
%
%     The arc must lie on the kernel's grid: every epoch t0 + j/fs with j an
%     integer (missing epochs are gaps, not an error). An output sample is NaN
%     unless all Nf samples of its window exist, are not NaN and are not
%     removed by a layer of the input: edges, gaps and masked samples never
%     leak into a filtered value. Those samples form the layer "crnWindow" of
%     the result, so a fit weights them zero. The result keeps names, mission,
%     product, release and provenance (Arc.derive); units gain "/s" or "/s^2"
%     for the derivatives.
%
%   INPUTS
%     arc     (1,1) Arc      -   Input on the raw-rate grid, e.g. 10 Hz ACC1A.
%     kernel  (1,1) struct   -   From timeSeriesPreparation.crnKernel.
%
%   OPTIONS
%     OutputEpochs  (:,1) int64    [arc.t]   Epochs to evaluate, on the
%                                            input grid, strictly increasing;
%                                            they may lie outside the arc
%                                            (then NaN).
%     Derivative    (1,1) double   [0]       0 filtered value, 1 first and
%                                            2 second time derivative.
%
%   OUTPUTS
%     out  (1,1) Arc   -   On OutputEpochs; obs (K,M) double; layer
%                          crnWindow (K,1) logical, true where the window was
%                          incomplete (and obs is NaN).
%
%   ACCURACY
%     Each output is one sum of Nf products in a fixed order, so its rounding
%     is that of an Nf-term dot product, a few hundred eps of the largest
%     term; it is independent of which or how many epochs are requested. A
%     constant c comes out as c*kernel.dcGain, a sinusoid at f0 with unit
%     gain; see crnKernel for the kernel's own accuracy.
%
%   ERRORS
%     Grid:
%       timeSeriesPreparation:crnApply:rate - 1e9/kernel.fs is not a whole
%           number of nanoseconds.
%       timeSeriesPreparation:crnApply:notOnGrid - an input epoch is not a
%           whole number of kernel sample intervals from the first.
%       timeSeriesPreparation:crnApply:epochNotOnGrid - an output epoch is not
%           on the input grid, or OutputEpochs is not strictly increasing.
%     Kernel:
%       timeSeriesPreparation:crnApply:badKernel - kernel lacks a field of
%           crnKernel's output, or its taps are not Nf x 1.
%     Input:
%       timeSeriesPreparation:crnApply:emptyArc - the arc holds no samples.
%       An OutputEpochs that is not int64 is refused by the arguments block
%       with a MATLAB: identifier.
%
%   EXAMPLE
%     % Filter a 10 Hz constant with the ACC kernel and keep 1 Hz samples.
%     k = timeSeriesPreparation.crnKernel("ACC");
%     t = int64(0:36000-1)' * int64(1e8);
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACC1A_2020-01-01_C_04.txt", "product", "ACC1A");
%     arc = timeSeriesPreparation.Arc(t, ones(36000, 1), aux);
%     out = timeSeriesPreparation.crnApply(arc, k, OutputEpochs = t(1:10:end));
%
%   LIMITATIONS
%     No time-tag correction and no interpolation: an input off the grid
%     refuses instead of being resampled; mapping ACT1A from OBC to GPS time
%     and resampling it to the grid is the caller's (TestCrnVerification
%     shows the chain, X-12). Lifting a model to 10 Hz is the caller's.
%
%   REFERENCES
%     R-1: GRACE L1B ATBD, JPL D-27672, App. B, PDF pp. 40-41.
%     docs/CONCEPT.md sections 6.1 (row 4), 8.
%
%   See also timeSeriesPreparation.crnKernel, timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-27 10:45 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        kernel (1,1) struct
        options.OutputEpochs (:,1) {mustBeA(options.OutputEpochs, "int64")} = arc.t
        options.Derivative (1,1) double {mustBeMember(options.Derivative, [0 1 2])} = 0
    end

    taps = ["F" "dF" "ddF"];
    need = ["fs" "Nh" "preset" "dcGain" "source" taps];
    if ~all(isfield(kernel, need)) || any(arrayfun(@(f) ...
            ~isequal(size(kernel.(f)), [2 * kernel.Nh + 1, 1]), taps))
        error("timeSeriesPreparation:crnApply:badKernel", ...
            "kernel must come from timeSeriesPreparation.crnKernel " + ...
            "(fields fs, Nh, preset, dcGain, source, F, dF, ddF with Nf x 1 taps).");
    end
    if isempty(arc.t)
        error("timeSeriesPreparation:crnApply:emptyArc", "The arc holds no samples.");
    end
    step = 1e9 / kernel.fs;
    if step ~= round(step)
        error("timeSeriesPreparation:crnApply:rate", ...
            "1e9/fs = %.17g ns is not a whole number of nanoseconds.", step);
    end
    step = int64(step);
    K = kernel.(taps(options.Derivative + 1));
    Nh = kernel.Nh;

    t0 = arc.t(1);
    j = arc.t - t0;
    if any(mod(j, step) ~= 0)
        error("timeSeriesPreparation:crnApply:notOnGrid", ...
            "Input epoch %d is not a whole number of %d ns steps from the first.", ...
            find(mod(j, step) ~= 0, 1), step);
    end
    tOut = options.OutputEpochs;
    jOut = tOut - t0;
    if any(mod(jOut, step) ~= 0) || any(diff(tOut) <= 0)
        error("timeSeriesPreparation:crnApply:epochNotOnGrid", ...
            "OutputEpochs must be strictly increasing and on the input grid " + ...
            "(t0 + j * %d ns).", step);
    end

    % The raw series on its full grid; gaps and removed samples are NaN.
    L = double(j(end) / step) + 1;
    x = NaN(L, size(arc.obs, 2));
    x(double(j / step) + 1, :) = arc.obs;
    x(double(j(arc.weights == 0) / step) + 1, :) = NaN;

    % Only output epochs whose whole window lies on the grid are summed.
    i = double(jOut / step) + 1;
    inside = i - Nh >= 1 & i + Nh <= L;
    iv = i(inside);
    y = zeros(numel(iv), size(x, 2));
    for n = -Nh:Nh
        y = y + K(n + Nh + 1) * x(iv - n, :);
    end
    obs = NaN(numel(tOut), size(x, 2));
    obs(inside, :) = y;

    suffix = ["" "/s" "/s^2"];
    units = arc.units;
    units(units ~= "") = units(units ~= "") + suffix(options.Derivative + 1);
    out = arc.derive(tOut, obs, "crnApply", struct("preset", kernel.preset, ...
        "Nf", 2 * Nh + 1, "fs", kernel.fs, "derivative", options.Derivative, ...
        "dcGain", kernel.dcGain, "source", kernel.source), Units = units);
    out = addLayer(out, "crnWindow", any(isnan(obs), 2));
end
