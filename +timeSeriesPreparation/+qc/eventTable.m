function T = eventTable(varargin)
%EVENTTABLE Canonical event table (schema authority) for quality-control results.
%
%   T = timeSeriesPreparation.qc.eventTable()                       % empty, schema only
%   T = timeSeriesPreparation.qc.eventTable(tStart, tEnd, class, axis, amplitude, sigma, source, confidence)
%
%   Every detector returns THIS table so that the mask builder and the
%   calibration bridge read one schema. Classes and their downstream use:
%     "outlier"  isolated sample(s)          -> masked, optionally interpolated
%     "impulse"  CRN-shaped pulse            -> masked; assigned to THR1B/twang
%     "jump"     step in level or slope      -> Heaviside column in calibration
%
% INPUT ARGUMENTS (all 1xN or Nx1, same N)
%   Name        Type      Units  Description
%   ----        ----      -----  -----------
%   tStart      datetime  -      UTC, first affected sample
%   tEnd        datetime  -      UTC, last affected sample (== tStart for a point)
%   class       string    -      "outlier" | "impulse" | "jump"
%   axis        string    -      "x" | "y" | "z" | "all"
%   amplitude   double    m/s^2  estimated size (step size for jumps); NaN means NOT ESTIMATED,
%                                which is what io.readTHR1B writes for a thruster firing
%   sigma       double    m/s^2  1-sigma uncertainty of amplitude, >= 0; NaN with the amplitude
%   source      string    -      "THR1B" | "MAS1B" | "eclipse" | "heater" |
%                                "magnetorquer" | "unassigned"
%   confidence  double    -      in [0,1], finite (a probability, never NaN)
%
% OUTPUT ARGUMENTS
%   T           table   N rows, columns as above in that order.
%
% ERRORS
%   timeSeriesPreparation:eventTable:inputArity   not 0 or 8 arguments
%   timeSeriesPreparation:eventTable:inputClass   class / axis / source not in set
%   timeSeriesPreparation:eventTable:inputLength  columns of different length
%   timeSeriesPreparation:eventTable:numericNaN   Inf amplitude or sigma, or non-finite confidence
%
% EXAMPLE
%   T = timeSeriesPreparation.qc.eventTable(); T.Properties.VariableNames
%
% See also timeSeriesPreparation.qc.screen, timeSeriesPreparation.qc.hampel.
%
% KEYWORDS event table schema quality control
% Created 2026-08-27 by Claude Fable 5 (Anthropic).
if nargin == 0
    T = table(datetime.empty(0,1), datetime.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        zeros(0,1), zeros(0,1), string.empty(0,1), zeros(0,1), ...
        'VariableNames', {'tStart','tEnd','class','axis','amplitude','sigma','source','confidence'});
    T.tStart.TimeZone = 'UTC'; T.tEnd.TimeZone = 'UTC';
    return
end
if nargin ~= 8
    timeSeriesPreparation.internal.fail("eventTable", "inputArity", "expects 0 or 8 arguments -> got %d", nargin);
end
[tS, tE, cl, ax, am, sg, so, cf] = varargin{:};
cl = string(cl(:)); ax = string(ax(:)); so = string(so(:));
tS = tS(:); tE = tE(:); am = double(am(:)); sg = double(sg(:)); cf = double(cf(:));
n = numel(tS);
if any([numel(tE) numel(cl) numel(ax) numel(am) numel(sg) numel(so) numel(cf)] ~= n)
    timeSeriesPreparation.internal.fail("eventTable", "inputLength", "all eight columns must have %d elements -> check the inputs", n);
end
if ~all(ismember(cl, ["outlier","impulse","jump"]))
    timeSeriesPreparation.internal.fail("eventTable", "inputClass", "class must be outlier|impulse|jump -> got '%s'", cl(find(~ismember(cl,["outlier","impulse","jump"]),1)));
end
if ~all(ismember(ax, ["x","y","z","all"]))
    timeSeriesPreparation.internal.fail("eventTable", "inputClass", "axis must be x|y|z|all -> check the axis column");
end
if ~all(ismember(so, ["THR1B","MAS1B","eclipse","heater","magnetorquer","unassigned"]))
    timeSeriesPreparation.internal.fail("eventTable", "inputClass", "source not in the admissible set -> use unassigned if unknown");
end
% amplitude and sigma may be NaN, meaning NOT ESTIMATED: io.readTHR1B writes exactly that for a
% thruster firing, whose epoch is certain while its size can only come from the accelerometer.
% Inf is never meaningful, and confidence is a probability, so a NaN there is the real defect:
% until 2026-09-07 it passed the [0,1] test below, because every comparison with NaN is false.
if any(isinf(am)) || any(isinf(sg))
    timeSeriesPreparation.internal.fail("eventTable", "numericNaN", "amplitude and sigma must be finite or NaN (not estimated) -> got an Inf");
end
if any(~isfinite(cf))
    timeSeriesPreparation.internal.fail("eventTable", "numericNaN", "confidence must be finite -> a NaN confidence passed the [0,1] test silently until 2026-09-07, since every comparison with NaN is false");
end
if any(sg < 0)
    timeSeriesPreparation.internal.fail("eventTable", "inputClass", "sigma must be >= 0 -> got %g", min(sg));
end
if any(cf < 0 | cf > 1)
    timeSeriesPreparation.internal.fail("eventTable", "inputClass", "confidence must be in [0,1] -> clip or rescale");
end
T = table(tS, tE, cl, ax, am, sg, so, cf, ...
    'VariableNames', {'tStart','tEnd','class','axis','amplitude','sigma','source','confidence'});
end
