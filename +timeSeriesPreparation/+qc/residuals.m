function [r, info] = residuals(y_meas, y_model, options)
%RESIDUALS  Residuals of measured minus modelled observations under a preliminary calibration, optionally whitened.
%
%   SYNTAX
%     r = timeSeriesPreparation.qc.residuals(y_meas, y_model)
%     [r, info] = timeSeriesPreparation.qc.residuals(y_meas, y_model, Bias = b, Scale = S, Whitening = "highpass", Window = 601)
%
%   DESCRIPTION
%     r_raw = y_meas - (b + y_model * S'), per channel (columns), with the
%     caller's preliminary calibration (defaults b = 0, S = I: the plain
%     difference). Whitening prepares the residual for the detectors,
%     which assume white noise:
%       "none"        r = r_raw;
%       "difference"  r = diff(r_raw), NaN in the first row: flattens the
%                     1/f accelerometer noise, doubles the white-noise
%                     variance, turns a level jump into a one-sample
%                     impulse;
%       "highpass"    r = r_raw - movmean(r_raw, Window, "omitnan"):
%                     removes bias drift slower than Window samples and
%                     keeps jumps and pulses shorter than Window/2 (the
%                     choice for detectJumps).
%     NaN samples propagate (they never enter the moving mean) and are
%     never invented; the detectors handle them. Ported from
%     NonGravForces.qc 0.12.0 (X-05); numbers unchanged (X-05b).
%
%   INPUTS
%     y_meas   (K,M) double   -   K samples of M channels, e.g. ACT1B
%                                 accelerations.
%     y_model  (K,M) double   -   Modelled observable at the same samples.
%
%   OPTIONS
%     Bias       (1,M) double   [zeros]   Preliminary bias, 1xM or KxM.
%     Scale      (M,M) double   [eye]     Preliminary scale, diagonal as
%                                         1xM or full MxM.
%     Whitening  (1,1) string   ["none"]  "none", "difference" or
%                                         "highpass".
%     Window     (1,1) double   []        Odd length >= 3 in samples;
%                                         required by "highpass".
%
%   OUTPUTS
%     r     (K,M) double   -   Whitened residuals, units of y_meas.
%     info  (1,1) struct   -   Fields: raw (K,M, before whitening),
%                              sigmaRobust (1,M, 1.4826 MAD of r, NaN-free),
%                              whitening, window, provenance.
%
%   ACCURACY
%     Arithmetic only. "highpass" keeps h (1 - 1/2) of a step of height h
%     at its centre over Window/2 samples on either side; "difference" is
%     exact for a step (one sample of height h). The robust sigma is
%     consistent with the standard deviation for Gaussian noise; for 1/f
%     noise it overestimates by up to 10 % inside short windows.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:residuals:inputShape - y_meas and y_model are
%           not KxM of one size, or Bias or Scale has the wrong size.
%       timeSeriesPreparation:residuals:inputWindow - "highpass" without an
%           odd Window >= 3.
%
%   EXAMPLE
%     % Residuals of three channels under a preliminary scale, high-passed.
%     rs = RandStream("twister", "Seed", 1);
%     y = randn(rs, 1000, 3); m = 0.9 * y + 0.1 * randn(rs, 1000, 3);
%     [r, info] = timeSeriesPreparation.qc.residuals(y, m, Scale = [1.1 1.1 1.1], Whitening = "highpass", Window = 61);
%
%   LIMITATIONS
%     The preliminary calibration is the caller's; nothing is fitted here.
%
%   REFERENCES
%     Klinger, B., Mayer-Guerr, T. (2016). The role of accelerometer data
%     calibration within GRACE gravity field recovery. Adv. Space Res.
%     58, 1597-1609. NonGravForces.qc 0.12.0 (3cc0123).
%
%   See also timeSeriesPreparation.qc.screen, timeSeriesPreparation.qc.hampel, timeSeriesPreparation.qc.detectJumps.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

arguments
    y_meas double
    y_model double
    options.Bias double = []
    options.Scale double = []
    options.Whitening (1,1) string {mustBeMember(options.Whitening, ["none","difference","highpass"])} = "none"
    options.Window double = []
end
if ~ismatrix(y_meas) || ~isequal(size(y_meas), size(y_model))
    error("timeSeriesPreparation:residuals:inputShape", "y_meas and y_model must be KxM of the same size -> got %s and %s (samples down the columns)", mat2str(size(y_meas)), mat2str(size(y_model)));
end
[K, M] = size(y_meas);
b = options.Bias;
if isempty(b), b = zeros(1, M); end
if ~(isequal(size(b), [1 M]) || isequal(size(b), [K M]))
    error("timeSeriesPreparation:residuals:inputShape", "Bias must be 1xM or KxM with M = %d -> got %s", M, mat2str(size(b)));
end
S = options.Scale;
if isempty(S), S = eye(M); elseif isequal(size(S), [1 M]), S = diag(S); end
if ~isequal(size(S), [M M])
    error("timeSeriesPreparation:residuals:inputShape", "Scale must be 1xM or MxM with M = %d -> got %s", M, mat2str(size(options.Scale)));
end
raw = y_meas - (b + y_model * S');
switch options.Whitening
    case "none"
        r = raw;
    case "difference"
        r = [nan(1, M); diff(raw, 1, 1)];
    case "highpass"
        W = options.Window;
        if isempty(W) || ~isscalar(W) || W < 3 || mod(W, 2) ~= 1 || W ~= fix(W)
            error("timeSeriesPreparation:residuals:inputWindow", "highpass needs an odd Window >= 3 samples -> pass 'Window', 601 for a 10-min drift scale at 1 Hz");
        end
        r = raw - movmean(raw, W, 1, 'omitnan');
end
sig = nan(1, M);
for m = 1:M
    x = r(~isnan(r(:, m)), m);
    if numel(x) >= 3, sig(m) = 1.4826 * median(abs(x - median(x))); end
end
info.raw = raw;
info.sigmaRobust = sig;
info.whitening = options.Whitening;
info.window = options.Window;
info.provenance = timeSeriesPreparation.internal.provenance("qc.residuals", 'Options', struct('Whitening', options.Whitening, 'Window', options.Window, 'biasGiven', ~isempty(options.Bias), 'scaleGiven', ~isempty(options.Scale)));
end
