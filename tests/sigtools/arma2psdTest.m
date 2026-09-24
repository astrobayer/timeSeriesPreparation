classdef arma2psdTest < matlab.unittest.TestCase
%ARMA2PSDTEST  arma2psd: PSD scaling, output options and round trips through psd2arma and spec2acv.
%
%   DESCRIPTION
%     arma2psd evaluates the one- or two-sided PSD of an ARMA model. Checked
%     here: the variance identity (the integrated PSD equals the time-domain
%     output variance), the flat level of white noise, ASD and two-sided
%     output, a custom frequency grid, and the round trips arma2psd ->
%     psd2arma -> arma2psd and arma2psd -> spec2acv that tie the spectral
%     and time-series halves of sigtools together.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - trapz(f,S) and info.variance equal sigma^2*sum(psi^2)
%                    (1e-3); white noise is flat at 2*sigma^2/Fs; spec2acv
%                    of the AR(1) PSD matches the closed-form ACV (5 %).
%     contract     - a custom frequency grid is returned as given, and one
%                    above Nyquist is refused.
%     metamorphic  - ASD equals sqrt(PSD); the two-sided level is half the
%                    one-sided; a psd2arma refit reproduces the PSD within
%                    0.5 dB RMS.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    function varianceIdentity(tc)
        % trapz(f,S) must equal the time-domain output variance sigma^2*sum(psi^2).
        Fs = 500; b = [1 -0.5 0.2]; a = [1 -1.2 0.6]; s2 = 1.3;
        [S, f, info] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', 8192);
        imp = filter(b, a, [1; zeros(8000,1)]);
        varTD = s2 * sum(imp.^2);
        tc.verifyEqual(info.variance, varTD, 'RelTol', 1e-3);
        tc.verifyEqual(trapz(f, S),   varTD, 'RelTol', 1e-3);
    end

    function whiteNoiseFlatPsd(tc)
        % b=a=1 -> H=1 -> flat one-sided PSD = 2*sigma^2/Fs.
        Fs = 200; s2 = 2.5;
        [S, ~] = timeSeriesPreparation.spectral.arma2psd(1, 1, Fs, 'NoiseVariance', s2);
        tc.verifyEqual(S, repmat(2*s2/Fs, size(S)), 'RelTol', 1e-12);
    end

    function roundTripThroughSpec2acv(tc)
        % arma2psd -> spec2acv must reproduce the ARMA autocovariance, which
        % for AR(1) is R(k) = sigma^2/(1-phi^2) * phi^|k|.
        Fs = 200; phi = 0.6; s2 = 1.0;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(1, [1 -phi], Fs, 'NoiseVariance', s2, 'NFreq', 8192);
        [R, lags] = timeSeriesPreparation.spectral.spec2acv(f, S, Window="tukey", WindowParam=0.25);
        v0 = s2/(1 - phi^2);
        Rref = v0 * phi.^round(lags*Fs);         % lags spaced at 1/Fs
        m = lags <= 0.05;                        % first ~10 lags
        tc.verifyLessThan(max(abs(R(m) - Rref(m))), 0.05*v0);
    end

    end

    methods (Test, TestTags = {'contract'})

    function customFrequencyGrid(tc)
        Fs = 1000; b = 1; a = [1 -0.9];
        fg = linspace(0, Fs/2, 257).';
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Frequencies', fg);
        tc.verifyEqual(f, fg, 'AbsTol', 1e-12);
        tc.verifySize(S, size(fg));
        tc.verifyError(@() timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Frequencies', [0; Fs]), ...
            'timeSeriesPreparation:arma2psd:freqRange');
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function asdIsSqrtPsd(tc)
        Fs = 400; b = [1 0.3]; a = [1 -0.8];
        Sp = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Output', 'psd');
        Sa = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Output', 'asd');
        tc.verifyEqual(Sa, sqrt(Sp), 'RelTol', 1e-12);
    end

    function twoSidedHalfLevel(tc)
        Fs = 400; b = [1 0.3]; a = [1 -0.8];
        S1 = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Sided', 'one');
        S2 = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'Sided', 'two');
        tc.verifyEqual(S2, S1/2, 'RelTol', 1e-12);
    end

    % ---------------------------------------------- integration round trips
    function roundTripThroughPsd2arma(tc)
        % arma2psd(model) -> psd2arma should recover a PSD that matches.
        Fs = 500; b0 = [1 -0.5 0.2]; a0 = [1 -1.2 0.6];
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b0, a0, Fs, 'NFreq', 1024);
        [b1, a1, res] = timeSeriesPreparation.spectral.psd2arma(f, S, Fs, 'Order', [2 2]);
        S1 = timeSeriesPreparation.spectral.arma2psd(b1, a1, Fs, 'Frequencies', f, ...
                      'NoiseVariance', res.NoiseVariance);
        errDb = 10*log10(max(S1,1e-30) ./ max(S,1e-30));
        tc.verifyLessThan(sqrt(mean(errDb.^2)), 0.5);   % < 0.5 dB RMS
    end

    end
end
