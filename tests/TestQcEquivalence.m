classdef TestQcEquivalence < matlab.unittest.TestCase
%TESTQCEQUIVALENCE  X-05b's gate: +qc gives the frozen port's outputs, bit for bit.
%
%   DESCRIPTION
%     X-05b brought +qc to this repository's conventions (help template,
%     literal error identifiers instead of a fail helper) and promised the
%     numbers unchanged (CONCEPT 12.9). The frozen port is
%     tests/qc/frozen/*.m.txt, which TestQcPort holds to NonGravForces.qc
%     0.12.0 byte for byte. It is written into a temporary folder as the
%     package qcPort and put on the path. Each case calls the port and the
%     converted unit on the same data and requires isequaln over all
%     outputs, with the provenance records removed at every depth (they
%     carry a creation time). A refusal must raise the same identifier in
%     both. A planted difference of one ulp must fire the comparison
%     (fault injection).
%     X-16 made +qc faster under the same gate (owner decisions
%     2026-09-26: pure MATLAB, the whole of screen, speed as a ratio
%     against the port). Its cases cover the new code paths: Inf and short
%     series in hampel, hampel's block boundary, a long PELT run, many
%     impulses in screen. The speed tests time the port and the unit on
%     one day, 86400 x 3 at 1 Hz, best of three runs each. Before checking
%     the unit, each applies its ratio check to the port against itself
%     (slowest run over fastest) with the bar 10, which must fail (fault
%     injection).
%
%   COVERAGE
%     reference   - each unit's default call and its option branches:
%                   residuals (bias, full scale, difference, highpass),
%                   hampel (window, threshold, floor, NaN), detectImpulses
%                   (priors, three channels, NaN), detectJumps (level,
%                   slope, penalty, NaN, three channels), eventTable (empty,
%                   rows), screen (with and without a template, highpass,
%                   priors); the refusals.
%     contract    - every ported unit of +qc is covered by a case (the
%                   X-17 units templateBank and detectTemplates are new
%                   and tested by TestTemplates).
%     robustness  - a one-ulp change of an output is detected.
%     speed       - hampel at least 5 times faster than the port (owner,
%                   2026-09-26, after 6.42 and 7.57 measured against 10),
%                   detectJumps not slower, screen at least 2 times faster.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.2.0 | 2026-09-26 19:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (TestParameter)
        Case
    end

    methods (TestParameterDefinition, Static)
        function Case = defineCases()
            Case = cellstr(caseNames());
        end
    end

    methods (TestClassSetup)
        function frozenPortOnPath(testCase)
            root = fileparts(fileparts(mfilename("fullpath")));
            src = fullfile(root, "tests", "qc", "frozen");
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            pkg = fullfile(tmp, "+qcPort");
            mkdir(pkg);
            for f = reshape(dir(fullfile(src, "*.m.txt")), 1, [])
                copyfile(fullfile(f.folder, f.name), fullfile(pkg, erase(f.name, ".txt")));
            end
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(tmp));
            testCase.assertNotEmpty(meta.package.fromName("qcPort"), "The frozen port did not load.");
        end
    end

    methods (Test, TestTags = {'reference'})
        function sameOutputs(testCase, Case)
            run = caseFunction(Case);
            [old, oldId] = capture(@() run("qcPort"));
            [new, newId] = capture(@() run("timeSeriesPreparation.qc"));
            testCase.verifyEqual(newId, oldId, Case + ": identifiers differ.");
            testCase.verifyTrue(isequaln(stripProvenance(new), stripProvenance(old)), ...
                Case + ": outputs differ from the frozen port.");
        end
    end

    methods (Test, TestTags = {'contract'})
        function everyUnitIsCovered(testCase)
            units = ["residuals" "hampel" "detectImpulses" "detectJumps" "eventTable" "screen"];
            names = string(caseNames());
            for u = units
                testCase.verifyTrue(any(startsWith(names, u)), u + " has no equivalence case.");
            end
            files = dir(fullfile(fileparts(fileparts(mfilename("fullpath"))), ...
                "+timeSeriesPreparation", "+qc", "*.m"));
            found = setdiff(erase(string({files.name}), ".m"), "Contents");
            % X-17 units are new, not ported; TestTemplates covers them.
            found = setdiff(found, ["templateBank" "detectTemplates"]);
            testCase.verifyEqual(sort(found), sort(units), "+qc gained or lost a unit.");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function oneUlpIsDetected(testCase)
            run = caseFunction("residualsHighpass");
            old = stripProvenance(run("qcPort"));
            new = stripProvenance(run("timeSeriesPreparation.qc"));
            testCase.assertTrue(isequaln(new, old));
            new{1}(7, 2) = new{1}(7, 2) + eps(new{1}(7, 2));
            testCase.verifyFalse(isequaln(new, old), "A one-ulp difference went unnoticed.");
        end
    end

    methods (Test, TestTags = {'speed'})
        function hampelFivefold(testCase)
            x = oneDay();
            verifyFaster(testCase, "hampel", 5, @() qcPort.hampel(x), ...
                @() timeSeriesPreparation.qc.hampel(x));
        end

        function detectJumpsNotSlower(testCase)
            [x, t] = oneDay();
            verifyFaster(testCase, "detectJumps", 1, @() qcPort.detectJumps(x, 'Epoch', t), ...
                @() timeSeriesPreparation.qc.detectJumps(x, 'Epoch', t));
        end

        function screenTwofold(testCase)
            [x, t, h] = oneDay();
            verifyFaster(testCase, "screen", 2, @() qcPort.screen(x, zeros(size(x)), t, 'Response', h), ...
                @() timeSeriesPreparation.qc.screen(x, zeros(size(x)), t, 'Response', h));
        end
    end
end

% ------------------------------------------------------------------------

function names = caseNames()
    names = {'residualsDefault', 'residualsHighpass', 'residualsDifference', ...
        'hampelDefault', 'hampelOptions', ...
        'detectImpulsesPriors', 'detectImpulsesThreeAxes', ...
        'detectJumpsLevel', 'detectJumpsSlope', 'detectJumpsThreeAxesNaN', ...
        'eventTableEmpty', 'eventTableRows', ...
        'screenDefault', 'screenFull', 'refusals', ...
        'hampelInfShortNaN', 'hampelBlocks', 'detectJumpsLong', 'screenManyImpulses'};
end

function run = caseFunction(name)
% A function of the namespace ("qcPort" or "timeSeriesPreparation.qc")
% returning every output of one call as a cell.
    f = @(ns, unit) str2func(ns + "." + unit);
    rs = @(seed) RandStream("twister", "Seed", seed);
    switch string(name)
        case "residualsDefault"
            [y, m] = pair(rs(11), 200, 3);
            run = @(ns) outs(2, f(ns, "residuals"), y, m);
        case "residualsHighpass"
            [y, m] = pair(rs(12), 400, 3);
            y(33, 2) = NaN;
            S = [1.02 0.01 0; 0 0.98 0.02; 0.01 0 1.01];
            run = @(ns) outs(2, f(ns, "residuals"), y, m, 'Bias', [1 2 3], 'Scale', S, ...
                'Whitening', "highpass", 'Window', 31);
        case "residualsDifference"
            [y, m] = pair(rs(13), 300, 1);
            run = @(ns) outs(2, f(ns, "residuals"), y, m, 'Scale', 1.05, 'Whitening', "difference");
        case "hampelDefault"
            x = randn(rs(14), 500, 3);
            x([50 51 320], 1) = [9; -8; 12];
            x(100:110, 2) = NaN;
            run = @(ns) outs(2, f(ns, "hampel"), x);
        case "hampelOptions"
            x = round(randn(rs(15), 400, 1) * 4) / 4;
            x(200) = 5;
            run = @(ns) outs(2, f(ns, "hampel"), x, 'Window', 21, 'Threshold', 3, 'MinSigma', 0.1);
        case "detectImpulsesPriors"
            [x, t, h] = pulses(rs(16), 3000);
            x(1500:1520) = NaN;
            pri = timeSeriesPreparation.qc.eventTable(t(1000) + seconds([1; 900]), t(1000) + seconds([2; 901]), ...
                ["impulse"; "impulse"], ["all"; "all"], [NaN; NaN], [NaN; NaN], ["THR1B"; "THR1B"], [1; 1]);
            run = @(ns) outs(2, f(ns, "detectImpulses"), x, 'Epoch', t, 'Response', h, 'Priors', pri);
        case "detectImpulsesThreeAxes"
            [x, t, h] = pulses(rs(17), 2000);
            X = [x, circshift(x, 311), -x];
            run = @(ns) outs(2, f(ns, "detectImpulses"), X, 'Epoch', t, 'Response', h, 'Threshold', 4);
        case "detectJumpsLevel"
            x = randn(rs(18), 1200, 1);
            x(401:end) = x(401:end) + 3;
            x(801:end) = x(801:end) - 5;
            run = @(ns) outs(2, f(ns, "detectJumps"), x, 'Epoch', epochs(1200));
        case "detectJumpsSlope"
            x = randn(rs(19), 800, 1);
            x(401:end) = x(401:end) + 0.05 * (1:400)';
            run = @(ns) outs(2, f(ns, "detectJumps"), x, 'Epoch', epochs(800), 'Model', "slope", ...
                'MinSegment', 10, 'Penalty', 40, 'PriorWindow_s', 30);
        case "detectJumpsThreeAxesNaN"
            X = randn(rs(20), 600, 3);
            X(301:end, 1) = X(301:end, 1) + 4;
            X(151:end, 3) = X(151:end, 3) - 3;
            X(290:310, 2) = NaN;
            run = @(ns) outs(2, f(ns, "detectJumps"), X, 'Epoch', epochs(600), 'Penalty', 25);
        case "eventTableEmpty"
            run = @(ns) outs(1, f(ns, "eventTable"));
        case "eventTableRows"
            t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds([0; 30; 90]);
            run = @(ns) outs(1, f(ns, "eventTable"), t, t + seconds(1), ["outlier"; "impulse"; "jump"], ...
                ["x"; "all"; "z"], [1e-9; NaN; 5e-9], [1e-10; NaN; 3e-10], ["unassigned"; "THR1B"; "eclipse"], [0.2; 1; 0.9]);
        case "screenDefault"
            [x, t] = pulses(rs(21), 3000);
            x(2500:end) = x(2500:end) + 5e-9;
            x(700) = 3e-8;
            run = @(ns) outs(3, f(ns, "screen"), x, zeros(3000, 1), t);
        case "screenFull"
            [x, t, h] = pulses(rs(22), 3000);
            x(2500:end) = x(2500:end) + 5e-9;
            x(700) = 3e-8;
            X = [x, circshift(x, 500), -x];
            M = 1e-10 * randn(rs(23), 3000, 3);
            thr = timeSeriesPreparation.qc.eventTable(t(1000), t(1003), "impulse", "all", NaN, NaN, "THR1B", 1);
            run = @(ns) outs(3, f(ns, "screen"), X, M, t, 'Whitening', "highpass", 'Window', 301, ...
                'Response', h, 'Thrusters', thr, 'HampelWindow', 41, 'JumpMinSegment', 20);
        case "refusals"
            run = @(ns) refusals(ns);
        case "hampelInfShortNaN"
            x = randn(rs(24), 300, 3);
            x(40:41, 1) = [Inf; -Inf];
            x(:, 3) = NaN;
            x([10 200], 3) = [1; 2];                    % fewer than three finite samples in every window
            r = randn(rs(25), 1, 20);                   % a row, shorter than the window
            run = @(ns) [outs(2, f(ns, "hampel"), x), outs(2, f(ns, "hampel"), r, 'Window', 61)];
        case "hampelBlocks"
            x = randn(rs(26), 5000, 1);                 % blocks of floor(2^16/61) = 1074 windows; a partial last block
            x(2140:2160) = NaN;                         % across the boundary at sample 2149
            x([2148 2150 4999]) = [10; -9; 8];
            run = @(ns) outs(2, f(ns, "hampel"), x);
        case "detectJumpsLong"
            x = randn(rs(27), 20000, 1);
            for k = 1:8
                x(2000 * k + 1:end) = x(2000 * k + 1:end) + 2 * (-1)^k;
            end
            run = @(ns) outs(2, f(ns, "detectJumps"), x, 'Epoch', epochs(20000), 'MinSegment', 30);
        case "screenManyImpulses"
            h = sin(pi * (0:29)' / 30).^2;
            X = 1e-9 * randn(rs(28), 6000, 3);
            for k = 0:39
                q = 100 + 140 * k;
                X(q:q + 29, mod(k, 3) + 1) = X(q:q + 29, mod(k, 3) + 1) + 8e-9 * h;
            end
            run = @(ns) outs(3, f(ns, "screen"), X, zeros(6000, 3), epochs(6000), 'Response', h);
    end
end

function verifyFaster(testCase, name, bar, old, new)
% The port's best time over the unit's must reach bar. The check is first
% applied to the port against itself (its slowest run over its fastest)
% with the bar 10 and must fail.
    met = @(tOld, tNew, b) tOld / tNew >= b;
    tPort = runs(old);
    testCase.assertFalse(met(max(tPort), min(tPort), 10), ...
        name + ": the ratio check passed the port against itself (fault injection).");
    tOld = min(tPort);
    tNew = min(runs(new));
    testCase.verifyTrue(met(tOld, tNew, bar), sprintf( ...
        "%s: port %.3f s, unit %.3f s, ratio %.2f < %g.", name, tOld, tNew, tOld / tNew, bar));
end

function t = runs(fn)
% Three timed runs; the best of them discounts the first call's warm-up.
    t = zeros(1, 3);
    for k = 1:3
        t0 = tic;
        fn();
        t(k) = toc(t0);
    end
end

function [x, t, h] = oneDay()
% One day at 1 Hz on three axes: white noise of 1e-9, ten pulses per axis
% and two level jumps; UTC epochs; the pulse template.
    K = 86400;
    h = sin(pi * (0:29)' / 30).^2;
    x = 1e-9 * randn(RandStream("twister", "Seed", 29), K, 3);
    for k = 1:10
        q = 8000 * k;
        x(q:q + 29, :) = x(q:q + 29, :) + 8e-9 * h;
    end
    x(30001:end, 1) = x(30001:end, 1) + 5e-9;
    x(60001:end, 3) = x(60001:end, 3) - 4e-9;
    t = epochs(K);
end

function c = outs(n, fn, varargin)
% All n outputs of fn(varargin{:}) as a cell.
    c = cell(1, n);
    [c{:}] = fn(varargin{:});
end

function c = refusals(ns)
% The identifier of each refused call, in order.
    t = epochs(50);
    calls = {
        @() feval(ns + ".residuals", randn(5, 3), randn(4, 3))
        @() feval(ns + ".residuals", randn(5, 3), randn(5, 3), 'Whitening', "highpass", 'Window', 4)
        @() feval(ns + ".hampel", randn(3, 3, 3))
        @() feval(ns + ".hampel", randn(9, 1), 'Window', 10)
        @() feval(ns + ".detectImpulses", randn(50, 1), 'Response', [0; 1; 0])
        @() feval(ns + ".detectImpulses", randn(50, 1), 'Epoch', t, 'Response', ones(5, 1))
        @() feval(ns + ".detectImpulses", randn(50, 2), 'Epoch', t, 'Response', [0; 1; 0])
        @() feval(ns + ".detectImpulses", randn(50, 1), 'Epoch', t, 'Response', [0; 1; 0], 'Threshold', 0)
        @() feval(ns + ".detectImpulses", randn(50, 1), 'Epoch', t, 'Response', [0; 1; 0], 'Priors', table(1))
        @() feval(ns + ".detectJumps", randn(50, 1))
        @() feval(ns + ".detectJumps", randn(50, 1), 'Epoch', t, 'MinSegment', 1)
        @() feval(ns + ".detectJumps", randn(3, 1), 'Epoch', t(1:3))
        @() feval(ns + ".eventTable", t(1))
        @() feval(ns + ".eventTable", t(1), t(1), "blip", "x", 1, 1, "THR1B", 1)
        @() feval(ns + ".eventTable", t(1), t(1), "jump", "x", 1, 1, "THR1B", NaN)
        @() feval(ns + ".screen", randn(50, 1), zeros(49, 1), t)
        @() feval(ns + ".screen", randn(50, 1), zeros(50, 1), datetime(2020, 1, 1) + seconds((0:49)'))};
    c = cell(1, numel(calls));
    for k = 1:numel(calls)
        try
            calls{k}();
            c{k} = "no error";
        catch err
            c{k} = string(err.identifier);
        end
    end
end

function [c, id] = capture(fn)
% The outputs of fn, or the identifier it raised.
    c = {};
    id = "";
    try
        c = fn();
    catch err
        id = string(err.identifier);
    end
end

function x = stripProvenance(x)
% Remove every field named provenance, at any depth of structs and cells.
    if iscell(x)
        for k = 1:numel(x)
            x{k} = stripProvenance(x{k});
        end
    elseif isstruct(x)
        if isfield(x, "provenance")
            x = rmfield(x, "provenance");
        end
        for fn = reshape(string(fieldnames(x)), 1, [])
            for k = 1:numel(x)
                x(k).(fn) = stripProvenance(x(k).(fn));
            end
        end
    end
end

function [y, m] = pair(rs, K, M)
    m = randn(rs, K, M);
    y = 1.03 * m + 0.2 + 0.1 * randn(rs, K, M);
end

function [x, t, h] = pulses(rs, K)
% White noise of 1e-9 with two raised-cosine pulses; UTC epochs at 1 Hz.
    h = sin(pi * (0:29)' / 30).^2;
    x = 1e-9 * randn(rs, K, 1);
    x(1000:1029) = x(1000:1029) + 8e-9 * h;
    x(1900:1929) = x(1900:1929) - 6e-9 * h;
    t = epochs(K);
end

function t = epochs(K)
    t = datetime(2020, 1, 1, "TimeZone", "UTC") + seconds((0:K - 1)');
end
