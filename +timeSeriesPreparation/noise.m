function nm = noise(arc, order, options)
%NOISE  Residual noise model per axis: ARMA by exact ML with gaps, or PSD -> ARMA.
%
%   SYNTAX
%     nm = timeSeriesPreparation.noise(arc, order)
%     nm = timeSeriesPreparation.noise(arc, order, Method = "exact", MaxLag = 100, Lags = 20, WelchAverages = 32, Seed = 0, Stage = "noise")
%
%   DESCRIPTION
%     The noise stage (CONCEPT 6.1, row 5): an ARMA(p,q) model of each
%     column of arc, for the gap stage and for the covariance of the
%     applications' lsqvce fit. The numerics are the sigtools functions,
%     unchanged; this function applies them to an Arc, one axis at a time:
%       - rows with weight 0 or filled are set to NaN (CONCEPT 5);
%       - Method "exact": tsmodels.tsFitArima(x, p, 0, q), exact Gaussian
%         ML by a Kalman filter that skips the NaN rows;
%       - Method "psd": a Welch spectrum of WelchAverages Hann segments
%         (spectral.powerSpectrum, 50 % overlap) and spectral.psd2arma with
%         Order [p q]. psd2arma sets the gain by a log least-squares fit,
%         which on a raw periodogram (chi-square, 2 degrees of freedom)
%         biases sigma2 low by exp(-0.577) = 0.56; averaging makes that
%         bias about -1/dof (dof about 2 WelchAverages). An axis with
%         missing rows would need an unaveraged Lomb-Scargle periodogram,
%         so "psd" refuses it; use "exact" there;
%       - the autocovariance of the model, spectral.arma2acv (exact,
%         Lyapunov), at lags 0..MaxLag samples;
%       - the Ljung-Box test of the model's residuals over Lags lags,
%         tsmodels.tsLjungBox with p + q fitted parameters.
%     The model is x_t - mu = filter(b, a, e), e white of variance sigma2,
%     b(1) = a(1) = 1: a = [1, -phi], b = [1, theta] in tsFitArima's terms.
%
%     The order is the caller's choice; no default is assumed (R5).
%     tsFitArima perturbs its starting points with randn. Every axis
%     therefore starts from the same state of an mrg32k3a stream seeded by
%     internal.stageSeed(Stage, Seed) (CONCEPT 8): an axis is fitted
%     identically alone and in a batched call, and reruns are identical.
%     The caller's global stream is restored afterwards.
%
%   INPUTS
%     arc    (1,1) Arc      -   Residuals on a uniform grid; missing rows
%                               are NaN, weight 0 or filled.
%     order  (1,2) double   -   [p q], AR and MA orders, integers >= 0.
%
%   OPTIONS
%     Method  (1,1) string   ["exact"]  "exact" (tsFitArima) or "psd"
%                                       (powerSpectrum, psd2arma).
%     MaxLag  (1,1) double   [100]      Largest autocovariance lag in
%                                       samples, integer >= 0.
%     Lags    (1,1) double   [20]       Ljung-Box lags, integer >= 1.
%     WelchAverages  (1,1) double   [32]  Welch segments of "psd", integer
%                                         >= 1.
%     Seed    (1,1) double   [0]        Caller's seed, integer >= 0.
%     Stage   (1,1) string   ["noise"]  Stage name the seed derives from.
%
%   OUTPUTS
%     nm  (1,1) struct   -   Fields: axes (1,M) string; method; order
%                            (1,2); dt (1,1) s, the grid step; a
%                            (M,p+1), b (M,q+1); sigma2, mu (1,M); acv
%                            (MaxLag+1,M), unit^2; lags (MaxLag+1,1) s;
%                            ljungBoxQ, ljungBoxP (1,M); nObs (1,M)
%                            samples used; seed.
%
%   ACCURACY
%     That of the functions applied (see their help). "exact" is
%     maximum-likelihood efficient; for an AR(1) the standard error of phi
%     is sqrt((1 - phi^2)/n). "psd" inherits the scatter of the spectrum
%     estimate and psd2arma's fit error; it is the fast route for long
%     arcs. acv is exact for the fitted model.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:noise:irregularGrid - the epochs are not
%           uniformly spaced; resample first (align) and mark missing rows
%           NaN.
%       timeSeriesPreparation:noise:tooFewSamples - an axis has fewer than
%           10 (p + q + 1) usable samples.
%       timeSeriesPreparation:noise:gapsInPsd - Method "psd" on an axis
%           with missing rows.
%       Options outside their domain are refused by the arguments block
%       with a MATLAB: identifier.
%
%   EXAMPLE
%     % An AR(1) at 1 Hz with a gap: phi near 0.7, residuals white.
%     aux = struct("obsNames", {{'lin_accl_x'}}, "variableNames", {{'lin_accl_x'}}, "variableFieldNames", {{'lin_accl_x'}}, "variableUnits", struct("lin_accl_x", "m/s2"), "fileName", "ACT1B_2020-01-01_C_04.txt", "product", "ACT1B");
%     x = filter(1, [1 -0.7], randn(RandStream("twister", "Seed", 5), 1500, 1));
%     x(400:450) = NaN;
%     nm = timeSeriesPreparation.noise(timeSeriesPreparation.Arc(int64(0:1499)' * int64(1e9), x, aux), [1 0], MaxLag = 10);
%
%   LIMITATIONS
%     Stationary ARMA only; differencing and seasonal terms are the
%     caller's (tsmodels.tsFitSarima). "psd" needs gap-free axes; its
%     residuals are formed by inverse filtering. Allan deviation
%     (spectral.allanVariance) needs a gap-free stretch and is not
%     computed here.
%
%   REFERENCES
%     Box, G. E. P., Jenkins, G. M., Reinsel, G. C., Ljung, G. M. (2015).
%     Time Series Analysis: Forecasting and Control, 5th ed. Wiley, ch. 7.
%     Jones, R. H. (1980). Maximum likelihood fitting of ARMA models to
%     time series with missing observations. Technometrics 22(3), 389-395.
%     docs/CONCEPT.md sections 5, 6.1 (row 5) and 8.
%
%   See also timeSeriesPreparation.tsmodels.tsFitArima, timeSeriesPreparation.spectral.psd2arma, timeSeriesPreparation.spectral.arma2acv.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        arc (1,1) timeSeriesPreparation.Arc
        order (1,2) double {mustBeInteger, mustBeNonnegative}
        options.Method (1,1) string {mustBeMember(options.Method, ["exact" "psd"])} = "exact"
        options.MaxLag (1,1) double {mustBeInteger, mustBeNonnegative} = 100
        options.Lags (1,1) double {mustBeInteger, mustBePositive} = 20
        options.WelchAverages (1,1) double {mustBeInteger, mustBePositive} = 32
        options.Seed (1,1) double {mustBeInteger, mustBeNonnegative} = 0
        options.Stage (1,1) string = "noise"
    end

    p = order(1);
    q = order(2);
    N = numel(arc.t);
    M = size(arc.obs, 2);
    step = diff(arc.t);
    if N < 2 || any(step ~= step(1))
        error("timeSeriesPreparation:noise:irregularGrid", ...
            "noise needs uniformly spaced epochs; resample with align and mark missing rows NaN.");
    end
    dt = double(step(1)) / 1e9;

    X = arc.obs;
    X(arc.weights == 0 | arc.filled, :) = NaN;
    nObs = sum(isfinite(X), 1);
    need = 10 * (p + q + 1);
    if any(nObs < need)
        error("timeSeriesPreparation:noise:tooFewSamples", ...
            "Axes %s have fewer than %d usable samples.", ...
            strjoin(arc.names(nObs < need), ", "), need);
    end

    if options.Method == "psd" && any(nObs < N)
        error("timeSeriesPreparation:noise:gapsInPsd", ...
            "Method ""psd"" needs gap-free axes (%s has missing rows); use ""exact"".", ...
            strjoin(arc.names(nObs < N), ", "));
    end

    seed = timeSeriesPreparation.internal.stageSeed(options.Stage, options.Seed);
    stream = RandStream("mrg32k3a", "Seed", seed);
    previous = RandStream.setGlobalStream(stream);
    restore = onCleanup(@() RandStream.setGlobalStream(previous));

    L = options.MaxLag;
    nm = struct("axes", arc.names, "method", options.Method, "order", order, ...
        "dt", dt, "a", zeros(M, p + 1), "b", zeros(M, q + 1), ...
        "sigma2", zeros(1, M), "mu", zeros(1, M), "acv", zeros(L + 1, M), ...
        "lags", (0:L)' * dt, "ljungBoxQ", NaN(1, M), "ljungBoxP", NaN(1, M), ...
        "nObs", nObs, "seed", seed);
    for m = 1:M
        reset(stream);
        x = X(:, m);
        switch options.Method
            case "exact"
                model = timeSeriesPreparation.tsmodels.tsFitArima(x, p, 0, q);
                a = [1, -model.ar];
                b = [1, model.ma];
                s2 = model.sigma2;
                mu = model.mu;
                resid = model.resid;
            case "psd"
                t = (0:N-1)' * dt;
                spec = timeSeriesPreparation.spectral.powerSpectrum(t, x, Type = "psd", ...
                    NAvg = options.WelchAverages);
                [bb, aa] = timeSeriesPreparation.spectral.psd2arma(spec.frequency, spec.power, ...
                    1 / dt, Order = [p q]);
                a = aa / aa(1);
                b = bb / bb(1);
                s2 = (bb(1) / aa(1))^2;
                mu = mean(x, "omitnan");
                resid = filter(a, b, x - mu);
        end
        nm.a(m, :) = a;
        nm.b(m, :) = b;
        nm.sigma2(m) = s2;
        nm.mu(m) = mu;
        nm.acv(:, m) = timeSeriesPreparation.spectral.arma2acv(b, a, L, NoiseVariance = s2);
        if any(isfinite(resid))
            [nm.ljungBoxQ(m), nm.ljungBoxP(m)] = timeSeriesPreparation.tsmodels.tsLjungBox(resid, options.Lags, p + q);
        end
    end
    clear restore
end
