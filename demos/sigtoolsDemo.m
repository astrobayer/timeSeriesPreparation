function sigtoolsDemo(which)
%SIGTOOLSDEMO  Launcher / index for the sigtools example scripts.
%
%   SIGTOOLSDEMO           lists the available demos with a one-line summary.
%   SIGTOOLSDEMO(N)        runs demo number N from that list.
%   SIGTOOLSDEMO('name')   runs the demo whose script name contains 'name'
%                          (case-insensitive, partial match allowed).
%
%   The demos are plain scripts under sigtools/demos; this launcher just
%   provides a single discoverable entry point. Run setupTimeSeriesPreparation first so
%   the demos are on the path.
%
%   INPUTS
%     which   1x1 double | char/string [mixed]
%       (optional) Demo selector: an index into the list, or a (partial)
%       script name. Omit to print the menu.
%
%   OUTPUTS
%     (none)  Prints the menu, or runs the selected demo script.
%
%   See also: setupTimeSeriesPreparation, Contents.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    demos = {
        'demo_plotPowerSpectrum',          'Five spectral-estimation scenarios (Welch / Lomb-Scargle).'
        'allanVariance_demo',              'Allan deviation of four canonical noise types.'
        'gap_filling_spectral_comparison', 'Gap-handling strategies and their effect on the spectrum.'
        'demo_tsmodels',                   'End-to-end ARIMA identification, fitting, forecasting.'
        'demo_sigtools_new',               'Spectral<->TS loop, SARIMA, residual diagnostics.'
        'demo_sigtools_v13',               'Newest: arma2acv, exact-ML/gap SARIMA, seasonal & bootstrap forecasts.'
    };

    if nargin < 1 || isempty(which)
        fprintf('\n  sigtools demos\n  --------------\n');
        for i = 1:size(demos,1)
            avail = exist(demos{i,1}, 'file') == 2;
            mark  = ''; if ~avail, mark = '   (not on path -- run setupTimeSeriesPreparation)'; end
            fprintf('  %d. %-32s %s%s\n', i, demos{i,1}, demos{i,2}, mark);
        end
        fprintf('\n  Run one with:  sigtoolsDemo(N)  or  sigtoolsDemo(''name'')\n\n');
        return;
    end

    % ---- resolve selection ----
    if isnumeric(which)
        idx = round(which);
        if idx < 1 || idx > size(demos,1)
            error('sigtoolsDemo:index', 'Demo index must be 1..%d.', size(demos,1));
        end
    else
        name = lower(char(which));
        hit  = find(contains(lower(demos(:,1)), name), 1);
        if isempty(hit)
            error('sigtoolsDemo:notFound', 'No demo matching "%s".', name);
        end
        idx = hit;
    end

    script = demos{idx,1};
    if exist(script, 'file') ~= 2
        error('sigtoolsDemo:notOnPath', ...
            'Demo "%s" is not on the path. Run setupTimeSeriesPreparation first.', script);
    end
    fprintf('Running %s ...\n', script);
    evalin('base', script);
end
