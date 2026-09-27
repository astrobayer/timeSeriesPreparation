classdef arma2acvTest < matlab.unittest.TestCase
%ARMA2ACVTEST  arma2acv: exact ARMA autocovariance against closed forms and the spectral route.
%
%   DESCRIPTION
%     arma2acv returns the exact autocovariance of an ARMA process (Lyapunov
%     solution or psi-weight sum). Checked here: the AR(1) and MA(2) closed
%     forms, the agreement of the Lyapunov and psi methods, the AR(1)
%     integral time, the round trip arma2acv = spec2acv(arma2psd(...)) to
%     quadrature accuracy, the sample ACF of long simulations, the output
%     shapes, the acf normalisation, the lag axis in seconds and the refusal
%     of a non-stationary model.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - AR(1) and MA(2) closed forms; Lyapunov equals psi;
%                    AR(1) integral time; spectral route spec2acv(arma2psd)
%                    (5e-4); multi-seed sample ACF (5 % of R(0)).
%     contract     - output sizes, class and stability flag; acf =
%                    acv/variance with unit lag 0; Fs gives the lag axis in
%                    seconds.
%     metamorphic  - the autocovariance scales linearly with the noise
%                    variance.
%     robustness   - a unit-root or explosive AR polynomial is refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function ar1ClosedForm(tc)
        % AR(1): gamma(k) = s2/(1-phi^2) * phi^|k|
        phi = 0.7; s2 = 1.7; L = 25;
        [R, ~, info] = timeSeriesPreparation.spectral.arma2acv(1, [1 -phi], L, 'NoiseVariance', s2);
        k = (0:L)';
        Rexact = s2/(1-phi^2) * phi.^k;
        tc.verifyEqual(R, Rexact, 'RelTol', 1e-10, 'AbsTol', 1e-12);
        tc.verifyEqual(info.variance, s2/(1-phi^2), 'RelTol', 1e-10);
    end

    function ma2ClosedForm(tc)
        % MA(2): gamma(0)=s2(1+th1^2+th2^2), gamma(1)=s2(th1+th1*th2),
        % gamma(2)=s2*th2, gamma(k>=3)=0.
        th1 = 0.5; th2 = -0.3; s2 = 2.0;
        [R, ~] = timeSeriesPreparation.spectral.arma2acv([1 th1 th2], 1, 6, 'NoiseVariance', s2);
        tc.verifyEqual(R(1), s2*(1+th1^2+th2^2), 'RelTol', 1e-12);
        tc.verifyEqual(R(2), s2*(th1 + th1*th2),  'RelTol', 1e-12);
        tc.verifyEqual(R(3), s2*th2,              'RelTol', 1e-12);
        tc.verifyEqual(R(4:end), zeros(4,1),      'AbsTol', 1e-12);
    end

    function lyapunovMatchesPsi(tc)
        % Both methods must agree to near machine precision on several models.
        models = {{[1 -0.5],       [1 -1.2 0.6]}, ...   % ARMA(2,1)
                  {1,              [1 -0.7]},      ...   % AR(1)
                  {[1 0.5 -0.3],   1},             ...   % MA(2)
                  {[1 0.4 -0.2 0.1],[1 -0.5]}};          % ARMA(1,3), q>p
        for i = 1:numel(models)
            b = models{i}{1}; a = models{i}{2};
            RL = timeSeriesPreparation.spectral.arma2acv(b, a, 18, 'Method', 'lyapunov');
            RP = timeSeriesPreparation.spectral.arma2acv(b, a, 18, 'Method', 'psi', 'PsiTerms', 5000);
            tc.verifyEqual(RL, RP, 'AbsTol', 1e-9, 'RelTol', 1e-9);
        end
    end

    function integralTimeAR1(tc)
        % AR(1) one-sided integral time = 0.5 + phi/(1-phi) (in samples)
        phi = 0.6;
        [~, ~, info] = timeSeriesPreparation.spectral.arma2acv(1, [1 -phi], 400);
        tc.verifyEqual(info.integralTime, 0.5 + phi/(1-phi), 'RelTol', 1e-6);
    end

    function roundTripWithSpec2acv(tc)
        % arma2acv must equal spec2acv(arma2psd(...)) at integer sample lags,
        % to quadrature accuracy on a fine PSD grid.
        Fs = 10; s2 = 2.0; a = [1 -1.2 0.6]; b = [1 -0.5]; L = 20;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 200000);
        lagSec = (0:L)'/Fs;
        Rspec = timeSeriesPreparation.spectral.spec2acv(f, S, 'Method', 'direct', 'Lags', lagSec);
        Racv  = timeSeriesPreparation.spectral.arma2acv(b, a, L, 'NoiseVariance', s2);
        tc.verifyEqual(Racv, Rspec, 'RelTol', 5e-4, 'AbsTol', 1e-6*Racv(1));
    end

    function matchesSampleAcf(tc)
        % A long synthetic realisation's sample ACF should match arma2acv
        % (loose statistical tolerance, multi-seed averaged).
        a = [1 -0.5]; b = [1 0.3]; s2 = 1.0; L = 8;
        Racc = zeros(L+1, 1); reps = 6;
        for r = 1:reps
            rng(900 + r);
            x = local_simARMA([0.5], [0.3], 20000);
            Racc = Racc + local_sampleAcv(x, L);
        end
        Rsim = Racc / reps;
        Rth  = timeSeriesPreparation.spectral.arma2acv(b, a, L);
        tc.verifyEqual(Rsim, Rth, 'AbsTol', 0.05*Rth(1));
    end

    end

    methods (Test, TestTags = {'contract'})

    function outputShapesAndTypes(tc)
        [R, lags, info] = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 20);
        tc.verifySize(R, [21 1]);
        tc.verifySize(lags, [21 1]);
        tc.verifyEqual(lags, (0:20)');
        tc.verifyClass(info, 'struct');
        tc.verifyTrue(all(isfinite(R)));
        tc.verifyGreaterThan(info.variance, 0);
        tc.verifyTrue(info.IsStable);
    end

    function acfNormalisation(tc)
        [Racf, ~, info] = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 20, 'Output', 'acf');
        tc.verifyEqual(Racf(1), 1, 'AbsTol', 1e-14);
        tc.verifyLessThanOrEqual(max(abs(Racf)), 1 + 1e-10);
        % acf == acv / variance
        Racv = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 20);
        tc.verifyEqual(Racf, Racv/info.variance, 'RelTol', 1e-12);
    end

    function fsGivesSecondsLags(tc)
        Fs = 50;
        [~, lags, info] = timeSeriesPreparation.spectral.arma2acv(1, [1 -0.6], 10, 'Fs', Fs);
        tc.verifyEqual(lags, (0:10)'/Fs, 'RelTol', 1e-12);
        tc.verifyEqual(info.dt, 1/Fs, 'RelTol', 1e-12);
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function noiseVarianceLinearity(tc)
        R1 = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 15, 'NoiseVariance', 1);
        R3 = timeSeriesPreparation.spectral.arma2acv([1 -0.5], [1 -1.2 0.6], 15, 'NoiseVariance', 3);
        tc.verifyEqual(R3, 3*R1, 'RelTol', 1e-12);
    end

    end

    methods (Test, TestTags = {'robustness'})

    function nonStationaryErrors(tc)
        tc.verifyError(@() timeSeriesPreparation.spectral.arma2acv(1, [1 -1.0], 10), 'timeSeriesPreparation:arma2acv:nonstationary');
        tc.verifyError(@() timeSeriesPreparation.spectral.arma2acv(1, [1 -1.5], 10), 'timeSeriesPreparation:arma2acv:nonstationary');
    end

    end
end

% ====================================================================
function x = local_simARMA(phi, theta, n, burn)
    if nargin < 4, burn = 500; end
    phi = phi(:); theta = theta(:);
    p = numel(phi); q = numel(theta); N = n + burn;
    e = randn(N,1); x = zeros(N,1);
    for t = max(p,q)+1:N
        ar = 0; if p>0, ar = phi.'  * x(t-1:-1:t-p); end
        ma = 0; if q>0, ma = theta.'* e(t-1:-1:t-q); end
        x(t) = ar + e(t) + ma;
    end
    x = x(burn+1:end);
end

function R = local_sampleAcv(x, L)
    x = x(:) - mean(x); n = numel(x);
    R = zeros(L+1,1);
    for k = 0:L
        R(k+1) = (x(1:n-k)' * x(k+1:n)) / n;
    end
end
