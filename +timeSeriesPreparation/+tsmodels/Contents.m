% timeSeriesPreparation.tsmodels - ARIMA and SARIMA time-series models
% sigtools v1.3.1, conventions of X-02
%
%   Base MATLAB only. Call as timeSeriesPreparation.tsmodels.<name>.
%
%   Identification
%     tsAcf              - Sample autocorrelation function (gap-aware).
%     tsPacf             - Sample partial autocorrelation function
%                          (Durbin-Levinson, gap-aware).
%     tsDiff             - Apply d-th order lag-1 differencing:
%                          y = (1-B)^d x.
%     tsIntegrate        - Inverse of tsDiff: reconstruct a series from its
%                          differences.
%
%   Estimation
%     tsFitArima         - Fit an ARIMA(p,d,q) model by exact ML, CSS or
%                          Yule-Walker.
%     tsFitAR            - Fit an AR(p) model. Wrapper for
%                          TSFITARIMA(X,p,0,0).
%     tsFitMA            - Fit an MA(q) model. Wrapper for
%                          TSFITARIMA(X,0,0,q).
%     tsFitARMA          - Fit an ARMA(p,q) model. Wrapper for
%                          TSFITARIMA(X,p,0,q).
%     tsFitSarima        - Fit a seasonal ARIMA(p,d,q)(P,D,Q)_s model by CSS
%                          or exact ML.
%
%   Order selection
%     tsAutoArima        - Grid search over (p,q) minimising an information
%                          criterion.
%     tsAutoSarima       - Grid search over seasonal ARIMA orders minimising
%                          AIC or BIC.
%
%   Forecasting
%     tsForecast         - h-step-ahead forecasts from a fitted (S)ARIMA
%                          model.
%
%   Diagnostics
%     tsCheckResiduals   - Residual diagnostics of a fitted ARIMA/SARIMA
%                          model: ACF, Ljung-Box, Jarque-Bera.
%     tsLjungBox         - Ljung-Box portmanteau test for residual
%                          autocorrelation.
%     tsModelDisp        - Pretty-print a fitted ARIMA or SARIMA model
%                          summary.
%     plotResiduals      - Draw the four-panel residual check from
%                          tsCheckResiduals.
%
%   The discrete Lyapunov solver shared with spectral is
%   timeSeriesPreparation.internal.dlyap.
