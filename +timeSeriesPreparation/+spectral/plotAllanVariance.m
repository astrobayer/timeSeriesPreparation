function h = plotAllanVariance(tau, adev, info, options)
%PLOTALLANVARIANCE  Draw Allan deviation on log-log axes with its shaded confidence band.
%
%   SYNTAX
%     h = timeSeriesPreparation.spectral.plotAllanVariance(tau, adev, info)
%     h = timeSeriesPreparation.spectral.plotAllanVariance(tau, adev, info, CiLevel = 0.95)
%
%   DESCRIPTION
%     The drawing half of sigtools' allanVariance (its former doPlot), split
%     at X-02 (owner decision 2026-09-23). Each column of adev is one line
%     over tau, in log-log axes, with the band between info.adevLow and
%     info.adevHigh shaded. The figure is the one v1.3.1 drew. CiLevel only
%     labels the title and must be the level the bounds were computed with.
%
%   INPUTS
%     tau   (K,1) double   s      From allanVariance.
%     adev  (K,P) double   unit   From allanVariance.
%     info  (1,1) struct   -      From allanVariance; adevLow and adevHigh
%                                 are used.
%
%   OPTIONS
%     CiLevel  (1,1) double   [0.6827]  Confidence level of the bounds, for
%                                       the title.
%     Axes     (1,1) handle   []        Target axes; [] = a new figure.
%
%   OUTPUTS
%     h  (1,1) struct   -   Graphics handles: figure, axes, lines (P,1),
%                           bands (P,1).
%
%   ACCURACY
%     Not applicable, because the function draws and computes nothing.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:plotAllanVariance:sizeMismatch - adev,
%           info.adevLow or info.adevHigh is not numel(tau) x P.
%       Inputs outside their domain are refused by the arguments block with
%       a MATLAB: identifier.
%
%   EXAMPLE
%     % White noise, the default 1-sigma band.
%     x = randn(RandStream("twister", "Seed", 1), 10000, 1);
%     [tau, ~, adev, info] = timeSeriesPreparation.spectral.allanVariance(x, 10);
%     h = timeSeriesPreparation.spectral.plotAllanVariance(tau, adev, info);
%     close(h.figure);
%
%   LIMITATIONS
%     Draws what it is given; it cannot check that CiLevel matches the
%     bounds.
%
%   REFERENCES
%     sigtools v1.3.1 allanVariance (docs/inputs), its doPlot branch.
%
%   See also timeSeriesPreparation.spectral.allanVariance, timeSeriesPreparation.spectral.plotPowerSpectrum.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        tau (:,1) double
        adev double
        info (1,1) struct
        options.CiLevel (1,1) double {mustBeGreaterThan(options.CiLevel, 0), mustBeLessThan(options.CiLevel, 1)} = 0.6827
        options.Axes = []
    end

    K = numel(tau);
    P = size(adev, 2);
    if size(adev, 1) ~= K || ~isfield(info, "adevLow") || ~isfield(info, "adevHigh") ...
            || ~isequal(size(info.adevLow), [K P]) || ~isequal(size(info.adevHigh), [K P])
        error("timeSeriesPreparation:plotAllanVariance:sizeMismatch", ...
            "adev, info.adevLow and info.adevHigh must be %d x P (numel(tau) rows).", K);
    end

    if isempty(options.Axes)
        h.figure = figure;
        h.axes = axes("Parent", h.figure);
    else
        h.axes = options.Axes;
        h.figure = ancestor(h.axes, "figure");
    end
    ax = h.axes;
    hold(ax, "on"); grid(ax, "on");
    colors = lines(P);
    h.lines = gobjects(P, 1);
    h.bands = gobjects(P, 1);
    for p = 1:P
        fillX = [tau; flipud(tau)];
        fillY = [info.adevLow(:, p); flipud(info.adevHigh(:, p))];
        h.bands(p) = fill(ax, fillX, fillY, colors(p, :), 'FaceAlpha', 0.15, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
        h.lines(p) = loglog(ax, tau, adev(:, p), 'LineWidth', 1.5, 'Color', colors(p, :));
    end
    set(ax, 'XScale', 'log', 'YScale', 'log');
    xlabel(ax, '\tau [s]');
    ylabel(ax, '\sigma_y(\tau)');
    title(ax, sprintf('Allan Deviation (%.0f%% CI shaded)', 100*options.CiLevel));
    if P > 1
        legend(ax, arrayfun(@(p) sprintf('col %d', p), 1:P, 'UniformOutput', false), ...
               'Location', 'best');
    end
    hold(ax, "off");
end
