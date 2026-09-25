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
%
%   COVERAGE
%     reference   - each unit's default call and its option branches:
%                   residuals (bias, full scale, difference, highpass),
%                   hampel (window, threshold, floor, NaN), detectImpulses
%                   (priors, three channels, NaN), detectJumps (level,
%                   slope, penalty, NaN, three channels), eventTable (empty,
%                   rows), screen (with and without a template, highpass,
%                   priors); the refusals.
%     contract    - every unit of +qc is covered by a case.
%     robustness  - a one-ulp change of an output is detected.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-24 22:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

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
end

% ------------------------------------------------------------------------

function names = caseNames()
    names = {'residualsDefault', 'residualsHighpass', 'residualsDifference', ...
        'hampelDefault', 'hampelOptions', ...
        'detectImpulsesPriors', 'detectImpulsesThreeAxes', ...
        'detectJumpsLevel', 'detectJumpsSlope', 'detectJumpsThreeAxesNaN', ...
        'eventTableEmpty', 'eventTableRows', ...
        'screenDefault', 'screenFull', 'refusals'};
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
    end
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
