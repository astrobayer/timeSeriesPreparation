function drv = drivers(arc, series, options)
%DRIVERS  Supplied driver series on the epochs of an arc, names and units checked.
%
%   SYNTAX
%     drv = timeSeriesPreparation.drivers(arc, series)
%     drv = timeSeriesPreparation.drivers(arc, series, Method = "pchip", MaxGap = [])
%
%   DESCRIPTION
%     The first half of the correlation stage (CONCEPT 6.1 row 9, 7).
%     Drivers are supplied, not computed here: beta' and u from
%     referenceSystem.orbitSunGeometry, the eclipse factor and space weather
%     from NonGravForces, THR1B counts, LRI/KBR SNR. drivers puts each one
%     onto arc.t by align's rule (internal.resampleOnto): a sample on a
%     coinciding epoch is taken bit for bit, elsewhere Method interpolates
%     inside stretches of usable samples, never across a hole (a NaN, or a
%     spacing above MaxGap) and never beyond the ends. An epoch no stretch
%     covers is NaN and marked in gap. Each driver is resampled on its own,
%     so its holes do not remove the others' samples.
%
%     Every driver states a name, a valid MATLAB field name distinct from
%     the others, and a unit; an unstated unit refuses (R5). Nothing is
%     averaged per revolution and no physics is evaluated (owner decision
%     2026-09-24).
%
%   INPUTS
%     arc     (1,1) Arc      -   Supplies the epochs arc.t.
%     series  (1,K) struct   -   One element per driver, fields: name
%                                (1,1) string; t (:,1) int64 GPS ns,
%                                strictly increasing; value (:,1) double,
%                                NaN missing, no Inf; unit (1,1) string.
%
%   OPTIONS
%     Method  (1,1) string   ["pchip"]   interp1 method: "pchip", "makima",
%                                        "spline" or "linear".
%     MaxGap  (1,1) double   [auto]      Widest driver spacing in s
%                                        interpolated across; [] (auto) =
%                                        1.5 x each driver's median step.
%
%   OUTPUTS
%     drv  (1,1) struct   -   Fields: t (N,1) int64, arc.t; names (1,K)
%                             string; units (1,K) string; values (N,K)
%                             double, NaN where not covered; gap (N,K)
%                             logical; method; maxGap (1,K) s as applied.
%
%   ACCURACY
%     That of align: exact at coinciding epochs, elsewhere the method's
%     interpolation error (pchip at 5 s spacing evaluated at 1 s: 3.8e-6 of
%     the amplitude of a 1/rev plus 2/rev signal). A driver with the arc's
%     unit gives align's result bit for bit (TestDrivers).
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:drivers:badSeries - series lacks a field, or
%           a driver's name is not a field name, its t is not an int64
%           strictly increasing column, or its value is not a real double
%           column of t's size without Inf.
%       timeSeriesPreparation:drivers:duplicateName - two drivers share a
%           name.
%       timeSeriesPreparation:drivers:unitUnknown - a driver states no
%           unit.
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%
%   EXAMPLE
%     % beta' at 60 s onto a 1 s arc.
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     arc = timeSeriesPreparation.Arc(int64(0:599)' * int64(1e9), zeros(600, 1), aux);
%     tb = int64(0:60:600)';
%     beta = struct("name", "betaPrime", "t", tb * int64(1e9), "value", 30 + double(tb) / 600, "unit", "deg");
%     drv = timeSeriesPreparation.drivers(arc, beta);
%
%   LIMITATIONS
%     No unit conversion and no frame or time-system handling: the drivers
%     are GPS ns and their units are the caller's statement. Angles are
%     interpolated as numbers, so a wrapping angle (u in [0, 360)) must be
%     supplied unwrapped or as sin/cos.
%
%   REFERENCES
%     docs/CONCEPT.md sections 6.1 (row 9) and 7; R5 (no assumed
%     defaults).
%
%   See also timeSeriesPreparation.correlate, timeSeriesPreparation.align, timeSeriesPreparation.internal.resampleOnto.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.1.0 | 2026-09-24 10:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        series (1,:) struct
        options.Method (1,1) string {mustBeMember(options.Method, ...
            ["pchip" "makima" "spline" "linear"])} = "pchip"
        options.MaxGap double {mustBeScalarOrEmpty, mustBePositive} = []
    end

    if isempty(series) || ~all(isfield(series, ["name" "t" "value" "unit"]))
        error("timeSeriesPreparation:drivers:badSeries", ...
            "series needs at least one element with the fields name, t, value and unit.");
    end
    K = numel(series);
    names = strings(1, K);
    units = strings(1, K);
    for k = 1:K
        s = series(k);
        name = string(s.name);
        if ~isscalar(name) || ~isvarname(name) || ~isa(s.t, "int64") || ~iscolumn(s.t) ...
                || any(diff(s.t) <= 0) || ~isa(s.value, "double") || ~isreal(s.value) ...
                || ~isequal(size(s.value), size(s.t)) || any(isinf(s.value))
            error("timeSeriesPreparation:drivers:badSeries", ...
                "Driver %d: name must be a field name, t an int64 strictly increasing " + ...
                "column, value a real double column of t's size without Inf.", k);
        end
        unit = string(s.unit);
        if ~isscalar(unit) || strlength(strtrim(unit)) == 0
            error("timeSeriesPreparation:drivers:unitUnknown", ...
                "Driver ""%s"" states no unit; a unit is never assumed (R5).", name);
        end
        names(k) = name;
        units(k) = unit;
    end
    if numel(unique(names)) < K
        error("timeSeriesPreparation:drivers:duplicateName", ...
            "Driver names must be distinct; got %s.", strjoin(names, ", "));
    end

    N = numel(arc.t);
    values = NaN(N, K);
    maxGap = zeros(1, K);
    for k = 1:K
        v = series(k).value;
        [values(:, k), info] = timeSeriesPreparation.internal.resampleOnto(series(k).t, v, ...
            isfinite(v), arc.t, options.Method, options.MaxGap);
        maxGap(k) = info.maxGap;
    end
    drv = struct("t", arc.t, "names", names, "units", units, "values", values, ...
        "gap", isnan(values), "method", options.Method, "maxGap", maxGap);
end
