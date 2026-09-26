function model = tsFitAR(x, p, options)
%TSFITAR  Fit an AR(p) model: tsFitArima(x, p, 0, 0, ...).
%
%   SYNTAX
%     model = timeSeriesPreparation.tsmodels.tsFitAR(x, p)
%     model = timeSeriesPreparation.tsmodels.tsFitAR(x, p, Method = "yw")
%
%   DESCRIPTION
%     Shorthand for the autoregressive model
%       x_t - mu = phi_1 (x_(t-1) - mu) + ... + phi_p (x_(t-p) - mu) + e_t,
%     fitted by timeSeriesPreparation.tsmodels.tsFitArima with d = q = 0;
%     the options given are passed on unchanged, and tsFitArima's defaults
%     apply otherwise. The default is exact Gaussian ML by a Kalman
%     filter, which accepts NaN gaps; Method "css" gives conditional sum
%     of squares and "yw" the closed-form Yule-Walker estimate.
%     tsFitArima describes the reparametrisation, the multi-start search
%     and the standard errors.
%
%   INPUTS
%     x  (:,1) double   -   Series; NaN marks a gap (exact method only).
%     p  (1,1) double   -   AR order, >= 0; rounded.
%
%   OPTIONS
%     Constant  (1,1) logical  [true]     Include the mean mu.
%     Method    (1,1) string   ["exact"]  "exact", "css" or "yw".
%     Display   (1,1) string   ["off"]    fminsearch display.
%     MaxIter   (1,1) double   [2000]     fminsearch iteration cap, > 0.
%
%   OUTPUTS
%     model  (1,1) struct   -   The AR(p) model of tsFitArima (fields
%                               type, p, d, q, mu, ar, sigma2, resid,
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
%     % AR(2) with phi = [0.5 -0.3], Yule-Walker.
%     x = filter(1, [1 -0.5 0.3], randn(RandStream("twister", "Seed", 5), 500, 1));
%     model = timeSeriesPreparation.tsmodels.tsFitAR(x, 2, Method = "yw");
%
%   LIMITATIONS
%     Those of tsFitArima. Options passed as one struct (inputParser's
%     StructExpand) are no longer accepted; pass name-value pairs.
%
%   REFERENCES
%     G. E. P. Box, G. M. Jenkins, G. C. Reinsel, G. M. Ljung (2015), Time
%     Series Analysis: Forecasting and Control, 5th ed., Wiley.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsFitMA, timeSeriesPreparation.tsmodels.tsFitARMA.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        x
        p (1,1) {mustBeNumeric, mustBeReal, mustBeNonnegative}
        % Forwarded to tsFitArima only when given, so that its own
        % defaults and validation apply otherwise, as in v1.3.1.
        options.Constant
        options.Method
        options.Display
        options.MaxIter
    end
    nv = namedargs2cell(options);
    model = timeSeriesPreparation.tsmodels.tsFitArima(x, p, 0, 0, nv{:});
end
