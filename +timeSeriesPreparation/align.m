function out = align(obs, ref, options)
%ALIGN  Move a reference series onto the epochs of an observation, units checked.
%
%   SYNTAX
%     out = timeSeriesPreparation.align(obs, ref)
%     out = timeSeriesPreparation.align(obs, ref, Method = "pchip", MaxGap = 15)
%
%   DESCRIPTION
%     Returns the reference (a model, a second instrument) on the epochs of
%     the observation, so that the two can be compared sample by sample
%     (CONCEPT 6.1, row 3). Where an observation epoch coincides with a
%     reference epoch, the reference value is taken bit for bit. Elsewhere
%     it is interpolated, by default with pchip. Linear chords attenuate the
%     amplitude, and a fitted scale absorbs that loss (v2). On a 1/rev
%     signal sampled at 5 s and evaluated at 1 s, linear errs by 1.2e-5 of
%     the amplitude and pchip by 3.8e-6. Evaluating the model at the
%     observation epochs directly avoids interpolation altogether.
%
%     Interpolation never bridges a hole. The usable reference samples
%     (finite in every column, weight > 0) split into stretches at every
%     unusable sample and wherever two usable samples lie more than MaxGap
%     apart. Each stretch is interpolated on its own, and nothing is
%     extrapolated. An observation epoch that no stretch covers gets NaN in
%     every column. Those epochs form the layer "alignGap" of the result,
%     so a fit weights them zero. The default MaxGap, 1.5 times the median
%     reference step, lets no missing sample be bridged.
%
%     Units are checked (CONCEPT 5.2): the columns of obs and ref pair by
%     position, and each pair must state the same unit. Units are compared
%     after removing blanks and "^", so "m/s^2" equals "m/s2". A mismatch
%     refuses, and so does a unit that either side leaves unstated ("").
%     An unstated unit cannot be checked, and assuming one is what R5
%     forbids.
%
%     The result is the reference (names, units, product, provenance) on
%     obs.t, with the stage "align" appended (Arc.derive). Time lags are not
%     looked for here: checkAlignment reports them and never shifts.
%
%   INPUTS
%     obs  (1,1) Arc   -   Observation; only its epochs and units are used.
%     ref  (1,1) Arc   -   Reference with as many columns as obs, in the
%                          same order.
%
%   OPTIONS
%     Method  (1,1) string   ["pchip"]   interp1 method: "pchip", "makima",
%                                        "spline" or "linear".
%     MaxGap  (1,1) double   [auto]      Widest reference spacing in s
%                                        interpolated across; [] (auto) =
%                                        1.5 x the median reference step.
%
%   OUTPUTS
%     out  (1,1) Arc   -   The reference on obs.t; obs (N,M) double, NaN
%                          rows where no stretch covers the epoch; layer
%                          alignGap (N,1) logical.
%
%   ACCURACY
%     Exact at coinciding epochs. Elsewhere it is the interpolation error of
%     Method on the reference. With pchip at 5 s spacing, evaluated at 1 s,
%     the error on a 1/rev plus 2/rev signal is 3.8e-6 of the amplitude
%     (measured with a NumPy transcription of MATLAB's pchip, 2026-09-23);
%     TestAlign holds it below 1e-5. Times are double seconds from the
%     first reference epoch, with a resolution of about 6e-10 s over a
%     month.
%
%   ERRORS
%     Units:
%       timeSeriesPreparation:align:columnMismatch - obs and ref have
%           different numbers of columns.
%       timeSeriesPreparation:align:unitMismatch - a column pair states
%           different units.
%       timeSeriesPreparation:align:unitUnknown - a column of obs or ref
%           states no unit.
%     Options:
%       A Method outside the list, or a MaxGap that is not a positive
%       scalar, is refused by the arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % A 5 s model onto 1 s observation epochs.
%     aux = @(p) struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", p + "_2020-01-01_C_04.txt", "product", p);
%     tObs = int64(0:599)' * int64(1e9);
%     tRef = int64(0:5:600)' * int64(1e9);
%     obs = timeSeriesPreparation.Arc(tObs, sin(double(tObs) * 1e-9 / 100), aux("ACT1B"));
%     ref = timeSeriesPreparation.Arc(tRef, sin(double(tRef) * 1e-9 / 100), aux("MOD1B"));
%     out = timeSeriesPreparation.align(obs, ref);
%
%   LIMITATIONS
%     Columns pair by position, not by name, because a model rarely shares
%     the file's column names. No frame check (the frame is the caller's,
%     v3 F5) and no time-system conversion: both arcs are GPS ns already.
%     Validity is joint over the columns, because weights are per row.
%
%   REFERENCES
%     docs/CONCEPT.md sections 5.2 (units), 6.1 (row 3); v3 WP-11 item 1
%     and F2 (docs/inputs/HANDOVER_AccelCal_v3.md); v2 alignAccelSeries.
%
%   See also timeSeriesPreparation.checkAlignment, timeSeriesPreparation.Arc, timeSeriesPreparation.internal.resampleOnto.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        obs (1,1) timeSeriesPreparation.Arc
        ref (1,1) timeSeriesPreparation.Arc
        options.Method (1,1) string {mustBeMember(options.Method, ...
            ["pchip" "makima" "spline" "linear"])} = "pchip"
        options.MaxGap double {mustBeScalarOrEmpty, mustBePositive} = []
    end

    checkUnits(obs, ref);
    valid = all(isfinite(ref.obs), 2) & ref.weights > 0;
    [y, info] = timeSeriesPreparation.internal.resampleOnto(ref.t, ref.obs, ...
        valid, obs.t, options.Method, options.MaxGap);
    gap = any(isnan(y), 2);

    out = ref.derive(obs.t, y, "align", struct( ...
        "observation", obs.product, "reference", ref.product, ...
        "method", options.Method, "maxGap", info.maxGap, ...
        "exact", nnz(info.exact), "gap", nnz(gap)));
    out = addLayer(out, "alignGap", gap);
end

% ------------------------------------------------------------------------

function checkUnits(obs, ref)
% Pair the columns by position; refuse a count, a unit or a missing unit.
    if numel(obs.units) ~= numel(ref.units)
        error("timeSeriesPreparation:align:columnMismatch", ...
            "obs has %d columns and ref %d; they pair by position.", ...
            numel(obs.units), numel(ref.units));
    end
    missing = obs.units == "" | ref.units == "";
    if any(missing)
        j = find(missing, 1);
        error("timeSeriesPreparation:align:unitUnknown", ...
            "Column %d (obs ""%s"", ref ""%s"") states no unit; it cannot be " + ...
            "checked (CONCEPT 5.2). State it in the arc's aux.variableUnits.", ...
            j, obs.names(j), ref.names(j));
    end
    canon = @(u) regexprep(u, "[\s\^]", "");
    differ = canon(obs.units) ~= canon(ref.units);
    if any(differ)
        j = find(differ, 1);
        error("timeSeriesPreparation:align:unitMismatch", ...
            "Column %d: obs ""%s"" is in %s, ref ""%s"" in %s (CONCEPT 5.2).", ...
            j, obs.names(j), obs.units(j), ref.names(j), ref.units(j));
    end
end
