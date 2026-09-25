classdef TestBinnedMap < matlab.unittest.TestCase
%TESTBINNEDMAP  binnedMap: per-bin mean, sd and count against an explicit loop.
%
%   DESCRIPTION
%     The reference is a loop over the bins with logical masks written
%     here from discretize's rule ([e_i, e_(i+1)), the last bin closed),
%     using mean and std: sums of a few hundred O(1) numbers, so 1e-12.
%     The edge rules are pinned by samples placed on edges. The refusals
%     are fault-injected by their own triggers.
%
%   COVERAGE
%     reference      - mean, sd and count equal the explicit loop.
%     contract       - shape, centres, empty bin NaN, one sample gives sd
%                      NaN, right edge inclusive, outside and NaN ignored,
%                      nUsed.
%     metamorphic    - adding c to value adds c to every mean and leaves
%                      sd and count.
%     robustness     - sizeMismatch and badEdges fire.
%     precision, vectorisation, speed - exempt: exact accumulation, one
%                      map per call, O(N).
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-24 11:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'reference'})
        function equalsExplicitLoop(testCase)
            rs = RandStream("twister", "Seed", 101);
            a = 180 * rand(rs, 3000, 1) - 90;
            b = 360 * rand(rs, 3000, 1);
            v = sind(b) .* cosd(a) + 0.1 * randn(rs, 3000, 1);
            ea = -90:30:90;
            eb = 0:60:360;
            map = timeSeriesPreparation.binnedMap(v, a, b, ea, eb);
            for i = 1:numel(ea) - 1
                for j = 1:numel(eb) - 1
                    inA = a >= ea(i) & (a < ea(i + 1) | (i == numel(ea) - 1 & a == ea(end)));
                    inB = b >= eb(j) & (b < eb(j + 1) | (j == numel(eb) - 1 & b == eb(end)));
                    x = v(inA & inB);
                    testCase.verifyEqual(map.count(i, j), numel(x));
                    testCase.verifyEqual(map.mean(i, j), mean(x), "AbsTol", 1e-12);
                    testCase.verifyEqual(map.sd(i, j), std(x), "AbsTol", 1e-12);
                end
            end
        end
    end

    methods (Test, TestTags = {'contract'})
        function edgesEmptyBinsAndIgnoredSamples(testCase)
            v = [1; 2; 3; 4; 5; NaN; 7];
            a = [0; 0.5; 1; 2; 5; 0.5; 0.5];               % 5 is outside [0, 2]
            b = [0; 0; 0; 0; 0; 0; NaN];
            map = timeSeriesPreparation.binnedMap(v, a, b, [0 1 2], [0 1]);
            testCase.verifySize(map.mean, [2 1]);
            testCase.verifyEqual(map.count, [2; 2]);        % 2 lands in the closed last bin
            testCase.verifyEqual(map.mean, [1.5; 3.5]);
            testCase.verifyEqual(map.nUsed, 4);
            testCase.verifyEqual(map.centresA, [0.5 1.5]);
            testCase.verifyEqual(map.centresB, 0.5);
            empty = timeSeriesPreparation.binnedMap([1; 2], [0.5; 0.5], [0.5; 1.5], [0 1 2], [0 1 2]);
            testCase.verifyEqual(empty.count, [1 1; 0 0]);
            testCase.verifyTrue(all(isnan(empty.mean(2, :))));
            testCase.verifyTrue(all(isnan(empty.sd), "all"));
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function shiftingValueShiftsMeans(testCase)
            rs = RandStream("twister", "Seed", 102);
            a = rand(rs, 500, 1);
            b = rand(rs, 500, 1);
            v = randn(rs, 500, 1);
            m1 = timeSeriesPreparation.binnedMap(v, a, b, 0:0.25:1, 0:0.5:1);
            m2 = timeSeriesPreparation.binnedMap(v + 3, a, b, 0:0.25:1, 0:0.5:1);
            testCase.verifyEqual(m2.mean, m1.mean + 3, "AbsTol", 1e-12);
            testCase.verifyEqual(m2.sd, m1.sd, "AbsTol", 1e-12);
            testCase.verifyEqual(m2.count, m1.count);
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            f = @(varargin) timeSeriesPreparation.binnedMap(varargin{:});
            testCase.verifyError(@() f(ones(3, 1), ones(2, 1), ones(3, 1), [0 1], [0 1]), ...
                "timeSeriesPreparation:binnedMap:sizeMismatch");
            testCase.verifyError(@() f(ones(2), ones(2), ones(2), [0 1], [0 1]), ...
                "timeSeriesPreparation:binnedMap:sizeMismatch");
            testCase.verifyError(@() f(ones(3, 1), ones(3, 1), ones(3, 1), 0, [0 1]), ...
                "timeSeriesPreparation:binnedMap:badEdges");
            testCase.verifyError(@() f(ones(3, 1), ones(3, 1), ones(3, 1), [0 1], [1 0]), ...
                "timeSeriesPreparation:binnedMap:badEdges");
            testCase.verifyError(@() f(ones(3, 1), ones(3, 1), ones(3, 1), [0 Inf], [0 1]), ...
                "timeSeriesPreparation:binnedMap:badEdges");
        end
    end
end
