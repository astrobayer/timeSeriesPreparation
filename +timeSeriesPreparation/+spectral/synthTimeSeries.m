function [x, t, info] = synthTimeSeries(mode, p1, p2, Fs, N, options)
%SYNTHTIMESERIES  Generate stationary noise from a PSD or an ARMA model.
%
%   SYNTAX
%     [x, t, info] = timeSeriesPreparation.spectral.synthTimeSeries("psd", f, S, Fs, N)
%     [x, t, info] = timeSeriesPreparation.spectral.synthTimeSeries("arma", b, a, Fs, N)
%     x = timeSeriesPreparation.spectral.synthTimeSeries("psd", f, S, Fs, N, NColumns = 4, Seed = 1)
%
%   DESCRIPTION
%     Synthesises N samples of a real, zero-mean Gaussian series at Fs
%     that is stationary from the first sample: there is no filter warmup
%     and no burn-in to discard.
%
%     Mode "psd" uses the randomised-phase spectral representation. The
%     one-sided target S(f) is interpolated onto the rFFT grid
%     f_k = k Fs/N (log-log if the grid is log-spaced and mostly positive,
%     else linear; zero outside [min f, max f]). Each bin gets a complex
%     Gaussian amplitude with E|X_k|^2 = S_k Fs N/2, DC and Nyquist are
%     real with the full power S_k Fs N, and the half-spectrum is inverted
%     with Hermitian symmetry.
%
%     Mode "arma" runs x[n] = filter(b, a, w[n]), w white with variance
%     NoiseVariance, in Harvey's companion state-space form. The initial
%     state is drawn from the stationary distribution, whose covariance
%     solves the discrete Lyapunov equation (doubling, tolerance 1e-14, 80
%     steps; timeSeriesPreparation.internal.dlyap), factored by Cholesky
%     (eigen-decomposition if not positive definite).
%
%     The PSD scaling matches arma2psd and powerSpectrum: one-sided S with
%     trapz(f,S) equal to the variance, so an arma2psd output fed back in
%     reproduces the spectrum. With Seed, the global generator is seeded
%     by rng(Seed) and restored on exit; without it, the global stream is
%     used and advanced.
%
%   INPUTS
%     mode  (1,1) string   -    "psd" or "arma", case-insensitive.
%     p1    (M,1) double   -    "psd": f, frequency grid in Hz, real,
%                               0 <= f <= Fs/2, any spacing. "arma": b,
%                               MA (numerator) coefficients, real, finite.
%     p2    (M,1) double   -    "psd": S, one-sided PSD (unit^2/Hz), or ASD
%                               with InputType "asd", real. "arma": a, AR
%                               (denominator) coefficients, real, finite.
%     Fs    (1,1) double   Hz   Output sampling rate, > 0, finite.
%     N     (1,1) double   -    Number of samples, positive integer.
%
%   OPTIONS
%     NoiseVariance  (1,1) double   [1]       Driving white-noise variance
%                                             sigma_w^2 ("arma"), > 0.
%     InputType      (1,1) string   ["psd"]   "psd" or "asd" (S squared
%                                             first; "psd" mode).
%     Mean           (1,1) double   [0]       Constant added to the
%                                             output, finite.
%     Seed           (1,1) double   [[]]      rng seed; [] leaves the
%                                             global generator untouched.
%     NColumns       (1,1) double   [1]       Number of independent
%                                             realisations (columns of x),
%                                             >= 1, rounded.
%
%   OUTPUTS
%     x     (N,C) double   -   Synthesised series, one column per
%                              realisation (C = NColumns), plus Mean.
%     t     (N,1) double   s   Time vector, (0:N-1)'/Fs.
%     info  (1,1) struct   -   Fields: method ('spectral' |
%                              'arma-stationary'); Fs; N; df, Hz;
%                              targetVariance (trapz(f,S), or sigma_w^2
%                              sum(psi^2) from 2000+ impulse samples);
%                              empiricalVariance (mean column variance);
%                              warmupFree (true).
%
%   ACCURACY
%     sigtools HANDOFF section 3 (NumPy re-derivation): the PSD path is
%     unbiased (mean bias about 1e-5, error falling as 1/sqrt(M) over M
%     realisations); the ARMA path variance matches theory; the ratio of
%     first-block to last-block mean square is about 1.00 (no warmup); the
%     Hermitian assembly is correct for even and odd N. A single
%     realisation scatters around the target like any Gaussian estimate.
%     Unchanged from sigtools v1.3.1; TestSigtoolsEquivalence holds it bit
%     for bit.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:synthTimeSeries:mode - mode is not "psd" or
%           "arma".
%       timeSeriesPreparation:synthTimeSeries:sizeMismatch - f and S differ
%           in length ("psd").
%       timeSeriesPreparation:synthTimeSeries:freqRange - an f exceeds
%           Fs/2 ("psd").
%       f, S, b or a outside their domain (see INPUTS) are refused by
%       validateattributes, and Fs, N or an option outside its domain by
%       the arguments block, with a MATLAB: identifier.
%     Options:
%       timeSeriesPreparation:synthTimeSeries:badOption - InputType is not
%           "psd" or "asd" (case-insensitive).
%
%   EXAMPLE
%     % 1000 samples of an ARMA(2,2) process at 500 Hz, reproducible.
%     [x, t, info] = timeSeriesPreparation.spectral.synthTimeSeries("arma", [1 -0.5 0.2], [1 -1.2 0.6], 500, 1000, NoiseVariance = 2, Seed = 1);
%
%   LIMITATIONS
%     Gaussian only: non-Gaussian higher moments are not reproduced. The
%     PSD path is periodic with period N (circular), so the ACV wraps
%     around. The draws use the global random stream (rng), not a
%     RandStream argument; Seed makes a call reproducible. The ARMA path
%     loops sample by sample in MATLAB and is slow for very long series.
%
%   REFERENCES
%     M. Shinozuka, G. Deodatis (1991), Appl. Mech. Rev. 44(4), 191-204
%     (spectral representation). A. C. Harvey (1989), Forecasting,
%     Structural Time Series Models and the Kalman Filter, Cambridge
%     University Press (state space). sigtools v1.3.1 HANDOFF
%     (docs/inputs).
%
%   See also timeSeriesPreparation.spectral.arma2psd, timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.spec2acv, timeSeriesPreparation.spectral.powerSpectrum, timeSeriesPreparation.spectral.sfreqz.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        mode
        p1
        p2
        Fs (1,1) {mustBeNumeric, mustBePositive, mustBeFinite}
        N (1,1) {mustBeNumeric, mustBePositive, mustBeInteger}
        options.NoiseVariance (1,1) {mustBeNumeric, mustBePositive} = 1
        options.InputType (1,1) string {mustBeOneOf(options.InputType, ["psd" "asd"])} = "psd"
        options.Mean (1,1) {mustBeNumeric, mustBeFinite} = 0
        options.Seed {mustBeScalarOrEmpty, mustBeNumeric, mustBeFinite} = []
        options.NColumns (1,1) {mustBeNumeric, mustBeGreaterThanOrEqual(options.NColumns, 1)} = 1
    end

    % ---- mode + positional parsing -------------------------------------
    mode = lower(char(mode));
    if ~any(strcmp(mode, {'psd','arma'}))
        error('timeSeriesPreparation:synthTimeSeries:mode', 'First argument must be ''psd'' or ''arma''.');
    end
    N = double(N);

    o = options;
    C = round(o.NColumns);

    % ---- reproducible RNG (restore global state on exit) ---------------
    if ~isempty(o.Seed)
        sPrev = rng; restore = onCleanup(@() rng(sPrev)); %#ok<NASGU>
        rng(o.Seed);
    end

    info = struct('method','', 'Fs', Fs, 'N', N, 'df', Fs/N, ...
                  'targetVariance', NaN, 'empiricalVariance', NaN, ...
                  'warmupFree', true);

    switch mode
        case 'psd'
            f = p1(:);  S = p2(:);
            validateattributes(f, {'numeric'}, {'vector','real','nonnegative'}, mfilename, 'f');
            validateattributes(S, {'numeric'}, {'vector','real'}, mfilename, 'S');
            if numel(f) ~= numel(S)
                error('timeSeriesPreparation:synthTimeSeries:sizeMismatch', 'f and S must have equal length.');
            end
            if any(f > Fs/2 + 10*eps(Fs))
                error('timeSeriesPreparation:synthTimeSeries:freqRange', 'f must lie within [0, Fs/2].');
            end
            if strcmpi(o.InputType, 'asd'), S = S.^2; end
            S = max(S, 0);
            [x, info] = local_synthFromPSD(f, S, Fs, N, C, info);
            info.method = 'spectral';
            info.targetVariance = trapz(f, S);

        case 'arma'
            b = p1(:).';  a = p2(:).';
            validateattributes(b, {'numeric'}, {'vector','real','finite'}, mfilename, 'b');
            validateattributes(a, {'numeric'}, {'vector','real','finite'}, mfilename, 'a');
            [x, info] = local_synthFromARMA(b, a, o.NoiseVariance, N, C, info);
            info.method = 'arma-stationary';
            imp = filter(b, a, [1; zeros(max(2000, 20*numel(a)),1)]);
            info.targetVariance = o.NoiseVariance * sum(imp.^2);
    end

    x = x + o.Mean;
    t = (0:N-1)'/Fs;
    info.empiricalVariance = mean(var(x, 0, 1));
