classdef psd2armaTest < matlab.unittest.TestCase
%PSD2ARMATEST  psd2arma: rational ARMA fit of a PSD, stability, input types and order search.
%
%   DESCRIPTION
%     psd2arma fits a discrete-time ARMA model to a given PSD, in base
%     MATLAB. Checked here: the accuracy of the reconstructed PSD, the
%     enforcement of stable poles and minimum-phase zeros, ASD against PSD
%     input, the automatic order search, that white noise filtered with the
%     returned (b,a) has the target spectral shape, the warning on out-of-
%     range frequencies, and the diagnostic plot of the fit.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - a low-pass PSD is fitted within 1 dB RMS; filtered
%                    white noise keeps the target band-power ratio.
%     contract     - EnforceStability and EnforceMinPhaseZeros hold and are
%                    flagged; the auto order meets Tol; the fit plot returns
%                    a figure.
%     metamorphic  - ASD input gives the same fit as its square as PSD
%                    input.
%     robustness   - frequencies below zero or above Nyquist raise a
%                    warning.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function lowpassFitAccurate(tc)
        f  = logspace(-2, 2, 500).';
        S  = 1 ./ (1 + (f/5).^2).^2;         % 2nd-order low-pass PSD
        Fs = 500;
        [b, a, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [4 4]);
        tc.verifyTrue(all(isfinite(b)) && all(isfinite(a)));
        tc.verifyLessThan(res.RMSErrorDb, 1.0);
    end

    function synthesisReproducesShape(tc)
        % Filter white noise with (b,a); its empirical PSD ratio between two
        % bands must track the target ratio.
        rng(301);
        f  = logspace(-1, log10(250), 400).';
        S  = 1 ./ (1 + (f/10).^4);           % steep low-pass
        Fs = 500;
        [b, a, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [6 6]);
        x = filter(b, a, randn(2e5,1) * sqrt(res.NoiseVariance));
        % crude band-power ratio via FFT
        X = abs(fft(x - mean(x))).^2;
        nfft = numel(x); fx = (0:nfft-1)'/nfft*Fs;
        low  = mean(X(fx > 2  & fx < 6));
        high = mean(X(fx > 60 & fx < 100));
        tc.verifyGreaterThan(low/high, 10);  % low band clearly dominant
    end

    end

    methods (Test, TestTags = {'contract'})

    function enforcesStability(tc)
        f  = logspace(-2, 2, 400).';
        S  = 1 ./ (1 + (f/8).^2);
        Fs = 400;
        [~, a, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [6 6], 'EnforceStability', true);
        tc.verifyTrue(all(abs(roots(a)) < 1));
        tc.verifyTrue(res.IsStable);
    end

    function enforcesMinPhaseZeros(tc)
        f  = logspace(-2, 2, 400).';
        S  = (1 + (f/20).^2) ./ (1 + (f/4).^4);
        Fs = 400;
        [b, ~, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [6 6], 'EnforceMinPhaseZeros', true);
        tc.verifyTrue(all(abs(roots(b)) <= 1 + 1e-8));
        tc.verifyTrue(res.IsMinPhaseZeros);
    end

    function autoOrderMeetsTolerance(tc)
        f  = logspace(-2, 2, 500).';
        S  = 1 ./ (1 + (f/5).^2).^2;
        Fs = 500;
        [~, ~, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', 'auto', ...
            'OrderCriterion', 'tol', 'Tol', 1.0, 'MaxOrder', 12);
        tc.verifyLessThanOrEqual(res.RMSErrorDb, 1.0 + 1e-9);
        tc.verifyTrue(res.OrderInfo.searched);
    end

    function displayRuns(tc)
        f  = logspace(-2, 2, 300).';
        S  = 1 ./ (1 + (f/5).^2).^2;
        Fs = 500;
        [~, ~, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [4 4]);
        h = timeSeriesPreparation.spectral.plotPsd2armaFit(res);
        figH = h.figure;
        tc.addTeardown(@() close(figH));
        tc.verifyTrue(ishghandle(figH));
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function asdEqualsSqrtPsd(tc)
        f  = logspace(-2, 2, 300).';
        A  = 1 ./ (1 + (f/6).^2);            % amplitude spectral density
        Fs = 400;
        [~, ~, rP] = timeSeriesPreparation.spectral.psd2arma(f, A.^2, Fs, 'Order', [4 4], 'InputType', 'psd');
        [~, ~, rA] = timeSeriesPreparation.spectral.psd2arma(f, A,     Fs, 'Order', [4 4], 'InputType', 'asd');
        tc.verifyEqual(rA.PSDfit, rP.PSDfit, 'RelTol', 1e-6);
    end

    end

    methods (Test, TestTags = {'robustness'})

    function clipsOutOfRangeFreqs(tc)
        f  = [-5; logspace(-2, 3, 200).'];   % includes negative + > Fs/2
        S  = 1 ./ (1 + (abs(f)/5).^2);
        Fs = 400;                             % Fs/2 = 200 < 1000
        tc.verifyWarning(@() timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [4 4]), ...
            'timeSeriesPreparation:psd2arma:freqRange');
    end

    end
end
