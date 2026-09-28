function res = partialCorrelation(X, options)
%PARTIALCORRELATION  Partial correlation of each pair of columns given all others, with block-bootstrap sigmas.
%
%   SYNTAX
%     res = timeSeriesPreparation.partialCorrelation(X)
%     res = timeSeriesPreparation.partialCorrelation(X, Names = [], NBoot = 1000, BlockLength = [], Seed = 0, Stage = "partialCorrelation", Level = 0.6827)
%
%   DESCRIPTION
%     The partial correlation of CONCEPT 7 (e.g. a residual against beta'
%     with the eclipse fraction held fixed): the correlation of columns i
%     and j after the linear effect of every other column is removed from
%     both. It is read from the inverse Q of the correlation matrix of the
%     complete rows, rho_ij.rest = -Q_ij / sqrt(Q_ii Q_jj), with 1 on the
%     diagonal. With two columns it is their ordinary correlation.
%     sigma and ci come from a moving-block bootstrap of the rows
%     (bootstrap; automatic Politis-White block length unless BlockLength;
%     seed from Stage and Seed), because rows in time order are serially
%     correlated (CONCEPT 8).
%
%   INPUTS
%     X  (R,V) double   -   Variables in columns, rows in time order; NaN =
%                           missing (the row is dropped).
%
%   OPTIONS
%     Names        (1,V) string   ["x1".."xV"]   Column names.
%     NBoot        (1,1) double   [1000]         Bootstrap replicates.
%     BlockLength  (1,1) double   [auto]         Block length in rows.
%     Seed         (1,1) double   [0]            Caller's seed.
%     Stage        (1,1) string   ["partialCorrelation"]  Stage of the seed.
%     Level        (1,1) double   [0.6827]       Two-sided level of ci.
%
%   OUTPUTS
%     res  (1,1) struct   -   Fields: names (1,V); r, sigma (V,V),
%                             symmetric, diagonal 1 and 0; ci (2,V,V);
%                             nRows; blockLength; level.
%
%   ACCURACY
%     r equals the correlation of the residuals of i and j each regressed
%     on the other columns (TestPartialCorrelation holds 1e-12) and, for
%     three columns, (r_ij - r_ik r_jk) / sqrt((1 - r_ik^2)(1 - r_jk^2)).
%     Its conditioning is that of the correlation matrix; nearly
%     dependent columns refuse.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:partialCorrelation:tooFewVariables - X has
%           fewer than two columns, or Names the wrong length.
%       timeSeriesPreparation:partialCorrelation:tooFewRows - fewer than
%           V + 2 complete rows.
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%     Numerical:
%       timeSeriesPreparation:partialCorrelation:collinear - the
%           correlation matrix is singular (reciprocal condition below
%           1e-12: a column constant or a combination of the others).
%
%   EXAMPLE
%     % A residual that depends on beta' only, beta' and eclipse correlated.
%     rs = RandStream("twister", "Seed", 22);
%     beta = randn(rs, 500, 1);
%     eclipse = 0.7 * beta + randn(rs, 500, 1);
%     residual = 0.5 * beta + randn(rs, 500, 1);
%     res = timeSeriesPreparation.partialCorrelation([residual beta eclipse], Names = ["residual" "betaPrime" "eclipse"], NBoot = 200);
%
%   LIMITATIONS
%     Linear and Gaussian in spirit; outliers act on r directly. The rows
%     used are those complete in every column.
%
%   REFERENCES
%     Whittaker, J. (1990). Graphical Models in Applied Multivariate
%     Statistics. Wiley, ch. 5 (partial correlation from the inverse
%     correlation matrix). docs/CONCEPT.md sections 7 and 8.
%
%   See also timeSeriesPreparation.regressDrivers, timeSeriesPreparation.correlate, timeSeriesPreparation.bootstrap.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        X (:,:) double
        options.Names (1,:) string = strings(1, 0)
        options.NBoot (1,1) double {mustBeInteger, mustBePositive} = 1000
        options.BlockLength double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Stage (1,1) string = "partialCorrelation"
        options.Level (1,1) double {mustBeGreaterThan(options.Level, 0), mustBeLessThan(options.Level, 1)} = 0.6827
    end

    V = size(X, 2);
    names = options.Names;
    if isempty(names)
        names = "x" + (1:V);
    end
    if V < 2 || numel(names) ~= V
        error("timeSeriesPreparation:partialCorrelation:tooFewVariables", ...
            "X needs at least two columns (it has %d) and Names one entry per column.", V);
    end
    rows = all(isfinite(X), 2);
    n = nnz(rows);
    if n < V + 2
        error("timeSeriesPreparation:partialCorrelation:tooFewRows", ...
            "%d complete rows; at least %d are needed.", n, V + 2);
    end
    C = corrcoef(X(rows, :));
    if ~all(isfinite(C), "all") || rcond(C) < 1e-12
        error("timeSeriesPreparation:partialCorrelation:collinear", ...
            "The correlation matrix is singular: a column is constant or a combination of the others.");
    end
    upper = triu(true(V), 1);
    [~, info] = timeSeriesPreparation.bootstrap(X, @(D) partialUpper(D, upper), ...
        NBoot = options.NBoot, BlockLength = options.BlockLength, ...
        Seed = options.Seed, Stage = options.Stage, Level = options.Level);
    res = struct("names", names, "r", partialFrom(C), "sigma", zeros(V), ...
        "ci", NaN(2, V, V), "nRows", n, "blockLength", info.blockLength, ...
        "level", options.Level);
    [iu, ju] = find(upper);
    for p = 1:numel(iu)
        res.sigma(iu(p), ju(p)) = info.sigma(p);
        res.sigma(ju(p), iu(p)) = info.sigma(p);
        res.ci(:, iu(p), ju(p)) = info.ci(:, p);
        res.ci(:, ju(p), iu(p)) = info.ci(:, p);
    end
    for v = 1:V
        res.ci(:, v, v) = 1;
    end
end

% ------------------------------------------------------------------------

function r = partialFrom(C)
% Partial correlations from a correlation matrix, diagonal 1.
    Q = inv(C);
    Q = (Q + Q') / 2;                   % inv of a symmetric matrix, symmetric to rounding
    d = sqrt(diag(Q));
    r = -Q ./ (d * d');
    r(1:size(C, 1) + 1:end) = 1;
end

function p = partialUpper(D, upper)
% bootstrap's statistic: the upper triangle of the partial correlations.
    rows = all(isfinite(D), 2);
    p = NaN(1, nnz(upper));
    if nnz(rows) < size(D, 2) + 2
        return
    end
    C = corrcoef(D(rows, :));
    if ~all(isfinite(C), "all") || rcond(C) < 1e-12
        return
    end
    r = partialFrom(C);
    p = r(upper)';
end
