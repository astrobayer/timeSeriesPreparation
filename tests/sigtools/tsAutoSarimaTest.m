classdef tsAutoSarimaTest < matlab.unittest.TestCase
%TSAUTOSARIMATEST  tsAutoSarima: seasonal ARIMA grid search, ranking and option forwarding.
%
%   DESCRIPTION
%     tsAutoSarima fits every SARIMA candidate of a small order grid and
%     ranks them by an information criterion. Checked here: the shape and
%     sorting of the result table, the choice of a seasonal AR term on
%     seasonal data, the aic/bic switch, forwarding of options to
%     tsFitSarima, and the error when no candidate can be fitted.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - simulated seasonal AR data select a model with P >= 1.
%     contract     - the table has 9 columns sorted by the criterion; column
%                    7 is aic or bic as chosen; Method is forwarded.
%     robustness   - a series too short for every candidate is refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function selectsSeasonalStructure(tc)
        % Data with a clear seasonal AR(1)_s should prefer a model that
        % includes a seasonal AR term (P>=1) over the purely non-seasonal ones.
        rng(821);
        x = local_simSAR(0.4, 0.5, 12, 2500);
        [best, ~] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 1], [1 0 1], 12, 'Criterion', 'bic', ...
            'Constant', false);
        tc.verifyGreaterThanOrEqual(best.P, 1);
    end

    end

    methods (Test, TestTags = {'contract'})

    function tableShapeAndSort(tc)
        rng(820);
        x = local_simSAR(0.5, 0.3, 12, 1200);
        [best, tbl] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 1], [1 0 1], 12);
        tc.verifyEqual(size(tbl,2), 9);
        tc.verifyTrue(issorted(tbl(:,7)));          % ascending criterion
        tc.verifyTrue(isstruct(best));
        tc.verifyTrue(startsWith(best.type, 'SARIMA') || startsWith(best.type,'ARMA') ...
                      || startsWith(best.type,'AR') || startsWith(best.type,'MA'));
    end

    function criterionSwitch(tc)
        rng(822);
        x = local_simSAR(0.5, 0.3, 6, 1500);
        [~, tblA] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 1], [1 0 0], 6, 'Criterion', 'aic');
        [~, tblB] = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 1], [1 0 0], 6, 'Criterion', 'bic');
        % column 7 holds the *selection* criterion: equals aic for A, bic for B
        tc.verifyEqual(tblA(1,7), min(tblA(:,8)), 'RelTol', 1e-10);   % aic col = 8
        tc.verifyEqual(tblB(1,7), min(tblB(:,9)), 'RelTol', 1e-10);   % bic col = 9
    end

    function forwardsMethodExact(tc)
        rng(823);
        x = local_simSAR(0.5, 0.3, 6, 1500);
        best = timeSeriesPreparation.tsmodels.tsAutoSarima(x, [1 0 0], [1 0 0], 6, 'Method', 'exact', ...
            'Constant', false);
        tc.verifyEqual(best.method, 'exact');
    end

    end

    methods (Test, TestTags = {'robustness'})

    function emptyGridErrors(tc)
        % A far-too-short series makes every fit fail -> informative error.
        % 8 samples with a seasonal-only grid (s=12): every candidate needs
        % >= s+... samples, so none can be fitted -> noFit.
        tc.verifyError(@() timeSeriesPreparation.tsmodels.tsAutoSarima((1:8)', [0 0 0], [1 0 1], 12), ...
            'timeSeriesPreparation:tsAutoSarima:noFit');
    end

    end
end

% ====================================================================
function x = local_simSAR(phi, Phi, s, n, burn)
    if nargin < 5, burn = 400; end
    N = n + burn; e = randn(N,1); x = zeros(N,1);
    for t = s+2:N
        x(t) = phi*x(t-1) + Phi*x(t-s) - phi*Phi*x(t-s-1) + e(t);
    end
    x = x(burn+1:end);
end
