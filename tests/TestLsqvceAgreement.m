classdef TestLsqvceAgreement < matlab.unittest.TestCase
%TESTLSQVCEAGREEMENT  Q12: the sigtools numerics agree with lsqvce's kernels.
%
%   DESCRIPTION
%     CONCEPT 11, Q12 (decided 2026-09-18): sigtools and lsqvce both keep
%     their ARMA autocovariance, PSD -> ACV, whiteness and AR-fitting code,
%     and this test holds them together mechanically. lsqvce is a
%     test-only dependency (v6.1.3 in CI, deps/lsqvce); without it every
%     test here is incomplete, never passed. Each tolerance names the term
%     it bounds and was measured in NumPy on transcriptions of both sides
%     (2026-09-23):
%       arma2acv <-> armaACV: exact Lyapunov solution versus the FFT of
%         the impulse response truncated below eps. Measured 1.6e-16 to
%         8.6e-16 of r(0), and 4.6e-13 for poles at |z| = 0.98, whose
%         stationary covariance has condition about 1/(1 - |z|^2) = 25.
%         Held to 1e-10 r(0).
%       spec2acv <-> psd2acv: the same trapezoid, once by inverse FFT and
%         once as a direct cosine sum. Measured 3.2e-16 of R(0). Held to
%         1e-12 R(0).
%       tsLjungBox <-> whitenessCorr: both use the biased sample ACF
%         (mean removed, lag-0 normalised), so the largest |rho_k| of
%         tsAcf equals whitenessCorr to rounding (1e-12). Q is then
%         bracketed exactly: N(N+2)/(N-1) c^2 <= Q <= L N(N+2)/(N-L) c^2.
%       tsFitAR <-> levinsonDurbin, whittle: on the same ACV, a Toeplitz
%         solve versus the Levinson (scalar) and Whittle (d = 1) recursions.
%         The Toeplitz condition number was at most 410 over 20 series of
%         these models, so a few 1e-13. Held to 1e-10.
%     A planted error, the AR(1) pole moved by 1e-7, must exceed the
%     arma2acv tolerance (fault injection of the check itself).
%
%   COVERAGE
%     reference      - four ARMA autocovariances, two PSD -> ACV
%                      transforms, the whiteness statistic, and three AR
%                      fits by Levinson and by Whittle agree with lsqvce.
%     robustness     - a 1e-7 planted error in the model fails the
%                      tolerance.
%     precision, contract, speed, vectorisation, metamorphic - exempt: the
%                      functions compared are tested in their own suites;
%                      this class checks agreement only.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Arma = struct("arma11", {{[1 0.5], [1 -0.9]}}, ...
                      "ar3", {{1, [1 -1.6 0.9 -0.25]}}, ...
                      "nearUnit", {{[1 0.4 0.2], [1 -1.95 0.9606]}}, ...
                      "slowAr1", {{[1 -0.3], [1 -0.99]}})
        Spectrum = struct("ar09", {{0.9, 5, 4097}}, "ar097", {{0.97, 0.1, 8193}})
        Ar = struct("ar1", {{[1 -0.5]}}, "ar2", {{[1 -1.95 0.9606]}}, ...
                    "ar3", {{[1 -1.6 0.9 -0.25]}})
    end

    methods (TestClassSetup)
        function requireLsqvce(testCase)
            testCase.assumeNotEmpty(meta.package.fromName('lsqvce'), ...
                "lsqvce is not on the path (test-only dependency, deps/lsqvce).");
        end
    end

    methods (Test, TestTags = {'reference'})
        function armaAutocovarianceAgrees(testCase, Arma)
            [b, a] = Arma{:};
            R = timeSeriesPreparation.spectral.arma2acv(b, a, 49);
            r = lsqvce.kernel.armaACV(a, b, 50);
            testCase.verifyEqual(R, r, "AbsTol", 1e-10 * R(1));
        end

        function psdToAcvAgrees(testCase, Spectrum)
            [phi, dt, nf] = Spectrum{:};
            f = linspace(0, 0.5 / dt, nf)';
            S = 2 * dt * abs(1 ./ (1 - phi * exp(-2i * pi * f * dt))).^2;
            [R, lags] = timeSeriesPreparation.spectral.spec2acv(f, S);
            r = lsqvce.kernel.psd2acv(f, S, dt, 50);
            testCase.verifyEqual(lags(1:50), (0:49)' * dt, "RelTol", 1e-12);
            testCase.verifyEqual(R(1:50), r, "AbsTol", 1e-12 * r(1));
        end

        function whitenessStatisticAgrees(testCase)
            x = filter(1, [1 -0.2], randn(RandStream("twister", "Seed", 41), 3000, 1));
            L = 20;
            N = numel(x);
            Q = timeSeriesPreparation.tsmodels.tsLjungBox(x, L);
            c = lsqvce.kernel.whitenessCorr(x, L);
            rho = timeSeriesPreparation.tsmodels.tsAcf(x, L);
            testCase.verifyEqual(max(abs(rho(2:end))), c, "AbsTol", 1e-12);
            testCase.verifyGreaterThanOrEqual(Q, N * (N + 2) / (N - 1) * c^2 * (1 - 1e-12));
            testCase.verifyLessThanOrEqual(Q, L * N * (N + 2) / (N - L) * c^2 * (1 + 1e-12));
        end

        function yuleWalkerAgreesWithLevinson(testCase, Ar)
            [x, p, acv, m] = ywCase(Ar{1});
            [aL, s2] = lsqvce.kernel.levinsonDurbin(acv, p);
            testCase.verifyEqual(-aL(2:end), m.ar, "AbsTol", 1e-10);
            testCase.verifyEqual(s2, m.sigma2, "RelTol", 1e-10);
            testCase.verifyNumElements(x, 2000);
        end

        function yuleWalkerAgreesWithWhittle(testCase, Ar)
            [~, p, acv, m] = ywCase(Ar{1});
            [A, Sigma] = lsqvce.kernel.whittle(reshape(acv, 1, 1, []), p);
            testCase.verifyEqual(reshape(A, 1, []), m.ar, "AbsTol", 1e-10);
            testCase.verifyEqual(Sigma, m.sigma2, "RelTol", 1e-10);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function plantedErrorExceedsTolerance(testCase)
            R = timeSeriesPreparation.spectral.arma2acv(1, [1 -0.9], 49);
            r = lsqvce.kernel.armaACV([1 -0.9 + 1e-7], 1, 50);
            testCase.verifyGreaterThan(max(abs(R - r)), 1e-10 * R(1));
        end
    end
end

function [x, p, acv, m] = ywCase(a)
% An AR(p) series, its Yule-Walker fit, and the ACV that fit solved.
    x = filter(1, a, randn(RandStream("twister", "Seed", 42), 2500, 1));
    x = x(501:end);
    p = numel(a) - 1;
    m = timeSeriesPreparation.tsmodels.tsFitAR(x, p, Method = "yw");
    % tsFitArima's Yule-Walker path: rho of the demeaned series, c0 = var(x, 1).
    rho = timeSeriesPreparation.tsmodels.tsAcf(x - mean(x), p);
    acv = var(x, 1) * rho;
end
