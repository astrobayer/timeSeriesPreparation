function model = tsFitMA(x, q, options)
%TSFITMA  Fit an MA(q) model: tsFitArima(x, 0, 0, q, ...).
%
%   SYNTAX
%     model = timeSeriesPreparation.tsmodels.tsFitMA(x, q)
%     model = timeSeriesPreparation.tsmodels.tsFitMA(x, q, Method = "css")
%
%   DESCRIPTION
%     Shorthand for the moving-average model
%       x_t - mu = e_t + theta_1 e_(t-1) + ... + theta_q e_(t-q),
%     fitted by timeSeriesPreparation.tsmodels.tsFitArima with p = d = 0;
%     the options given are passed on unchanged, and tsFitArima's defaults
%     apply otherwise. The default is exact Gaussian ML by a Kalman
%     filter, which accepts NaN gaps; Method "css" gives conditional sum
%     of squares. The MA polynomial is invertible by
%     construction (PACF reparametrisation, see tsFitArima).
%
%   INPUTS
%     x  (:,1) double   -   Series; NaN marks a gap (exact method only).
%     q  (1,1) double   -   MA order, >= 0; rounded.
%
%   OPTIONS
%     Constant  (1,1) logical  [true]     Include the mean mu.
%     Method    (1,1) string   ["exact"]  "exact" or "css" ("yw" is
%                                         refused for q > 0).
%     Display   (1,1) string   ["off"]    fminsearch display.
%     MaxIter   (1,1) double   [2000]     fminsearch iteration cap, > 0.
%
%   OUTPUTS
%     model  (1,1) struct   -   The MA(q) model of tsFitArima (fields
%                               type, p, d, q, mu, ma, sigma2, resid,
%                               stdErr, logL, aic, bic, ...).
%
%   ACCURACY
%     That of tsFitArima, which it calls; unchanged from sigtools v1.3.1;
%     TestSigtoolsEquivalence holds it bit for bit.
%
%   ERRORS
%     (none of its own)
%     The errors of timeSeriesPreparation.tsmodels.tsFitArima pass
%     through, and so do tsFitArima's refusals of an option outside its
%     domain.
%
%   EXAMPLE
%     % MA(1) with theta = 0.5 and zero mean, by CSS.
%     x = filter([1 0.5], 1, randn(RandStream("twister", "Seed", 6), 300, 1));
%     model = timeSeriesPreparation.tsmodels.tsFitMA(x, 1, Method = "css", Constant = false);
%
%   LIMITATIONS
%     Those of tsFitArima. Options passed as one struct (inputParser's
%     StructExpand) are no longer accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsFitAR, timeSeriesPreparation.tsmodels.tsFitARMA.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        q (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        % Forwarded to tsFitArima only when given, so that its own
        % defaults and validation apply otherwise, as in v1.3.1.
        options.Constant
        options.Method
        options.Display
        options.MaxIter
    end
    nv = namedargs2cell(options);
    model = timeSeriesPreparation.tsmodels.tsFitArima(x, 0, 0, q, nv{:});
end