end

% ======================================================================
function [x, info] = local_synthFromPSD(f, S, Fs, N, C, info)
% Randomized-phase spectral synthesis. Interpolate the one-sided PSD onto
% the rFFT grid, form a complex spectrum with the target magnitude and
% uniform random phases (real DC and Nyquist bins), and inverse-FFT. The
% resulting series is stationary (no warmup) with the target PSD.
    Nf = floor(N/2) + 1;
    fk = (0:Nf-1)' * (Fs/N);

    % interpolate PSD onto the FFT grid (log-log when appropriate)
    Sk = local_interpPSD(f, S, fk);

    df = Fs/N;
    % Bin variance (two-sided) is S/2 * df; the complex Gaussian amplitude
    % with E|X_k|^2 = Sk*Fs*N/2 gives the correct one-sided PSD
    %   Sxx(f_k) = (2/(Fs*N)) |X_k|^2   (interior bins).
    sigmaK = sqrt(Sk * Fs * N / 2);            % per-bin complex std

    x = zeros(N, C);
    for c = 1:C
        re = randn(Nf,1);  im = randn(Nf,1);
        X  = sigmaK .* (re + 1i*im) / sqrt(2); % E|X|^2 = sigmaK^2
        % DC and Nyquist must be real; give them the full (two-sided) power
        X(1) = randn * sqrt(Sk(1) * Fs * N);
        if mod(N,2) == 0
            X(Nf) = randn * sqrt(Sk(Nf) * Fs * N);
        end
        x(:,c) = irfftLocal(X, N);
    end
    info.df = df;
