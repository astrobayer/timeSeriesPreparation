% timeSeriesPreparation.qc - residual quality control
% NonGravForces.qc 0.12.0 (3cc0123), ported at X-05, conventions of X-05b
%
%   Base MATLAB only. Call as timeSeriesPreparation.qc.<name>. Errors are
%   timeSeriesPreparation:<name>:<mnemonic>. The numbers of the six ported
%   units equal the port's (tests/TestQcEquivalence); templateBank and
%   detectTemplates are new (X-17, tests/TestTemplates).
%
%   residuals            - Whitened residuals measured - modelled with preliminary calibration
%   hampel               - Robust point-outlier detector (moving median + MAD)
%   detectImpulses       - Matched filter on the CRN impulse response with THR1B priors
%   detectJumps          - Piecewise-constant/linear change-point detection (PELT + BIC)
%   eventTable           - Canonical event table constructor and schema
%   screen               - Orchestrator: residuals -> outliers -> impulses -> jumps -> mask
%   templateBank         - Empirical spike templates of the ACT1B residual (thruster; C, D)
%   detectTemplates      - 3-axis matched filter on the template bank, one mask per class
