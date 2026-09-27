function h = fileSha256(file)
%FILESHA256  SHA-256 of a file's bytes, as 64 lowercase hex digits.
%
%   SYNTAX
%     h = timeSeriesPreparation.internal.fileSha256(file)
%
%   DESCRIPTION
%     The integrity record of a campaign's day files (X-15, CONCEPT 5.2):
%     the plain SHA-256 of the bytes, as sha256sum prints it, so a file
%     can be checked outside MATLAB against the manifest. It differs from
%     internal.contentHash, which hashes MATLAB values through a tagged
%     byte stream. The file is read whole (java.security.MessageDigest).
%
%   INPUTS
%     file  (1,1) string   -   Path of an existing file.
%
%   OUTPUTS
%     h  (1,1) string   -   64 lowercase hexadecimal digits.
%
%   ACCURACY
%     Exact. TestCampaign pins the FIPS 180-4 values: "abc" gives
%     ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad,
%     the empty file e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855.
%
%   ERRORS
%     Input:
%       timeSeriesPreparation:fileSha256:fileNotFound - file cannot be
%           opened for reading.
%
%   EXAMPLE
%     % The SHA-256 of a three-byte file.
%     f = tempname; fid = fopen(f, "w"); fwrite(fid, 'abc'); fclose(fid);
%     h = timeSeriesPreparation.internal.fileSha256(f);
%     delete(f);
%
%   LIMITATIONS
%     The whole file is held in memory once; a day file of run is tens of
%     MB.
%
%   REFERENCES
%     NIST FIPS 180-4, Secure Hash Standard (2015), SHA-256 and example B.1;
%     docs/CONCEPT.md 5.2 (per-day storage, manifest).
%
%   See also timeSeriesPreparation.internal.contentHash, timeSeriesPreparation.run.
%
%   ---------------------------------------------------------------------
%   timeSeriesPreparation v1.3.0 | 2026-09-26 12:00 (CEST, UTC+02:00) | Matthias Weigelt with the help of Claude Code (Anthropic)

    arguments
        file (1,1) string
    end

    fid = fopen(file, "r");
    if fid < 0
        error("timeSeriesPreparation:fileSha256:fileNotFound", ...
            "Cannot open %s for reading.", file);
    end
    bytes = fread(fid, Inf, "*uint8");
    fclose(fid);
    md = java.security.MessageDigest.getInstance("SHA-256");
    if ~isempty(bytes)
        md.update(typecast(bytes(:)', "int8"));
    end
    h = string(sprintf("%02x", typecast(md.digest(), "uint8")));
end
