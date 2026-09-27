function P = dlyap(T, Q, tol, maxIter)
%DLYAP  Stationary covariance P = T P T' + Q, the one Lyapunov solver of the toolbox.
%
%   SYNTAX
%     P = timeSeriesPreparation.internal.dlyap(T, Q, tol, maxIter)
%
%   DESCRIPTION
%     Solves the discrete Lyapunov equation P = T*P*T' + Q for the
%     stationary state covariance of a stable state-space model. It uses the
%     doubling iteration P <- P + A*P*A', A <- A*A (Anderson and Moore),
%     O(r^3) per step and well behaved for a stable T. It stops when the
%     Frobenius change falls to tol times max(||P||, 1), and falls back to
%     the direct Kronecker solve (I - kron(T, T)) \ Q(:) when maxIter steps
%     do not converge or the iterate is not finite (eigenvalues at the unit
%     circle). The result is symmetrised.
%
%     sigtools v1.3.1 carried five copies of this routine, which differed
%     only in tol and maxIter: arma2acv 1e-15 and 80, synthTimeSeries and
%     tsFitSarima 1e-14 and 80, tsFitArima and tsForecast 1e-14 and 60. X-02
%     made them one function (owner decision 2026-09-23). Each caller
%     passes its own values, so every result is bit-identical to v1.3.1.
%
%   INPUTS
%     T        (r,r) double   -   Transition matrix, stable.
%     Q        (r,r) double   -   Innovation covariance, symmetric.
%     tol      (1,1) double   -   Relative stopping tolerance.
%     maxIter  (1,1) double   -   Largest number of doubling steps.
%
%   OUTPUTS
%     P  (r,r) double   -   Stationary covariance, symmetric.
%
%   ACCURACY
%     The doubling iterate matches the Kronecker solve to about 1e-15
%     relative (sigtools HANDOFF section 3, NumPy re-derivation). The
%     arithmetic is that of the v1.3.1 copies, operation for operation, so
%     TestSigtoolsEquivalence holds every caller's output bit for bit.
%
%   ERRORS
%     (none)
%
%   EXAMPLE
%     % AR(1) with phi = 0.9: the stationary variance is 1/(1 - 0.81).
%     P = timeSeriesPreparation.internal.dlyap(0.9, 1, 1e-14, 60);
%
%   LIMITATIONS
%     The Kronecker fallback costs O(r^6) and r^4 memory; it is meant for
%     the small state dimensions of ARMA models.
%
%   REFERENCES
%     B. D. O. Anderson, J. B. Moore (1979), Optimal Filtering, Prentice
%     Hall, ch. 4. docs/CONCEPT.md 10.1 row X-02.
%
%   See also timeSeriesPreparation.spectral.arma2acv, timeSeriesPreparation.tsmodels.tsFitArima.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-23 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        T (:,:) double
        Q (:,:) double
        tol (1,1) double
        maxIter (1,1) double
    end

    r = size(T,1);
    A = T; P = Q; converged = false;
    for it = 1:maxIter %#ok<NASGU>
        Pnew = P + A*P*A';
        A    = A*A;
        if norm(Pnew - P, 'fro') <= tol*max(norm(Pnew,'fro'), 1)
            P = Pnew; converged = true; break;
        end
        P = Pnew;
    end
    if ~converged || any(~isfinite(P(:)))
        P = reshape((eye(r*r) - kron(T,T)) \ Q(:), r, r);
    end
    P = 0.5*(P + P');
end
