function h = plotResiduals(out)
%PLOTRESIDUALS  Draw the four-panel residual check from tsCheckResiduals.
%
%   SYNTAX
%     h = timeSeriesPreparation.tsmodels.plotResiduals(out)
%
%   DESCRIPTION
%     The drawing half of sigtools' tsCheckResiduals, which always drew in
%     v1.3.1, split at X-02 (owner decision 2026-09-23). It draws the
%     figure v1.3.1 drew, in four panels:
%       - the standardised residuals over time;
%       - the residual ACF with the +/- white-noise band;
%       - the normal Q-Q plot, titled with the Jarque-Bera p-value;
%       - the Ljung-Box p-value ladder with the 5 % line.
%
%   INPUTS
%     out  (1,1) struct   -   From tsCheckResiduals.
%
%   OUTPUTS
%     h  (1,1) struct   -   Graphics handles: figure, axes (1,4).
%
%   ACCURACY
%     Not applicable, because the function draws and computes nothing.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:plotResiduals:badInput - out lacks a field of
%           tsCheckResiduals' output.
%
%   EXAMPLE
%     % An AR(1) fit, checked and drawn.
%     x = filter(1, [1 -0.6], randn(RandStream("twister", "Seed", 2), 500, 1));
%     out = timeSeriesPreparation.tsmodels.tsCheckResiduals(timeSeriesPreparation.tsmodels.tsFitAR(x, 1));
%     h = timeSeriesPreparation.tsmodels.plotResiduals(out);
%     close(h.figure);
%
%   LIMITATIONS
%     Always a new figure.
%
%   REFERENCES
%     sigtools v1.3.1 tsCheckResiduals (docs/inputs), its plot branch.
%
%   See also timeSeriesPreparation.tsmodels.tsCheckResiduals, timeSeriesPreparation.tsmodels.tsLjungBox.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        out (1,1) struct
    end

    need = ["resid" "acf" "acfConf" "lags" "lbP" "jbP" "qqSample" "qqTheoretical"];
    if ~all(isfield(out, need))
        error("timeSeriesPreparation:plotResiduals:badInput", ...
            "out must come from tsCheckResiduals (fields %s).", strjoin(need, ", "));
    end

    h.figure = figure('Name', 'tsCheckResiduals', 'Color', 'w');
    h.axes = gobjects(1, 4);

    h.axes(1) = subplot(2,2,1, 'Parent', h.figure);
    plot(h.axes(1), out.resid, 'k-'); hold(h.axes(1), 'on'); yline(h.axes(1), 0, ':');
    title(h.axes(1), 'Standardized residuals'); xlabel(h.axes(1), 't');
    ylabel(h.axes(1), 'z'); grid(h.axes(1), 'on');

    h.axes(2) = subplot(2,2,2, 'Parent', h.figure);
    stem(h.axes(2), out.lags, out.acf, 'filled', 'MarkerSize', 3); hold(h.axes(2), 'on');
    yline(h.axes(2), [out.acfConf -out.acfConf], '--r');
    title(h.axes(2), 'Residual ACF'); xlabel(h.axes(2), 'lag');
    ylabel(h.axes(2), '\rho'); grid(h.axes(2), 'on');
    ylim(h.axes(2), [-1 1]*max(0.2, 1.1*max(abs(out.acf))));

    h.axes(3) = subplot(2,2,3, 'Parent', h.figure);
    theo = out.qqTheoretical; zs = out.qqSample;
    plot(h.axes(3), theo, zs, 'k.', 'MarkerSize', 4); hold(h.axes(3), 'on');
    lim = [min(theo(1), zs(1)), max(theo(end), zs(end))];
    plot(h.axes(3), lim, lim, 'r-');
    title(h.axes(3), sprintf('Normal Q-Q  (JB p=%.3f)', out.jbP));
    xlabel(h.axes(3), 'theoretical quantile'); ylabel(h.axes(3), 'sample quantile');
    grid(h.axes(3), 'on');

    h.axes(4) = subplot(2,2,4, 'Parent', h.figure);
    stem(h.axes(4), out.lags, out.lbP, 'filled', 'MarkerSize', 3); hold(h.axes(4), 'on');
    yline(h.axes(4), 0.05, '--r', '5%');
    title(h.axes(4), 'Ljung-Box p-values'); xlabel(h.axes(4), 'lag');
    ylabel(h.axes(4), 'p'); grid(h.axes(4), 'on');
    ylim(h.axes(4), [0 1]);
end