end

% ----------------------------------------------------------------------
function Sk = local_interpPSD(f, S, fk)
% Interpolate a one-sided PSD onto grid fk, zero outside [min(f),max(f)],
% using log-log interpolation when the input grid is log-spaced & positive.
    Sk = zeros(size(fk));
    inRange = fk >= f(1) & fk <= f(end);
    fpos = f(f > 0);
    logSpaced = numel(fpos) > 4 && std(diff(log(fpos)))/mean(diff(log(fpos))) < 0.2;
    mostlyPos = mean(S > 0) > 0.9;
    if logSpaced && mostlyPos
        ok = f > 0 & S > 0;
        idx = inRange & fk > 0;
        Sk(idx) = exp(interp1(log(f(ok)), log(S(ok)), log(fk(idx)), 'linear', -Inf));
        Sk(isinf(Sk)) = 0;
        if fk(1) == 0 && f(1) == 0, Sk(1) = S(1); end
    else
        Sk(inRange) = max(interp1(f, S, fk(inRange), 'linear'), 0);
    end
end

% ----------------------------------------------------------------------
function x = irfftLocal(X, N)
% Inverse real FFT from a half-spectrum X (length floor(N/2)+1) to a real
% length-N signal, enforcing Hermitian symmetry. Base MATLAB (no irfft).
    Nf = numel(X);
    if mod(N,2) == 0
        full = [X; conj(X(Nf-1:-1:2))];
    else
        full = [X; conj(X(Nf:-1:2))];
    end
    x = real(ifft(full));
end

% ======================================================================
function [x, info] = local_synthFromARMA(b, a, s2, N, C, info)
% ARMA synthesis with a stationary initial state (Harvey state space).
% Draw alpha_0 ~ N(0, s2*P) with P the discrete-Lyapunov covariance, then
% run the state recursion. No warmup transient, no burn-in discard.
    a = a / a(1);  b = b / a(1);
    p = numel(a) - 1;  q = numel(b) - 1;  r = max(p, q+1);

    phi = zeros(r,1);  phi(1:p) = -a(2:p+1).';
    R   = zeros(r,1);  R(1) = 1;  if q > 0, R(2:1+q) = b(2:1+q).'; end
    T = zeros(r);  T(:,1) = phi;  T(1:r-1, 2:r) = eye(r-1);
    RR = R*R';

    P = timeSeriesPreparation.internal.dlyap(T, RR, 1e-14, 80);                    % stationary state cov (units s2)
    P = 0.5*(P + P');
    % robust Cholesky of a PSD matrix
    [L, pd] = chol(P + 1e-12*trace(P)/r*eye(r), 'lower');
    if pd > 0
        [U, D] = eig(P); d = max(real(diag(D)), 0);
        L = U * diag(sqrt(d));
    end

    x = zeros(N, C);
    sw = sqrt(s2);
    for c = 1:C
        alpha = sw * (L * randn(r,1));         % stationary initial state
        eps   = sw * randn(N,1);               % driving noise
        xc = zeros(N,1);
        for tt = 1:N
            xc(tt) = alpha(1);                 % y_t = first state
            alpha  = T*alpha + R*eps(tt);      % advance
        end
        x(:,c) = xc;
    end
end

% ----------------------------------------------------------------------
function mustBeOneOf(value, allowed)
% Case-insensitive membership, as v1.3.1's strcmpi validators.
    if ~any(strcmpi(value, allowed))
        error("timeSeriesPreparation:synthTimeSeries:badOption", ...
            "Value must be one of: %s.", strjoin(allowed, ", "));
    end
end
