classdef spec2acvTest < matlab.unittest.TestCase
%SPEC2ACVTEST  spec2acv: autocovariance from a PSD against analytic transform pairs.
%
%   DESCRIPTION
%     spec2acv turns a one- or two-sided PSD (or ASD) into an autocovariance
%     by a cosine transform, with optional smoothing, tapering, resampling
%     of log grids and an uncertainty estimate. Checked here: analytic pairs
%     (band-limited white, Lorentzian, Gaussian), the variance identity, the
%     agreement of the direct and IFFT methods, the decorrelation time
%     scales, the conservation of power by smoothing, the output options,
%     and the repair of NaN, unsorted and duplicate bins.
%
%     This is the sigtools v1.3.1 suite, carried over at X-02 with its
%     assertions unchanged; only the help block and the grouping of the test
%     methods by tag are new.
%
%   COVERAGE
%     reference    - band-limited white, Lorentzian and Gaussian pairs; a
%                    log-spaced grid and custom lags reproduce exp(-a*tau);
%                    the Lorentzian time scales equal 1/a.
%     precision    - R(0) equals trapz(f,S) to 1e-9 (direct method); direct
%                    and IFFT methods agree to 1e-8.
%     contract     - acf is 1 at lag 0; smoothing preserves power (5 %);
%                    InterpFactor extends the lags; Rstd has the size of R
%                    and scales with 1/sqrt(DOF); single input stays single.
%     metamorphic  - ASD input equals its square as PSD; two-sided equals
%                    one-sided; octave smoothing keeps a 1/f^2 variance.
%     robustness   - NaN bins are repaired and counted, or refused with
%                    NanPolicy "error"; shuffled and duplicate bins give the
%                    sorted result.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

methods (Test, TestTags = {'reference'})

    function bandlimitedWhite(tc)
        % S = S0 for f <= B  <->  R(tau) = S0*sin(2*pi*B*tau)/(2*pi*tau)
        B = 100; S0 = 2; df = 0.05;
        f = (0:df:400)';  S = S0*(f <= B);
        [R, tau] = timeSeriesPreparation.spectral.spec2acv(f, S, Method="direct");
        Ra = S0*sin(2*pi*B*tau)./(2*pi*tau);  Ra(1) = S0*B;
        tc.verifyLessThan(max(abs(R - Ra)), 5e-3*Ra(1));
    end

    function lorentzianExponential(tc)
        % G(f) = 4*a*s2/(a^2 + (2*pi*f)^2)  <->  R(tau) = s2*exp(-a*tau)
        a = 5; s2 = 3; df = 0.1;
        f = (0:df:2000)';  G = 4*a*s2 ./ (a^2 + (2*pi*f).^2);
        [R, tau] = timeSeriesPreparation.spectral.spec2acv(f, G);
        m = tau <= 0.5;
        tc.verifyLessThan(max(abs(R(m) - s2*exp(-a*tau(m)))), 1e-3*s2);
    end

    function gaussianPair(tc)
        % R(tau) = s2*exp(-tau^2/(2*tc^2)) <-> G = 2*s2*sqrt(2*pi)*tc*exp(-2*pi^2*f^2*tc^2)
        tcorr = 0.01; s2 = 3; df = 0.5;
        f = (0:df:200)';
        G = 2*s2*sqrt(2*pi)*tcorr*exp(-2*pi^2*f.^2*tcorr^2);
        [R, tau] = timeSeriesPreparation.spectral.spec2acv(f, G);
        m = tau <= 0.1;
        tc.verifyLessThan(max(abs(R(m) - s2*exp(-tau(m).^2/(2*tcorr^2)))), 1e-6*s2);
    end

    function logGridResampling(tc)
        % log-spaced Lorentzian must reproduce the uniform-grid result
        a = 5; s2 = 3;
        % Log grid must span the Lorentzian's support: it has ~0.8% of its
        % variance below 0.01 Hz, so start the grid at 1e-4 (else R(0) is
        % biased low by the unrepresented near-DC band, not a spec2acv bug).
        fl = logspace(-4, 3, 600)';
        Gl = 4*a*s2 ./ (a^2 + (2*pi*fl).^2);
        [Rl, tl, nfo] = timeSeriesPreparation.spectral.spec2acv(fl, Gl, MaxBins=2^20);
        tc.verifyTrue(nfo.resampled);
        tc.verifyEqual(nfo.resampleSpace, "loglog");
        m = tl <= 0.3;
        tc.verifyLessThan(max(abs(Rl(m) - s2*exp(-a*tl(m)))), 5e-3*s2);
    end

    function customLags(tc)
        a = 5; s2 = 3; df = 0.1;
        f = (0:df:2000)';  G = 4*a*s2 ./ (a^2 + (2*pi*f).^2);
        tau = (0:1e-4:0.2)';                   % lag grid unrelated to 1/(2*fNyq)
        R = timeSeriesPreparation.spectral.spec2acv(f, G, Method="direct", Lags=tau);
        tc.verifyLessThan(max(abs(R - s2*exp(-a*tau))), 1e-3*s2);
    end

    function timescalesLorentzian(tc)
        % integral timescale of exp(-a*tau) is 1/a; 1/e time is 1/a
        a = 5; s2 = 3; df = 0.05;
        f = (0:df:2000)';  G = 4*a*s2 ./ (a^2 + (2*pi*f).^2);
        [~, ~, nfo] = timeSeriesPreparation.spectral.spec2acv(f, G);
        tc.verifyEqual(nfo.tauDecorr, 1/a, RelTol=1e-2);
        tc.verifyEqual(nfo.integralTimescale, 1/a, RelTol=5e-2);
    end

