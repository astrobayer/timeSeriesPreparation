function h = plotPsd2armaFit(results)
%PLOTPSD2ARMAFIT  Draw a psd2arma fit: target and fitted PSD, and the fit error in dB.
%
%   SYNTAX
%     h = timeSeriesPreparation.spectral.plotPsd2armaFit(results)
%
%   DESCRIPTION
%     The drawing half of sigtools' psd2arma (its former Display option),
%     split at X-02 (owner decision 2026-09-23). It draws two panels in one
%     figure:
%       - top: the target PSD and the fitted PSD on log-log axes, titled
%         with the orders and the RMS and maximum errors;
%       - bottom: the error 10 log10(PSDfit/PSDtarget) in dB over
%         frequency.
%     The zero-frequency bin is left out of the log-log panel.
%
%   INPUTS
%     results  (1,1) struct   -   Third output of psd2arma.
%
%   OUTPUTS
%     h  (1,1) struct   -   Graphics handles: figure, psdAxes, errorAxes.
%
%   ACCURACY
%     Not applicable, because the function draws. The error panel divides
%     the stored PSDfit by PSDtarget; psd2arma floors both at 1e-12 of the
%     target's peak before its own RMSErrorDb, which the title quotes, so
%     the panel can differ from it only where the fit falls below that
%     floor.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:plotPsd2armaFit:badResults - results lacks a
%           field of psd2arma's output.
%
%   EXAMPLE
%     % The psd2arma example, drawn.
%     f = logspace(-2, 2, 500)';
%     [~, ~, res] = timeSeriesPreparation.spectral.psd2arma(f, 1 ./ (1 + (f/5).^2).^2, 500, Order = [8 8]);
%     h = timeSeriesPreparation.spectral.plotPsd2armaFit(res);
%     close(h.figure);
%
%   LIMITATIONS
%     Always a new figure.
%
%   REFERENCES
%     sigtools v1.3.1 psd2arma (docs/inputs), its Display branch.
%
%   See also timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.plotPowerSpectrum.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        results (1,1) struct
    end

    need = ["b" "a" "fGrid" "PSDtarget" "PSDfit" "RMSErrorDb" "MaxErrorDb"];
    if ~all(isfield(results, need))
        error("timeSeriesPreparation:plotPsd2armaFit:badResults", ...
            "results must be the third output of psd2arma (fields %s).", ...
            strjoin(need, ", "));
    end
    fgrid = results.fGrid;
    Sgrid = results.PSDtarget;
    psdFit = results.PSDfit;
    errDb = 10*log10(max(psdFit, realmin) ./ Sgrid);

    h.figure = figure('Name', 'psd2arma: fit diagnostics');
    h.psdAxes = subplot(2,1,1, 'Parent', h.figure);
    loglog(h.psdAxes, fgrid(2:end), Sgrid(2:end), 'k-', 'LineWidth', 1.5);
    hold(h.psdAxes, 'on');
    loglog(h.psdAxes, fgrid(2:end), psdFit(2:end), 'r--', 'LineWidth', 1.2);
    grid(h.psdAxes, 'on'); xlabel(h.psdAxes, 'Frequency [Hz]'); ylabel(h.psdAxes, 'PSD');
    legend(h.psdAxes, 'Target', 'ARMA fit', 'Location', 'best');
    title(h.psdAxes, sprintf('PSD fit  (na=%d, nb=%d, RMS err = %.2f dB, max err = %.2f dB)', ...
        numel(results.a)-1, numel(results.b)-1, results.RMSErrorDb, results.MaxErrorDb));
    hold(h.psdAxes, 'off');

    h.errorAxes = subplot(2,1,2, 'Parent', h.figure);
    semilogx(h.errorAxes, fgrid, errDb, 'b-');
    grid(h.errorAxes, 'on'); xlabel(h.errorAxes, 'Frequency [Hz]'); ylabel(h.errorAxes, 'Error [dB]');
    title(h.errorAxes, 'Fit error (fit - target)');
end
