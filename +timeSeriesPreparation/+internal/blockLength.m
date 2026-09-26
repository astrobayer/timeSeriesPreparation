function [b, info] = blockLength(x)
%BLOCKLENGTH  Automatic block length for block resampling (Politis-White, Patton correction).
%
%   SYNTAX
%     [b, info] = timeSeriesPreparation.internal.blockLength(x)
%
%   DESCRIPTION
%     The block length that minimises the MSE of the block-bootstrap
%     variance estimator of the mean, estimated per column by Politis &
%     White (2004) with the correction of Patton, Politis & White (2009).
%     bootstrap and crossval use it when no BlockLength is given (owner
%     decision 2026-09-23).
%
%     With n samples, K_N = max(5, ceil(sqrt(log10 n))), m_max =
%     ceil(sqrt n) + K_N and the band c sqrt(log10(n)/n), c = 2:
%       1. rho(k), k = 1..m_max, the correlation of x(t) with x(t-k) over
%          the common sample t = m_max+1..n.
%       2. mhat is the first lag L with rho(L..L+K_N-1) all inside the
%          band; if there is none, the largest lag outside it. M = 2 mhat,
%          capped at m_max.
%       3. With R(k) the covariance of x(t) and x(t-k) over t = M+1..n
%          (N-1 normalisation) and the flat-top window lambda(s) = 1 for
%          |s| < 1/2, 2(1-|s|) up to 1:
%            G = sum_{|k|<=M} lambda(k/M) |k| R(k),
%            D = 4/3 (sum_{|k|<=M} lambda(k/M) R(k))^2,
%            b = (2 G^2 / D)^(1/3) n^(1/3), capped at
%            ceil(min(3 sqrt n, n/3)).
%     D is the circular (and moving) block bootstrap's constant.
%     These are the steps of Patton's reference implementation
%     (opt_block_length_REV_dec07). A NaN sample is left out of every
%     sum it would enter (pairwise-complete moments). A column without
%     variance gets b = 1.
%
%   INPUTS
%     x  (N,M) double   -   Samples in rows; NaN marks a missing sample.
%
%   OUTPUTS
%     b     (1,M) double   samples   Block length per column, not rounded;
%                                    callers round it up.
%     info  (1,1) struct   -         mhat, M (1,M) double: the lags of
%                                    steps 2 and 3; mmax, kn (1,1) double.
%
%   ACCURACY
%     A NumPy transcription of these steps equals recombinator 0.0.6.1 (a
%     port of Patton's code) to 3e-14 relative on six AR(1) series
%     (phi -0.6 to 0.99, n 500 to 20000), measured 2026-09-23. That port
%     returns mhat 0-based in the no-window branch of step 2; this
%     function returns the lag, as Patton's MATLAB find does.
%     tests/oracles/block_length_pw.json pins the numbers.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:blockLength:tooShort - fewer than
%           2 (m_max + 1) samples, so step 1 has too few pairs.
%
%   EXAMPLE
%     % An AR(1) with phi = 0.9: a block of about 50 samples.
%     x = filter(1, [1 -0.9], randn(RandStream("twister", "Seed", 1), 2000, 1));
%     b = timeSeriesPreparation.internal.blockLength(x);
%
%   LIMITATIONS
%     Built for the variance of the mean; for other statistics it is a
%     guide, not an optimum. Columns are treated one by one.
%
%   REFERENCES
%     Politis, D. N., White, H. (2004). Automatic block-length selection for
%     the dependent bootstrap. Econometric Reviews 23(1), 53-70,
%     doi:10.1081/ETC-120028836. Patton, A., Politis, D. N., White, H.
%     (2009). Correction to "Automatic block-length selection for the
%     dependent bootstrap". Econometric Reviews 28(4), 372-375,
%     doi:10.1080/07474930802459016. Politis, D. N. (2003). Adaptive
%     bandwidth choice. J. Nonparametric Statistics 15(4-5), 517-533
%     (the rule of step 2).
%
%   See also timeSeriesPreparation.bootstrap, timeSeriesPreparation.crossval.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.1.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    [n, M] = size(x);
    kn = max(5, ceil(sqrt(log10(n))));
    mmax = ceil(sqrt(n)) + kn;
    if n < 2 * (mmax + 1)
        error("timeSeriesPreparation:blockLength:tooShort", ...
            "%d samples are too few; the rule needs at least %d.", n, 2 * (mmax + 1));
    end
    bmax = ceil(min(3 * sqrt(n), n / 3));
    crit = 2 * sqrt(log10(n) / n);

    b = ones(1, M);
    info = struct("mhat", zeros(1, M), "M", zeros(1, M), "mmax", mmax, "kn", kn);
    for c = 1:M
        col = x(:, c);
        rho = zeros(mmax, 1);
        for k = 1:mmax
            rho(k) = pairStat(col(mmax+1:n), col(mmax+1-k:n-k), "corr");
        end
        inside = abs(rho) < crit;
        mhat = 0;
        for L = 1:mmax - kn + 1
            if all(inside(L:L+kn-1))
                mhat = L;
                break
            end
        end
        if mhat == 0
            outside = find(abs(rho) > crit, 1, "last");
            if ~isempty(outside)
                mhat = outside;
            end
        end
        Mc = min(2 * mhat, mmax);
        info.mhat(c) = mhat;
        info.M(c) = Mc;
        if Mc == 0
            continue
        end
        R = zeros(Mc + 1, 1);
        for k = 0:Mc
            R(k+1) = pairStat(col(Mc+1:n), col(Mc+1-k:n-k), "cov");
        end
        k = (1:Mc)';
        s = k / Mc;
        lambda = ones(Mc, 1);
        lambda(s >= 0.5) = 2 * (1 - s(s >= 0.5));
        G = 2 * sum(lambda .* k .* R(2:end));
        S = R(1) + 2 * sum(lambda .* R(2:end));
        if ~(S > 0) || ~isfinite(G)
            continue
        end
        D = 4 / 3 * S^2;
        b(c) = min((2 * G^2 / D)^(1/3) * n^(1/3), bmax);
    end
end

function v = pairStat(y, z, kind)
% Correlation or covariance (N-1) of y and z over the rows where both are finite.
    keep = isfinite(y) & isfinite(z);
    y = y(keep);
    z = z(keep);
    if numel(y) < 2
        v = NaN;
        return
    end
    if kind == "corr"
        C = corrcoef(y, z);
    else
        C = cov(y, z);
    end
    v = C(1, 2);
end
