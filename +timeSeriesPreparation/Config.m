classdef Config
%CONFIG  Instrument settings in ten sections, strict about field names.
%
%   SYNTAX
%     cfg = timeSeriesPreparation.Config()
%     cfg = timeSeriesPreparation.Config(arc)
%     cfg = set(cfg, section, field, value)
%     s   = toStruct(cfg)
%
%   DESCRIPTION
%     The settings of every stage, in the sections of CONCEPT 5: mask, qc,
%     crn, align, fill, noise, unc, drivers, run, export. Each section has a schema,
%     the list of fields it knows; set refuses a section or a field outside
%     it, so a misspelt option fails instead of being silently ignored.
%     Config(arc) records the arc's mission and product and returns the
%     preset for that product (CONCEPT 5).
%
%     Each section holds the options of its stage (X-10: every section
%     has its fields; run passes them on). An option whose default
%     would be an assumption defaults to empty (R5). Applications take a
%     Config as 'Preproc' and hash it with their own options; toStruct gives
%     them a plain struct to hash.
%
%     mask (X-05): fields removeBits (qualflg bits that remove), snrFraction
%     (the "snr" threshold as a fraction of the median), thrMargin and
%     eclipseMargin ([] = half the CRN fit interval of the crn preset) and
%     crnEdge (false). Presets (owner decisions 2026-09-24, from the RL04
%     file headers): ACT1B removes bits 5-7, the L1B fill flags; KBR1B and
%     LRI1B remove bit 0 (phase break) and bits 6-7 (fill flags) and set
%     snrFraction 0.5, provisional until real data refine it. Every other
%     bit - ACT1B clock-offset extrapolation (3/4), KBR1B time-tag bias
%     correction (5) - is reported by mask, not removed. Classic GRACE
%     (X-13, owner decision 2026-09-27): ACC1B of mission GRACE removes
%     bits 5-7, the fill flags of the GRACE L1B handbook (JPL D-22027
%     v1.3, 4.3.2 and 6.2, whose bit table equals ACT1B's), and classic
%     KBR1B takes the KBR1B preset (4.1.2 and 6.7 match it); the
%     handbook's absolute KBR SNR edit (> 450 in 0.1 dB-Hz) is not used.
%     GRACE-FO ACC1B removes none: its bits were never measured here.
%     GRACE-FO's hybrid transplant ACH1B (the .ACX archives, GRACE-D;
%     X-19) takes ACT1B's preset in every section: its RL04 header has
%     ACT1B's nine columns and units, the same eight qualflg meanings
%     word for word, and residuals "from non-CRN-filtered value", i.e. the
%     1 Hz CRN output. Any other product removes no bit and has no snr
%     layer unless told.
%
%     crn (X-04): field preset, the crnKernel preset the product was filtered
%     with in L1B processing - "ACC" for ACC1B (GRACE), ACT1B and ACH1B
%     (GRACE-FO), "KBR" for KBR1B (R-1 App. B; R-2 PDF p. 20). Any other product leaves
%     it "" (not known, so not assumed).
%
%     align (X-06): fields method ("pchip"), maxGap ([] = 1.5 x the median
%     reference step), maxLag (60 s) and threshold (1 s), the options of
%     align and checkAlignment (CONCEPT 6.1, row 3). maxLag and threshold
%     are CONCEPT's numbers; pchip is v2's measured choice (see align).
%
%     fill (X-08): fields method ("none", CONCEPT Q3), maxGap ([] s: no
%     default, a collocation without it refuses) and window ([] = the
%     largest the covariance model allows), the options of fill.
%
%     drivers (X-09): fields method ("pchip") and maxGap ([] = 1.5 x each
%     driver's median step), the options of drivers, and maxLag ([] in
%     samples, no default: correlate needs it given), and maxVif (10, the
%     VIF gate of regressDrivers; owner decision 2026-09-24, provisional
%     until real data refine it), CONCEPT 7.
%
%     unc (X-07): the gate and the uncertainty stages (CONCEPT 6.1, rows 6
%     and 7). minWeightFraction is the minimum-data gate of observability
%     (CONCEPT 5.2): an axis keeping less weight than this refuses. The
%     presets set 0.5 for ACC1B, ACT1B, ACH1B, KBR1B and LRI1B (owner decision
%     2026-09-23: half the arc must survive, provisional until the
%     regression baseline ORC-10 can refine it); any other product leaves
%     it [] and observability then needs it given. blockLength ([] =
%     automatic, Politis-White), nBoot (1000), level (0.6827, 1 sigma) and
%     folds (5) are the defaults of bootstrap and crossval.
%
%     qc (X-10): the options of qc.screen - whitening ("none"), window
%     ([]), hampelWindow (61 samples), hampelThreshold (4 sigma),
%     impulseThreshold (5 sigma), jumpModel ("level"), jumpPenalty ([] =
%     BIC) and jumpMinSegment (30 samples) - with qc.screen's own
%     defaults, ported from NonGravForces 0.12.0; no product sets others.
%     templates (X-17): false; true lets run add the matched-filter
%     events of qc.detectTemplates, one layer per class of the bank.
%
%     noise (X-10): order ([p q], no default, R5: without it run skips the
%     noise stage) and noise's options method ("exact"), maxLag (100
%     samples), lags (20) and welchAverages (32), with noise's defaults.
%
%     run (X-10): filterReference ([] = not stated; true filters the
%     reference with the crn preset before align, false leaves it; see
%     run) and seed (0), the caller's seed of the random stages; cacheDir
%     ("" = the stage cache is off, R5; X-14), the folder of run's stage
%     cache. Campaigns (X-15): parallel (false; true runs the arcs in
%     parfor when a pool can be used), outDir ("" = results stay in
%     memory, R5; else the root of the per-day files and the manifest),
%     overwrite (false: existing day files and manifests are kept) and
%     mixedRelease (false: the arcs must share one L1B release, CONCEPT
%     5.2). format (X-18): "mat" (default), "netcdf" or "both", the
%     day files a campaign with outDir writes.
%
%     export (X-18): the dataset metadata of exportNetcdf and of the
%     campaign manifest's DataCite block - creator (required for NetCDF;
%     "" refuses rather than inventing one), creatorOrcid, creatorEmail,
%     institution, publisher, license ("CC-BY-4.0"), title and project;
%     all "" but the license (R5).
%
%   INPUTS
%     arc      (1,1) Arc      -   The arc whose product selects the preset.
%     section  (1,1) string   -   One of Config.Sections.
%     field    (1,1) string   -   A field of that section's schema.
%     value    (1,1) any      -   The setting.
%
%   OUTPUTS
%     cfg  (1,1) Config   -   Properties: mission, product, and one struct
%                             per section.
%     s    (1,1) struct   -   mission, product and the ten sections.
%
%   ACCURACY
%     Not applicable, because the class computes no number; values are
%     stored as given.
%
%   ERRORS
%     Settings:
%       timeSeriesPreparation:Config:unknownSection - section is not one of
%           the ten sections.
%       timeSeriesPreparation:Config:unknownField - field is not in the
%           section's schema.
%
%   EXAMPLE
%     % The empty skeleton as a plain struct, e.g. for hashing.
%     cfg = timeSeriesPreparation.Config();
%     s = toStruct(cfg);
%
%   LIMITATIONS
%     Presets exist for ACC1B, ACT1B, ACH1B, KBR1B and LRI1B; any other product
%     gets the defaults. The crn preset of classic ACC1B ("ACC", 140.7 s)
%     is GRACE-FO's; whether classic L1B used the handbook's 70.7 s is
%     open (V-1), there being no public classic ACC1A to test it on.
%
%   REFERENCES
%     docs/CONCEPT.md section 5 (Config), R5 (no assumed defaults). R-1: GRACE
%     L1B ATBD, JPL D-27672, App. B. R-2: GRACE-FO L1 Handbook, JPL D-56935.
%
%   See also timeSeriesPreparation.Arc, timeSeriesPreparation.run, timeSeriesPreparation.mask, timeSeriesPreparation.crnKernel, timeSeriesPreparation.align, timeSeriesPreparation.fill, timeSeriesPreparation.observability, timeSeriesPreparation.drivers.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.4.0 | 2026-10-20 12:40 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    properties (Constant)
        Sections = ["mask" "qc" "crn" "align" "fill" "noise" "unc" "drivers" "run" "export"]
    end

    properties (SetAccess = private)
        mission = ""
        product = ""
        mask = struct("removeBits", zeros(1, 0), "snrFraction", [], "thrMargin", [], ...
            "eclipseMargin", [], "crnEdge", false)
        qc = struct("whitening", "none", "window", [], "hampelWindow", 61, ...
            "hampelThreshold", 4, "impulseThreshold", 5, "jumpModel", "level", ...
            "jumpPenalty", [], "jumpMinSegment", 30, "templates", false)
        crn = struct("preset", "")
        align = struct("method", "pchip", "maxGap", [], "maxLag", 60, "threshold", 1)
        fill = struct("method", "none", "maxGap", [], "window", [])
        noise = struct("order", [], "method", "exact", "maxLag", 100, "lags", 20, ...
            "welchAverages", 32)
        unc = struct("minWeightFraction", [], "blockLength", [], "nBoot", 1000, ...
            "level", 0.6827, "folds", 5)
        drivers = struct("method", "pchip", "maxGap", [], "maxLag", [], "maxVif", 10)
        run = struct("filterReference", [], "seed", 0, "cacheDir", "", ...
            "parallel", false, "outDir", "", "overwrite", false, "mixedRelease", false, ...
            "format", "mat")
        export = struct("creator", "", "creatorOrcid", "", "creatorEmail", "", ...
            "institution", "", "publisher", "", "license", "CC-BY-4.0", "title", "", ...
            "project", "")
    end

    methods
        function cfg = Config(arc)
            arguments
                arc timeSeriesPreparation.Arc = timeSeriesPreparation.Arc.empty
            end
            if isempty(arc)
                return
            end
            cfg.mission = arc(1).mission;
            cfg.product = arc(1).product;
            switch cfg.product
                case {"ACC1B", "ACT1B", "ACH1B"}
                    cfg.crn.preset = "ACC";
                case "KBR1B"
                    cfg.crn.preset = "KBR";
            end
            if any(cfg.product == ["ACC1B" "ACT1B" "ACH1B" "KBR1B" "LRI1B"])
                cfg.unc.minWeightFraction = 0.5;
            end
            switch cfg.product
                case {"ACT1B", "ACH1B"}            % ACH1B: ACT1B's bit table; X-19
                    cfg.mask.removeBits = [5 6 7];
                case "ACC1B"
                    if cfg.mission == "GRACE"      % D-22027 4.3.2; X-13
                        cfg.mask.removeBits = [5 6 7];
                    end
                case {"KBR1B", "LRI1B"}
                    cfg.mask.removeBits = [0 6 7];
                    cfg.mask.snrFraction = 0.5;
            end
        end

        function cfg = set(cfg, section, field, value)
            arguments
                cfg (1,1) timeSeriesPreparation.Config
                section (1,1) string
                field (1,1) string
                value
            end
            if ~any(section == cfg.Sections)
                error("timeSeriesPreparation:Config:unknownSection", ...
                    "Unknown section ""%s""; sections are %s.", section, ...
                    strjoin(cfg.Sections, ", "));
            end
            known = schema(section);
            if ~any(field == known)
                list = "(none yet)";
                if ~isempty(known), list = strjoin(known, ", "); end
                error("timeSeriesPreparation:Config:unknownField", ...
                    "Section ""%s"" has no field ""%s""; known: %s.", ...
                    section, field, list);
            end
            cfg.(section).(field) = value;
        end

        function s = toStruct(cfg)
            arguments
                cfg (1,1) timeSeriesPreparation.Config
            end
            s = struct("mission", cfg.mission, "product", cfg.product);
            for sec = cfg.Sections
                s.(sec) = cfg.(sec);
            end
        end
    end
end

function known = schema(section)
% Fields SECTION accepts; each stage adds its own case in its work package.
    switch section
        case "mask"
            known = ["removeBits" "snrFraction" "thrMargin" "eclipseMargin" "crnEdge"];
        case "crn"
            known = "preset";
        case "align"
            known = ["method" "maxGap" "maxLag" "threshold"];
        case "fill"
            known = ["method" "maxGap" "window"];
        case "drivers"
            known = ["method" "maxGap" "maxLag" "maxVif"];
        case "unc"
            known = ["minWeightFraction" "blockLength" "nBoot" "level" "folds"];
        case "qc"
            known = ["whitening" "window" "hampelWindow" "hampelThreshold" ...
                "impulseThreshold" "jumpModel" "jumpPenalty" "jumpMinSegment" "templates"];
        case "noise"
            known = ["order" "method" "maxLag" "lags" "welchAverages"];
        case "run"
            known = ["filterReference" "seed" "cacheDir" "parallel" "outDir" "overwrite" "mixedRelease" "format"];
        case "export"
            known = ["creator" "creatorOrcid" "creatorEmail" "institution" "publisher" ...
                "license" "title" "project"];
        otherwise
            known = strings(1, 0);
    end
end
