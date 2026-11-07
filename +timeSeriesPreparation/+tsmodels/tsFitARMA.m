function model = tsFitARMA(x, p, q, options)
%TSFITARMA  Fit an ARMA(p,q) model: tsFitArima(x, p, 0, q, ...).
%
%   SYNTAX
%     model = timeSeriesPreparation.tsmodels.tsFitARMA(x, p, q)
%     model = timeSeriesPreparation.tsmodels.tsFitARMA(x, p, q, Method = "css")
%
%   DESCRIPTION
%     Shorthand for the ARMA model
%       phi(B) (x_t - mu) = theta(B) e_t,
%     fitted by timeSeriesPreparation.tsmodels.tsFitArima with d = 0; the
%     options given are passed on unchanged, and tsFitArima's defaults
%     apply otherwise. The default is exact Gaussian ML by a Kalman
%     filter, which accepts NaN gaps; Method "css" gives conditional sum
%     of squares. Both polynomials are stationary and
%     invertible by construction (PACF reparametrisation, see
%     tsFitArima).
%
%   INPUTS
%     x  (:,1) double   -   Series; NaN marks a gap (exact method only).
%     p  (1,1) double   -   AR order, >= 0; rounded.
%     q  (1,1) double   -   MA order, >= 0; rounded.
%
%   OPTIONS
%     Constant  (1,1) logical  [true]     Include the mean mu.
%     Method    (1,1) string   ["exact"]  "exact" or "css" ("yw" only for
%                                         q = 0).
%     Display   (1,1) string   ["off"]    fminsearch display.
%     MaxIter   (1,1) double   [2000]     fminsearch iteration cap, > 0.
%
%   OUTPUTS
%     model  (1,1) struct   -   The ARMA(p,q) model of tsFitArima (fields
%                               type, p, d, q, mu, ar, ma, sigma2, resid,
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
%     % ARMA(1,1) with phi = 0.5, theta = 0.4 and zero mean, by CSS.
%     x = filter([1 0.4], [1 -0.5], randn(RandStream("twister", "Seed", 7), 300, 1));
%     model = timeSeriesPreparation.tsmodels.tsFitARMA(x, 1, 1, Method = "css", Constant = false);
%
%   LIMITATIONS
%     Those of tsFitArima. Options passed as one struct (inputParser's
%     StructExpand) are no longer accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsFitAR, timeSeriesPreparation.tsmodels.tsFitMA, timeSeriesPreparation.tsmodels.tsAutoArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        p (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        q (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        % Forwarded to tsFitArima only when given, so that its own
        % defaults and validation apply otherwise, as in v1.3.1.
        options.Constant
        options.Method
        options.Display
        options.MaxIter
    end
    nv = namedargs2cell(options);
    model = timeSeriesPreparation.tsmodels.tsFitArima(x, p, 0, q, nv{:});
end
