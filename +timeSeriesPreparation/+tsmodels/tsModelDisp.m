function tsModelDisp(model)
%TSMODELDISP  Pretty-print a fitted ARIMA or SARIMA model summary.
%
%   SYNTAX
%     timeSeriesPreparation.tsmodels.tsModelDisp(model)
%
%   DESCRIPTION
%     A readable summary of a fit for the command window: the model type
%     and method (flagged when the optimiser did not converge), each
%     coefficient (mu, AR, MA and, for SARIMA, SAR, SMA) with its standard
%     error, sigma^2, the log-likelihood with n and k, the observed count
%     when samples are missing, AIC and BIC, and a Ljung-Box test of the
%     residuals at L = min(20, max(1, floor(n/4))) lags with nParam =
%     p + q (+ P + Q). Standard errors are shown only when the model
%     carries a field stdErr; tsFitSarima fits do not compute them, so the
%     column reads '-'. Base MATLAB only.
%
%   INPUTS
%     model  (1,1) struct   -   Fit from tsFitArima, tsFitAR, tsFitMA,
%                               tsFitARMA, tsFitSarima, tsAutoArima or
%                               tsAutoSarima.
%
%   OUTPUTS
%     (none)
%     Prints to the command window.
%
%   ACCURACY
%     Not applicable, because it prints the model's numbers, rounded to the
%     printed digits (%12.6g for coefficients, %.5g for standard errors),
%     and a Ljung-Box value computed by tsLjungBox.
%
%   ERRORS
%     (none)
%     A model that is not a 1x1 struct is refused by the arguments block,
%     and a missing field by MATLAB, each with a MATLAB: identifier.
%
%   EXAMPLE
%     % Fit an AR(1) and print its summary.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 4), 300, 1));
%     timeSeriesPreparation.tsmodels.tsModelDisp(timeSeriesPreparation.tsmodels.tsFitAR(x, 1));
%
%   LIMITATIONS
%     Output only; nothing is returned. Use tsCheckResiduals for the
%     residual numbers.
%
%   REFERENCES
%     G. M. Ljung, G. E. P. Box (1978), Biometrika 65(2), 297-303.
%     sigtools v1.3.1 HANDOFF (docs/inputs).
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.tsmodels.tsLjungBox, timeSeriesPreparation.tsmodels.tsForecast.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        model (1,1) struct
    end

    if isfield(model,'stdErr'), se = model.stdErr; else, se = []; end
    getSE = @(i) local_se(se, i);
    isSeasonal = isfield(model,'season') && isfield(model,'P');

    fprintf('\n%s   (method: %s', model.type, model.method);
    if isfield(model,'converged') && ~model.converged
        fprintf(', NOT converged');
    end
    fprintf(')\n%s\n', repmat('-',1,48));
    fprintf('  %-9s %12s %12s\n', 'param', 'estimate', 'std.err');

    idx = 1;
    if model.const
        fprintf('  %-9s %12.6g %12s\n', 'mu', model.mu, local_fmt(getSE(idx)));
        idx = idx + 1;
    end
    for i = 1:model.p
        fprintf('  AR(%-5d) %12.6g %12s\n', i, model.ar(i), local_fmt(getSE(idx)));
        idx = idx + 1;
    end
    for j = 1:model.q
        fprintf('  MA(%-5d) %12.6g %12s\n', j, model.ma(j), local_fmt(getSE(idx)));
        idx = idx + 1;
    end
    if isSeasonal
        for i = 1:model.P
            fprintf('  SAR(%-4d) %12.6g %12s\n', i, model.sar(i), local_fmt(getSE(idx)));
            idx = idx + 1;
        end
        for j = 1:model.Q
            fprintf('  SMA(%-4d) %12.6g %12s\n', j, model.sma(j), local_fmt(getSE(idx)));
            idx = idx + 1;
        end
    end
    fprintf('  %-9s %12.6g\n', 'sigma^2', model.sigma2);
    fprintf('%s\n', repmat('-',1,48));
    fprintf('  logL = %.4f   n = %d   k = %d\n', model.logL, model.n, model.k);
    if isfield(model,'nObs') && model.nObs < model.n
        fprintf('  observed = %d / %d  (%d missing)\n', ...
                model.nObs, model.n, model.n - model.nObs);
    end
    fprintf('  AIC  = %.4f   BIC = %.4f\n', model.aic, model.bic);

    nLag = min(20, max(1, floor(model.n/4)));
    nParam = model.p + model.q;
    if isSeasonal, nParam = nParam + model.P + model.Q; end
    [Q, pv] = timeSeriesPreparation.tsmodels.tsLjungBox(model.resid, nLag, nParam);
    fprintf('  Ljung-Box(%d): Q = %.3f, p = %.4f\n\n', nLag, Q, pv);
end

function v = local_se(se, i)
    if ~isempty(se) && i <= numel(se), v = se(i); else, v = NaN; end
end

function s = local_fmt(v)
    if isnan(v), s = '-'; else, s = sprintf('%.5g', v); end
end
