function [best, tbl] = tsAutoSarima(x, maxOrder, maxSeasonal, s, options)
%TSAUTOSARIMA  Grid search over seasonal ARIMA orders minimising AIC or BIC.
%
%   SYNTAX
%     [best, tbl] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, maxOrder, maxSeasonal, s)
%     [best, tbl] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [2 1 2], [1 1 1], 12, Criterion = "bic")
%     best = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 0], [1 0 0], 6, Method = "exact", Constant = false)
%
%   DESCRIPTION
%     Chooses the orders of a multiplicative SARIMA(p,d,q)(P,D,Q)_s model
%     when they are not known. Every model of the rectangular grid
%     0 <= p <= maxp, ..., 0 <= Q <= maxQ except the all-zero one is fitted
%     with tsFitSarima; a fit that fails (too short, not estimable) or has a
%     non-finite criterion is skipped. best is the fit with the smallest
%     criterion, tbl lists all successful fits sorted by it.
%
%     The differencing orders d and D are searched too, although the
%     likelihoods of models with different differencing are not strictly
%     comparable: each fit's own AIC/BIC, based on its own nObs, is used as
%     returned by tsFitSarima. For a clean comparison fix d and D (maxd =
%     maxD = 0 on a pre-differenced series). Every option other than
%     Criterion is passed to each tsFitSarima call only when given, so
%     tsFitSarima's own defaults (listed under OPTIONS) apply otherwise.
%     Base MATLAB only.
%
%   INPUTS
%     x            (:,1) double   -   Series; finite, or NaN gaps with
%                                     Method = "exact" and d = D = 0.
%     maxOrder     (1,3) double   -   Upper orders [maxp maxd maxq], each
%                                     a nonnegative integer; []: [2 1 2].
%     maxSeasonal  (1,3) double   -   Upper seasonal orders [maxP maxD
%                                     maxQ]; []: [1 1 1].
%     s            (1,1) double   -   Seasonal period in samples, an
%                                     integer >= 2.
%
%   OPTIONS
%     Criterion  (1,1) string    ["aic"]   Selection criterion, "aic" or
%                                          "bic" (case-insensitive).
%     Method     (1,1) string    ["css"]   Passed to tsFitSarima: "css" or
%                                          "exact".
%     Constant   (1,1) logical   [true]    Passed to tsFitSarima: fit a
%                                          mean.
%     Display    (1,1) string    ["off"]   Passed to tsFitSarima: fminsearch
%                                          display.
%     MaxIter    (1,1) double    [3000]    Passed to tsFitSarima: iteration
%                                          cap per start.
%     NStart     (1,1) double    [3]       Passed to tsFitSarima: number of
%                                          optimiser starts.
%
%   OUTPUTS
%     best  (1,1) struct   -   The best fit, a tsFitSarima struct.
%     tbl   (R,9) double   -   One row per successful fit, [p d q P D Q
%                              criterion aic bic], sorted ascending by the
%                              criterion (column 7).
%
%   ACCURACY
%     That of tsFitSarima for each fit; the search itself is exhaustive over
%     the grid. The exact-ML SARIMA likelihood reproduces the direct
%     multivariate-normal density to about 1e-14 (sigtools v1.3.1 HANDOFF,
%     section 3). Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence
%     holds it bit for bit.
%
%   ERRORS
%     Options:
%       timeSeriesPreparation:tsAutoSarima:criterion - Criterion is neither
%           "aic" nor "bic".
%     Fit:
%       timeSeriesPreparation:tsAutoSarima:noFit - no order in the grid
%           could be fitted.
%     Input:
%       A maxOrder or maxSeasonal that is not three nonnegative integers,
%       an s that is not an integer >= 2, or an unknown option, is refused
%       by the arguments block or by validateattributes with a MATLAB:
%       identifier.
%
%   EXAMPLE
%     % A seasonal AR(1) with period 4 on a small grid.
%     x = filter(1, [1 0 0 0 -0.6], randn(RandStream("twister", "Seed", 5), 300, 1));
%     [best, tbl] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 0], [1 0 0], 4, Criterion = "bic");
%
%   LIMITATIONS
%     The cost grows with the product of the grid sizes, each fit with
%     NStart optimiser starts. AIC/BIC across different d and D are not
%     strictly comparable (see above). Only the tsFitSarima options listed
%     above are forwarded.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, Time Series Analysis:
%     Forecasting and Control, Wiley. sigtools v1.3.1 HANDOFF (docs/inputs),
%     sections 3 and 6.
%
%   See also timeSeriesPreparation.tsmodels.tsFitSarima, timeSeriesPreparation.tsmodels.tsAutoArima, timeSeriesPreparation.tsmodels.tsForecast, timeSeriesPreparation.tsmodels.tsModelDisp.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x {mustBeNumeric, mustBeReal}
        maxOrder {mustBeNumeric}
        maxSeasonal {mustBeNumeric}
        s (1,1) {mustBeNumeric, mustBeInteger, mustBeGreaterThanOrEqual(s, 2)}
        options.Criterion {mustBeTextScalar} = 'aic'
        % Forwarded to tsFitSarima only when given, so that its own
        % defaults apply otherwise.
        options.Method
        options.Constant
        options.Display
        options.MaxIter
        options.NStart
    end

    if isempty(maxOrder),    maxOrder    = [2 1 2]; end
    if isempty(maxSeasonal), maxSeasonal = [1 1 1]; end
    validateattributes(maxOrder,    {'numeric'}, {'numel',3,'nonnegative','integer'}, mfilename, 'maxOrder');
    validateattributes(maxSeasonal, {'numeric'}, {'numel',3,'nonnegative','integer'}, mfilename, 'maxSeasonal');

    crit = lower(char(options.Criterion));
    keep = namedargs2cell(rmfield(options, 'Criterion'));
    if ~any(strcmp(crit, {'aic','bic'}))
        error('timeSeriesPreparation:tsAutoSarima:criterion', 'Criterion must be ''aic'' or ''bic''.');
    end

    mp = maxOrder(1); md = maxOrder(2); mq = maxOrder(3);
    mP = maxSeasonal(1); mD = maxSeasonal(2); mQ = maxSeasonal(3);

    rows = [];  models = {};
    for p = 0:mp
      for d = 0:md
        for q = 0:mq
          for P = 0:mP
            for D = 0:mD
              for Q = 0:mQ
                if (p+d+q+P+D+Q) == 0, continue; end
                try
                    mdl = timeSeriesPreparation.tsmodels.tsFitSarima(x, [p d q], [P D Q], s, keep{:});
                    switch crit
                        case 'aic', c = mdl.aic;
                        case 'bic', c = mdl.bic;
                    end
                    if ~isfinite(c), continue; end
                    rows(end+1,:) = [p d q P D Q c mdl.aic mdl.bic]; %#ok<AGROW>
                    models{end+1} = mdl;                              %#ok<AGROW>
                catch
                    % skip orders that fail to fit / are too short
                end
              end
            end
          end
        end
      end
    end

    if isempty(rows)
        error('timeSeriesPreparation:tsAutoSarima:noFit', ...
            'No SARIMA order in the grid could be fitted to the series.');
    end

    [~, ix] = sortrows(rows, 7);
    tbl  = rows(ix, :);
    best = models{ix(1)};
end
