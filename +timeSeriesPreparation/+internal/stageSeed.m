function seed = stageSeed(stage, seed0)
%STAGESEED  RNG seed of a stage: its name hashed, plus the caller's seed.
%
%   SYNTAX
%     seed = timeSeriesPreparation.internal.stageSeed(stage, seed0)
%
%   DESCRIPTION
%     CONCEPT 8: "RNG substream per replicate, seed per stage name". Each
%     random stage draws from its own seed, so that adding or removing a
%     stage never changes another stage's numbers. The seed is the 32-bit
%     FNV-1a hash of the stage name's UTF-8 bytes plus seed0, modulo 2^32:
%     a valid RandStream seed. The arithmetic is exact (uint64).
%
%   INPUTS
%     stage  (1,1) string   -   Stage name, e.g. "bootstrap".
%     seed0  (1,1) double   -   Caller's seed, integer >= 0.
%
%   OUTPUTS
%     seed  (1,1) double   -   Integer in [0, 2^32).
%
%   ACCURACY
%     Exact: integer arithmetic. FNV-1a of "a" is 0xE40C292C and of
%     "foobar" 0xBF9CF968, computed from the definition in Python
%     (2026-09-23); TestBootstrap pins both.
%
%   ERRORS
%     (none)
%
%   EXAMPLE
%     % The seed of the bootstrap stage with the caller's seed 0.
%     seed = timeSeriesPreparation.internal.stageSeed("bootstrap", 0);
%
%   LIMITATIONS
%     A hash, not an injection: two names can share a seed (probability
%     2^-32 per pair).
%
%   REFERENCES
%     Fowler, G., Noll, L. C., Vo, K.-P., Eastlake, D. The FNV
%     Non-Cryptographic Hash Algorithm. IETF Internet-Draft
%     draft-eastlake-fnv (FNV-1a, 32 bit: offset basis 2166136261, prime
%     16777619).
%
%   See also timeSeriesPreparation.bootstrap, RandStream.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.0.0 | 2026-09-23 20:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    h = uint64(2166136261);
    for byte = unicode2native(char(stage), "UTF-8")
        h = bitxor(h, uint64(byte));
        h = mod(h * uint64(16777619), uint64(2)^32);
    end
    seed = mod(double(h) + seed0, 2^32);
end
