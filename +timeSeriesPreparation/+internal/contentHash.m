function h = contentHash(varargin)
%CONTENTHASH  SHA-256 of the content of values, as 64 lowercase hex digits.
%
%   SYNTAX
%     h = timeSeriesPreparation.internal.contentHash(v1, v2, ...)
%
%   DESCRIPTION
%     The key of the stage cache (X-14, CONCEPT 6.6) is the SHA-256 of the
%     stage, the toolbox version, the resolved settings and the input
%     contents. This function feeds a canonical byte stream of its
%     arguments to one SHA-256 (java.security.MessageDigest), so equal
%     content gives equal keys on every machine and in every session:
%       - numeric and logical arrays: class name, size, then the raw
%         little-endian bytes (real part, then imaginary part);
%       - char and string: size, then each element's UTF-8 bytes with its
%         length (a missing string has its own tag);
%       - struct: size, then per element each field name and value, in
%         field order;
%       - cell: size, then each cell;
%       - table: its variable names, then each variable;
%       - datetime: its time zone and the POSIX seconds.
%     Objects are refused: this L0 helper knows no class of the package
%     (CONCEPT 3.2). run hashes an Arc as a struct of its content (t, obs,
%     names, units, weights, layers, filled), leaving out the provenance,
%     which carries creation times.
%     Every value starts with a type tag, so [1 2] and "12" or a struct and
%     a cell never share a stream. A function handle refuses: what it
%     computes cannot be read from it (func2str misses captured variables
%     and the code of named functions).
%
%   INPUTS
%     varargin  (1,:) cell   -   Values to hash, in order, each of a type
%                              above.
%
%   OUTPUTS
%     h  (1,1) string   -   64 lowercase hexadecimal digits.
%
%   ACCURACY
%     Exact: the SHA-256 of the canonical bytes. The stream is specified
%     above so it can be rebuilt elsewhere. A Python rebuild (hashlib,
%     2026-09-25) gives, and TestStageCache pins:
%       contentHash(uint8('abc'))
%         = 40227623b648a612552d1d3ee04c07d5013520f932d94327a12d1b2554717715
%       contentHash("qc", struct("hampelWindow", 61))
%         = 5bdcf53a514ff0c8eeba0139dc6c1bfbcc3125d4aa8ad79ea3b8a8b19310fc93
%     The tag of a value is its type name in UTF-8, a zero byte and its
%     size as little-endian doubles; a string element is prefixed by its
%     byte count as a tagged double.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:contentHash:unsupported - a value of another
%           class, e.g. a function handle or an object (an Arc included).
%
%   EXAMPLE
%     % Two equal settings structs give one key; a changed field another.
%     a = timeSeriesPreparation.internal.contentHash("qc", struct("hampelWindow", 61));
%     b = timeSeriesPreparation.internal.contentHash("qc", struct("hampelWindow", 31));
%
%   LIMITATIONS
%     Field order matters: struct("a", 1, "b", 2) and struct("b", 2, "a",
%     1) hash differently. The callers build their settings in a fixed
%     order.
%
%   REFERENCES
%     NIST FIPS 180-4, Secure Hash Standard (2015), SHA-256 and example B.1;
%     docs/CONCEPT.md 6.6 (stage cache).
%
%   See also timeSeriesPreparation.internal.stageCache, timeSeriesPreparation.run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.5.1 | 2026-09-25 23:55 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    md = java.security.MessageDigest.getInstance("SHA-256");
    for k = 1:nargin
        feed(md, varargin{k});
    end
    h = string(sprintf("%02x", typecast(md.digest(), "uint8")));
end

% ------------------------------------------------------------------------

function feed(md, v)
    if isstring(v)
        tag(md, "string", size(v));
        for s = reshape(v, 1, [])
            if ismissing(s)
                bytes(md, uint8(255));
            else
                u = unicode2native(char(s), "UTF-8");
                feed(md, numel(u));
                bytes(md, u);
            end
        end
    elseif ischar(v)
        tag(md, "char", size(v));
        bytes(md, unicode2native(v(:)', "UTF-8"));
    elseif isnumeric(v) || islogical(v)
        tag(md, class(v), size(v));
        if islogical(v)
            bytes(md, uint8(v(:)'));
        else
            bytes(md, typecast(real(v(:))', "uint8"));
            if ~isreal(v)
                bytes(md, typecast(imag(v(:))', "uint8"));
            end
        end
    elseif isstruct(v)
        tag(md, "struct", size(v));
        names = fieldnames(v);
        for e = 1:numel(v)
            for f = 1:numel(names)
                bytes(md, unicode2native(names{f}, "UTF-8"));
                feed(md, v(e).(names{f}));
            end
        end
    elseif iscell(v)
        tag(md, "cell", size(v));
        for e = 1:numel(v)
            feed(md, v{e});
        end
    elseif istable(v)
        tag(md, "table", size(v));
        feed(md, string(v.Properties.VariableNames));
        for c = 1:width(v)
            feed(md, v.(c));
        end
    elseif isdatetime(v)
        tag(md, "datetime", size(v));
        feed(md, string(v.TimeZone));
        feed(md, convertTo(v, "posixtime"));
    else
        error("timeSeriesPreparation:contentHash:unsupported", ...
            "Cannot hash a value of class %s; the stage cache keys only data values.", class(v));
    end
end

function tag(md, name, sz)
% Type name and size ahead of every value.
    bytes(md, unicode2native(char(name), "UTF-8"));
    bytes(md, uint8(0));
    bytes(md, typecast(double(sz), "uint8"));
end

function bytes(md, u)
    if ~isempty(u)
        md.update(typecast(uint8(u(:)'), "int8"));
    end
end
