classdef plotPowerSpectrumTest < matlab.unittest.TestCase
%PLOTPOWERSPECTRUMTEST  powerSpectrum and plotPowerSpectrum: scaling, peaks, Welch and Lomb-Scargle.
%
%   DESCRIPTION
%     The sigtools v1.3.1 suite of plotPowerSpectrum, carried over at X-02
%     to the split into powerSpectrum (numbers) and plotPowerSpectrum
%     (drawing). Every assertion of v1.3.1 is kept; only the calls changed:
%     a series is one powerSpectrum call, and peaks are fields of its
%     result. The checks cover:
%       - the amplitude and PSD scaling;
%       - peak detection with sub-bin refinement;
%       - the FFT (Welch) and Lomb-Scargle branches, and the switch on gaps,
%         uneven sampling or custom frequencies;
%       - the false-alarm levels, datetime time stamps, and the handles of
%         a multi-series plot.
%     Figures go to invisible axes and are closed in teardown.
%
%   COVERAGE
%     reference    - a sinusoid peaks at its amplitude (rect window, 5 %;
%                    flattop off-bin, 3 %); the one-sided PSD integrates to
%                    the variance (15 %); more Welch averages scatter less.
%     contract     - custom frequencies force Lomb-Scargle on that grid; FAP
%                    levels are filled; two series give two spectra and two
%                    plotted lines.
%     robustness   - NaN gaps and uneven sampling switch to Lomb-Scargle and
%                    still find the peak; datetime stamps work; a call
%                    without data is refused.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties
        fig
    end

    methods (TestMethodTeardown)
        function closeFigs(tc)
            if ~isempty(tc.fig) && all(isgraphics(tc.fig))
                close(tc.fig);
            end
            tc.fig = [];
        end
    end

    methods (Access = private)
        function ax = freshAxes(tc)
            tc.fig = figure('Visible','off');
            ax = axes('Parent', tc.fig);
        end
    end

    methods (Test, TestTags = {'reference'})

    function amplitudeScalingFFT(tc)
        % A pure sinusoid at an on-bin frequency must peak at ~A.
        rng(201);
        fs = 200; t = (0:1/fs:40)'; A = 1.7; f0 = 5;
        x = A*sin(2*pi*f0*t);
        S = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Label', 's', 'Type','amplitude', ...
            'Window','rect', 'NPeaks',1);
        tc.verifyEqual(S.method, 'fft');
        tc.verifyEqual(S.peakFrequency, f0, 'AbsTol', 0.2);
        tc.verifyEqual(S.peakValue, A, 'RelTol', 0.05);
    end

    function psdParsevalApprox(tc)
        % One-sided PSD integrated over f ~ variance of the (detrended) signal.
        rng(202);
        fs = 100; t = (0:1/fs:60)';
        x = randn(numel(t),1);
        S = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Type','psd', ...
            'Window','rect', 'Detrend','mean');
        df = S.frequency(2) - S.frequency(1);
        integ = sum(S.power)*df;          % one-sided integral
        tc.verifyEqual(integ, var(x,1), 'RelTol', 0.15);
    end

    function welchReducesVariance(tc)
        % More Welch averages -> smaller noise-floor scatter (lower std of log PSD).
        rng(206);
        fs = 100; t = (0:1/fs:120)';
        x = randn(numel(t),1);
        S1 = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'NAvg',1);
        S8 = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'NAvg',8, 'Overlap',0.5);
        s1 = std(log(S1.power(S1.frequency>1)));
        s8 = std(log(S8.power(S8.frequency>1)));
        tc.verifyLessThan(s8, s1);
        tc.verifyEqual(S8.nseg, 8);
    end

    function peaksSubBinRefinement(tc)
        % Off-bin frequency: parabolic refinement should beat the raw bin.
        rng(208);
        fs = 1000; t = (0:1/fs:5)';
        f0 = 123.37; x = 2*sin(2*pi*f0*t);
        S = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Type','amplitude', ...
            'Window','flattop', 'NPeaks',1);
        tc.verifyEqual(S.peakFrequency, f0, 'AbsTol', 0.5);
        tc.verifyEqual(S.peakValue, 2.0, 'RelTol', 0.03);
    end

    end

    methods (Test, TestTags = {'contract'})

    function customFrequenciesForceLomb(tc)
        rng(205);
        fs = 20; t = (0:1/fs:50)';
        x = sin(2*pi*2*t) + 0.3*randn(numel(t),1);
        fgrid = linspace(0.1, 8, 300);
        S = timeSeriesPreparation.spectral.powerSpectrum(fs, x, 'Frequencies', fgrid);
        tc.verifyEqual(S.method, 'lomb-scargle');
        tc.verifyEqual(numel(S.frequency), numel(fgrid));
    end

    function multiSeriesOutputs(tc)
        rng(207);
        fs = 100; t = (0:1/fs:20)';
        x1 = sin(2*pi*5*t);
        t2 = sort(20*rand(800,1)); x2 = sin(2*pi*7*t2);
        S = [timeSeriesPreparation.spectral.powerSpectrum(t, x1, 'Label', 'A', 'NPeaks',1), ...
             timeSeriesPreparation.spectral.powerSpectrum(t2, x2, 'Label', 'B', 'NPeaks',1)];
        ax = tc.freshAxes();
        H = timeSeriesPreparation.spectral.plotPowerSpectrum(S, 'Axes', ax);
        tc.verifySize(S, [1 2]);
        tc.verifyNumElements(S(1).peakFrequency, 1);
        tc.verifyNumElements(S(2).peakFrequency, 1);
        tc.verifyEqual(S(1).method, 'fft');
        tc.verifyEqual(S(2).method, 'lomb-scargle');
        tc.verifyNumElements(H.lines, 2);
        tc.verifyNumElements(H.peakMarkers, 2);
    end

    function fapLevelsPopulated(tc)
        rng(209);
        t = sort(100*rand(600,1));
        x = 0.5*sin(2*pi*t/13) + randn(size(t));
        S = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'FAP',[0.05 0.01], ...
            'MaxFreq',0.5);
        tc.verifyNotEmpty(S.fapLevels);
        tc.verifyNumElements(S.fapLevels.fap, 2);
        tc.verifyEqual(S.fapLevels.method, 'analytic');
        ax = tc.freshAxes();
        H = timeSeriesPreparation.spectral.plotPowerSpectrum(S, 'Axes', ax);
        tc.verifyNumElements(H.fapLines, 2);
    end

    end

    methods (Test, TestTags = {'robustness'})

    function lombBranchOnGaps(tc)
        % NaN gaps must switch the estimator to Lomb-Scargle.
        rng(203);
        fs = 50; t = (0:1/fs:40)';
        x = 1.2*sin(2*pi*3*t) + 0.3*randn(numel(t),1);
        x(500:650) = NaN;
        S = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'Label', 'gap', 'Type','amplitude', ...
            'NPeaks',1);
        tc.verifyEqual(S.method, 'lomb-scargle');
        tc.verifyEqual(S.peakFrequency, 3, 'AbsTol', 0.1);
    end

    function unevenSamplingLomb(tc)
        rng(204);
        t = sort(30*rand(1500,1));
        x = 2.0*sin(2*pi*4*t) + 0.4*randn(size(t));
        S = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'Type','amplitude', ...
            'NPeaks',1, 'MaxFreq',10);
        tc.verifyEqual(S.method, 'lomb-scargle');
        tc.verifyEqual(S.peakFrequency, 4, 'AbsTol', 0.1);
        tc.verifyEqual(S.peakValue, 2.0, 'RelTol', 0.15);
    end

    function datetimeTimeVector(tc)
        rng(210);
        fs = 10; n = 600;
        t0 = datetime(2026,1,1);
        t  = t0 + seconds((0:n-1)'/fs);
        x  = sin(2*pi*1.5*seconds(t-t0)) + 0.2*randn(n,1);
        S = timeSeriesPreparation.spectral.powerSpectrum(t, x, 'Type','amplitude', ...
            'NPeaks',1);
        tc.verifyEqual(S.method, 'fft');
        tc.verifyEqual(S.peakFrequency, 1.5, 'AbsTol', 0.1);
    end

    function badInputErrors(tc)
        tc.verifyError(@() timeSeriesPreparation.spectral.powerSpectrum(), ?MException);
        tc.verifyError(@() timeSeriesPreparation.spectral.plotPowerSpectrum(struct('x', 1)), ...
            'timeSeriesPreparation:plotPowerSpectrum:badSpec');
    end

    end
end
