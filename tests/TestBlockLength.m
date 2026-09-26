classdef TestBlockLength < matlab.unittest.TestCase
%TESTBLOCKLENGTH  internal.blockLength against Patton's reference code (via recombinator).
%
%   DESCRIPTION
%     The automatic block length of bootstrap and crossval is pinned against
%     tests/oracles/block_length_pw.json, written by recombinator 0.0.6.1, a
%     port of Patton's opt_block_length_REV_dec07, which shares no code with
%     this toolbox. The six series are rebuilt here from an integer LCG and
%     an explicit AR(1) loop, so both programs see the same doubles.
%     Tolerances name the term they bound: the moments are sums over up to
%     5000 products, rounded differently by corrcoef/cov and NumPy, a few
%     1e-13 relative, so 1e-9 on b. The band decisions of step 2 cannot
%     flip on that rounding: the smallest margin of any |rho| to the band is
%     1.2e-3 relative (case ar09, NumPy, 2026-09-23).
%
%   COVERAGE
%     reference      - b of six series (white, AR(1) with phi 0.5, 0.9,
%                      0.95, -0.6, and a square wave in noise) equals the
%                      oracle; phi 0.95 and the square wave enter the
%                      no-window branch of step 2.
%     contract       - sizes of b and info; b >= 1 and at most the cap.
%     vectorisation  - a batched call equals the per-column calls bitwise.
%     robustness     - a constant column gives 1; NaN gaps give a finite
%                      length close to the complete series'; too few rows
%                      are refused.
%     precision, speed, metamorphic - exempt: no closed form beyond the
%                      oracle; the rule is O(N sqrt N) and runs once per
%                      call of bootstrap or crossval.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Access = private)
        Oracle
    end

    methods (TestClassSetup)
        function readOracle(testCase)
            file = fullfile(fileparts(mfilename("fullpath")), "oracles", "block_length_pw.json");
            testCase.Oracle = jsondecode(fileread(file));
        end
    end

    methods (Test, TestTags = {'reference'})
        function equalsPattonReference(testCase)
            for c = reshape(testCase.Oracle.cases, 1, [])
                x = lcgSeries(c);
                testCase.assertEqual([x(1) x(end)], [c.first c.last], ...
                    "The series rebuild differs from NumPy's: " + c.name);
                b = timeSeriesPreparation.internal.blockLength(x);
                testCase.verifyEqual(b, c.b, "RelTol", 1e-9, c.name);
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function sizesAndBounds(testCase)
            c = testCase.Oracle.cases(3);
            x = lcgSeries(c);
            [b, info] = timeSeriesPreparation.internal.blockLength([x, -x, x.^2]);
            testCase.verifySize(b, [1 3]);
            testCase.verifySize(info.mhat, [1 3]);
            testCase.verifySize(info.M, [1 3]);
            n = numel(x);
            testCase.verifyGreaterThanOrEqual(b, 1);
            testCase.verifyLessThanOrEqual(b, ceil(min(3 * sqrt(n), n / 3)));
            testCase.verifyEqual(info.kn, 5);
            testCase.verifyEqual(info.mmax, ceil(sqrt(n)) + 5);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function batchEqualsColumns(testCase)
            % Cases 2 and 5 have 1000 and 3000 samples; the first 1000 of each.
            a = lcgSeries(testCase.Oracle.cases(2));
            b = lcgSeries(testCase.Oracle.cases(5));
            X = [a(1:1000), b(1:1000)];
            b = timeSeriesPreparation.internal.blockLength(X);
            testCase.verifyEqual(b, [timeSeriesPreparation.internal.blockLength(X(:, 1)), ...
                timeSeriesPreparation.internal.blockLength(X(:, 2))]);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function constantColumnGivesOne(testCase)
            testCase.verifyEqual(timeSeriesPreparation.internal.blockLength(ones(500, 1)), 1);
        end

        function gapsStayFinite(testCase)
            % 10 % of the samples missing in five holes: the pairwise moments
            % move b a little, not to NaN (NumPy: 51.3 -> 53.7, 2026-09-23).
            x = lcgSeries(testCase.Oracle.cases(3));
            full = timeSeriesPreparation.internal.blockLength(x);
            for s = 100:400:1700
                x(s:s+39) = NaN;
            end
            b = timeSeriesPreparation.internal.blockLength(x);
            testCase.verifyTrue(isfinite(b));
            testCase.verifyEqual(b, full, "RelTol", 0.25);
        end

        function tooShortRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.internal.blockLength(zeros(20, 1)), ...
                "timeSeriesPreparation:blockLength:tooShort");
        end
    end
end

function x = lcgSeries(c)
% The oracle's series: integer LCG noise through an AR(1), plus a square wave.
    u = uint64(c.seed);
    x = zeros(c.n, 1);
    prev = 0;
    for k = 1:c.n
        u = mod(uint64(1664525) * u + uint64(1013904223), uint64(2)^32);
        e = double(u) / 2^32 - 0.5;
        if k == 1
            prev = e;
        else
            prev = c.phi * prev + e;
        end
        x(k) = prev;
    end
    if c.period > 0
        k = (1:c.n)';
        x = x + c.amp * (-1) .^ floor(k / c.period);
    end
end
