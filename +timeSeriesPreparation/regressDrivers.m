function res = regressDrivers(P, Z, options)
%REGRESSDRIVERS  Regression of per-revolution parameters on drivers, with a VIF gate and block-bootstrap sigmas.
%
%   SYNTAX
%     res = timeSeriesPreparation.regressDrivers(P, Z)
%     res = timeSeriesPreparation.regressDrivers(P, Z, Names = [], DriverNames = [], MaxVif = 10, NBoot = 1000, BlockLength = [], Seed = 0, Stage = "regressDrivers", Level = 0.6827)
%
%   DESCRIPTION
%     The regression of CONCEPT 7: gated per-revolution parameters (a bias
%     or scale per revolution, from the application's fit) on the drivers
%     averaged per revolution by the caller. Rows are revolutions in time
%     order, so that blocks of rows are blocks of time.
%       - VIF gate: vif = diag(inv(corrcoef(Z))) on the rows complete in
%         Z. A driver above MaxVif refuses (default 10, the common rule of
%         thumb, Kutner et al. 2005; owner decision 2026-09-24,
%         provisional); a caller that accepts collinear drivers raises
%         MaxVif.
%       - For each parameter j, ordinary least squares on the rows
%         complete in P(:,j) and Z, with the drivers demeaned over those
%         rows (CONCEPT 8: demeaned regressors decorrelate the intercept):
%         P(:,j) = c0 + (Z - mean(Z)) c + e. coef(1,j) = c0, the mean of
%         P(:,j); coef(2:end,j) = c.
%       - sigma and ci: moving-block bootstrap of the rows [P(:,j) Z]
%         (bootstrap; automatic Politis-White block length unless
%         BlockLength; seed from Stage and Seed), each replicate refitted
%         with its own demeaning (CONCEPT 8: naive sigmas were 5-14 times
%         optimistic on GRACE residuals).
%       - r2: 1 - SSE/SST of the fit.
%
%   INPUTS
%     P  (R,J) double   -   Per-revolution parameters; NaN = gated out.
%     Z  (R,K) double   -   Drivers per revolution; NaN = missing.
%
%   OPTIONS
%     Names        (1,J) string   ["p1".."pJ"]   Parameter names.
%     DriverNames  (1,K) string   ["z1".."zK"]   Driver names.
%     MaxVif       (1,1) double   [10]           VIF gate, >= 1.
%     NBoot        (1,1) double   [1000]         Bootstrap replicates.
%     BlockLength  (1,1) double   [auto]         Block length in rows.
%     Seed         (1,1) double   [0]            Caller's seed.
%     Stage        (1,1) string   ["regressDrivers"]  Stage of the seed.
%     Level        (1,1) double   [0.6827]       Two-sided level of ci.
%
%   OUTPUTS
%     res  (1,1) struct   -   Fields: names (1,J), driverNames (1,K);
%                             coef, sigma (K+1,J), unit of P per unit of
%                             the driver, row 1 the intercept; ci
%                             (2,K+1,J); vif (1,K); r2, nRows,
%                             blockLength (1,J); level.
%
%   ACCURACY
%     coef is the least-squares solution by QR (backslash); with exact
%     data it recovers the coefficients to rounding. The bootstrap slope
%     sigma lay within 0.86-1.21 of the OLS sigma for white errors (NumPy,
%     100 realisations of 600 rows, 2026-09-24); for serially correlated
%     errors it is the one that stays honest. The intercept's bootstrap
%     sigma also carries the scatter of the replicate means of Z.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:regressDrivers:sizeMismatch - P and Z have
%           different rows, or Names or DriverNames the wrong length.
%       timeSeriesPreparation:regressDrivers:tooFewRows - fewer than K + 2
%           complete rows for a parameter.
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%     Numerical:
%       timeSeriesPreparation:regressDrivers:collinear - a driver's VIF
%           exceeds MaxVif, or the drivers are linearly dependent.
%
%   EXAMPLE
%     % A bias per revolution driven by beta' and the eclipse fraction.
%     rs = RandStream("twister", "Seed", 21);
%     Z = [randn(rs, 300, 1), rand(rs, 300, 1)];
%     P = 2 + Z * [0.3; -0.5] + 0.1 * randn(rs, 300, 1);
%     res = timeSeriesPreparation.regressDrivers(P, Z, DriverNames = ["betaPrime" "eclipse"], NBoot = 200);
%
%   LIMITATIONS
%     Linear in the drivers, one parameter at a time. The bootstrap
%     percentile interval is first-order accurate. Per-revolution
%     averaging and gating are the caller's.
%
%   REFERENCES
%     Kutner, M. H., Nachtsheim, C. J., Neter, J., Li, W. (2005). Applied
%     Linear Statistical Models, 5th ed. McGraw-Hill, sect. 10.5 (VIF).
%     Kuensch, H. R. (1989). Ann. Statist. 17, 1217-1241 (block
%     bootstrap). docs/CONCEPT.md sections 7 and 8.
%
%   See also timeSeriesPreparation.bootstrap, timeSeriesPreparation.observability, timeSeriesPreparation.partialCorrelation.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        P (:,:) double
        Z (:,:) double
        options.Names (1,:) string = strings(1, 0)
        options.DriverNames (1,:) string = strings(1, 0)
        options.MaxVif (1,1) double {mustBeGreaterThanOrEqual(options.MaxVif, 1)} = 10
        options.NBoot (1,1) double {mustBeInteger, mustBePositive} = 1000
        options.BlockLength double {mustBeScalarOrEmpty, mustBeInteger, mustBePositive} = []
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Stage (1,1) string = "regressDrivers"
        options.Level (1,1) double {mustBeGreaterThan(options.Level, 0), mustBeLessThan(options.Level, 1)} = 0.6827
    end

    [R, J] = size(P);
    K = size(Z, 2);
    names = defaultNames(options.Names, "p", J);
    driverNames = defaultNames(options.DriverNames, "z", K);
    if size(Z, 1) ~= R || K == 0 || numel(names) ~= J || numel(driverNames) ~= K
        error("timeSeriesPreparation:regressDrivers:sizeMismatch", ...
            "P (%d x %d) and Z (%d x %d) need the same rows and at least one driver; " + ...
            "Names needs %d and DriverNames %d entries.", R, J, size(Z, 1), K, J, K);
    end

    okZ = all(isfinite(Z), 2);
    vif = ones(1, K);
    if K > 1
        C = corrcoef(Z(okZ, :));
        if ~all(isfinite(C), "all") || rcond(C) < 1e-12
            error("timeSeriesPreparation:regressDrivers:collinear", ...
                "The drivers are linearly dependent (or constant) on their complete rows.");
        end
        vif = diag(inv(C))';
    end
    if any(vif > options.MaxVif)
        error("timeSeriesPreparation:regressDrivers:collinear", ...
            "VIF above %g for %s (%s); raise MaxVif to accept them.", options.MaxVif, ...
            strjoin(driverNames(vif > options.MaxVif), ", "), ...
            strjoin(compose("%.3g", vif(vif > options.MaxVif)), ", "));
    end

    res = struct("names", names, "driverNames", driverNames, "coef", NaN(K + 1, J), ...
        "sigma", NaN(K + 1, J), "ci", NaN(2, K + 1, J), "vif", vif, "r2", NaN(1, J), ...
        "nRows", zeros(1, J), "blockLength", NaN(1, J), "level", options.Level);
    for j = 1:J
        rows = okZ & isfinite(P(:, j));
        n = nnz(rows);
        if n < K + 2
            error("timeSeriesPreparation:regressDrivers:tooFewRows", ...
                "Parameter %s has %d complete rows; at least %d are needed.", names(j), n, K + 2);
        end
        [c, r2] = olsFit([P(rows, j), Z(rows, :)]);
        res.coef(:, j) = c';
        res.r2(j) = r2;
        res.nRows(j) = n;
        [~, info] = timeSeriesPreparation.bootstrap([P(:, j), Z], @olsCoef, ...
            NBoot = options.NBoot, BlockLength = options.BlockLength, ...
            Seed = options.Seed, Stage = options.Stage, Level = options.Level);
        res.sigma(:, j) = info.sigma';
        res.ci(:, :, j) = info.ci;
        res.blockLength(j) = info.blockLength;
    end
end

% ------------------------------------------------------------------------

function c = olsCoef(D)
% bootstrap's statistic: [intercept, slopes] of D(:,1) on demeaned D(:,2:end).
    rows = all(isfinite(D), 2);
    if nnz(rows) < size(D, 2) + 1
        c = NaN(1, size(D, 2));
        return
    end
    c = olsFit(D(rows, :));
end

function [c, r2] = olsFit(D)
% OLS of D(:,1) on [1, D(:,2:end) - mean], complete rows only; c is a row.
    y = D(:, 1);
    X = D(:, 2:end) - mean(D(:, 2:end), 1);
    c = ([ones(size(y)), X] \ y)';
    e = y - [ones(size(y)), X] * c';
    r2 = 1 - sum(e.^2) / sum((y - mean(y)).^2);
end

function s = defaultNames(s, prefix, n)
% Given names, or prefix1..prefixN.
    if isempty(s)
        s = prefix + (1:n);
    end
end
