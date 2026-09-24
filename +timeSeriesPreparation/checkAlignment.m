function report = checkAlignment(obs, ref, options)
%CHECKALIGNMENT  Report a time lag between observation and reference; never shift.
%
%   SYNTAX
%     report = timeSeriesPreparation.checkAlignment(obs, ref)
%     report = timeSeriesPreparation.checkAlignment(obs, ref, MaxLag = 60, Threshold = 1)
%
%   DESCRIPTION
%     A diagnostic for timing between two series (CONCEPT 6.1, row 3; v3
%     F2). v2 searched the lag over a full revolution and silently shifted
%     the model by it. Near-periodic 1/rev signals can lock that search
%     onto the wrong lobe, and a real physical lag (the thermosphere
%     responding late to its driver) was absorbed instead of reported.
%     Here the search is bounded to +/- MaxLag (60 s, far below one
%     revolution), and the result is a report only. No series is shifted;
%     correcting a timing error is the caller's explicit decision, for
%     example by fixing the time system.
%
%     Both series are resampled onto one uniform grid of spacing Step,
%     anchored at the first observation epoch over the common span. The
%     rule is the one align uses: no interpolation across a hole. Each
%     column is AC-coupled (its mean over the common valid rows removed).
%     For every lag L = -K..K (K = MaxLag/Step) the normalised
%     cross-correlation is taken over the valid pairs:
%
%       r(L) = sum a_i b_(i-L) / sqrt(sum a_i^2 * sum b_(i-L)^2)
%
%     A parabola through the peak and its two neighbours refines the lag
%     below the grid step. A positive lag means that the observation lags
%     the reference: obs(t) matches ref(t - lag).
%
%     Verdict per column:
%       "aligned"       |lag| <= Threshold (1 s).
%       "offset"        Threshold < |lag| <= MaxLag/2; warns.
%       "gross"         |lag| > MaxLag/2, or the peak lies on the edge of
%                       the search; warns. Fix the time systems.
%       "undetermined"  no positive peak, or fewer valid pairs than lags
%                       searched (e.g. no common span); warns.
%
%   INPUTS
%     obs  (1,1) Arc   -   Observation.
%     ref  (1,1) Arc   -   Reference with as many columns as obs, in the
%                          same order.
%
%   OPTIONS
%     MaxLag     (1,1) double   [60]       Search bound in s, a whole
%                                          multiple of Step.
%     Threshold  (1,1) double   [1]        Largest lag in s reported as
%                                          aligned.
%     Step       (1,1) double   [1]        Grid spacing in s, a whole
%                                          number of nanoseconds.
%     Method     (1,1) string   ["pchip"]  Interpolation onto the grid.
%     MaxGap     (1,1) double   [auto]     Widest spacing in s interpolated
%                                          across, both series; [] (auto) =
%                                          1.5 x each series' median step.
%
%   OUTPUTS
%     report  (1,1) struct   -   Fields:
%                                  lag (1,M) double s: refined lag per
%                                      column, NaN if undetermined;
%                                  peak (1,M) double: r at the grid peak;
%                                  verdict (1,M) string;
%                                  names (1,M) string: obs column names;
%                                  lags (2K+1,1) double s: the lags
%                                      searched;
%                                  corr (2K+1,M) double: r(L);
%                                  pairs (2K+1,1) double: valid pairs per
%                                      lag;
%                                  maxLag, threshold, step (1,1) double s.
%
%   ACCURACY
%     On one day at 1 s with a 1/rev signal plus 40 broadband tones, a
%     NumPy transcription of this estimator recovers an injected lag of
%     7.0 s to 4e-6 s and one of 7.3 s to 1e-3 s. The parabola's bias grows
%     towards half a step (measured 2026-09-23). TestCheckAlignment holds
%     the 7.0 s case to 0.05 s and the 7.3 s case to 0.01 s. Each
%     correlation is a sum over one lag's valid pairs, and each column is
%     summed on its own, so a batched call equals the per-column calls bit
%     for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:checkAlignment:columnMismatch - obs and ref
%           have different numbers of columns.
%       timeSeriesPreparation:checkAlignment:badGrid - Step is not a whole
%           number of nanoseconds, or MaxLag is not a whole multiple of
%           Step.
%       Options outside their domain are refused by the arguments block
%       with a MATLAB: identifier.
%
%   WARNINGS
%     Verdict:
%       timeSeriesPreparation:checkAlignment:offset - a column lags by more
%           than Threshold.
%       timeSeriesPreparation:checkAlignment:grossOffset - a column lags by
%           more than MaxLag/2, or its peak lies on the search edge.
%       timeSeriesPreparation:checkAlignment:undetermined - a column has no
%           positive peak or too few valid pairs.
%
%   EXAMPLE
%     % Two identical 1 Hz series: lag 0, verdict "aligned", no warning.
%     aux = @(p) struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", p + "_2020-01-01_C_04.txt", "product", p);
%     t = int64(0:3599)' * int64(1e9);
%     x = sin(double(t) * 1e-9 / 30) + cos(double(t) * 1e-9 / 7);
%     report = timeSeriesPreparation.checkAlignment(timeSeriesPreparation.Arc(t, x, aux("ACT1B")), timeSeriesPreparation.Arc(t, x, aux("MOD1B")));
%
%   LIMITATIONS
%     A lag beyond MaxLag cannot be measured. With a smooth signal the peak
%     then sits on the search edge ("gross"). With broadband content a side
%     lobe inside the window can be reported instead: a 90 s lag of the
%     1/rev plus 40-tone test signal shows as 7.27 s with peak 0.50, where
%     a true lag peaks at 0.9999 (NumPy, 2026-09-23). A low peak is the
%     sign. One constant lag per column over the whole arc; a drifting clock
%     shows as a broadened peak, not as a drift. Columns pair by position.
%     Units are not compared, because the correlation is scale-free; align
%     compares them.
%
%   REFERENCES
%     docs/CONCEPT.md section 6.1 (row 3); v3 F2 and WP-02 item 3
%     (docs/inputs/HANDOVER_AccelCal_v3.md); v2 crossCorrLag.
%
%   See also timeSeriesPreparation.align, timeSeriesPreparation.internal.resampleOnto.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 10:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        obs (1,1) timeSeriesPreparation.Arc
        ref (1,1) timeSeriesPreparation.Arc
        options.MaxLag (1,1) double {mustBePositive, mustBeFinite} = 60
        options.Threshold (1,1) double {mustBeNonnegative, mustBeFinite} = 1
        options.Step (1,1) double {mustBePositive, mustBeFinite} = 1
        options.Method (1,1) string {mustBeMember(options.Method, ...
            ["pchip" "makima" "spline" "linear"])} = "pchip"
        options.MaxGap double {mustBeScalarOrEmpty, mustBePositive} = []
    end

    M = numel(obs.names);
    if numel(ref.names) ~= M
        error("timeSeriesPreparation:checkAlignment:columnMismatch", ...
            "obs has %d columns and ref %d; they pair by position.", ...
            M, numel(ref.names));
    end
    stepNs = options.Step * 1e9;
    K = options.MaxLag / options.Step;
    if stepNs ~= round(stepNs) || K ~= round(K)
        error("timeSeriesPreparation:checkAlignment:badGrid", ...
            "Step (%.17g s) must be a whole number of ns and MaxLag " + ...
            "(%.17g s) a whole multiple of it.", options.Step, options.MaxLag);
    end
    stepNs = int64(stepNs);

    % The common grid, anchored at the first observation epoch.
    tg = int64.empty(0, 1);
    if ~isempty(obs.t) && ~isempty(ref.t)
        t1 = max(obs.t(1), ref.t(1));
        t2 = min(obs.t(end), ref.t(end));
        if t2 >= t1
            k1 = idivide(t1 - obs.t(1), stepNs, "ceil");
            k2 = idivide(t2 - obs.t(1), stepNs, "floor");
            tg = obs.t(1) + (k1:k2)' * stepNs;
        end
    end
    a = onGrid(obs, tg, options);
    b = onGrid(ref, tg, options);
    va = ~any(isnan(a), 2);
    vb = ~any(isnan(b), 2);
    both = va & vb;
    a(~va, :) = 0;
    b(~vb, :) = 0;
    for j = 1:M                                   % column by column: bitwise
        a(va, j) = a(va, j) - mean(a(both, j));   % equal to single-column calls
        b(vb, j) = b(vb, j) - mean(b(both, j));
    end

    n = numel(tg);
    lags = (-K:K)';
    r = NaN(2 * K + 1, M);
    pairs = zeros(2 * K + 1, 1);
    for i = 1:2 * K + 1
        L = lags(i);
        ia = max(1, 1 + L):min(n, n + L);        % a_i pairs with b_(i-L)
        m = va(ia) & vb(ia - L);
        pairs(i) = nnz(m);
        for j = 1:M
            x = a(ia, j) .* m;
            y = b(ia - L, j) .* m;
            r(i, j) = sum(x .* y) / sqrt(sum(x .^ 2) * sum(y .^ 2));
        end
    end

    lag = NaN(1, M);
    peak = NaN(1, M);
    verdict = repmat("undetermined", 1, M);
    for j = 1:M
        [p, i] = max(r(:, j));
        if isnan(p) || p <= 0 || pairs(i) < 2 * K + 1
            continue
        end
        peak(j) = p;
        if i == 1 || i == 2 * K + 1
            lag(j) = lags(i) * options.Step;
            verdict(j) = "gross";
            continue
        end
        den = r(i - 1, j) - 2 * p + r(i + 1, j);
        delta = 0;
        if den < 0
            delta = 0.5 * (r(i - 1, j) - r(i + 1, j)) / den;
        end
        lag(j) = (lags(i) + delta) * options.Step;
        if abs(lag(j)) <= options.Threshold
            verdict(j) = "aligned";
        elseif abs(lag(j)) <= options.MaxLag / 2
            verdict(j) = "offset";
        else
            verdict(j) = "gross";
        end
    end

    report = struct("lag", lag, "peak", peak, "verdict", verdict, ...
        "names", obs.names, "lags", lags * options.Step, "corr", r, ...
        "pairs", pairs, "maxLag", options.MaxLag, ...
        "threshold", options.Threshold, "step", options.Step);
    warnFor(report, "offset", "timeSeriesPreparation:checkAlignment:offset", ...
        "lag above the %g s threshold; nothing was shifted");
    warnFor(report, "gross", "timeSeriesPreparation:checkAlignment:grossOffset", ...
        "lag above %g s or at the search edge; check the time systems, nothing was shifted");
    warnFor(report, "undetermined", "timeSeriesPreparation:checkAlignment:undetermined", ...
        "no lag could be determined (no positive peak or too few pairs; threshold %g s)");
end

% ------------------------------------------------------------------------

function y = onGrid(arc, tg, options)
% The arc's usable rows resampled onto the grid, NaN where not covered.
    valid = all(isfinite(arc.obs), 2) & arc.weights > 0;
    y = timeSeriesPreparation.internal.resampleOnto(arc.t, arc.obs, valid, ...
        tg, options.Method, options.MaxGap);
end

function warnFor(report, which, id, what)
% One warning naming every column with this verdict.
    hit = report.verdict == which;
    if ~any(hit)
        return
    end
    bound = report.threshold;
    if which == "gross"
        bound = report.maxLag / 2;
    end
    % compose, not string(): string(NaN) is <missing>, which warning refuses.
    lags = compose("%.4g", reshape(report.lag(hit), [], 1))';   % one per row
    list = strjoin(report.names(hit) + " (" + lags + " s)", ", ");
    warning(id, "checkAlignment: %s: " + what + ".", list, bound);
end