end

methods (Test, TestTags = {'precision'})

    function varianceIdentity(tc)
        % R(0) == trapz(f,S) without smoothing/taper (direct: exact)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        [R, ~, nfo] = timeSeriesPreparation.spectral.spec2acv(f, S, Method="direct");
        % R(0) via the direct (NUFFT) cosine transform is accurate to the
        % NUFFT tolerance (~1e-12 rel); nfo.varIn is the exact trapz.
        tc.verifyEqual(R(1), trapz(f, S), RelTol=1e-9);
        tc.verifyEqual(nfo.varIn, trapz(f, S), RelTol=1e-12);
    end

    function directMatchesIfft(tc)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        [Ri, ti] = timeSeriesPreparation.spectral.spec2acv(f, S, Method="ifft");
        [Rd, td] = timeSeriesPreparation.spectral.spec2acv(f, S, Method="direct");
        tc.verifyEqual(td, ti, AbsTol=1e-12);
        tc.verifyEqual(Rd, Ri, RelTol=1e-8, AbsTol=1e-10*max(abs(Ri)));
    end

end

methods (Test, TestTags = {'contract'})

    function acfIsUnitAtZero(tc)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        R = timeSeriesPreparation.spectral.spec2acv(f, S, Output="acf", Window="cosine");
        tc.verifyEqual(R(1), 1, AbsTol=1e-10);
        tc.verifyLessThanOrEqual(max(abs(R)), 1 + 1e-8);
    end

    function smoothingPreservesPower(tc)
        rng(1);
        f = (0:0.1:500)';
        S = (1./(1 + (f/40).^4)) .* (0.5 + rand(size(f)));   % noisy PSD
        for method = ["boxcar","triangle","cosine","gauss","octave"]
            [~, ~, nfo] = timeSeriesPreparation.spectral.spec2acv(f, S, Smooth=method, SmoothWidth=2*(method~="octave") + (1/3)*(method=="octave"));
            tc.verifyEqual(nfo.varOut, nfo.varIn, ...
                "Power not preserved for Smooth=" + method, RelTol=0.05);
        end
    end

    function interpFactorExtendsLags(tc)
        f = (0:0.5:500)';  S = 1./(1 + (f/40).^4);
        [~, t1] = timeSeriesPreparation.spectral.spec2acv(f, S);
        [~, t4] = timeSeriesPreparation.spectral.spec2acv(f, S, InterpFactor=4);
        tc.verifyEqual(t4(end)/t1(end), 4, RelTol=1e-6);
    end

    function uncertaintyBasics(tc)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        [R, ~, nfo] = timeSeriesPreparation.spectral.spec2acv(f, S, DOF=32);
        tc.verifyNotEmpty(nfo.Rstd);
        tc.verifySize(nfo.Rstd, size(R));
        tc.verifyGreaterThan(nfo.Rstd(1), 0);
        % var R(0) = df^2 * sum(w^2 * 2 S^2/DOF): sanity vs 4x DOF
        [~, ~, nfo2] = timeSeriesPreparation.spectral.spec2acv(f, S, DOF=128);
        tc.verifyEqual(nfo.Rstd(1)/nfo2.Rstd(1), 2, RelTol=1e-10);
        % smoothing must reduce the uncertainty
        [~, ~, nfoS] = timeSeriesPreparation.spectral.spec2acv(f, S, DOF=32, Smooth="boxcar", SmoothWidth=2);
        tc.verifyLessThan(nfoS.Rstd(1), nfo.Rstd(1));
    end

    function singlePrecisionPassesThrough(tc)
        f = single((0:0.1:500)');  S = single(1./(1 + (f/40).^4));
        R = timeSeriesPreparation.spectral.spec2acv(f, S);
        tc.verifyClass(R, "single");
    end

end

methods (Test, TestTags = {'metamorphic'})

    function asdEqualsSquaredPsd(tc)
        f = (0:0.1:500)';  A = 1./(1 + (f/40).^2);
        R1 = timeSeriesPreparation.spectral.spec2acv(f, A, InputType="asd");
        R2 = timeSeriesPreparation.spectral.spec2acv(f, A.^2);
        tc.verifyEqual(R1, R2, AbsTol=1e-12);
    end

    function twoSidedEqualsOneSided(tc)
        a = 5; s2 = 3; df = 0.1; fmax = 1000;
        f2 = (-fmax:df:fmax)';                 % two-sided Lorentzian
        S2 = 2*a*s2 ./ (a^2 + (2*pi*f2).^2);
        f1 = (0:df:fmax)';
        G1 = 4*a*s2 ./ (a^2 + (2*pi*f1).^2);
        Ra = timeSeriesPreparation.spectral.spec2acv(f2, S2, Sided="two");
        Rb = timeSeriesPreparation.spectral.spec2acv(f1, G1);
        tc.verifyEqual(Ra, Rb, RelTol=1e-9, AbsTol=1e-12);
    end

    function octaveSmoothingIsRelativeBandwidth(tc)
        % a 1/f^2 spectrum is invariant in shape under octave smoothing
        f = (0:0.05:1000)';  S = 1./max(f, 1).^2;
        [~, ~, n0] = timeSeriesPreparation.spectral.spec2acv(f, S);
        [~, ~, n1] = timeSeriesPreparation.spectral.spec2acv(f, S, Smooth="octave", SmoothWidth=1/3);
        tc.verifyEqual(n1.varOut, n0.varOut, RelTol=0.02);
    end

end

methods (Test, TestTags = {'robustness'})

    function nanRepair(tc)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        Sn = S; Sn(100:110) = NaN;
        [Rn, ~, nfo] = timeSeriesPreparation.spectral.spec2acv(f, Sn);
        Rc = timeSeriesPreparation.spectral.spec2acv(f, S);
        tc.verifyEqual(nfo.nBadBins, 11);
        tc.verifyEqual(Rn, Rc, RelTol=1e-3, AbsTol=1e-6*max(abs(Rc)));
        tc.verifyError(@() timeSeriesPreparation.spectral.spec2acv(f, Sn, NanPolicy="error"), "timeSeriesPreparation:spec2acv:badBins");
    end

    function unsortedAndDuplicates(tc)
        f = (0:0.1:500)';  S = 1./(1 + (f/40).^4);
        idx = randperm(numel(f));
        R1 = timeSeriesPreparation.spectral.spec2acv(f(idx), S(idx));         % shuffled
        R2 = timeSeriesPreparation.spectral.spec2acv([f; f(50)], [S; S(50)]); % duplicate bin
        Rc = timeSeriesPreparation.spectral.spec2acv(f, S);
        tc.verifyEqual(R1, Rc, AbsTol=1e-12);
        tc.verifyEqual(R2, Rc, AbsTol=1e-12);
    end

end
end
