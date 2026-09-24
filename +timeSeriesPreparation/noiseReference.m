function [asd, info] = noiseReference(model, f, options)
%NOISEREFERENCE  Published noise ASDs of the GRACE-FO instruments: LRI requirement, KBR, LRI laser, ACC.
%
%   SYNTAX
%     [asd, info] = timeSeriesPreparation.noiseReference(model, f)
%     [asd, info] = timeSeriesPreparation.noiseReference("ACC", f, Axis = "y", Derivative = 0)
%
%   DESCRIPTION
%     The reference noise-model library of the noise stage (CONCEPT 6.1,
%     row 5; W-12). These are amplitude spectral densities (ASD, one-sided)
%     as printed in the sources, to be used as priors and as validation
%     targets for a fitted noise model (noise, spectral.spec2acv). Each
%     formula below was read from the page image of the cited copy on
%     2026-09-23:
%       "LRI"       the GRACE-FO LRI ranging-noise REQUIREMENT, in m/sqrt(Hz):
%                   80e-9 sqrt(1 + (3 mHz/f)^2) sqrt(1 + (10 mHz/f)^2),
%                   stated for 2 mHz <= f <= 100 mHz (Abich et al. 2019,
%                   arXiv:1907.00104v1 p. 4, the unnumbered display).
%       "LRI-laser" the LRI laser-frequency ranging noise of the simulation
%                   model, for a separation of 238 km, in m/sqrt(Hz):
%                   5e-9 sqrt(1 + (0.0182 Hz/f)^2) (Darbeheshti et al.
%                   2017, Eq. 21, p. 841). The equation states no band;
%                   info.band is the range its Figure 12 plots, 1e-4 to
%                   1e-1 Hz.
%       "KBR"       the KBR system and oscillator range noise of the
%                   simulation model, for a separation of 238 km, in
%                   m/sqrt(Hz): 1e-6 sqrt(1 + (0.0018 Hz/f)^4), stated
%                   for 1e-5 <= f <= 1e-1 Hz (Darbeheshti et al. 2017,
%                   Eq. 15, p. 839, after Kim 2000).
%       "ACC"       the accelerometer noise of the simulation model, in
%                   m s^-2/sqrt(Hz): sensitive axes x and z 1e-10
%                   sqrt(1 + 0.005 Hz/f), less-sensitive axis y 1e-9
%                   sqrt(1 + 0.1 Hz/f), stated for 1e-5 <= f <= 1e-1 Hz
%                   (Darbeheshti et al. 2017, Eq. 9, p. 838, after Kim
%                   2000). Axes are the science frame (SF).
%     Derivative n multiplies by (2 pi f)^n: range to range rate (1) and
%     range acceleration (2), the ASD of the n-th time derivative of a
%     stationary process.
%
%     These are models and a requirement, not measurements. For scale:
%     the in-orbit LRI reached about 1 nm/sqrt(Hz) above 100 mHz (Abich et
%     al. 2019, abstract), well below its requirement. The KBR-LRI
%     residuals show a KBR white-noise level of about 0.6 um/sqrt(Hz)
%     (Mueller et al. 2022, sect. 6.3), below the model's 1 um/sqrt(Hz).
%
%   INPUTS
%     model  (1,1) string   -    "LRI", "LRI-laser", "KBR" or "ACC".
%     f      (:,:) double   Hz   Frequencies, > 0; any shape.
%
%   OPTIONS
%     Axis        (1,1) string   [none]  "x", "y" or "z"; required for
%                                        "ACC", refused otherwise.
%     Derivative  (1,1) double   [0]     Order n of the time derivative,
%                                        0, 1 or 2.
%
%   OUTPUTS
%     asd   (size f) double   unit/sqrt(Hz)   The ASD at f.
%     info  (1,1) struct      -               Fields: model, axis,
%                                             quantity (e.g. "range
%                                             rate"), unit (string, per
%                                             sqrt(Hz)), status
%                                             ("requirement" or
%                                             "simulation model"), band
%                                             (1,2) Hz where the source
%                                             states the formula, inBand
%                                             (size f) logical, source
%                                             (citation with page and
%                                             equation).
%
%   ACCURACY
%     Exact evaluation of the printed formulas. TestNoiseReference pins
%     each at its corner frequencies, where the printed constants give
%     closed forms (e.g. KBR at 1.8 mHz is sqrt(2) um/sqrt(Hz)), to 1e-15
%     relative. The formulas themselves carry no stated uncertainty.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:noiseReference:unknownModel - model is not
%           one of the four.
%       timeSeriesPreparation:noiseReference:axis - "ACC" without Axis, or
%           Axis given for a ranging model.
%       Options outside their domain are refused by the arguments block
%           with a MATLAB: identifier.
%
%   EXAMPLE
%     % The LRI requirement and the KBR model from 1 to 100 mHz.
%     f = logspace(-3, -1, 50)';
%     lri = timeSeriesPreparation.noiseReference("LRI", f);
%     [kbr, info] = timeSeriesPreparation.noiseReference("KBR", f);
%
%   LIMITATIONS
%     Outside info.band the formulas are evaluated as printed; the source
%     does not state them there (info.inBand is false). "KBR" and
%     "LRI-laser" hold for a separation of 238 km; the other separations
%     are not modelled. The requirement is an upper bound on the noise,
%     not a model of it. The GRACE (classic) instruments are not covered.
%
%   REFERENCES
%     Abich, K. et al. (2019). In-orbit performance of the GRACE Follow-on
%     Laser Ranging Interferometer. Phys. Rev. Lett. 123, 031101,
%     doi:10.1103/PhysRevLett.123.031101 (read: arXiv:1907.00104v1, p. 4).
%     Darbeheshti, N., Wegener, H., Mueller, V., Naeimi, M., Heinzel, G.,
%     Hewitson, M. (2017). Instrument data simulations for GRACE
%     Follow-on: observation and noise models. Earth Syst. Sci. Data 9,
%     833-848, doi:10.5194/essd-9-833-2017 (Eqs. 9, 15, 21). Kim, J.
%     (2000). Simulation study of a low-low satellite-to-satellite
%     tracking mission. PhD thesis, University of Texas at Austin (the
%     origin of the ACC and KBR models, not read here). Mueller, V. et al.
%     (2022). Comparing GRACE-FO KBR and LRI ranging data with focus on
%     carrier frequency variations. Remote Sens. 14, 4335,
%     doi:10.3390/rs14174335 (read: arXiv:2205.08862v1, sect. 6.3).
%     docs/references/REFERENCES.md P-9, P-13, P-21.
%
%   See also timeSeriesPreparation.noise, timeSeriesPreparation.spectral.spec2acv, timeSeriesPreparation.crnKernel.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v0.2.0 | 2026-09-23 22:30 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        model (1,1) string
        f double {mustBePositive, mustBeFinite}
        options.Axis string {mustBeScalarOrEmpty} = strings(0, 0)
        options.Derivative (1,1) double {mustBeMember(options.Derivative, [0 1 2])} = 0
    end

    darbeheshti = "Darbeheshti et al. (2017), Earth Syst. Sci. Data 9, 833-848";
    hasAxis = ~isempty(options.Axis);
    switch model
        case "LRI"
            asd = 80e-9 * sqrt(1 + (3e-3 ./ f).^2) .* sqrt(1 + (10e-3 ./ f).^2);
            status = "requirement";
            band = [2e-3 100e-3];
            base = "range";
            source = "Abich et al. (2019), Phys. Rev. Lett. 123, 031101, p. 4 (arXiv:1907.00104v1)";
        case "LRI-laser"
            asd = 5e-9 * sqrt(1 + (0.0182 ./ f).^2);
            status = "simulation model";
            band = [1e-4 1e-1];
            base = "range";
            source = darbeheshti + ", Eq. 21, p. 841 (separation 238 km)";
        case "KBR"
            asd = 1e-6 * sqrt(1 + (0.0018 ./ f).^4);
            status = "simulation model";
            band = [1e-5 1e-1];
            base = "range";
            source = darbeheshti + ", Eq. 15, p. 839 (separation 238 km, after Kim 2000)";
        case "ACC"
            if ~hasAxis || ~any(options.Axis == ["x" "y" "z"])
                error("timeSeriesPreparation:noiseReference:axis", ...
                    "Model ""ACC"" needs Axis ""x"", ""y"" or ""z"".");
            end
            if options.Axis == "y"
                asd = 1e-9 * sqrt(1 + 0.1 ./ f);
            else
                asd = 1e-10 * sqrt(1 + 0.005 ./ f);
            end
            status = "simulation model";
            band = [1e-5 1e-1];
            base = "acceleration";
            source = darbeheshti + ", Eq. 9, p. 838 (after Kim 2000)";
        otherwise
            error("timeSeriesPreparation:noiseReference:unknownModel", ...
                "Unknown model ""%s""; models are LRI, LRI-laser, KBR, ACC.", model);
    end
    if hasAxis && model ~= "ACC"
        error("timeSeriesPreparation:noiseReference:axis", ...
            "Axis applies to ""ACC"" only, not to ""%s"".", model);
    end

    n = options.Derivative;
    asd = asd .* (2 * pi * f).^n;
    if base == "range"
        names = ["range" "range rate" "range acceleration"];
        units = ["m" "m/s" "m/s^2"];
    else
        names = ["acceleration" "jerk" "acceleration, second derivative"];
        units = ["m/s^2" "m/s^3" "m/s^4"];
    end
    axis = "";
    if hasAxis
        axis = options.Axis;
    end
    info = struct("model", model, "axis", axis, "quantity", names(n + 1), ...
        "unit", units(n + 1) + "/sqrt(Hz)", "status", status, "band", band, ...
        "inBand", f >= band(1) & f <= band(2), "source", source);
end
