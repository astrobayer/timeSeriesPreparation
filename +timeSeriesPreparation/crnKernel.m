function kernel = crnKernel(preset, options)
%CRNKERNEL  The CRN-class digital filter of the GRACE L1B ATBD, as printed.
%
%   SYNTAX
%     kernel = timeSeriesPreparation.crnKernel(preset)
%     kernel = timeSeriesPreparation.crnKernel(preset, Tf = 140.7, B = 0.035)
%
%   DESCRIPTION
%     Builds the weights F_n with which JPL's Level-1B processing turns 10 Hz
%     Level-1A samples into ACC1B/ACT1B and KBR1B, and the weights of their
%     first and second time derivatives, from Appendix B of the GRACE L1B
%     ATBD (JPL D-27672, printed pp. 39-40, PDF pp. 40-41):
%
%       H_k   = sum_{m=-NB..NB} ( sin[pi(k-m)/Nc] / sin[pi(k-m)/Nf] )^Nc
%       F_n   = (1/FNorm) sum_{k=-Nh..Nh} H_k cos(2 pi k n/Nf),   |n| <= Nh
%       FNorm = sum_{i=-Nh..Nh} cos(2 pi f0 i/fs) sum_k H_k cos(2 pi k i/Nf)
%
%     with Nf = fs*Tf (odd), NB = B*Tf rounded, Nh = (Nf-1)/2, and the
%     removable singularity k = m set to its limit Nf/Nc. The power Nc stands
%     on EACH passband term, as printed. Raising the SUM to Nc instead - the
%     v2 port's error - gives DC gain 1.0004533 (ACC), which real data refute:
%     GRACE-C 2020-01-02, mean(ACT1B_y)/mean(ACT1A_x) = 1.000000064 (CONCEPT
%     8). The printed kernel gives 1 + 1.115e-7. The kernel is normalised to
%     unit response at the J2 frequency f0, not at DC; renormalising to unit
%     DC would change every calibrated scale by the DC gain.
%
%     The page prints FNorm's inner cosine with n inside a sum over i, and
%     the derivative sums over i; both are read with the index of their sum.
%     That reading makes the response at f0 exactly 1 and reproduces the
%     numbers above. Filtered data are R_i = sum_n F_n R_{i-n} (crnApply).
%
%     Presets (ATBD App. B): "ACC" fs 10 Hz, Nc 7, Tf 140.7 s, B 0.035 Hz;
%     "KBR" fs 10 Hz, Nc 7, Tf 70.7 s, B 0.1 Hz; both f0 = 0.37 mHz. GRACE-FO
%     ACT1B uses a CRN filter whose numbers its handbook (JPL D-56935, PDF p.
%     20) does not print. The GRACE values reproduce it: ACT1A of GRACE-FO C
%     and D, 2020-01-02, mapped from OBC to GPS time (TIM1B, CLK1B),
%     resampled to 0.1 s and filtered with this preset, equals ACT1B to a
%     relative rms of 2e-6 to 2.5e-5 per axis, while Tf 70.7 s - the ACC span
%     the classic GRACE handbook JPL D-22027 prints - misses by 3.7e-3 to
%     3.6e-2 (X-12, TestCrnVerification).
%     "LRI" refuses: its numbers are open (V-2).
%
%   INPUTS
%     preset  (1,1) string   -   "ACC", "KBR" or "LRI".
%
%   OPTIONS
%     Fs  (1,1) double   [preset]   Raw data rate in Hz.
%     Nc  (1,1) double   [preset]   Self-convolution number, odd.
%     Tf  (1,1) double   [preset]   Fit interval in s; Fs*Tf must be an odd
%                                   integer.
%     B   (1,1) double   [preset]   Target low-pass bandwidth in Hz.
%     F0  (1,1) double   [preset]   Normalisation frequency in Hz.
%
%   OUTPUTS
%     kernel  (1,1) struct   -   Fields: preset (1,1) string; fs, Nc, Tf, B,
%                                f0, Nf, NB, Nh (1,1) double; lags (Nf,1)
%                                double, n = -Nh..Nh; F (Nf,1) double,
%                                dimensionless; dF (Nf,1) double, 1/s; ddF
%                                (Nf,1) double, 1/s^2; FNorm, dcGain,
%                                gainAtF0 (1,1) double; overridden (1,:)
%                                string, the options that replaced preset
%                                values; source (1,1) string.
%
%   ACCURACY
%     The taps equal the independent NumPy transcription of the page
%     (tests/oracles/crn_atbd_asprinted.py, ORC-1) to 1e-12 of the largest
%     tap: each tap is a sum of Nf terms rounded differently in the two
%     programs, worst case Nf*eps = 3.1e-13 of it. gainAtF0 is 1 to rounding
%     (2e-16 measured in the oracle). In the passband the derivative kernels
%     reproduce i*2*pi*f and (i*2*pi*f)^2 times the filter response to 1e-12.
%
%   ERRORS
%     Preset:
%       timeSeriesPreparation:crnKernel:unknownPreset - preset is not "ACC",
%           "KBR" or "LRI".
%       timeSeriesPreparation:crnKernel:unverifiedPreset - "LRI": no CRN
%           numbers for LRI1B are confirmed from a registered document yet.
%     Parameters:
%       timeSeriesPreparation:crnKernel:badParameters - Fs*Tf is not an odd
%           integer, Nc is not a positive odd integer, or B*Tf rounds to a
%           passband of zero bins or of Nh bins or more.
%
%   EXAMPLE
%     % The ACC1B kernel: 1407 taps, DC gain 1 + 1.1e-7, unit gain at f0.
%     k = timeSeriesPreparation.crnKernel("ACC");
%     fprintf("Nf = %d, DC gain - 1 = %.3g\n", k.Nf, k.dcGain - 1);
%
%   LIMITATIONS
%     The ATBD states B as approximate ("~0.035 Hz"); NB is B*Tf rounded to
%     the nearest integer (ACC 4.92 -> 5, KBR 7.07 -> 7). The kernel is built
%     in O(Nf^2) time and memory (16 MB for ACC); build it once and reuse it.
%
%   REFERENCES
%     R-1: Wu, Kruizinga, Bertiger (2006), GRACE L1B ATBD V1.2, JPL D-27672,
%     App. B, PDF pp. 40-41. R-2: Wen et al. (2019), GRACE-FO L1 Data Product
%     User Handbook, JPL D-56935, PDF p. 20. docs/CONCEPT.md sections 8, 9.3.
%
%   See also timeSeriesPreparation.crnApply.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-09-27 10:45 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        preset (1,1) string
        options.Fs (1,1) double {mustBePositive, mustBeFinite}
        options.Nc (1,1) double {mustBePositive, mustBeFinite}
        options.Tf (1,1) double {mustBePositive, mustBeFinite}
        options.B (1,1) double {mustBePositive, mustBeFinite}
        options.F0 (1,1) double {mustBeNonnegative, mustBeFinite}
    end

    switch upper(preset)
        case "ACC"
            p = struct("Fs", 10, "Nc", 7, "Tf", 140.7, "B", 0.035, "F0", 0.37e-3);
        case "KBR"
            p = struct("Fs", 10, "Nc", 7, "Tf", 70.7, "B", 0.1, "F0", 0.37e-3);
        case "LRI"
            error("timeSeriesPreparation:crnKernel:unverifiedPreset", ...
                "No LRI1B CRN parameters are confirmed from a registered " + ...
                "document yet (V-2, CONCEPT 9.3). To experiment, start from " + ...
                """KBR"" and state every parameter (Fs, Nc, Tf, B, F0).");
        otherwise
            error("timeSeriesPreparation:crnKernel:unknownPreset", ...
                "Unknown preset ""%s""; use ""ACC"", ""KBR"" or ""LRI"".", preset);
    end
    overridden = string(fieldnames(options))';
    for f = overridden
        p.(f) = options.(f);
    end

    fs = p.Fs; Nc = p.Nc; Tf = p.Tf; B = p.B; f0 = p.F0;
    Nf = round(fs * Tf);
    NB = round(B * Tf);
    Nh = (Nf - 1) / 2;
    if abs(fs * Tf - Nf) > 1e-9 * Nf || mod(Nf, 2) ~= 1 || mod(Nc, 2) ~= 1 ...
            || Nc ~= round(Nc) || NB < 1 || NB >= Nh
        error("timeSeriesPreparation:crnKernel:badParameters", ...
            "Need Fs*Tf an odd integer (got %.12g), Nc a positive odd " + ...
            "integer (got %g) and 1 <= round(B*Tf) < (Nf-1)/2 (got %d).", ...
            fs * Tf, Nc, NB);
    end

    k = (-Nh:Nh)';
    H = zeros(Nf, 1);
    for m = -NB:NB
        d = k - m;
        term = sin(pi * d / Nc) ./ sin(pi * d / Nf);
        term(d == 0) = Nf / Nc;                 % removable singularity
        H = H + term .^ Nc;                     % the power on each term
    end
    A = 2 * pi * (k * k') / Nf;                 % rows n, columns k
    G = cos(A) * H;
    FNorm = sum(cos(2 * pi * f0 * k / fs) .* G);
    w = 2 * pi * k / Tf;

    kernel = struct();
    kernel.preset = upper(preset);
    kernel.fs = fs; kernel.Nc = Nc; kernel.Tf = Tf; kernel.B = B; kernel.f0 = f0;
    kernel.Nf = Nf; kernel.NB = NB; kernel.Nh = Nh;
    kernel.lags = k;
    kernel.F = G / FNorm;
    kernel.dF = (sin(A) * (-w .* H)) / FNorm;
    kernel.ddF = (cos(A) * (-(w .^ 2) .* H)) / FNorm;
    kernel.FNorm = FNorm;
    kernel.dcGain = sum(kernel.F);
    kernel.gainAtF0 = sum(kernel.F .* cos(2 * pi * f0 * k / fs));
    kernel.overridden = overridden;
    kernel.source = "GRACE L1B ATBD (JPL D-27672) App. B, PDF pp. 40-41, as printed";
end
