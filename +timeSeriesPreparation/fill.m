function [arc, info] = fill(arc, options)
%FILL  Report the gaps of an arc, or fill the short ones by covariance collocation.
%
%   SYNTAX
%     [arc, info] = timeSeriesPreparation.fill(arc)
%     [arc, info] = timeSeriesPreparation.fill(arc, Method = "collocation", Model = nm, MaxGap = 10, Window = [])
%
%   DESCRIPTION
%     The gap stage (CONCEPT 6.1 row 8, 6.5). A sample is missing on an axis
%     when it is NaN, has weight 0 or was filled before; each axis has its
%     own gaps, a gap being a run of missing samples on the uniform grid.
%       - Method "none" (the default, Q3): nothing changes; info.gaps
%         reports every gap. Splitting the arc there is the caller's.
%       - Method "collocation": each interior gap of at most MaxGap
%         seconds is replaced by the optimal (least-squares) prediction
%         under the covariance model,
%             x_g = mu + C_go C_oo^-1 (x_o - mu),
%         with the prediction variance diag(C_gg - C_go C_oo^-1 C_og). The
%         conditioning samples x_o are the observed samples within W
%         samples either side of the gap. The covariances are the Toeplitz
%         entries Model.acv(|i - j| + 1), never extrapolated: W is at most
%         floor((L - k + 1) / 2) for a gap of k samples and a model to lag
%         L, so that every pair in the window has a lag <= L and the matrix
%         used is the model's own. Window lowers W further. For an AR(p)
%         model with W >= p the result equals the prediction from the whole
%         record (the AR precision matrix is banded); for ARMA it converges
%         as W grows (ACCURACY).
%       - Method "reference" (a calibrated reference plus the collocated
%         residual, CONCEPT 6.5) is deferred until the drivers exist (X-09)
%         and refuses.
%     Not filled, and reported with the reason: gaps touching the first or
%     last sample ("edge", which would be extrapolation), gaps longer than
%     MaxGap ("tooLong"), and gaps the model is too short to bridge
%     ("beyondModel", W < 1).
%
%     The epochs stay. Filled values enter arc.obs, the row is flagged in
%     arc.filled, and a "fill" entry is appended to the provenance
%     (Arc.fillSamples). Every fit weighs filled rows 0 (CONCEPT 5). With
%     Method "none" the arc is returned unchanged.
%
%     The model is noise's output or, e.g. from lsqvce, any struct with
%     acv (L+1, M) in unit^2 at lags 0..L samples, dt (s) and mu (1, M)
%     (CONCEPT 3.2: fill takes a covariance model; there is no estimator
%     here).
%
%   INPUTS
%     arc  (1,1) Arc   -   Series on a uniform grid; missing samples are
%                          NaN, weight 0 or filled.
%
%   OPTIONS
%     Method  (1,1) string        ["none"]  "none", "collocation" or
%                                           "reference" (deferred).
%     Model   (1,1) struct        []        Covariance model: fields acv
%                                           (L+1, M), dt (s), mu (1, M);
%                                           required by "collocation".
%     MaxGap  (1,1) double    s   []        Longest gap filled; no default,
%                                           required by "collocation".
%     Window  (1,1) double        []        Largest W in samples, integer
%                                           >= 1; [] = the largest the
%                                           model allows.
%
%   OUTPUTS
%     arc   (1,1) Arc      -   The arc, filled where info.gaps.status is
%                              "filled".
%     info  (1,1) struct   -   Fields: method; maxGap; window; gaps, a
%                              struct of (K,1) columns - axis (string),
%                              first, last (sample indices), duration (s,
%                              samples times dt), status ("filled",
%                              "notRequested", "edge", "tooLong",
%                              "beyondModel"), width (W used, NaN where not
%                              filled); sigma (N, M) prediction standard
%                              deviation, NaN where not filled, unit of
%                              obs; nFilled (1, M) samples.
%
%   ACCURACY
%     A linear solve with the Cholesky factor of C_oo, whose condition
%     is that of the model's covariance over 2W + 1 lags. An AR(1) one-sample
%     gap equals phi/(1 + phi^2) (x_(t-1) + x_(t+1)) and an AR(1) bridge of
%     k samples its closed form to rounding (NumPy: 6e-16). An ARMA(1,1)
%     with phi 0.6, theta 0.5 and a 20-sample gap differs from the
%     whole-record prediction by at most 1.4e-3, 1.4e-6, 1.1e-12 and
%     4.7e-15 standard deviations for L = 40, 60, 100 and 140 (NumPy, 200
%     realisations, 2026-09-24): the error decays like max(|phi|,
%     |theta|)^W. The fill is optimal only as far as the model is right.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:fill:irregularGrid - the epochs are not
%           uniformly spaced; resample first (align).
%       timeSeriesPreparation:fill:maxGapMissing - "collocation" without
%           MaxGap (it has no default, Q3).
%       timeSeriesPreparation:fill:modelMissing - "collocation" without
%           Model.
%       timeSeriesPreparation:fill:modelMismatch - Model lacks acv, dt or
%           mu, or its columns or dt differ from the arc's.
%       timeSeriesPreparation:fill:referenceDeferred - Method "reference",
%           which follows the drivers (X-09).
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%     Numerical:
%       timeSeriesPreparation:fill:notPositiveDefinite - C_oo is not
%           positive definite: Model.acv is not an autocovariance.
%
%   EXAMPLE
%     % An AR(1) at 1 Hz with a 5 s gap, modelled and filled.
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     x = filter(1, [1 -0.7], randn(RandStream("twister", "Seed", 5), 1500, 1));
%     x(700:704) = NaN;
%     arc = timeSeriesPreparation.Arc(int64(0:1499)' * int64(1e9), x, aux);
%     nm = timeSeriesPreparation.noise(arc, [1 0], MaxLag = 50);
%     [filledArc, info] = timeSeriesPreparation.fill(arc, Method = "collocation", Model = nm, MaxGap = 10);
%
%   LIMITATIONS
%     arc.filled is one flag per row (CONCEPT 5), so a row filled on one
%     axis is weighed 0 on every axis. Gaps are filled independently: a
%     neighbouring gap's samples are missing in the window, not predicted.
%     The model is taken as stationary over the window. "reference" is not
%     available yet.
%
%   REFERENCES
%     Moritz, H. (1980). Advanced Physical Geodesy. Wichmann, Karlsruhe,
%     part B (least-squares collocation). Brockwell, P. J., Davis, R. A.
%     (1991). Time Series: Theory and Methods, 2nd ed. Springer, sect. 5.1
%     (best linear prediction). docs/CONCEPT.md sections 3.2, 5, 6.5 and
%     V-7 (answered 2026-09-24: the sigtools Kalman filter only predicts).
%
%   See also timeSeriesPreparation.noise, timeSeriesPreparation.spectral.arma2acv, timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-24 08:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        options.Method (1,1) string {mustBeMember(options.Method, ["none" "collocation" "reference"])} = "none"
        options.Model = []
        options.MaxGap double {mustBeScalarOrEmpty, mustBePositive} = []
        options.Window double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
    end

    if options.Method == "reference"
        error("timeSeriesPreparation:fill:referenceDeferred", ...
            "Method ""reference"" follows the drivers (X-09); use ""collocation"" or ""none"".");
    end
    N = numel(arc.t);
    M = size(arc.obs, 2);
    step = diff(arc.t);
    if N < 2 || any(step ~= step(1))
        error("timeSeriesPreparation:fill:irregularGrid", ...
            "fill needs uniformly spaced epochs; resample with align and mark missing rows NaN.");
    end
    dt = double(step(1)) / 1e9;

    missing = isnan(arc.obs) | arc.weights == 0 | arc.filled;
    gaps = findGapRuns(missing, arc.names, dt);
    info = struct("method", options.Method, "maxGap", options.MaxGap, ...
        "window", options.Window, "gaps", gaps, "sigma", NaN(N, M), ...
        "nFilled", zeros(1, M));
    if options.Method == "none"
        return
    end

    if isempty(options.MaxGap)
        error("timeSeriesPreparation:fill:maxGapMissing", ...
            "Method ""collocation"" needs MaxGap in seconds; it has no default (CONCEPT Q3).");
    end
    model = checkModel(options.Model, dt, M);
    L = size(model.acv, 1) - 1;
    maxSamples = floor(options.MaxGap / dt + 1e-9);

    values = arc.obs;
    mask = false(N, M);
    [~, axisIndex] = ismember(gaps.axis, arc.names);
    for g = 1:numel(gaps.first)
        i1 = gaps.first(g);
        i2 = gaps.last(g);
        m = axisIndex(g);
        k = i2 - i1 + 1;
        W = floor((L - k + 1) / 2);
        if ~isempty(options.Window)
            W = min(W, options.Window);
        end
        if i1 == 1 || i2 == N
            gaps.status(g) = "edge";
        elseif k > maxSamples
            gaps.status(g) = "tooLong";
        elseif W < 1
            gaps.status(g) = "beyondModel";
        else
            idx = (max(1, i1 - W):min(N, i2 + W))';
            o = idx(~missing(idx, m));
            gi = (i1:i2)';
            acv = model.acv(:, m);
            Coo = toeplitzAt(acv, o, o);
            Cgo = toeplitzAt(acv, gi, o);
            [R, flag] = chol(Coo);
            if flag ~= 0
                error("timeSeriesPreparation:fill:notPositiveDefinite", ...
                    "The covariance of axis %s is not positive definite over the " + ...
                    "window of the gap at sample %d; Model.acv is not an autocovariance.", ...
                    arc.names(m), i1);
            end
            mu = model.mu(m);
            values(gi, m) = mu + Cgo * (R \ (R' \ (arc.obs(o, m) - mu)));
            V = R' \ Cgo';
            info.sigma(gi, m) = sqrt(max(acv(1) - sum(V.^2, 1)', 0));
            mask(gi, m) = true;
            gaps.status(g) = "filled";
            gaps.width(g) = W;
        end
    end
    info.gaps = gaps;
    info.nFilled = sum(mask, 1);
    arc = fillSamples(arc, values, mask, struct("method", options.Method, ...
        "maxGap", options.MaxGap, "window", options.Window, ...
        "nFilled", info.nFilled));
end

% ------------------------------------------------------------------------

function gaps = findGapRuns(missing, names, dt)
% Runs of missing samples per axis, as a struct of (K,1) columns.
    first = zeros(0, 1);
    last = zeros(0, 1);
    axisName = strings(0, 1);
    for m = 1:size(missing, 2)
        d = diff([false; missing(:, m); false]);
        s = find(d == 1);
        e = find(d == -1) - 1;
        first = [first; s];                         %#ok<AGROW>
        last = [last; e];                           %#ok<AGROW>
        axisName = [axisName; repmat(names(m), numel(s), 1)]; %#ok<AGROW>
    end
    K = numel(first);
    gaps = struct("axis", axisName, "first", first, "last", last, ...
        "duration", (last - first + 1) * dt, ...
        "status", repmat("notRequested", K, 1), "width", NaN(K, 1));
end

function model = checkModel(model, dt, M)
% The covariance model's fields, columns and step.
    if isempty(model)
        error("timeSeriesPreparation:fill:modelMissing", ...
            "Method ""collocation"" needs Model (noise's output, or acv, dt and mu).");
    end
    ok = isstruct(model) && isscalar(model) && all(isfield(model, ["acv" "dt" "mu"]));
    if ok
        ok = isa(model.acv, "double") && ismatrix(model.acv) && ~isempty(model.acv) ...
            && size(model.acv, 2) == M && all(isfinite(model.acv), "all") ...
            && isnumeric(model.mu) && numel(model.mu) == M && all(isfinite(model.mu)) ...
            && isnumeric(model.dt) && isscalar(model.dt) ...
            && abs(model.dt - dt) <= 1e-9 * dt;
    end
    if ~ok
        error("timeSeriesPreparation:fill:modelMismatch", ...
            "Model needs acv (L+1 x %d, finite), mu (1 x %d) and dt = %g s, the arc's step.", ...
            M, M, dt);
    end
end

function C = toeplitzAt(acv, r, c)
% Covariance between samples r and c, acv(|r - c| + 1), shaped numel(r) x numel(c).
    lag = abs(r(:) - c(:)');
    C = reshape(acv(lag + 1), size(lag));
end
