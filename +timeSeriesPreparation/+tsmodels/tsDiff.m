function [y, x0] = tsDiff(x, d)
%TSDIFF  Apply d-th order lag-1 differencing: y = (1-B)^d x.
%
%   SYNTAX
%     y = timeSeriesPreparation.tsmodels.tsDiff(x)
%     [y, x0] = timeSeriesPreparation.tsmodels.tsDiff(x, d)
%
%   DESCRIPTION
%     Differencing removes a stochastic trend before an ARMA model is fitted
%     (the "I" of ARIMA): y = (1-B)^d x, with B the lag operator, applied as
%     d successive diff calls. x0(i) keeps the first value at level i, so
%     tsIntegrate(y, x0) rebuilds x exactly. d = 0 passes the series
%     through, NaN gaps included; for d > 0 the series must be finite,
%     because a difference across a missing sample is undefined. Base
%     MATLAB only.
%
%   INPUTS
%     x  (:,1) double   -   Series. A matrix is read as x(:).
%     d  (1,1) double   -   Differencing order >= 0, rounded; [] or
%                           omitted: 0.
%
%   OUTPUTS
%     y   (N-d,1) double   -   Differenced series (1-B)^d x.
%     x0  (d,1) double     -   First value at each differencing level, for
%                              tsIntegrate.
%
%   ACCURACY
%     Exact up to rounding in the differences. Unchanged from sigtools
%     v1.3.1; TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     Order:
%       timeSeriesPreparation:tsDiff:negativeOrder - d < 0.
%       timeSeriesPreparation:tsDiff:tooShort - d >= numel(x).
%     Gaps:
%       timeSeriesPreparation:tsDiff:nonfiniteWithDiff - d > 0 and x holds
%           NaN or Inf.
%     Input:
%       A non-numeric or complex x, or a d that is not a numeric scalar or
%       [], is refused by the arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Second differences of a quadratic are constant.
%     x = ((1:10)').^2;
%     [y, x0] = timeSeriesPreparation.tsmodels.tsDiff(x, 2);
%
%   LIMITATIONS
%     Lag-1 differencing only; seasonal differencing (1-B^s)^D lives in
%     tsFitSarima. No differencing across gaps.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley. sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.tsmodels.tsIntegrate, timeSeriesPreparation.tsmodels.tsFitArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x {mustBeNumeric, mustBeReal}
        d {mustBeScalarOrEmpty, mustBeNumeric} = 0
    end

    x = x(:);
    % Allow NaN gaps only when d==0 (pass-through); differencing across
    % missing samples is undefined, so require finiteness once d>0.
    if isempty(d), d = 0; end
    d = round(d);
    if d < 0, error('timeSeriesPreparation:tsDiff:negativeOrder','D must be >= 0.'); end
    if d > 0 && any(~isfinite(x))
        error('timeSeriesPreparation:tsDiff:nonfiniteWithDiff', ...
            'Differencing (d>0) requires a finite series (no NaN/Inf gaps).');
    end
    if d >= numel(x), error('timeSeriesPreparation:tsDiff:tooShort','D too large for series length.'); end
    y = x; x0 = zeros(d,1);
    for i = 1:d
        x0(i) = y(1);
        y = diff(y);
    end
end
