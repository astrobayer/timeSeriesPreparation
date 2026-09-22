% timeSeriesPreparation.spectral - spectral analysis (sigtools v1.3.1, imported unchanged at X-01)
%
%   Base MATLAB only. Call as timeSeriesPreparation.spectral.<name>.
%
%     plotPowerSpectrum  - Welch-FFT / Lomb-Scargle power & amplitude spectra.
%     allanVariance      - Overlapping Allan variance/deviation + CI + slope.
%     spec2acv           - PSD/ASD -> auto-covariance / -correlation (Wiener-Khinchin).
%     psd2arma           - Fit a discrete-time ARMA process to a target PSD/ASD.
%     arma2psd           - PSD/ASD of an ARMA process (inverse of psd2arma).
%     arma2acv           - Exact ARMA auto-covariance / -correlation (Lyapunov).
%     synthTimeSeries    - Warmup-free noise series from a PSD or ARMA model.
%     sfreqz             - Digital frequency response B(z)/A(z) (base freqz).
%     sinvfreqz          - Fit an IIR filter to a frequency response (SK).
%     sstmcb             - Steiglitz-McBride IIR fit to an impulse response.
%
%   Help text, error identifiers and plotting are sigtools' own until X-02
%   brings them to this toolbox's conventions (CONCEPT 10.1, X-02).
