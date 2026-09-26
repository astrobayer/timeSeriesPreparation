classdef synthTimeSeriesTest < matlab.unittest.TestCase
%SYNTHTIMESERIESTEST  synthTimeSeries: PSD and ARMA synthesis, variance, spectrum and no warm-up.
%
%   DESCRIPTION
%     synthTimeSeries draws a stationary series with a given PSD or ARMA
%     model. Checked here: the variance and the averaged periodogram against
%     the target in both modes, the absence of a warm-up transient (first
%     block against last block mean square), the output shape and options,
%     reproducibility with Seed, ASD input, odd lengths and the refusal of
%     bad input.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - variance and averaged periodogram match the target PSD
%                    or the ARMA theory (5 %, 15 % median); first and last
%                    block have equal mean square; arma2psd -> synthesis
%                    keeps the variance.
%     contract     - size, time axis and realness; NColumns gives distinct
%                    columns; Mean is applied; info flags the warm-up-free
%                    spectral method.
%     metamorphic  - the same Seed gives the same series; ASD input equals
%                    its square as PSD.
%     robustness   - an unknown mode and a frequency above Nyquist are
%                    refused; an odd length stays real with the right
%                    variance.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})

    % ---------------------------------------------------- PSD accuracy
    function psdVarianceMatchesTrapz(tc)
        Fs = 500; N = 2^16;
        f = (0:0.25:Fs/2)'; S = 1./(1+(f/20).^4);
        [x, ~, info] = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 3);
        tc.verifyEqual(var(x), trapz(f, S), 'RelTol', 0.05);
        tc.verifyEqual(info.targetVariance, trapz(f, S), 'RelTol', 1e-10);
    end

    function psdMatchesTargetAveraged(tc)
        % Average many realisations -> periodogram tracks the target PSD.
        Fs = 400; N = 4096;
        f = (0:0.5:Fs/2)'; S = 1./(1+(f/15).^2);
        M = 200; acc = zeros(N/2+1,1);
        for r = 1:M
            x = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 100+r);
            X = fft(x); acc = acc + (2/(Fs*N))*abs(X(1:N/2+1)).^2;
        end
        Pxx = acc/M; fk = (0:N/2)'*Fs/N;
        St = interp1(f, S, fk);
        band = fk > 2 & fk < 150;
        relErr = abs(Pxx(band) - St(band)) ./ St(band);
        tc.verifyLessThan(median(relErr), 0.15);
    end

    function psdNoWarmupTransient(tc)
        % Mean square of the first block equals that of the last block.
        Fs = 500; N = 2048;
        f = (0:0.5:Fs/2)'; S = 1./(1+(f/10).^4);   % strongly coloured
        K = 400; L = 64;
        msFirst = zeros(L,1); msLast = zeros(L,1);
        for r = 1:K
            x = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 500+r);
            msFirst = msFirst + x(1:L).^2;
            msLast  = msLast  + x(end-L+1:end).^2;
        end
        ratio = mean(msFirst) / mean(msLast);
        tc.verifyEqual(ratio, 1, 'AbsTol', 0.1);   % stationary => ~1
    end

    % --------------------------------------------------- ARMA mode
    function armaVarianceMatchesTheory(tc)
        b = [1 -0.5 0.2]; a = [1 -1.2 0.6]; Fs = 500; N = 2^17; s2 = 2;
        [x, ~, info] = timeSeriesPreparation.spectral.synthTimeSeries('arma', b, a, Fs, N, ...
            'NoiseVariance', s2, 'Seed', 9);
        imp = filter(b, a, [1; zeros(8000,1)]);
        tc.verifyEqual(var(x), s2*sum(imp.^2), 'RelTol', 0.05);
        tc.verifyEqual(info.targetVariance, s2*sum(imp.^2), 'RelTol', 1e-6);
    end

    function armaNoWarmupTransient(tc)
        % The key property: stationary from sample 1 (no filter ramp-up).
        b = [1 -0.5 0.2]; a = [1 -1.4 0.7]; Fs = 500; N = 400; s2 = 1;
        K = 3000; L = 40;
        msFirst = zeros(L,1); msLast = zeros(L,1);
        for r = 1:K
            x = timeSeriesPreparation.spectral.synthTimeSeries('arma', b, a, Fs, N, 'NoiseVariance', s2, 'Seed', 2000+r);
            msFirst = msFirst + x(1:L).^2;
            msLast  = msLast  + x(end-L+1:end).^2;
        end
        tc.verifyEqual(mean(msFirst)/mean(msLast), 1, 'AbsTol', 0.08);
    end

    function armaSpectrumMatchesArma2psd(tc)
        % Averaged periodogram of the synthesised ARMA series matches arma2psd.
        b = [1 0.3]; a = [1 -0.8]; Fs = 300; N = 4096; s2 = 1;
        [Sref, fref] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', s2, 'NFreq', N/2);
        M = 200; acc = zeros(N/2+1,1);
        for r = 1:M
            x = timeSeriesPreparation.spectral.synthTimeSeries('arma', b, a, Fs, N, 'NoiseVariance', s2, 'Seed', 3000+r);
            X = fft(x); acc = acc + (2/(Fs*N))*abs(X(1:N/2+1)).^2;
        end
        Pxx = acc/M; fk = (0:N/2)'*Fs/N;
        Si = interp1(fref, Sref, fk, 'linear', 'extrap');
        band = fk > 2 & fk < 140;
        tc.verifyLessThan(median(abs(Pxx(band)-Si(band))./Si(band)), 0.15);
    end

    % ------------------------------------------- round trip & validation
    function roundTripArma2psd(tc)
        % arma2psd -> synthTimeSeries('psd') -> variance preserved.
        b = [1 -0.4 0.15]; a = [1 -1.1 0.5]; Fs = 500; N = 2^16;
        [S, f] = timeSeriesPreparation.spectral.arma2psd(b, a, Fs, 'NoiseVariance', 1, 'NFreq', 2048);
        [x, ~, info] = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 11);
        tc.verifyEqual(var(x), info.targetVariance, 'RelTol', 0.05);
    end

    end

    methods (Test, TestTags = {'contract'})

    % ---------------------------------------------------------- basics
    function outputShapeAndReal(tc)
        Fs = 500; N = 4096;
        f = (0:0.5:Fs/2)'; S = 1./(1+(f/20).^4);
        [x, t] = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 1);
        tc.verifySize(x, [N 1]);
        tc.verifySize(t, [N 1]);
        tc.verifyTrue(isreal(x));
        tc.verifyEqual(t(2)-t(1), 1/Fs, 'RelTol', 1e-12);
    end

    function multiColumn(tc)
        Fs = 200; N = 2048;
        f = (0:0.5:Fs/2)'; S = ones(size(f));
        x = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'NColumns', 4, 'Seed', 2);
        tc.verifySize(x, [N 4]);
        % columns are distinct realisations
        tc.verifyGreaterThan(min(std(x)), 0);
        cc = corrcoef(x(:,1), x(:,2));
        tc.verifyLessThan(abs(cc(1,2)), 0.2);
    end

    function meanOffsetApplied(tc)
        Fs = 100; N = 8192; f = (0:0.5:Fs/2)'; S = ones(size(f));
        x = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Mean', 5, 'Seed', 13);
        tc.verifyEqual(mean(x), 5, 'AbsTol', 0.2);
    end

    function infoWarmupFlag(tc)
        f = (0:0.5:50)'; S = ones(size(f));
        [~, ~, info] = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, 100, 1024, 'Seed', 1);
        tc.verifyTrue(info.warmupFree);
        tc.verifyEqual(info.method, 'spectral');
    end

    end

    methods (Test, TestTags = {'metamorphic'})

    function reproducibleWithSeed(tc)
        Fs = 100; N = 1024; f = (0:0.5:Fs/2)'; S = 1./(1+f);
        x1 = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 42);
        x2 = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 42);
        tc.verifyEqual(x1, x2, 'AbsTol', 0);
    end

    function asdInputEqualsPsdSquared(tc)
        Fs = 200; N = 8192;
        f = (0:0.5:Fs/2)'; A = 1./(1+(f/10).^2);
        x1 = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, A.^2, Fs, N, 'Seed', 7);
        x2 = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, A, Fs, N, 'InputType','asd', 'Seed', 7);
        tc.verifyEqual(x1, x2, 'RelTol', 1e-10);
    end

    end

    methods (Test, TestTags = {'robustness'})

    function rejectsBadMode(tc)
        tc.verifyError(@() timeSeriesPreparation.spectral.synthTimeSeries('bogus', 1, 1, 100, 10), ...
            'timeSeriesPreparation:synthTimeSeries:mode');
    end

    function rejectsFreqAboveNyquist(tc)
        tc.verifyError(@() timeSeriesPreparation.spectral.synthTimeSeries('psd', [0;60], [1;1], 100, 1024), ...
            'timeSeriesPreparation:synthTimeSeries:freqRange');
    end

    function oddLengthOutputIsReal(tc)
        % Hermitian assembly must also be correct for odd N.
        Fs = 100; N = 4097; f = (0:0.5:Fs/2)'; S = 1./(1+(f/10).^2);
        x = timeSeriesPreparation.spectral.synthTimeSeries('psd', f, S, Fs, N, 'Seed', 5);
        tc.verifySize(x, [N 1]);
        tc.verifyTrue(isreal(x));
        tc.verifyEqual(var(x), trapz(f, S), 'RelTol', 0.08);
    end

    end
end
