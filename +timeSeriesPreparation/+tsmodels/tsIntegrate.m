function x = tsIntegrate(y, x0)
%TSINTEGRATE  Inverse of tsDiff: reconstruct a series from its differences.
%
%   SYNTAX
%     x = timeSeriesPreparation.tsmodels.tsIntegrate(y, x0)
%
%   DESCRIPTION
%     Undoes y = (1-B)^d x of tsDiff, for instance to bring a forecast of
%     the differenced series back to the original scale. Starting from the
%     deepest level, each step prepends the stored initial value x0(i) and
%     cumulatively sums: x = x0(i) + [0; cumsum(y)]. With d = numel(x0)
%     levels the result is d samples longer than y; an empty x0 returns y.
%     Base MATLAB only.
%
%   INPUTS
%     y   (:,1) double   -   Differenced series, finite. A matrix is read
%                            as y(:).
%     x0  (:,1) double   -   Initial value per differencing level, as
%                            returned by tsDiff; [] for d = 0.
%
%   OUTPUTS
%     x  (M+d,1) double   -   Reconstructed series on the original scale.
%
%   ACCURACY
%     Exact up to rounding in the cumulative sums; tsIntegrate(tsDiff(x, d))
%     returns x to rounding. Unchanged from sigtools v1.3.1;
%     TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none)
%     A non-numeric, complex or non-finite y, or a non-numeric x0, is
%     refused by the arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Difference twice and rebuild.
%     x = ((1:10)').^2;
%     [y, x0] = timeSeriesPreparation.tsmodels.tsDiff(x, 2);
%     xr = timeSeriesPreparation.tsmodels.tsIntegrate(y, x0);
%
%   LIMITATIONS
%     Lag-1 levels only, matching tsDiff. The rounding error of the
%     cumulative sums grows with the length and with d.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley. sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.tsmodels.tsDiff, timeSeriesPreparation.tsmodels.tsForecast.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        y {mustBeNumeric, mustBeReal, mustBeFinite}
        x0 {mustBeNumeric}
    end

    y = y(:); x0 = x0(:);
    for i = numel(x0):-1:1
        x = x0(i) + [0; cumsum(y)];
        y = x;
    end
    if isempty(x0), x = y; end
end
