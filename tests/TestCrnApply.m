classdef TestCrnApply < matlab.unittest.TestCase
%TESTCRNAPPLY  crnApply: output-epoch evaluation, windows, grid rules, derivatives.
%
%   DESCRIPTION
%     crnApply evaluates the ATBD convolution only at the output epochs
%     (CONCEPT 6.1, item 11). The promises pinned here: the numbers equal
%     full-rate convolution followed by sampling, and piecewise evaluation
%     with half-span overlap, bit for bit; an independent implementation
%     (MATLAB conv) agrees to rounding; a constant is scaled by the DC gain
%     and a sinusoid at f0 passes with unit gain; windows touching an edge, a
%     gap, a NaN or a removed sample give NaN and the layer crnWindow; the
%     grid rules refuse. Tolerances: one output is an Nf-term dot product of
%     taps (sum|F| = 1.0000001) with data of size 1, so its rounding is at
%     worst Nf*eps = 3.1e-13; 1e-12 is used.
%
%   COVERAGE
%     contract       - constant in, c*dcGain out; NaN edges of Nh samples;
%                      layer crnWindow; units and provenance of derivatives.
%     reference      - equals conv(x, K, "same") for F and dF; unit gain at
%                      f0; derivative of an in-band sinusoid.
%     vectorisation  - 1 Hz outputs equal the 10 Hz output sampled, bitwise;
%                      three columns equal three single-column calls, bitwise.
%     metamorphic    - two overlapping pieces equal the whole, bitwise;
%                      linearity.
%     robustness     - gaps, NaN and removed samples blank exactly their
%                      windows; off-grid input and output, non-increasing
%                      output, double epochs, a bad kernel, a non-integer
%                      step and an empty arc are refused.
%     speed          - 1 Hz outputs cost at most half of full rate (ideal 0.1).
%     precision      - exempt beyond the tolerances above: crnApply adds no
%                      arithmetic of its own to the kernel's dot product.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-23 08:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Access = private)
        K
    end

    methods (TestClassSetup)
        function buildKernel(testCase)
            testCase.K = timeSeriesPreparation.crnKernel("ACC");
        end
    end

    methods (Test, TestTags = {'contract'})
        function constantScaledByDcGain(testCase)
            arc = arcOf(3 * ones(6000, 1));
            out = timeSeriesPreparation.crnApply(arc, testCase.K);
            Nh = testCase.K.Nh;
            inner = out.obs(Nh + 1:end - Nh);
            testCase.verifyEqual(inner, 3 * testCase.K.dcGain * ones(size(inner)), "RelTol", 1e-12);
            testCase.verifyTrue(all(isnan(out.obs([1:Nh, end - Nh + 1:end]))));
            testCase.verifyEqual(out.layers.crnWindow, isnan(out.obs));
            testCase.verifyEqual(out.weights, double(~isnan(out.obs)));
        end

        function derivativeUnitsAndProvenance(testCase)
            arc = arcOf(ones(3000, 1));
            d1 = timeSeriesPreparation.crnApply(arc, testCase.K, Derivative = 1);
            d2 = timeSeriesPreparation.crnApply(arc, testCase.K, Derivative = 2);
            testCase.verifyEqual([d1.units d2.units], ["m/s2/s" "m/s2/s^2"]);
            testCase.verifyEqual(d1.names, arc.names);
            % crnApply's entry, then the crnWindow layer's.
            testCase.verifyEqual([d1.provenance(end - 1:end).stage], ["crnApply" "addLayer"]);
            testCase.verifyEqual(d1.provenance(end - 1).detail.derivative, 1);
            testCase.verifyEqual(d1.provenance(end - 1).detail.preset, "ACC");
            testCase.verifyEqual(numel(d1.provenance), numel(arc.provenance) + 2);
        end
    end

    methods (Test, TestTags = {'reference'})
        function equalsConv(testCase)
            x = sin((1:6000)' / 300) + 0.1 * cos((1:6000)' / 7);
            arc = arcOf(x);
            Nh = testCase.K.Nh;
            names = ["F" "dF"];
            for d = [0 1]
                taps = testCase.K.(names(d + 1));
                ref = conv(x, taps, "same");
                out = timeSeriesPreparation.crnApply(arc, testCase.K, Derivative = d);
                in = Nh + 1:numel(x) - Nh;
                testCase.verifyEqual(out.obs(in), ref(in), "AbsTol", 1e-12 * max(abs(ref)), "derivative " + d);
            end
        end

        function unitGainAtF0(testCase)
            f0 = testCase.K.f0;
            t = (0:40000 - 1)' / 10;
            arc = arcOf(cos(2 * pi * f0 * t));
            out = timeSeriesPreparation.crnApply(arc, testCase.K);
            in = ~isnan(out.obs);
            testCase.verifyEqual(out.obs(in), cos(2 * pi * f0 * t(in)), "AbsTol", 1e-12);
        end

        function derivativeOfInBandSinusoid(testCase)
            f = 0.01;
            k = testCase.K;
            t = (0:6000 - 1)' / 10;
            G = sum(k.F .* cos(2 * pi * f * k.lags / k.fs));     % real: F is even
            out = timeSeriesPreparation.crnApply(arcOf(sin(2 * pi * f * t)), k, Derivative = 1);
            in = ~isnan(out.obs);
            testCase.verifyEqual(out.obs(in), 2 * pi * f * G * cos(2 * pi * f * t(in)), ...
                "AbsTol", 1e-10 * 2 * pi * f);
        end
    end

    methods (Test, TestTags = {'vectorisation'})
        function outputEpochsEqualFullRateSampled(testCase)
            arc = arcOf(randn(RandStream("twister", "Seed", 3), 8000, 1));
            full = timeSeriesPreparation.crnApply(arc, testCase.K);
            oneHz = timeSeriesPreparation.crnApply(arc, testCase.K, OutputEpochs = arc.t(1:10:end));
            testCase.verifyTrue(isequaln(oneHz.obs, full.obs(1:10:end)));
            testCase.verifyEqual(oneHz.t, arc.t(1:10:end));
        end

        function columnsEqualSingleColumns(testCase)
            x = randn(RandStream("twister", "Seed", 4), 5000, 3);
            all3 = timeSeriesPreparation.crnApply(arcOf(x), testCase.K);
            for c = 1:3
                one = timeSeriesPreparation.crnApply(arcOf(x(:, c)), testCase.K);
                testCase.verifyTrue(isequaln(all3.obs(:, c), one.obs), "column " + c);
            end
        end
    end

    methods (Test, TestTags = {'metamorphic'})
        function piecesEqualWhole(testCase)
            x = randn(RandStream("twister", "Seed", 5), 10000, 1);
            arc = arcOf(x);
            whole = timeSeriesPreparation.crnApply(arc, testCase.K);
            Nh = testCase.K.Nh;
            cut = 5000;                                      % pieces overlap by 2*Nh
            a = arcOf(x(1:cut + Nh), arc.t(1));
            b = arcOf(x(cut - Nh + 1:end), arc.t(cut - Nh + 1));
            pa = timeSeriesPreparation.crnApply(a, testCase.K, OutputEpochs = arc.t(Nh + 1:cut));
            pb = timeSeriesPreparation.crnApply(b, testCase.K, OutputEpochs = arc.t(cut + 1:end - Nh));
            testCase.verifyTrue(isequal([pa.obs; pb.obs], whole.obs(Nh + 1:end - Nh)));
        end

        function linear(testCase)
            s = RandStream("twister", "Seed", 6);
            x = randn(s, 4000, 1); y = randn(s, 4000, 1);
            ax = timeSeriesPreparation.crnApply(arcOf(x), testCase.K); fx = ax.obs;
            ay = timeSeriesPreparation.crnApply(arcOf(y), testCase.K); fy = ay.obs;
            axy = timeSeriesPreparation.crnApply(arcOf(2 * x - 3 * y), testCase.K); fxy = axy.obs;
            in = ~isnan(fxy);
            testCase.verifyEqual(fxy(in), 2 * fx(in) - 3 * fy(in), "AbsTol", 1e-12 * 5 * max(abs(fxy)));
        end
    end

    methods (Test, TestTags = {'robustness'})
        function gapBlanksExactlyItsWindows(testCase)
            Nh = testCase.K.Nh;
            arc = arcOf(ones(6000, 1));
            keep = true(6000, 1); keep(3000) = false;             % one missing epoch
            gapped = arcOf(ones(5999, 1), arc.t(1), arc.t(keep));
            out = timeSeriesPreparation.crnApply(gapped, testCase.K, OutputEpochs = arc.t);
            expectNaN = false(6000, 1);
            expectNaN([1:Nh, end - Nh + 1:end]) = true;
            expectNaN(3000 - Nh:3000 + Nh) = true;
            testCase.verifyEqual(isnan(out.obs), expectNaN);
        end

        function nanAndRemovedSamplesBlankTheirWindows(testCase)
            Nh = testCase.K.Nh;
            x = ones(6000, 1); x(2000) = NaN;
            arc = addLayer(arcOf(x), "user", (1:6000)' == 4000);
            out = timeSeriesPreparation.crnApply(arc, testCase.K);
            expectNaN = false(6000, 1);
            expectNaN([1:Nh, end - Nh + 1:end]) = true;
            expectNaN([2000 - Nh:2000 + Nh, 4000 - Nh:4000 + Nh]) = true;
            testCase.verifyEqual(isnan(out.obs), expectNaN);
        end

        function gridRulesRefused(testCase)
            arc = arcOf(ones(3000, 1));
            off = arcOf(ones(3000, 1), int64(0), arc.t + [0; int64(1); zeros(2998, 1, "int64")]);
            testCase.verifyError(@() timeSeriesPreparation.crnApply(off, testCase.K), ...
                "timeSeriesPreparation:crnApply:notOnGrid");
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, testCase.K, ...
                OutputEpochs = arc.t(1:10) + 5), "timeSeriesPreparation:crnApply:epochNotOnGrid");
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, testCase.K, ...
                OutputEpochs = flipud(arc.t(1:10))), "timeSeriesPreparation:crnApply:epochNotOnGrid");
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, testCase.K, ...
                OutputEpochs = double(arc.t(1:10))), "MATLAB:validators:mustBeA");
        end

        function badKernelAndRateRefused(testCase)
            arc = arcOf(ones(3000, 1));
            k = rmfield(testCase.K, "dF");
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, k), ...
                "timeSeriesPreparation:crnApply:badKernel");
            k = testCase.K; k.F = k.F(1:end - 1);
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, k), ...
                "timeSeriesPreparation:crnApply:badKernel");
            k = testCase.K; k.fs = 3;
            testCase.verifyError(@() timeSeriesPreparation.crnApply(arc, k), ...
                "timeSeriesPreparation:crnApply:rate");
        end

        function emptyArcRefused(testCase)
            testCase.verifyError(@() timeSeriesPreparation.crnApply(timeSeriesPreparation.Arc(), testCase.K), ...
                "timeSeriesPreparation:crnApply:emptyArc");
        end
    end

    methods (Test, TestTags = {'speed'})
        function outputEpochsAreCheaper(testCase)
            % Ratio budget, not a wall-clock number: 1 Hz outputs do a tenth of
            % the multiply-adds of 10 Hz outputs; half is allowed for overheads.
            arc = arcOf(randn(RandStream("twister", "Seed", 7), 72000, 3));
            t1 = arc.t(1:10:end);
            full = @() timeSeriesPreparation.crnApply(arc, testCase.K);
            oneHz = @() timeSeriesPreparation.crnApply(arc, testCase.K, OutputEpochs = t1);
            ratio = median(arrayfun(@(r) timed(oneHz) / timed(full), 1:3));
            testCase.verifyLessThan(ratio, 0.5, sprintf("1 Hz / 10 Hz time ratio %.3f", ratio));
        end
    end
end

% ------------------------------------------------------------------------

function arc = arcOf(x, t0, t)
% A 10 Hz ACC1A-shaped arc of the columns of X starting at T0 (default 2020).
    if nargin < 2, t0 = int64(631152000) * int64(1e9); end
    if nargin < 3, t = t0 + int64(0:size(x, 1) - 1)' * int64(1e8); end
    names = "lin_accl_" + ["x" "y" "z"];
    names = cellstr(names(1:size(x, 2)));
    units = struct();
    for n = names, units.(n{1}) = "m/s2"; end
    aux = struct("obsNames", {names}, "variableNames", {names}, ...
        "variableFieldNames", {names}, "variableUnits", units, ...
        "fileName", "ACC1A_2020-01-01_C_04.txt", "product", "ACC1A");
    arc = timeSeriesPreparation.Arc(t, x, aux);
end

function s = timed(f)
    tic; f(); s = toc;
end
