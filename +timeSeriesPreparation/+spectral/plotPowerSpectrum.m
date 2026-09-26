function h = plotPowerSpectrum(spec, options)
%PLOTPOWERSPECTRUM  Draw spectra from powerSpectrum: lines, peaks, FAP levels, confidence bars.
%
%   SYNTAX
%     h = timeSeriesPreparation.spectral.plotPowerSpectrum(spec)
%     h = timeSeriesPreparation.spectral.plotPowerSpectrum(spec, Confidence = 0.95, Unit = "nT")
%
%   DESCRIPTION
%     The drawing half of sigtools' plotPowerSpectrum, split at X-02 (owner
%     decision 2026-09-23): it computes nothing but the placement of the
%     display elements. It takes the struct array from powerSpectrum and
%     draws each series in the quantity that series was computed for
%     (spec.type), on log-log axes by default. It also draws the peaks
%     returned by powerSpectrum (triangles), and each Lomb-Scargle series'
%     false-alarm levels as dashed lines labelled with their confidence.
%     Confidence adds a chi-square confidence bar for each FFT/Welch series
%     (dof = spec.dof). ShowSpectralWindow adds a lower panel with the
%     spectral window |W(f)|^2 of each Lomb-Scargle series, to judge alias
%     peaks.
%
%   INPUTS
%     spec  (1,S) struct   -   From powerSpectrum; all series of one type.
%
%   OPTIONS
%     Confidence          (1,1) double   []       Confidence level in (0,1)
%                                                 of the chi-square bar.
%     XScale              (1,1) string   ["log"]  "log" or "linear".
%     YScale              (1,1) string   ["log"]  "log" or "linear".
%     Unit                (1,1) string   [""]     Unit of the data, for the
%                                                 axis label.
%     Title               (1,1) string   [""]     Plot title.
%     Axes                (1,1) handle   []       Target axes; [] = a new
%                                                 figure.
%     ShowSpectralWindow  (1,1) logical  [false]  Lower panel with |W(f)|^2
%                                                 (new figure only).
%
%   OUTPUTS
%     h  (1,1) struct   -   Graphics handles: figure, axes, windowAxes,
%                           lines (S,1), peakMarkers, ciBars, fapLines,
%                           legend.
%
%   ACCURACY
%     Not applicable, because the function draws and computes no result.
%     The confidence bar's factors solve gammainc(x/2, dof/2) = p with
%     fzero, as in sigtools v1.3.1.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:plotPowerSpectrum:badSpec - spec is empty,
%           lacks a field of powerSpectrum's output, or mixes "psd" and
%           "amplitude" series.
%     Options:
%       timeSeriesPreparation:plotPowerSpectrum:badOption - XScale or
%           YScale is neither "log" nor "linear" (case-insensitive).
%       Other options outside their domain are refused by the arguments
%       block with a MATLAB: identifier.
%
%   EXAMPLE
%     % Two series, one figure; the peaks come from powerSpectrum.
%     t = (0:1/100:20)';
%     spec = [timeSeriesPreparation.spectral.powerSpectrum(t, sin(2*pi*3*t), Label = "A", Type = "amplitude", NPeaks = 1), timeSeriesPreparation.spectral.powerSpectrum(t, 0.5*sin(2*pi*7*t), Label = "B", Type = "amplitude")];
%     h = timeSeriesPreparation.spectral.plotPowerSpectrum(spec, Unit = "nT");
%     close(h.figure);
%
%   LIMITATIONS
%     One figure per call. The spectral-window panel needs a new figure, so
%     it is ignored when Axes is given.
%
%   REFERENCES
%     sigtools v1.3.1 plotPowerSpectrum (docs/inputs); the numbers are
%     powerSpectrum's.
%
%   See also timeSeriesPreparation.spectral.powerSpectrum, timeSeriesPreparation.spectral.plotAllanVariance.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        spec (1,:) struct
        options.Confidence {mustBeScalarOrEmpty, mustBeNumeric, mustBeGreaterThan(options.Confidence, 0), mustBeLessThan(options.Confidence, 1)} = []
        options.XScale (1,1) string {mustBeScale(options.XScale)} = "log"
        options.YScale (1,1) string {mustBeScale(options.YScale)} = "log"
        options.Unit (1,1) string = ""
        options.Title (1,1) string = ""
        options.Axes = []
        options.ShowSpectralWindow (1,1) logical = false
    end

    need = ["label" "type" "frequency" "power" "amplitude" "method" "dof" ...
        "fapLevels" "spectralWindow" "peakFrequency" "peakValue"];
    if isempty(spec) || ~all(isfield(spec, need)) || numel(unique(string({spec.type}))) > 1
        error("timeSeriesPreparation:plotPowerSpectrum:badSpec", ...
            "spec must be a non-empty struct array from powerSpectrum, " + ...
            "all of one type (""psd"" or ""amplitude"").");
    end
    opts = options;
    opts.Unit = char(opts.Unit); opts.Title = char(opts.Title);
    nSer = numel(spec);
    isPsd = strcmpi(spec(1).type, 'psd');
    anyLS = any(strcmp({spec.method},'lomb-scargle'));

    % ------------------------------------------------------------------ axes
    h = struct('figure',[],'axes',[],'windowAxes',gobjects(0), ...
               'lines',gobjects(nSer,1),'peakMarkers',gobjects(0), ...
               'ciBars',gobjects(0),'fapLines',gobjects(0),'legend',gobjects(0));
    showWin = opts.ShowSpectralWindow && anyLS && isempty(opts.Axes);
    if isempty(opts.Axes)
        h.figure = figure('Color','w','Units','centimeters', ...
            'Position',[2 2 16 10 + 3*showWin],'PaperPositionMode','auto');
        if showWin
            h.axes      = axes('Parent',h.figure,'Position',[0.12 0.34 0.84 0.60]);
            h.windowAxes= axes('Parent',h.figure,'Position',[0.12 0.10 0.84 0.17]);
        else
            h.axes = axes('Parent',h.figure);
        end
    else
        h.axes = opts.Axes; h.figure = ancestor(h.axes,'figure');
        set(h.figure,'Color','w'); showWin = false;
    end
    ax = h.axes;  hold(ax,'on');

    cols = lines(max(nSer,7));
    pick = @(s) ternary(isPsd, spec(s).power, spec(s).amplitude);

    % ------------------------------------------------------------------ lines
    for s = 1:nSer
        h.lines(s) = plot(ax, spec(s).frequency, pick(s), '-', ...
            'Color', cols(s,:), 'LineWidth', 1.2, 'DisplayName', spec(s).label);
    end

    % ------------------------------------------------- FAP significance levels
    for s = 1:nSer
        lv = spec(s).fapLevels;                 % struct: .fap .psd .amp
        if isempty(lv), continue; end
        y  = ternary(isPsd, lv.psd, lv.amp);
        fr = spec(s).frequency([1 end]);
        for k = 1:numel(y)
            hf = plot(ax, fr, [y(k) y(k)], '--', 'Color', cols(s,:), ...
                'LineWidth', 0.8, 'HandleVisibility','off');
            h.fapLines(end+1) = hf;
            text(ax, fr(end), y(k), sprintf(' %g%%', 100*(1-lv.fap(k))), ...
                'Color', cols(s,:), 'FontSize', 8, ...
                'VerticalAlignment','middle','Clipping','off');
        end
    end

    % ------------------------------------------------------------------ peaks
    for s = 1:nSer
        if isempty(spec(s).peakFrequency), continue; end
        hp = plot(ax, spec(s).peakFrequency, spec(s).peakValue, 'v', 'MarkerSize', 6, ...
            'MarkerEdgeColor', cols(s,:)*0.6, 'MarkerFaceColor', cols(s,:), ...
            'HandleVisibility','off');
        h.peakMarkers(end+1) = hp;
    end

    % ------------------------------------------------------ styling main axes
    set(ax, 'XScale', opts.XScale, 'YScale', opts.YScale, ...
        'FontName','Helvetica','FontSize',11,'LineWidth',0.9, ...
        'TickDir','out','TickLength',[0.012 0.012],'Box','on','Layer','top', ...
        'XMinorTick','on','YMinorTick','on');
    grid(ax,'on'); set(ax,'GridAlpha',0.12,'MinorGridAlpha',0.05);
    u = strtrim(opts.Unit);
    if isPsd
        yl = sprintf('Power spectral density (%s^2 Hz^{-1})', ternaryStr(u,'unit'));
    else
        yl = sprintf('Amplitude (%s)', ternaryStr(u,'unit'));
    end
    ylabel(ax, yl, 'FontSize', 12);
    if ~isempty(opts.Title), title(ax, opts.Title, 'FontWeight','normal'); end
    h.legend = legend(ax, h.lines, 'Location','best'); set(h.legend,'Box','off');

    % -------------------------------------------- chi-square confidence bars
    if ~isempty(opts.Confidence)
        drawnow;                                    % settle axis limits
        xl = get(ax,'XLim'); yliml = get(ax,'YLim');
        nb = 0;
        for s = 1:nSer
            if ~strcmp(spec(s).method,'fft'), continue; end
            c   = opts.Confidence;  k = spec(s).dof;
            lo  = k / chi2invBase(1-(1-c)/2, k);    % multiplicative CI factors
            hi  = k / chi2invBase((1-c)/2,   k);
            if ~isPsd, lo = sqrt(lo); hi = sqrt(hi); end
            if strcmpi(opts.XScale,'log')
                xpos = 10^(log10(xl(1)) + (0.06 + 0.05*nb)*diff(log10(xl)));
            else
                xpos = xl(1) + (0.06 + 0.05*nb)*diff(xl);
            end
            if strcmpi(opts.YScale,'log')
                yref = 10^(log10(yliml(1)) + 0.85*diff(log10(yliml)));
            else
                yref = yliml(1) + 0.85*diff(yliml);
            end
            hb = plot(ax, [xpos xpos], yref*[lo hi], '-', 'Color', cols(s,:), ...
                'LineWidth', 1.4, 'HandleVisibility','off');
            plot(ax, xpos, yref, 'o', 'MarkerSize',3, 'MarkerFaceColor',cols(s,:), ...
                'MarkerEdgeColor','none','HandleVisibility','off');
            if nb == 0
                text(ax, xpos, yref*hi, sprintf('  %g%%',100*c), ...
                    'FontSize',8,'Color',[0.25 0.25 0.25], ...
                    'VerticalAlignment','bottom');
            end
            h.ciBars(end+1) = hb; nb = nb + 1;
        end
    end

    % --------------------------------------------------- spectral-window panel
    if showWin
        axw = h.windowAxes; hold(axw,'on');
        for s = 1:nSer
            if isempty(spec(s).spectralWindow), continue; end
            plot(axw, spec(s).frequency, spec(s).spectralWindow, '-', ...
                'Color', cols(s,:), 'LineWidth', 0.9);
        end
        set(axw,'XScale',opts.XScale,'YScale','log', ...
            'FontName','Helvetica','FontSize',10,'LineWidth',0.9, ...
            'TickDir','out','Box','on','XMinorTick','on');
        grid(axw,'on'); set(axw,'GridAlpha',0.12);
        ylabel(axw,'|W(f)|^2','FontSize',11);
        xlabel(axw,'Frequency (Hz)','FontSize',12);
        linkaxes([ax axw],'x'); set(ax,'XTickLabel',[]);
        hold(axw,'off');
    else
        xlabel(ax,'Frequency (Hz)','FontSize',12);
    end
    hold(ax,'off');
end

% ========================================================================
function x = chi2invBase(p, k)
% Inverse chi-square CDF in base MATLAB: solve gammainc(x/2, k/2) = p.
fun = @(x) gammainc(max(x,0)/2, k/2) - p;
hiB = k + 20*sqrt(2*k) + 100;                 % safe upper bracket
x = fzero(fun, [1e-12, hiB]);
end

% ========================================================================
function y = ternary(cond, a, b)
if cond, y = a; else, y = b; end
end

function s = ternaryStr(s, alt)
if isempty(s), s = alt; end
end

function mustBeScale(v)
% "log" or "linear", case-insensitive as in v1.3.1.
    if ~any(strcmpi(v, ["log" "linear"]))
        error("timeSeriesPreparation:plotPowerSpectrum:badOption", ...
            "Scale must be ""log"" or ""linear"".");
    end
end
