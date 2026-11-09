classdef spectralIntegrationTest < matlab.unittest.TestCase
%SPECTRALINTEGRATIONTEST  Closed loop of arma2psd, psd2arma, spec2acv and arma2acv.
%
%   DESCRIPTION
%     Cross-function integration tests of the sigtools spectral functions:
%     arma2psd -> spec2acv must reproduce the ARMA variance and the AR(1)
%     autocovariance, arma2acv must agree with that spectral route, and
%     arma2psd -> psd2arma -> arma2psd must return the PSD it started from;
%     psd2arma, in both its fitting methods, must run in base MATLAB.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - trapz of the ARMA PSD equals the time-domain variance;
%                    spec2acv of it gives R(0) and the AR(1) lag-1
%                    correlation; arma2acv equals the spectral route (5e-4)
%                    and the arma2psd variance (2e-3).
%     contract     - psd2arma (default and stmcb methods) runs and fits in
%                    base MATLAB.
%     metamorphic  - fit then re-evaluate: the PSD comes back within 5 %
%                    median.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.6.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function arma2psdParsevalVariance(tc)
        % trapz(f,S) must equal the time-domain output variance sigma^2*sum(psi^2).
        Fs = 500; b = [1 -0.5 0.2]; a = [1 -1.2 0.6]; s2 = 1.7;
        [S, f, info] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 8192);
        imp = filter(b, a, [1; zeros(6000,1)]);
        varTD = s2 * sum(imp.^2);
        tc.verifyEqual(trapz(f, S), varTD, 'RelTol', 1e-3);
        tc.verifyEqual(info.variance, trapz(f, S), 'RelTol', 1e-10);
        tc.verifyTrue(info.IsStable);
    end

    function arma2psdMatchesSpec2acvR0(tc)
        % R(0) from spec2acv on the ARMA PSD equals the process variance.
        Fs = 400; b = [1 0.3]; a = [1 -0.7]; s2 = 1.0;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 8192);
        [R, lags] = timeSeriesPreparation.spectral.spec2acv(f, S);
        imp = filter(b, a, [1; zeros(4000,1)]);
        tc.verifyEqual(R(1), s2*sum(imp.^2), 'RelTol', 5e-3);
        tc.verifyEqual(lags(1), 0, 'AbsTol', 0);
    end

    function arma2psdAcvMatchesTheoryAR1(tc)
        % AR(1): R(k) = sigma^2/(1-phi^2) * phi^|k|. Check via spec2acv.
        Fs = 200; phi = 0.6; s2 = 1.0;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(1, [1 -phi], Fs, 'NoiseVariance', s2, 'NFreq', 16384);
        % No taper: a taper attenuates the spectrum and biases the ACV
        % (R(0) low, lag-1 autocorr high). The AR(1) PSD is smooth, so the
        % untapered transform reproduces the closed form to high accuracy.
        [R, ~] = timeSeriesPreparation.spectral.spec2acv(f, S);
        R0theory = s2/(1-phi^2);
        tc.verifyEqual(R(1), R0theory, 'RelTol', 2e-2);
        % lag-1 autocorrelation ~ phi
        tc.verifyEqual(R(2)/R(1), phi, 'AbsTol', 0.03);
    end

    function arma2acvMatchesSpec2acvRoute(tc)
        % The direct ARMA autocovariance (arma2acv, exact Lyapunov) must equal
        % the spectral route arma2psd -> spec2acv at integer sample lags.
        Fs = 10; b = [1 -0.5]; a = [1 -1.2 0.6]; s2 = 2.0; L = 20;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 200000);
        Rspec  = timeSeriesPreparation.spectral.spec2acv(f, S, 'Method', 'direct', 'Lags', (0:L)'/Fs);
        Racv   = timeSeriesPreparation.spectral.arma2acv(b, a, L, 'NoiseVariance', s2);
        tc.verifyEqual(Racv, Rspec, 'RelTol', 5e-4, 'AbsTol', 1e-6*Racv(1));
    end

    function arma2acvVarianceMatchesArma2psd(tc)
        % R(0) from arma2acv equals trapz(f,S) from arma2psd (process variance).
        Fs = 500; b = [1 -0.4 0.15]; a = [1 -1.1 0.5]; s2 = 1.3;
        [S, f, info] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 16384);
        [R, ~, ainfo] = timeSeriesPreparation.spectral.arma2acv(b, a, 5, 'NoiseVariance', s2);
        tc.verifyEqual(R(1), info.variance, 'RelTol', 2e-3);
        tc.verifyEqual(ainfo.variance, R(1), 'AbsTol', 1e-12);
    end

    end

    methods (Test, TestTags = {'contract'})

    function psd2armaNoToolboxNeeded(tc)
        % Sanity: the fit runs and is accurate using only base MATLAB.
        Fs = 500; f = logspace(-2, log10(Fs/2), 400).';
        S = 1 ./ (1 + (f/5).^2).^2;
        [~, ~, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [4 4]);
        tc.verifyLessThan(res.RMSErrorDb, 1.5);
    end

    function psd2armaStmcbBaseMATLAB(tc)
        % The Steiglitz-McBride path must also run without a toolbox.
        Fs = 400; f = logspace(-2, log10(Fs/2), 300).';
        S = 1 ./ (1 + (f/8).^2);
        [b, a, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [4 4], 'Method', 'stmcb');
        tc.verifyTrue(all(isfinite(b)) && all(isfinite(a)));
        tc.verifyLessThan(res.RMSErrorDb, 3.0);
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function psd2armaRoundTrip(tc)
        % Build a known ARMA PSD, fit it, re-evaluate: PSDs must agree.
        tc.assumeTrue(true);  % psd2arma is now base MATLAB, always runnable
        Fs = 500; bt = [1 -0.4 0.15]; at = [1 -1.1 0.5];
        [Starget, f] = timeSeriesPreparation.spectral.arma2psd(bt, at, Fs, 'NFreq', 1024);
        [b, a, res] = timeSeriesPreparation.spectral.psd2arma(f, Starget, Fs, 'Order', [2 2]);
        Sfit = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', res.NoiseVariance, ...
                        'Frequencies', f);
        rel = abs(Sfit - Starget) ./ max(Starget, max(Starget)*1e-6);
        tc.verifyLessThan(median(rel), 0.05);
        tc.verifyTrue(res.IsStable);
    end

    end
end
