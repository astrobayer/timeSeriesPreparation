classdef TestReport < matlab.unittest.TestCase
%TESTREPORT  report: four figures of a run, the self-contained HTML page, a campaign index, speed.
%
%   DESCRIPTION
%     X-11 (CONCEPT 10.1; owner decisions 2026-09-26). The runs are 1 Hz
%     ACT1B-like arcs of GRACE-FO C: three sinusoids plus seeded white
%     noise with a spike on y, the sinusoids as reference, and the noise
%     stage (AR(1)) and alignment switched on. The figures are made with
%     Visible "off" and closed by teardown. No pixel reference is kept
%     (owner decision), so there is no precision or reference test: the
%     contract is the handles, the notes, the files and the page's
%     structure. Fault injection: a struct that is no result and a
%     campaign without ExportTo refuse; the speed bar of 0 s must fail.
%
%   COVERAGE
%     contract       - four figure handles; the PNGs and the page with
%                      its four embedded images; a bare run notes why noise
%                      and alignment are empty; a campaign's index links
%                      one page per day.
%     robustness     - the refusals.
%     speed          - a six-hour three-axis run is reported and exported
%                      in under 10 s per figure.
%     precision, reference, vectorisation, metamorphic - exempt: the
%                      report draws stored values (no pixel reference).
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.0 | 2026-09-26 23:15 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    methods (Test, TestTags = {'contract'})
        function figureHandles(testCase)
            out = timeSeriesPreparation.report(fullRun(600), Visible = "off");
            closeLater(testCase, out);
            testCase.verifyEqual(string(fieldnames(out.figures))', ["series" "events" "noise" "alignment"]);
            for name = string(fieldnames(out.figures))'
                h = out.figures.(name);
                testCase.verifyTrue(isgraphics(h, "figure"), name);
                testCase.verifyEqual(string(h.Visible), "off", name);
                testCase.verifyEqual(out.notes.(name), "", name);
            end
            testCase.verifyEmpty(out.files);
            testCase.verifyEqual(out.html, "");
        end

        function exportWritesFiles(testCase)
            folder = tempFolder(testCase);
            res = fullRun(600);
            out = timeSeriesPreparation.report(res, Visible = "off", ExportTo = folder);
            closeLater(testCase, out);
            for name = ["series" "events" "noise" "alignment"]
                testCase.verifyTrue(isfile(fullfile(folder, name + ".png")), name);
            end
            testCase.verifyEqual(out.html, fullfile(folder, "report.html"));
            testCase.verifyEqual(numel(out.files), 5);
            page = string(fileread(out.html));
            testCase.verifyTrue(startsWith(page, "<!DOCTYPE html>"));
            testCase.verifyTrue(endsWith(strtrim(page), "</html>"));
            testCase.verifyEqual(count(page, "src=""data:image/png;base64,"), 4);
            testCase.verifyFalse(contains(page, ["http://" "https://"]), "the page refers outside");
            testCase.verifyTrue(contains(page, sprintf("QC events (%d of %d)", ...
                min(200, height(res.flags.events)), height(res.flags.events))));
            testCase.verifyTrue(contains(page, res.provenance(end).detail.configHash));
        end

        function stageNotRunNoted(testCase)
            [arc, ~] = pair(300, 1);
            res = timeSeriesPreparation.run(arc);
            out = timeSeriesPreparation.report(res, Visible = "off");
            closeLater(testCase, out);
            testCase.verifyEqual(out.notes.noise, "noise: cfg.noise.order not stated");
            testCase.verifyTrue(startsWith(out.notes.alignment, "align: no Reference"));
            testCase.verifyEqual(out.notes.events, "qc: no Reference");
            testCase.verifyEqual(out.notes.series, "");
            txt = findall(out.figures.noise, "Type", "text");
            testCase.verifyTrue(any(contains(string({txt.String}), "not run")));
        end

        function campaignIndex(testCase)
            folder = tempFolder(testCase);
            [a1, r1] = pair(300, 1);
            [a2, r2] = pair(300, 2);
            res = timeSeriesPreparation.run([a1 a2], Reference = [r1 r2]);
            out = timeSeriesPreparation.report(res, ExportTo = folder);
            testCase.verifyEqual(out.html, fullfile(folder, "index.html"));
            index = string(fileread(out.html));
            for day = ["2020-01-02" "2020-01-03"]
                testCase.verifyTrue(isfile(fullfile(folder, day, "report.html")), day);
                testCase.verifyTrue(contains(index, "href=""" + day + "/report.html"""), day);
            end
            testCase.verifyEmpty(fieldnames(out.figures));
            testCase.verifyEmpty(findall(groot, "Type", "figure", "Name", "series"), ...
                "a campaign report left figures open");
        end
    end

    methods (Test, TestTags = {'robustness'})
        function refusals(testCase)
            testCase.verifyError(@() timeSeriesPreparation.report(struct("a", 1)), ...
                "timeSeriesPreparation:report:inputResult");
            [a1, r1] = pair(300, 1);
            [a2, r2] = pair(300, 2);
            res = timeSeriesPreparation.run([a1 a2], Reference = [r1 r2]);
            testCase.verifyError(@() timeSeriesPreparation.report(res), ...
                "timeSeriesPreparation:report:exportToRequired");
        end
    end

    methods (Test, TestTags = {'speed'})
        function speedPerFigure(testCase)
            folder = tempFolder(testCase);
            res = fullRun(21600);
            tic;
            out = timeSeriesPreparation.report(res, Visible = "off", ExportTo = folder);
            elapsed = toc;
            closeLater(testCase, out);
            perFigure = elapsed / 4;
            testCase.verifyGreaterThan(perFigure, 0, "a bar of 0 s must fail (fault injection)");
            testCase.verifyLessThan(perFigure, 10, sprintf("%.2f s per figure", perFigure));
        end
    end
end

% ------------------------------------------------------------------------

function res = fullRun(n)
% A run of n seconds with a spike on y, the noise stage and alignment.
    [arc, ref] = pair(n, 1);
    x = arc.obs; x(round(n / 2), 2) = x(round(n / 2), 2) + 1e-7;
    arc = arcOf(arc.t, x, "2020-01-02");
    cfg = set(timeSeriesPreparation.Config(arc), "noise", "order", [1 0]);
    res = timeSeriesPreparation.run(arc, Reference = ref, Config = cfg);
end

function [arc, ref] = pair(n, k)
% Day k from 2020-01-02, n s at 1 Hz: sinusoids plus seeded noise; the sinusoids.
    s = (0:n - 1)';
    sig = 1e-7 * [sin(2 * pi * s / 300), cos(2 * pi * s / 300), sin(2 * pi * s / 200)];
    t = int64(7306 + k - 1) * int64(86400e9) - int64(43200e9) + int64(18e9) + int64(s) * int64(1e9);
    day = string(datetime(2020, 1, 1 + k, "Format", "yyyy-MM-dd"));
    arc = arcOf(t, sig + 1e-9 * randn(RandStream("twister", "Seed", 30 + k), n, 3), day);
    ref = arcOf(t, sig, day);
end

function arc = arcOf(t, obs, day)
    names = {'lin_accl_x', 'lin_accl_y', 'lin_accl_z'};
    units = struct('lin_accl_x', 'm/s2', 'lin_accl_y', 'm/s2', 'lin_accl_z', 'm/s2');
    aux = struct("obsNames", {names}, "variableNames", {names}, "variableFieldNames", {names}, ...
        "variableUnits", units, "fileName", "ACT1B_" + day + "_C_04.txt", "product", "ACT1B");
    arc = timeSeriesPreparation.Arc(t, obs, aux);
end

function closeLater(testCase, out)
    for name = string(fieldnames(out.figures))'
        h = out.figures.(name);
        testCase.addTeardown(@() close(h(isgraphics(h))));
    end
end

function folder = tempFolder(testCase)
    fx = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    folder = string(fx.Folder);
end
