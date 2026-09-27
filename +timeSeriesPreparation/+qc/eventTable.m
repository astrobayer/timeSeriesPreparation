function T = eventTable(varargin)
%EVENTTABLE  Canonical event table (schema authority) for quality-control results.
%
%   SYNTAX
%     T = timeSeriesPreparation.qc.eventTable()
%     T = timeSeriesPreparation.qc.eventTable(tStart, tEnd, class, axis, amplitude, sigma, source, confidence)
%
%   DESCRIPTION
%     Every detector returns this table, so the mask builder and the
%     calibration read one schema. Without arguments it returns the empty
%     table (the schema). Classes and their downstream use: "outlier"
%     (isolated samples, masked), "impulse" (CRN-shaped pulse, masked,
%     assigned to THR1B or a twang), "jump" (step in level or slope, a
%     Heaviside column in the calibration, never masked). An amplitude
%     and sigma of NaN mean not estimated, which is what a THR1B firing
%     carries; confidence is a probability and never NaN. Ported from
%     NonGravForces.qc 0.12.0 (X-05); unchanged (X-05b).
%
%   INPUTS
%     tStart      (N,1) datetime   -   UTC, first affected sample.
%     tEnd        (N,1) datetime   -   UTC, last affected sample (tStart
%                                      for a point).
%     class       (N,1) string     -   "outlier", "impulse" or "jump".
%     axis        (N,1) string     -   "x", "y", "z" or "all".
%     amplitude   (N,1) double     -   Estimated size (step size for
%                                      jumps), units of the data; NaN =
%                                      not estimated.
%     sigma       (N,1) double     -   1-sigma of amplitude, >= 0; NaN
%                                      with the amplitude.
%     source      (N,1) string     -   "THR1B", "MAS1B", "eclipse",
%                                      "heater", "magnetorquer" or
%                                      "unassigned".
%     confidence  (N,1) double     -   In [0, 1], finite.
%
%   OUTPUTS
%     T  (N,8) table   -   Variables tStart, tEnd, class, axis, amplitude,
%                          sigma, source, confidence, in that order.
%
%   ACCURACY
%     Not applicable, because the function computes no number; values are
%     stored as given.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:eventTable:inputArity - not 0 or 8 arguments.
%       timeSeriesPreparation:eventTable:inputClass - class, axis or source
%           outside its set, sigma negative, or confidence outside [0, 1].
%       timeSeriesPreparation:eventTable:inputLength - columns of different
%           length.
%       timeSeriesPreparation:eventTable:numericNaN - amplitude or sigma
%           Inf, or confidence not finite.
%
%   EXAMPLE
%     % A jump and an outlier.
%     t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds([10; 20]);
%     T = timeSeriesPreparation.qc.eventTable(t, t, ["outlier"; "jump"], ["x"; "all"], [1e-8; 2e-9], [1e-9; 1e-9], ["unassigned"; "eclipse"], [0.9; 0.5]);
%
%   LIMITATIONS
%     The source set is closed; a new source is a schema change.
%
%   REFERENCES
%     NonGravForces.qc 0.12.0 (3cc0123).
%
%   See also timeSeriesPreparation.qc.screen, timeSeriesPreparation.qc.hampel, timeSeriesPreparation.qc.detectImpulses, timeSeriesPreparation.qc.detectJumps.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

if nargin == 0
    T = table(datetime.empty(0,1), datetime.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        zeros(0,1), zeros(0,1), string.empty(0,1), zeros(0,1), ...
        'VariableNames', {'tStart','tEnd','class','axis','amplitude','sigma','source','confidence'});
    T.tStart.TimeZone = 'UTC'; T.tEnd.TimeZone = 'UTC';
    return
end
if nargin ~= 8
    error("timeSeriesPreparation:eventTable:inputArity", "expects 0 or 8 arguments -> got %d", nargin);
end
[tS, tE, cl, ax, am, sg, so, cf] = varargin{:};
cl = string(cl(:)); ax = string(ax(:)); so = string(so(:));
tS = tS(:); tE = tE(:); am = double(am(:)); sg = double(sg(:)); cf = double(cf(:));
n = numel(tS);
if any([numel(tE) numel(cl) numel(ax) numel(am) numel(sg) numel(so) numel(cf)] ~= n)
    error("timeSeriesPreparation:eventTable:inputLength", "all eight columns must have %d elements -> check the inputs", n);
end
if ~all(ismember(cl, ["outlier","impulse","jump"]))
    error("timeSeriesPreparation:eventTable:inputClass", "class must be outlier|impulse|jump -> got '%s'", cl(find(~ismember(cl,["outlier","impulse","jump"]),1)));
end
if ~all(ismember(ax, ["x","y","z","all"]))
    error("timeSeriesPreparation:eventTable:inputClass", "axis must be x|y|z|all -> check the axis column");
end
if ~all(ismember(so, ["THR1B","MAS1B","eclipse","heater","magnetorquer","unassigned"]))
    error("timeSeriesPreparation:eventTable:inputClass", "source not in the admissible set -> use unassigned if unknown");
end
% amplitude and sigma may be NaN, meaning NOT ESTIMATED: io.readTHR1B writes exactly that for a
% thruster firing, whose epoch is certain while its size can only come from the accelerometer.
% Inf is never meaningful, and confidence is a probability, so a NaN there is the real defect:
% until 2026-09-07 it passed the [0,1] test below, because every comparison with NaN is false.
if any(isinf(am)) || any(isinf(sg))
    error("timeSeriesPreparation:eventTable:numericNaN", "amplitude and sigma must be finite or NaN (not estimated) -> got an Inf");
end
if any(~isfinite(cf))
    error("timeSeriesPreparation:eventTable:numericNaN", "confidence must be finite -> a NaN confidence passed the [0,1] test silently until 2026-09-07, since every comparison with NaN is false");
end
if any(sg < 0)
    error("timeSeriesPreparation:eventTable:inputClass", "sigma must be >= 0 -> got %g", min(sg));
end
if any(cf < 0 | cf > 1)
    error("timeSeriesPreparation:eventTable:inputClass", "confidence must be in [0,1] -> clip or rescale");
end
T = table(tS, tE, cl, ax, am, sg, so, cf, ...
    'VariableNames', {'tStart','tEnd','class','axis','amplitude','sigma','source','confidence'});
end
