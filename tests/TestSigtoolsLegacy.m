classdef TestSigtoolsLegacy < matlab.unittest.TestCase
%TESTSIGTOOLSLEGACY  sigtools' legacy function-based suite, one counted test per case.
%
%   DESCRIPTION
%     sigtools v1.3.1 ships 29 legacy cases in tests/sigtools/runAllTests.m,
%     a plain function that returns a struct array instead of TestResults, so
%     the gate could not count them. This class runs it once, with its own
%     default seed (12345), and turns each case into one parameterised test,
%     so the imported suite is counted as its HANDOFF states it: 180
%     class-based tests plus 29 legacy ones. runAllTests itself stays
%     byte-identical to the archive apart from namespace qualifiers
%     (TestSigtoolsImport).
%
%   COVERAGE
%     reference  - each legacy case passed (sigtools' own oracles, ORC-8).
%     contract   - runAllTests runs exactly 29 cases, all of them named here.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-22 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Case = {'test_acf_whitenoise', 'test_acf_known', 'test_pacf_ar1', ...
            'test_diff_integrate_roundtrip', 'test_norminv_values', ...
            'test_chi2_ljungbox_null', 'test_yw_ar2_recovery', ...
            'test_exact_ar1_recovery', 'test_exact_ma1_recovery', ...
            'test_exact_arma21_recovery', 'test_exact_vs_css_close', ...
            'test_exact_ll_matches_closedform_ar1', 'test_stderr_positive', ...
            'test_aic_bic_consistency', 'test_auto_selects_true_order', ...
            'test_forecast_ar1_meanrevert', 'test_forecast_interval_coverage', ...
            'test_arima_forecast_runs', 'test_input_validation', ...
            'test_short_series_error', 'test_acf_pairwise_gaps', ...
            'test_miss_ar1_recovery', 'test_miss_arma_recovery', ...
            'test_miss_ll_matches_marginal_ar1', 'test_miss_resid_nan_at_gaps', ...
            'test_miss_forecast_runs', 'test_miss_blockgap_recovery', ...
            'test_miss_requires_exact', 'test_miss_no_diff'}
    end

    properties (Access = private)
        Results
        Log
    end

    methods (TestClassSetup)
        function runLegacySuiteOnce(testCase)
            folder = fullfile(fileparts(mfilename("fullpath")), "sigtools");
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "runAllTests:failures"));
            r = [];
            testCase.Log = evalc("r = runAllTests();");
            testCase.Results = r;
        end
    end

    methods (Test, TestTags = {'reference'})
        function legacyCasePasses(testCase, Case)
            hit = testCase.Results(strcmp({testCase.Results.name}, Case));
            testCase.assertNumElements(hit, 1, "runAllTests did not run " + Case + ".");
            testCase.verifyTrue(hit.passed, Case + " failed: " + hit.msg);
        end
    end

    methods (Test, TestTags = {'contract'})
        function legacyCaseCountIsTwentyNine(testCase)
            % Each listed case is looked up by legacyCasePasses; the count
            % catches a case runAllTests gained that the list does not name.
            testCase.verifyNumElements(testCase.Results, 29, ...
                "runAllTests no longer runs 29 cases; update the Case parameter.");
        end
    end
end
