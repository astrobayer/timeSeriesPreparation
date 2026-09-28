function [best, table] = tsAutoArima(x, maxP, maxQ, d, options)
%TSAUTOARIMA  Grid search over ARIMA(p,d,q) orders minimising AIC or BIC.
%
%   SYNTAX
%     [best, table] = timeSeriesPreparation.tsmodels.tsAutoArima(x)
%     [best, table] = timeSeriesPreparation.tsmodels.tsAutoArima(x, maxP, maxQ, d)
%     [best, table] = timeSeriesPreparation.tsmodels.tsAutoArima(x, 3, 3, 0, Criterion = "bic", Method = "css")
%
%   DESCRIPTION
%     Fits every ARIMA(p,d,q) with 0 <= p <= maxP and 0 <= q <= maxQ,
%     except p = q = 0, by timeSeriesPreparation.tsmodels.tsFitArima, and
%     returns the model with the smallest information criterion. The
%     options other than Criterion that are given are passed on to
%     tsFitArima, whose defaults apply otherwise. An order whose fit raises
%     an error is skipped silently. The table lists every fitted
%     order, sorted by the criterion (ties keep the grid order: p outer, q
%     inner). AIC = 2 nll + 2 k and BIC = 2 nll + k log(nObs), with k the
%     number of coefficients plus one, as tsFitArima computes them; d is
%     fixed, so all candidates share one differenced series. Base MATLAB
%     only.
%
%   INPUTS
%     x     (:,1) double   -   Series; NaN marks a gap (exact method,
%                              d = 0).
%     maxP  (1,1) double   -   Largest AR order; [] or omitted: 3.
%     maxQ  (1,1) double   -   Largest MA order; [] or omitted: 3.
%     d     (1,1) double   -   Differencing order; [] or omitted: 0.
%
%   OPTIONS
%     Criterion  (1,1) string   ["aic"]    "aic" or "bic"
%                                          (case-insensitive).
%     Constant   (1,1) logical  [true]     Passed to tsFitArima.
%     Method     (1,1) string   ["exact"]  Passed to tsFitArima: "exact",
%                                          "css" or "yw".
%     Display    (1,1) string   ["off"]    Passed to tsFitArima.
%     MaxIter    (1,1) double   [2000]     Passed to tsFitArima, > 0.
%
%   OUTPUTS
%     best   (1,1) struct   -   The selected model (see tsFitArima).
%     table  (R,6) double   -   One row per fitted order, sorted by the
%                               criterion: [p q criterion aic bic logL].
%
%   ACCURACY
%     Each candidate is a tsFitArima fit; unchanged from sigtools v1.3.1;
%     TestSigtoolsEquivalence holds it bit for bit. The selection is only
%     as good as the individual optima (fminsearch from four starts).
%
%   ERRORS
%     Options:
%       timeSeriesPreparation:tsAutoArima:badOption - Criterion is not
%           "aic" or "bic" (case-insensitive).
%       timeSeriesPreparation:tsAutoArima:unknownCriterion - a criterion
%           other than "aic" or "bic" reaches the grid loop; raised inside
%           the per-order try, so it skips the order. The arguments block
%           refuses such a Criterion first, so it is a guard only.
%     When no order can be fitted (also when tsFitArima refuses a
%     forwarded option, since every order then fails), the call fails in
%     sortrows or in the indexing of the empty result with a MATLAB:
%     identifier. maxP, maxQ or d outside their domain are refused by the
%     arguments block with a MATLAB: identifier.
%
%   EXAMPLE
%     % An AR(1) series: the lowest-BIC order with p <= 2, q <= 1, by CSS.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 8), 300, 1));
%     [best, table] = timeSeriesPreparation.tsmodels.tsAutoArima(x, 2, 1, 0, Criterion = "bic", Method = "css");
%
%   LIMITATIONS
%     The cost is (maxP + 1)(maxQ + 1) - 1 fits; exact ML makes a large
%     grid slow. d is not searched. A failing order is skipped without a
%     message. Options passed as one struct are not accepted; pass
%     name-value pairs.
%
%   REFERENCES
%     H. Akaike (1974), IEEE Trans. Autom. Control 19(6), 716-723.
%     G. Schwarz (1978), Ann. Statist. 6(2), 461-464.
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsAutoSarima, timeSeriesPreparation.tsmodels.tsForecast, timeSeriesPreparation.tsmodels.tsModelDisp.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        maxP {mustBeScalarOrEmpty, mustBeNumeric, mustBeNonnegative} = 3
        maxQ {mustBeScalarOrEmpty, mustBeNumeric, mustBeNonnegative} = 3
        d {mustBeScalarOrEmpty, mustBeNumeric, mustBeNonnegative} = 0
        options.Criterion {mustBeTextScalar, mustBeCriterion} = 'aic'
        % Forwarded to tsFitArima only when given, so that its own
        % defaults and validation apply otherwise, as in v1.3.1.
        options.Constant
        options.Method
        options.Display
        options.MaxIter
    end
    if isempty(maxP), maxP = 3; end
    if isempty(maxQ), maxQ = 3; end
    if isempty(d),    d = 0;    end

    crit = lower(options.Criterion);
    keep = namedargs2cell(rmfield(options, 'Criterion'));

    rows = [];
    models = {};
    for p = 0:maxP
        for q = 0:maxQ
            if p==0 && q==0, continue; end
            try
                mdl = timeSeriesPreparation.tsmodels.tsFitArima(x, p, d, q, keep{:});
                switch crit
                    case 'aic', c = mdl.aic;
                    case 'bic', c = mdl.bic;
                    otherwise, error('timeSeriesPreparation:tsAutoArima:unknownCriterion', 'Unknown criterion');
                end
                rows(end+1,:) = [p q c mdl.aic mdl.bic mdl.logL]; %#ok<AGROW>
                models{end+1} = mdl; %#ok<AGROW>
            catch
                % skip non-converging orders
            end
        end
    end

    [~, ix] = sortrows(rows, 3);
    table = rows(ix,:);
    best  = models{ix(1)};
end

% ----------------------------------------------------------------------
function mustBeCriterion(v)
% Case-insensitive "aic" or "bic".
    if ~any(strcmpi(v, {'aic','bic'}))
        error('timeSeriesPreparation:tsAutoArima:badOption', ...
            'Criterion must be ''aic'' or ''bic''.');
    end
end
