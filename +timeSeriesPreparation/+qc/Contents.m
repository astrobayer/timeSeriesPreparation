% timeSeriesPreparation.qc - residual quality control
% Port of NonGravForces.qc 0.12.0 (3cc0123), unchanged but for the namespace (X-05)
%
%   Base MATLAB only. Call as timeSeriesPreparation.qc.<name>. Errors are
%   timeSeriesPreparation:<name>:<mnemonic>, raised through
%   timeSeriesPreparation.internal.fail.
%
%   residuals            - Whitened residuals measured - modelled with preliminary calibration
%   hampel               - Robust point-outlier detector (moving median + MAD)
%   detectImpulses       - Matched filter on the CRN impulse response with THR1B priors
%   detectJumps          - Piecewise-constant/linear change-point detection (PELT + BIC)
%   eventTable           - Canonical event table constructor and schema
%   screen               - Orchestrator: residuals -> outliers -> impulses -> jumps -> mask
