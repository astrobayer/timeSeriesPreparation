% timeSeriesPreparation.tsmodels - time-series models (sigtools v1.3.1, imported unchanged at X-01)
%
%   Base MATLAB only. Call as timeSeriesPreparation.tsmodels.<name>.
%
%     tsAcf              - Sample autocorrelation (gap-aware).
%     tsPacf             - Sample partial autocorrelation (Durbin-Levinson, PD-repair).
%     tsDiff             - (1-B)^d differencing.
%     tsIntegrate        - Inverse of tsDiff.
%     tsFitArima         - Core ARIMA estimator (exact-ML / CSS / Yule-Walker).
%     tsFitAR            - AR(p) wrapper.
%     tsFitMA            - MA(q) wrapper.
%     tsFitARMA          - ARMA(p,q) wrapper.
%     tsFitSarima        - Seasonal ARIMA(p,d,q)(P,D,Q)_s by CSS or exact ML (gaps).
%     tsAutoArima        - (p,q) grid search by AIC/BIC.
%     tsAutoSarima       - Seasonal (p,d,q)(P,D,Q)_s grid search by AIC/BIC.
%     tsForecast         - h-step forecasts + intervals (ARIMA/SARIMA, gaps, bootstrap).
%     tsLjungBox         - Ljung-Box portmanteau test.
%     tsCheckResiduals   - Four-panel residual diagnostics.
%     tsModelDisp        - Pretty-print a fitted model.
%
%   Help text, error identifiers and plotting are sigtools' own until X-02
%   brings them to this toolbox's conventions (CONCEPT 10.1, X-02).
