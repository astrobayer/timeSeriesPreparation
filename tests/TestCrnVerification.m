classdef TestCrnVerification < matlab.unittest.TestCase
%TESTCRNVERIFICATION  V-1: the CRN preset reproduces GRACE-FO ACT1B from ACT1A, epoch by epoch.
%
%   DESCRIPTION
%     X-12 (CONCEPT V-1 and 8; owner decisions 2026-09-27; scan PR #66).
%     JPL's Level-1B chain, as the GRACE L1B handbook describes it (R-4,
%     JPL D-22027 v1.3, section 3.3), is rebuilt from the DATAPOOL files of
%     GRACE-FO C and D, 2020-01-02:
%       1. ACT1A time tags, OBC time, to receiver time: linear in the TIM1B
%          records (obctime -> rcvtime); records with a zero time dropped;
%       2. receiver to GPS time: + eps_time of CLK1B, linear in receiver
%          time (GPS = rcv_time + eps_time); CLK1B is read by
%          gracefoReading.readL1b since its v1.2.0 (v1.1.0 refused it,
%          readL1b:noTime, gracefoReading#29), and was parsed here before;
%       3. resampled to the 0.1 s grid by linear interpolation, NaN where
%          neighbouring samples are more than 0.15 s apart;
%       4. crnApply with crnKernel("ACC") at the ACT1B epochs.
%     Per ACT1B axis, paired as x <- ACT1A z, y <- x, z <- y, the relative
%     rms rel = rms(d) / rms(b - mean b), d = (b - mean b) - (a - mean a),
%     must be at most 2e-3 (owner decision; the scan measured 2e-6 to
%     2.5e-5). Fault injection: the 70.7 s span that R-4 p. 20 prints must
%     miss the bar and be at least 10 times worse on every axis (measured
%     3.7e-3 to 3.6e-2).
%
%   COVERAGE
%     reference      - C and D: every axis within the bar.
%     robustness     - the wrong span (Tf 70.7 s) is refuted on both
%                      satellites.
%     contract, precision, speed, vectorisation, metamorphic - exempt: a
%                      validation against real data; crnKernel and crnApply
%                      have their own tests.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-27 22:10 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        Bar = 2e-3
        Factor = 10
    end

    methods (Test, TestTags = {'reference'})
        function frequencyResponseC(testCase)
            verifyWithinBar(testCase, "C");
        end

        function frequencyResponseD(testCase)
            verifyWithinBar(testCase, "D");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function wrongSpanRefuted(testCase)
            for sat = ["C" "D"]
                good = relative(testCase, sat, timeSeriesPreparation.crnKernel("ACC"));
                wrong = relative(testCase, sat, timeSeriesPreparation.crnKernel("ACC", Tf = 70.7));
                testCase.verifyGreaterThan(wrong, testCase.Bar, sat + ": Tf 70.7 s passed the bar");
                testCase.verifyGreaterThan(wrong ./ good, testCase.Factor, ...
                    sat + ": Tf 70.7 s is not 10 times worse: " + mat2str(wrong ./ good, 3));
            end
        end
    end
end

% ------------------------------------------------------------------------

function verifyWithinBar(testCase, sat)
    rel = relative(testCase, sat, timeSeriesPreparation.crnKernel("ACC"));
    testCase.verifyLessThanOrEqual(rel, TestCrnVerification.Bar, ...
        sat + ": relative rms per axis (x, y, z) " + mat2str(rel, 3));
end

function rel = relative(testCase, sat, kernel)
% The relative rms per ACT1B axis of CRN(ACT1A mapped to GPS) against ACT1B.
    d = dayData(testCase, sat);
    out = timeSeriesPreparation.crnApply(d.arc, kernel, OutputEpochs = d.tb);
    ok = all(isfinite(out.obs), 2);
    testCase.assertGreaterThan(nnz(ok), 80000, sat + ": too few filtered epochs");
    pair = [3 1 2];                                      % ACT1B x <- z, y <- x, z <- y
    rel = zeros(1, 3);
    for j = 1:3
        a = out.obs(ok, pair(j)); b = d.b(ok, j);
        bm = b - mean(b);
        r = bm - (a - mean(a));
        rel(j) = sqrt(mean(r .^ 2)) / sqrt(mean(bm .^ 2));
    end
end

function d = dayData(testCase, sat)
% The mapped, resampled ACT1A arc and the ACT1B epochs and axes of SAT,
% read once per MATLAB session.
    persistent cache
    if isempty(cache), cache = struct(); end
    if isfield(cache, sat)
        d = cache.(sat);
        return
    end
    day = "2020-01-02";
    fA = poolFile(testCase, "L1A", "ACT1A", day, sat);
    fB = poolFile(testCase, "L1B", "ACT1B", day, sat);
    fT = poolFile(testCase, "L1B", "TIM1B", day, sat);
    fC = poolFile(testCase, "L1B", "CLK1B", day, sat);

    [ta, xa, auxa] = gracefoReading.readL1b(fA, "TimeFormat", "gpsns");
    ia = find(startsWith(string(auxa.obsNames), "lin_accl"));
    xa = xa(:, ia);
    % 1. OBC -> receiver time (TIM1B)
    [tt, xt] = gracefoReading.readL1b(fT, "TimeFormat", "gpsns");
    obc = xt(:, 1); rcv = double(tt) * 1e-9;
    use = obc > 0 & rcv > 0;
    [obc, iu] = unique(obc(use)); rcv = rcv(use); rcv = rcv(iu);
    tO = double(ta) * 1e-9;
    tR = interp1(obc, rcv, tO, "linear", "extrap");
    % 2. receiver -> GPS time (CLK1B)
    [tc, xc, auxc] = gracefoReading.readL1b(fC, "TimeFormat", "gpsns");
    rc = double(tc) * 1e-9;                             % rcv_time, receiver time
    eps = xc(:, strcmp(string(auxc.obsNames), "eps_time"));
    [rc, ic] = unique(rc); eps = eps(ic);
    tG = tR + interp1(rc, eps, tR, "linear", "extrap");
    % 3. resample to the 0.1 s grid
    keep = [true; diff(tG) > 0];
    tG = tG(keep); xa = xa(keep, :);
    g0 = int64(ceil(tG(1) * 10)) * int64(1e8);
    ref = double(g0) * 1e-9;
    ts = tG - ref;
    n = floor(ts(end) * 10);
    gs = (0:n)' / 10;
    X = interp1(ts, xa, gs, "linear");
    bin = discretize(gs, ts);
    wide = [diff(ts) > 0.15; false];
    X(~isnan(bin) & wide(max(bin, 1)), :) = NaN;
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    [~, fileName, ext] = fileparts(fA);
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2'), ...
        "fileName", fileName + ext, "product", "ACT1A");
    arc = timeSeriesPreparation.Arc(g0 + int64(0:n)' * int64(1e8), X, aux);
    % ACT1B
    [tb, xb, auxb] = gracefoReading.readL1b(fB, "TimeFormat", "gpsns");
    ib = find(startsWith(string(auxb.obsNames), "lin_accl"));
    d = struct("arc", arc, "tb", tb, "b", xb(:, ib));
    cache.(sat) = d;
end

function f = poolFile(testCase, level, product, day, sat)
% The DATAPOOL file of PRODUCT on DAY for SAT; the test is incomplete without it.
    pool = string(getenv("READING_DATA_POOL"));
    testCase.assumeNotEmpty(char(pool), "READING_DATA_POOL is not set (X-12 needs the DATAPOOL).");
    testCase.assumeNotEmpty(meta.package.fromName("gracefoReading"), "gracefoReading is not on the path.");
    folder = fullfile(pool, "GRACEFO", level, "RL04", extractBefore(day, 5), day);
    hits = dir(fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    testCase.assumeNotEmpty(hits, "X-12 file missing: " + fullfile(folder, product + "_" + day + "_" + sat + "_*.txt"));
    f = string(fullfile(hits(1).folder, hits(1).name));
end
