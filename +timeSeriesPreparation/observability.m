function report = observability(arc, X, options)
%OBSERVABILITY  Identifiability metrics of a design before the fit, and the minimum-data gate.
%
%   SYNTAX
%     report = timeSeriesPreparation.observability(arc, X)
%     report = timeSeriesPreparation.observability(arc, X, Names = names, MinWeightFraction = 0.5)
%
%   DESCRIPTION
%     The gate stage (CONCEPT 6.1, row 6). An application calls it with
%     the regressors it is about to fit, and refuses or downgrades
%     parameters the data cannot separate. v2 fitted bias and scale on
%     quiet arcs, where the two estimates correlate at -1 (CONCEPT 8). No
%     fit happens here (CONCEPT 3.2); the metrics describe the design.
%
%     Per axis m (column of arc.obs) the fit weight of a row is
%       w = arc.weights, times 0 where obs(:, m) or any regressor is not
%       finite, and 0 where the row was filled (CONCEPT 5),
%     and the kept weight fraction is sum(w)/N.
%
%     Minimum-data gate (CONCEPT 5.2): if any axis keeps less than
%     MinWeightFraction, the call refuses with an identifier naming the
%     axes; it never returns NaN metrics for them. MinWeightFraction []
%     takes Config(arc).unc.minWeightFraction (0.5 for ACC1B, ACT1B, ACH1B,
%     KBR1B, LRI1B; owner decision 2026-09-23). A product without a preset needs
%     it given.
%
%     Metrics per axis, from the rows with w > 0, each scaled by sqrt(w):
%       cond       the condition number of X after scaling each column to
%                  unit length (Belsley, Kuh & Welsch 1980): above about 30
%                  the columns are nearly dependent.
%       paramCorr  the correlation matrix of the least-squares estimates,
%                  from (X' W X)^-1, for X exactly as given. For [1, a]
%                  it is -mean(a)/sqrt(mean(a.^2)): -1 when a barely
%                  varies about a large mean.
%       vif        the variance inflation factor of each regressor,
%                  1/(1 - R_j^2) with R_j^2 from regressing column j on the
%                  others and a constant (the weighted, centred form). NaN
%                  for a constant column. Above about 10 a parameter is
%                  poorly determined (Kutner et al. 2005, ch. 10).
%     Whether to demean a regressor is the application's decision; the
%     paramCorr of the demeaned design shows the effect.
%
%   INPUTS
%     arc  (1,1) Arc      -   Observations and weights; one axis per
%                             column.
%     X    (N,P) double   -   Regressors on arc.t, one column per
%                             parameter, as the application will fit them.
%
%   OPTIONS
%     Names              (1,P) string   ["x1".."xP"]  Regressor names.
%     MinWeightFraction  (1,1) double   [preset]      Gate in (0,1]; []
%                                                     (preset) =
%                                                     Config(arc).unc.
%
%   OUTPUTS
%     report  (1,1) struct   -   Fields: axes (1,M) string, names (1,P)
%                                string, weightFraction (1,M), threshold,
%                                cond (1,M), paramCorr (P,P,M), vif (P,M),
%                                maxAbsCorr (1,M) the largest off-diagonal
%                                |paramCorr|, nRows (1,M) rows with w > 0.
%
%   ACCURACY
%     Linear algebra in double: cond from the singular values, paramCorr
%     and vif from inv of P x P matrices whose condition number is cond^2
%     at most. An exactly dependent design gives cond Inf (or near
%     1/eps), NaN paramCorr (rcond below eps) and Inf vif; an all-zero
%     column leaves cond and paramCorr NaN. TestObservability pins the
%     closed forms for [1, a] and for two regressors of known correlation
%     to 1e-12.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:observability:sizeMismatch - X does not have
%           one row per epoch of arc, or Names not one name per column.
%       timeSeriesPreparation:observability:noThreshold - no
%           MinWeightFraction given and none in the product's preset.
%     Gate:
%       timeSeriesPreparation:observability:insufficientData - an axis
%           keeps less than MinWeightFraction of its weight.
%       Options outside their domain are refused by the arguments block
%       with a MATLAB: identifier.
%
%   EXAMPLE
%     % Bias and scale on a quiet arc: the estimates correlate near -1.
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     t = int64(0:999)' * int64(1e9);
%     model = 1e-7 + 1e-9 * sin((0:999)' / 100);
%     report = timeSeriesPreparation.observability(timeSeriesPreparation.Arc(t, model, aux), [ones(1000, 1), model], Names = ["bias" "scale"]);
%
%   LIMITATIONS
%     One design for all axes; per-axis designs need one call each. The
%     thresholds quoted for cond and vif are rules of thumb and are not
%     applied here: the application chooses.
%
%   REFERENCES
%     Belsley, D. A., Kuh, E., Welsch, R. E. (1980). Regression
%     Diagnostics. Wiley, ch. 3. Kutner, M. H., Nachtsheim, C. J., Neter,
%     J., Li, W. (2005). Applied Linear Statistical Models, 5th ed.
%     McGraw-Hill, ch. 10. docs/CONCEPT.md sections 5.2, 6.1 (row 6)
%     and 8.
%
%   See also timeSeriesPreparation.Config, timeSeriesPreparation.bootstrap, timeSeriesPreparation.Arc.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-10-20 12:40 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        X (:,:) double
        options.Names string = strings(1, 0)
        options.MinWeightFraction double {mustBeScalarOrEmpty, mustBePositive, mustBeLessThanOrEqual(options.MinWeightFraction, 1)} = []
    end

    N = numel(arc.t);
    P = size(X, 2);
    names = reshape(options.Names, 1, []);
    if isempty(names)
        names = "x" + (1:P);
    end
    if size(X, 1) ~= N || numel(names) ~= P
        error("timeSeriesPreparation:observability:sizeMismatch", ...
            "X must be %d x P with one name per column (got %d x %d, %d names).", ...
            N, size(X, 1), P, numel(names));
    end

    thr = options.MinWeightFraction;
    if isempty(thr)
        thr = timeSeriesPreparation.Config(arc).unc.minWeightFraction;
    end
    if isempty(thr)
        error("timeSeriesPreparation:observability:noThreshold", ...
            "Product ""%s"" has no minimum-data preset; pass MinWeightFraction.", arc.product);
    end

    M = size(arc.obs, 2);
    W = arc.weights .* all(isfinite(X), 2) .* ~arc.filled .* isfinite(arc.obs);
    frac = sum(W, 1) / N;
    low = frac < thr;
    if any(low)
        error("timeSeriesPreparation:observability:insufficientData", ...
            "Axes %s keep %s of their weight, below the gate %g.", ...
            strjoin(arc.names(low), ", "), strjoin(compose("%.3g", frac(low)), ", "), thr);
    end

    report = struct("axes", arc.names, "names", names, "weightFraction", frac, ...
        "threshold", thr, "cond", NaN(1, M), "paramCorr", NaN(P, P, M), ...
        "vif", NaN(P, M), "maxAbsCorr", NaN(1, M), "nRows", zeros(1, M));
    for m = 1:M
        keep = W(:, m) > 0;
        sw = sqrt(W(keep, m));
        A = sw .* X(keep, :);
        report.nRows(m) = nnz(keep);

        % Column scaling changes neither cond's meaning (Belsley) nor the
        % correlation of the estimates, and keeps inv well scaled.
        norms = vecnorm(A);
        if isempty(A) || any(norms == 0)
            continue
        end
        As = A ./ norms;
        s = svd(As);
        report.cond(m) = s(1) / s(end);
        G = As' * As;
        if rcond(G) >= eps
            C = inv(G);
            C = (C + C') / 2;
            d = sqrt(diag(C));
            R = C ./ (d * d');
            report.paramCorr(:, :, m) = R;
            report.maxAbsCorr(m) = max([reshape(abs(R - diag(diag(R))), [], 1); 0]);
        end

        report.vif(:, m) = vifOf(X(keep, :), W(keep, m));
    end
end

function v = vifOf(X, w)
% Weighted, centred variance inflation factors; NaN for constant columns.
    P = size(X, 2);
    v = NaN(P, 1);
    varying = ~all(X == X(1, :), 1);
    if ~any(varying)
        return
    end
    mu = sum(w .* X(:, varying), 1) / sum(w);
    Z = sqrt(w) .* (X(:, varying) - mu);
    Zv = Z ./ vecnorm(Z);
    R = Zv' * Zv;
    if rcond(R) < eps
        v(varying) = Inf;
        return
    end
    v(varying) = diag(inv(R));
end
