% timeSeriesPreparation.spectral - spectral analysis and noise models
% sigtools v1.3.1, conventions of X-02
%
%   Base MATLAB only. Call as timeSeriesPreparation.spectral.<name>.
%
%   Spectra and Allan variance
%     powerSpectrum      - Power and amplitude spectrum of one series: Welch
%                          FFT or Lomb-Scargle.
%     allanVariance      - Overlapping Allan variance and deviation, with
%                          confidence bounds and slopes.
%     spec2acv           - One- or two-sided PSD/ASD to auto-covariance /
%                          -correlation.
%
%   ARMA noise models
%     psd2arma           - Fit a discrete-time ARMA (IIR) process to a target
%                          PSD or ASD.
%     arma2psd           - One-sided PSD (or ASD) of a discrete-time ARMA
%                          process.
%     arma2acv           - Exact auto-covariance / -correlation of a
%                          discrete-time ARMA process.
%     synthTimeSeries    - Generate stationary noise from a PSD or an ARMA
%                          model.
%
%   Filter design (base-MATLAB stand-ins)
%     sfreqz             - Digital frequency response of an IIR/FIR filter
%                          (base MATLAB).
%     sinvfreqz          - Fit an IIR filter to a complex frequency response
%                          (base MATLAB).
%     sstmcb             - Steiglitz-McBride IIR fit to an impulse response
%                          (base MATLAB).
%
%   Plots (draw only, from the numbers above)
%     plotPowerSpectrum  - Draw spectra from powerSpectrum: lines, peaks, FAP
%                          levels, confidence bars.
%     plotAllanVariance  - Draw Allan deviation on log-log axes with its
%                          shaded confidence band.
%     plotPsd2armaFit    - Draw a psd2arma fit: target and fitted PSD, and the
%                          fit error in dB.
%
%   The discrete Lyapunov solver shared with tsmodels is
%   timeSeriesPreparation.internal.dlyap.
