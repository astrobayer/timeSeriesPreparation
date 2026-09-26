classdef TestSigtoolsEquivalence < matlab.unittest.TestCase
%TESTSIGTOOLSEQUIVALENCE  ORC-8: every sigtools function gives v1.3.1's numbers, bit for bit.
%
%   DESCRIPTION
%     X-02 changed sigtools' conventions (arguments blocks, identifiers,
%     help, one Lyapunov solver, plotting split out) and promised the
%     numbers unchanged (CONCEPT 10.1, 12.5). This is the gate. The archived
%     docs/inputs/sigtools_v1.3.1.zip is unzipped into a temporary folder
%     and its spectral/ and tsmodels/ put on the path, where the original
%     functions answer to their unqualified names. Each case calls the
%     original and the converted function on the same data, with the
%     global random stream reset to the same seed before each call, and
%     requires isequaln over all outputs.
%
%     The four split functions compare what they share:
%       - plotPowerSpectrum's spectra and peaks against powerSpectrum;
%       - allanVariance without doPlot;
%       - psd2arma without Display;
%       - tsCheckResiduals without its figure field (and without the Q-Q
%         fields it gained).
%     Figures drawn by the originals are closed. Every archived function is
%     covered by at least one case, and a planted difference of one ulp
%     must fire the comparison (fault injection).
%
%   COVERAGE
%     reference   - one case per behaviour: each function's default call
%                   and its option branches (exact/CSS/Yule-Walker, gaps,
%                   seasonal, bootstrap, Welch/Lomb-Scargle/FAP, psi and
%                   Lyapunov, direct and FFT ACV, PSD and ARMA synthesis).
%     contract    - every function of the archive's spectral/ and tsmodels/
%                   is covered by a case.
%     robustness  - a one-ulp change of an output is detected.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Case
    end

    methods (TestParameterDefinition, Static)
        function Case = defineCases()
            Case = cellstr(caseNames());
        end
    end

    properties (Access = private)
        Archive
    end

    methods (TestClassSetup)
        function archiveOnPath(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            zipFile = fullfile(root, "docs", "inputs", "sigtools_v1.3.1.zip");
            testCase.assertTrue(isfile(zipFile), "Archive missing: " + zipFile);
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            unzip(zipFile, tmp);
            testCase.Archive = string(tmp);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                {fullfile(tmp, "spectral"), fullfile(tmp, "tsmodels")}));
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                ["psd2arma:toleranceNotMet" "timeSeriesPreparation:psd2arma:toleranceNotMet" ...
                 "plotPowerSpectrum:fapResolution" "timeSeriesPreparation:powerSpectrum:fapResolution"]));
        end
    end

    methods (Test, TestTags = {'reference'})
        function outputsEqualArchive(testCase, Case)
            c = caseDef(Case);
            before = findall(groot, "Type", "figure");
            cleanup = onCleanup(@() closeNew(before));
            rng(c.seed, "twister");
            old = c.old();
            rng(c.seed, "twister");
            new = c.new();
            testCase.verifyTrue(isequaln(old, new), ...
                Case + ": outputs differ from sigtools v1.3.1.");
        end
    end

    methods (Test, TestTags = {'contract'})
        function everyArchivedFunctionIsCovered(testCase)
            archived = strings(0, 1);
            for sub = ["spectral" "tsmodels"]
                d = dir(fullfile(testCase.Archive, sub, "*.m"));
                archived = [archived; erase(string({d.name})', ".m")]; %#ok<AGROW>
            end
            archived = setdiff(archived, "Contents");
            covered = strings(0, 1);
            for name = caseNames()
                covered = [covered; caseDef(name).covers(:)]; %#ok<AGROW>
            end
            testCase.verifyEmpty(setdiff(archived, covered), ...
                "Archived sigtools functions without an equivalence case.");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function oneUlpFires(testCase)
            c = caseDef("arma2acv_lyapunov");
            old = c.old();
            new = old;
            new{1}(3) = new{1}(3) + eps(new{1}(3));
            testCase.verifyFalse(isequaln(old, new));
            testCase.verifyTrue(isequaln(old, c.new()));
        end
    end
end

% ------------------------------------------------------------------------

function names = caseNames()
% Every case of caseDef, in order.
    names = ["arma2acv_lyapunov" "arma2acv_psiAcf" "arma2psd_default" ...
        "arma2psd_options" "sfreqz_radians" "sfreqz_hertz" "sinvfreqz" ...
        "sstmcb" "psd2arma_fixedOrder" "psd2arma_autoOrder" "spec2acv_ifft" ...
        "spec2acv_direct" "synthTimeSeries_psd" "synthTimeSeries_arma" ...
        "allanVariance_default" "allanVariance_mCi" "powerSpectrum_fftPeaks" ...
        "powerSpectrum_welch" "powerSpectrum_lombGaps" ...
        "powerSpectrum_lombBootstrap" "powerSpectrum_frequencies" ...
        "tsAcf_gaps" "tsPacf" "tsPacf_makePSD" "tsDiff_tsIntegrate" ...
        "tsLjungBox" "tsFitArima_exact" "tsFitArima_css" "tsFitArima_yw" ...
        "tsFitArima_gaps" "tsFitAR_MA_ARMA" "tsAutoArima" "tsFitSarima_css" ...
        "tsFitSarima_exact" "tsAutoSarima" "tsForecast_gaussian" ...
        "tsForecast_bootstrap" "tsForecast_sarima" "tsCheckResiduals" ...
        "tsModelDisp"];
end

function c = caseDef(name)
% Old call, new call (each returning a cell of outputs), seed, functions covered.
    S = "timeSeriesPreparation.spectral.";
    T = "timeSeriesPreparation.tsmodels.";
    sp = @(f) str2func(S + f);
    ts = @(f) str2func(T + f);
    b = [1 0.4]; a = [1 -0.5 0.2];
    x = data(1, 600);
    xg = x; xg([50:60 300:305]) = NaN;
    c = struct("seed", 1, "covers", strings(0, 1));
    switch name
        case "arma2acv_lyapunov"
            c.old = @() outs(@() arma2acv(b, a, 50), 3);
            c.new = @() outs(@() feval(sp("arma2acv"), b, a, 50), 3);
            c.covers = "arma2acv";
        case "arma2acv_psiAcf"
            opts = {'Method', 'psi', 'Output', 'acf', 'Fs', 10, 'NoiseVariance', 2};
            c.old = @() outs(@() arma2acv(b, a, 30, opts{:}), 3);
            c.new = @() outs(@() feval(sp("arma2acv"), b, a, 30, opts{:}), 3);
            c.covers = "arma2acv";
        case "arma2psd_default"
            c.old = @() outs(@() arma2psd(b, a, 10), 3);
            c.new = @() outs(@() feval(sp("arma2psd"), b, a, 10), 3);
            c.covers = "arma2psd";
        case "arma2psd_options"
            opts = {'Frequencies', (0:0.1:5)', 'Output', 'asd', 'Sided', 'two', 'NoiseVariance', 2};
            c.old = @() outs(@() arma2psd(b, a, 10, opts{:}), 3);
            c.new = @() outs(@() feval(sp("arma2psd"), b, a, 10, opts{:}), 3);
            c.covers = "arma2psd";
        case "sfreqz_radians"
            w = linspace(0, pi, 64)';
            c.old = @() outs(@() sfreqz(b, a, w), 2);
            c.new = @() outs(@() feval(sp("sfreqz"), b, a, w), 2);
            c.covers = "sfreqz";
        case "sfreqz_hertz"
            f = linspace(0, 5, 51)';
            c.old = @() outs(@() sfreqz(b, a, f, 10), 2);
            c.new = @() outs(@() feval(sp("sfreqz"), b, a, f, 10), 2);
            c.covers = "sfreqz";
        case "sinvfreqz"
            w = linspace(0, pi, 256)';
            H = sfreqz(b, a, w);
            c.old = @() outs(@() sinvfreqz(H, w, 1, 2, 30), 2);
            c.new = @() outs(@() feval(sp("sinvfreqz"), H, w, 1, 2, 30), 2);
            c.covers = "sinvfreqz";
        case "sstmcb"
            h = filter(b, a, [1; zeros(99, 1)]);
            c.old = @() outs(@() sstmcb(h, 1, 2, 20), 2);
            c.new = @() outs(@() feval(sp("sstmcb"), h, 1, 2, 20), 2);
            c.covers = "sstmcb";
        case "psd2arma_fixedOrder"
            f = logspace(-2, 2, 200)'; Sx = 1 ./ (1 + (f/5).^2).^2;
            c.old = @() outs(@() psd2arma(f, Sx, 500, 'Order', [6 6]), 3);
            c.new = @() outs(@() feval(sp("psd2arma"), f, Sx, 500, 'Order', [6 6]), 3);
            c.covers = ["psd2arma" "sinvfreqz" "sfreqz"];
        case "psd2arma_autoOrder"
            f = logspace(-2, 2, 200)'; Sx = 1 ./ (1 + (f/5).^2).^2;
            opts = {'MaxOrder', 6, 'Tol', 1, 'Method', 'stmcb', 'InputType', 'asd'};
            c.old = @() outs(@() psd2arma(f, sqrt(Sx), 500, opts{:}), 3);
            c.new = @() outs(@() feval(sp("psd2arma"), f, sqrt(Sx), 500, opts{:}), 3);
            c.covers = ["psd2arma" "sstmcb"];
        case "spec2acv_ifft"
            f = linspace(0, 5, 501)'; Sx = 1 ./ (1 + (f/0.5).^2);
            c.old = @() outs(@() spec2acv(f, Sx, 'Output', 'acf'), 3);
            c.new = @() outs(@() feval(sp("spec2acv"), f, Sx, 'Output', 'acf'), 3);
            c.covers = "spec2acv";
        case "spec2acv_direct"
            f = linspace(0, 5, 501)'; Sx = 1 ./ (1 + (f/0.5).^2);
            opts = {'Method', 'direct', 'Lags', (0:10)'};
            c.old = @() outs(@() spec2acv(f, Sx, opts{:}), 3);
            c.new = @() outs(@() feval(sp("spec2acv"), f, Sx, opts{:}), 3);
            c.covers = "spec2acv";
        case "synthTimeSeries_psd"
            f = linspace(0, 5, 501)'; Sx = 1 ./ (1 + (f/0.5).^2);
            c.old = @() outs(@() synthTimeSeries('psd', f, Sx, 10, 1000, 'Seed', 3), 3);
            c.new = @() outs(@() feval(sp("synthTimeSeries"), 'psd', f, Sx, 10, 1000, 'Seed', 3), 3);
            c.covers = "synthTimeSeries";
        case "synthTimeSeries_arma"
            opts = {'Seed', 4, 'NColumns', 2, 'NoiseVariance', 0.5};
            c.old = @() outs(@() synthTimeSeries('arma', b, a, 10, 1000, opts{:}), 3);
            c.new = @() outs(@() feval(sp("synthTimeSeries"), 'arma', b, a, 10, 1000, opts{:}), 3);
            c.covers = "synthTimeSeries";
        case "allanVariance_default"
            X = [data(2, 5000) data(3, 5000)];
            c.old = @() outs(@() allanVariance(X, 10), 4);
            c.new = @() outs(@() feval(sp("allanVariance"), X, 10), 4);
            c.covers = "allanVariance";
        case "allanVariance_mCi"
            X = data(2, 5000);
            c.old = @() outs(@() allanVariance(X, 10, [1 2 4 8 16]', false, 0.95), 4);
            c.new = @() outs(@() feval(sp("allanVariance"), X, 10, [1 2 4 8 16]', 0.95), 4);
            c.covers = "allanVariance";
        case "powerSpectrum_fftPeaks"
            t = (0:1/100:20)'; y = sin(2*pi*3*t) + 0.2*data(4, numel(t));
            opts = {'Type', 'amplitude', 'NPeaks', 2, 'Window', 'flattop'};
            c.old = @() oldSpectrum({{100, y, 's'}}, opts, true);
            c.new = @() newSpectrum({{100, y, 's'}}, opts, true);
            c.covers = ["plotPowerSpectrum" "powerSpectrum"];
        case "powerSpectrum_welch"
            y = data(5, 4096);
            opts = {'NAvg', 8, 'Overlap', 0.5, 'Window', 'hamming', 'Detrend', 'mean'};
            c.old = @() oldSpectrum({{50, y, 'w'}}, opts, false);
            c.new = @() newSpectrum({{50, y, 'w'}}, opts, false);
            c.covers = ["plotPowerSpectrum" "powerSpectrum"];
        case "powerSpectrum_lombGaps"
            t = (0:0.1:200)'; y = sin(2*pi*0.7*t) + 0.3*data(6, numel(t));
            y(400:520) = NaN;
            opts = {'FAP', [0.05 0.01], 'NPeaks', 1, 'Type', 'amplitude'};
            c.old = @() oldSpectrum({{t, y, 'g'}}, opts, true);
            c.new = @() newSpectrum({{t, y, 'g'}}, opts, true);
            c.covers = ["plotPowerSpectrum" "powerSpectrum"];
        case "powerSpectrum_lombBootstrap"
            t = sort(200 * uniform(7, 800)); y = sin(2*pi*1.3*t) + 0.5*data(8, 800);
            opts = {'FAP', 0.05, 'FAPMethod', 'bootstrap', 'NBootstrap', 200, ...
                'LombMethod', 'classic', 'MaxFreq', 4};
            c.old = @() oldSpectrum({{t, y, 'u'}}, opts, false);
            c.new = @() newSpectrum({{t, y, 'u'}}, opts, false);
            c.seed = 11;
            c.covers = ["plotPowerSpectrum" "powerSpectrum"];
        case "powerSpectrum_frequencies"
            t = (0:0.1:100)'; y = sin(2*pi*1.1*t) + 0.2*data(9, numel(t));
            opts = {'Frequencies', linspace(0.5, 2, 61)', 'Detrend', 'none'};
            c.old = @() oldSpectrum({{t, y, 'f'}}, opts, false);
            c.new = @() newSpectrum({{t, y, 'f'}}, opts, false);
            c.covers = ["plotPowerSpectrum" "powerSpectrum"];
        case "tsAcf_gaps"
            c.old = @() outs(@() tsAcf(xg, 20), 4);
            c.new = @() outs(@() feval(ts("tsAcf"), xg, 20), 4);
            c.covers = "tsAcf";
        case "tsPacf"
            c.old = @() outs(@() tsPacf(x, 15), 3);
            c.new = @() outs(@() feval(ts("tsPacf"), x, 15), 3);
            c.covers = "tsPacf";
        case "tsPacf_makePSD"
            c.old = @() outs(@() tsPacf(xg, 15, true), 3);
            c.new = @() outs(@() feval(ts("tsPacf"), xg, 15, true), 3);
            c.covers = "tsPacf";
        case "tsDiff_tsIntegrate"
            y = cumsum(x);
            c.old = @() chain(@() tsDiff(y, 2), @(d, x0) tsIntegrate(d, x0));
            c.new = @() chain(@() feval(ts("tsDiff"), y, 2), ...
                @(d, x0) feval(ts("tsIntegrate"), d, x0));
            c.covers = ["tsDiff" "tsIntegrate"];
        case "tsLjungBox"
            c.old = @() outs(@() tsLjungBox(x, 10, 2), 3);
            c.new = @() outs(@() feval(ts("tsLjungBox"), x, 10, 2), 3);
            c.covers = "tsLjungBox";
        case "tsFitArima_exact"
            c.old = @() {tsFitArima(x, 1, 0, 1)};
            c.new = @() {feval(ts("tsFitArima"), x, 1, 0, 1)};
            c.covers = "tsFitArima";
        case "tsFitArima_css"
            c.old = @() {tsFitArima(cumsum(x), 1, 1, 0, 'Method', 'css', 'Constant', false)};
            c.new = @() {feval(ts("tsFitArima"), cumsum(x), 1, 1, 0, 'Method', 'css', 'Constant', false)};
            c.covers = "tsFitArima";
        case "tsFitArima_yw"
            c.old = @() {tsFitArima(x, 2, 0, 0, 'Method', 'yw')};
            c.new = @() {feval(ts("tsFitArima"), x, 2, 0, 0, 'Method', 'yw')};
            c.covers = "tsFitArima";
        case "tsFitArima_gaps"
            c.old = @() {tsFitArima(xg, 1, 0, 0)};
            c.new = @() {feval(ts("tsFitArima"), xg, 1, 0, 0)};
            c.covers = "tsFitArima";
        case "tsFitAR_MA_ARMA"
            c.old = @() {tsFitAR(x, 2), tsFitMA(x, 1), tsFitARMA(x, 1, 1)};
            c.new = @() {feval(ts("tsFitAR"), x, 2), feval(ts("tsFitMA"), x, 1), ...
                feval(ts("tsFitARMA"), x, 1, 1)};
            c.covers = ["tsFitAR" "tsFitMA" "tsFitARMA"];
        case "tsAutoArima"
            c.old = @() outs(@() tsAutoArima(x, 2, 1, 0), 2);
            c.new = @() outs(@() feval(ts("tsAutoArima"), x, 2, 1, 0), 2);
            c.covers = "tsAutoArima";
        case "tsFitSarima_css"
            z = seasonal(12, 480);
            c.old = @() {tsFitSarima(z, [1 0 0], [1 0 0], 4)};
            c.new = @() {feval(ts("tsFitSarima"), z, [1 0 0], [1 0 0], 4)};
            c.covers = "tsFitSarima";
        case "tsFitSarima_exact"
            z = seasonal(13, 400); z(100:104) = NaN;
            opts = {'Method', 'exact', 'NStart', 2};
            c.old = @() {tsFitSarima(z, [1 0 0], [1 0 0], 4, opts{:})};
            c.new = @() {feval(ts("tsFitSarima"), z, [1 0 0], [1 0 0], 4, opts{:})};
            c.covers = "tsFitSarima";
        case "tsAutoSarima"
            z = seasonal(14, 400);
            c.old = @() outs(@() tsAutoSarima(z, [1 0 1], [1 0 0], 4), 2);
            c.new = @() outs(@() feval(ts("tsAutoSarima"), z, [1 0 1], [1 0 0], 4), 2);
            c.covers = "tsAutoSarima";
        case "tsForecast_gaussian"
            c.old = @() outs(@() tsForecast(tsFitArima(x, 1, 0, 1), 10, 0.05), 4);
            c.new = @() outs(@() feval(ts("tsForecast"), feval(ts("tsFitArima"), x, 1, 0, 1), 10, 0.05), 4);
            c.covers = "tsForecast";
        case "tsForecast_bootstrap"
            opts = {'Bootstrap', true, 'NBoot', 200, 'Seed', 5};
            c.old = @() outs(@() tsForecast(tsFitArima(x, 1, 0, 0), 8, 0.1, opts{:}), 4);
            c.new = @() outs(@() feval(ts("tsForecast"), feval(ts("tsFitArima"), x, 1, 0, 0), 8, 0.1, opts{:}), 4);
            c.covers = "tsForecast";
        case "tsForecast_sarima"
            z = seasonal(12, 480);
            c.old = @() outs(@() tsForecast(tsFitSarima(z, [1 0 0], [1 0 0], 4), 8, 0.05), 4);
            c.new = @() outs(@() feval(ts("tsForecast"), ...
                feval(ts("tsFitSarima"), z, [1 0 0], [1 0 0], 4), 8, 0.05), 4);
            c.covers = "tsForecast";
        case "tsCheckResiduals"
            c.old = @() {rmfield(tsCheckResiduals(tsFitArima(x, 1, 0, 1), 12), 'figure')};
            c.new = @() {rmfield(feval(ts("tsCheckResiduals"), ...
                feval(ts("tsFitArima"), x, 1, 0, 1), 12), {'qqSample', 'qqTheoretical'})};
            c.covers = "tsCheckResiduals";
        case "tsModelDisp"
            c.old = @() {printed(@tsModelDisp, tsFitArima(x, 1, 0, 1))};
            c.new = @() {printed(ts("tsModelDisp"), feval(ts("tsFitArima"), x, 1, 0, 1))};
            c.covers = "tsModelDisp";
        otherwise
            error("TestSigtoolsEquivalence:unknownCase", "No case %s.", name);
    end
end

function closeNew(before)
% Close the figures that did not exist in BEFORE.
    for fig = reshape(findall(groot, "Type", "figure"), 1, [])
        if ~any(fig == before)
            close(fig);
        end
    end
end

function o = outs(f, n)
% The first N outputs of F, as a cell.
    o = cell(1, n);
    [o{:}] = f();
end

function o = chain(first, second)
% tsDiff then tsIntegrate on its outputs: {d, x0, back}.
    [d, x0] = first();
    o = {d, x0, second(d, x0)};
end

function s = printed(fn, model)
% What FN prints for MODEL.
    s = evalc("fn(model)");
end

function o = oldSpectrum(series, opts, withPeaks)
% v1.3.1 plotPowerSpectrum's spectra (and peaks) for SERIES.
    [pk, spec] = plotPowerSpectrum(series{:}, opts{:});
    o = {spec};
    if withPeaks
        o = [o, {[pk.frequency]}, {[pk.amplitude]}];
    end
end

function o = newSpectrum(series, opts, withPeaks)
% powerSpectrum's spectra (and peaks) for SERIES, one call per series.
    spec = struct([]);
    for k = 1:numel(series)
        s = series{k};
        one = timeSeriesPreparation.spectral.powerSpectrum(s{1}, s{2}, ...
            'Label', s{3}, opts{:});
        spec = [spec, one]; %#ok<AGROW>
    end
    o = {rmfield(spec, {'type', 'peakFrequency', 'peakValue'})};
    if withPeaks
        o = [o, {[spec.peakFrequency]}, {[spec.peakValue]}];
    end
end

function x = data(seed, n)
% N samples of an ARMA(1,1) from a fixed stream.
    x = filter([1 0.3], [1 -0.6], randn(RandStream("twister", "Seed", seed), n, 1));
end

function u = uniform(seed, n)
% N uniform samples from a fixed stream.
    u = rand(RandStream("twister", "Seed", seed), n, 1);
end

function z = seasonal(seed, n)
% N samples of a seasonal AR, period 4.
    z = filter(1, conv([1 -0.5], [1 0 0 0 -0.4]), randn(RandStream("twister", "Seed", seed), n, 1));
end
