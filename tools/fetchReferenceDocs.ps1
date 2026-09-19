# fetchReferenceDocs.ps1 - GUIDE Stage C: mirror the Level-1-relevant documentation of GRACE-FO and GRACE from the
# GFZ ISDC into the owner's DATAPOOL (GRACEFO\DOCUMENTS\..., GRACE\DOCUMENTS\...), keeping the server's folder names.
# Skipped on purpose: AOD1B product descriptions (176 MB, another project), Level-2 documents and Level-2 technical notes.
# Never overwrites or deletes an existing file; SHA-256 manifest and SOURCE note; idempotent.
# Written with Claude Opus 5 (Anthropic), 2026-09-19.
param([string]$Root = $env:READING_DATA_POOL)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { throw "Root '$Root' is not a folder" }
$isdc = 'https://isdc-data.gfz.de'
$tmpBase = Join-Path $env:RUNNER_TEMP ("fetch_" + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $tmpBase | Out-Null
$stats = [ordered]@{ downloaded=0; skipped=0; failed=0 }
$written = New-Object System.Collections.ArrayList
function Fetch([string]$url, [string]$dest) {
  [void]$script:written.Add($dest)
  if (Test-Path -LiteralPath $dest) { $script:stats.skipped++; return }
  New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
  $tmp = Join-Path $tmpBase ([guid]::NewGuid().ToString('N') + '.part')
  & curl.exe --fail --silent --show-error --location --retry 3 --retry-delay 5 -o $tmp $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { $script:stats.failed++; Write-Output "  FAILED $url"; return }
  Move-Item -LiteralPath $tmp -Destination $dest; $script:stats.downloaded++
}
function Crawl([string]$remote, [string]$local, [string]$include, [string]$exclude, [bool]$recurse) {
  $html = (& curl.exe --fail --silent --show-error --location "$isdc/$remote/") -join "`n"
  $names = [regex]::Matches($html, 'href="([^"?/][^"]*)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  $n = 0
  foreach ($name in $names) {
    if ($name.EndsWith('/')) { if ($recurse) { Crawl "$remote/$($name.TrimEnd('/'))" (Join-Path $local $name.TrimEnd('/')) $include $exclude $true }; continue }
    if ($include -and $name -notmatch $include) { continue }
    if ($exclude -and $name -match $exclude) { continue }
    Fetch "$isdc/$remote/$name" (Join-Path $local $name); $n++
  }
  Write-Output ("{0}: {1} file(s)" -f $remote, $n)
}
$gfo = Join-Path $Root 'GRACEFO\DOCUMENTS'
$gr  = Join-Path $Root 'GRACE\DOCUMENTS'
# GRACE-FO
Fetch "$isdc/grace-fo/DOCUMENTS/_README" (Join-Path $gfo '_README')
Crawl 'grace-fo/DOCUMENTS/Level-1'       (Join-Path $gfo 'Level-1')       ''          'AOD1B'  $false
Crawl 'grace-fo/DOCUMENTS/RELEASE_NOTES' (Join-Path $gfo 'RELEASE_NOTES') ''          ''       $false
Crawl 'grace-fo/DOCUMENTS/NEWSLETTER'    (Join-Path $gfo 'NEWSLETTER')    '\.pdf$'    ''       $true
# GRACE
Crawl 'grace/DOCUMENTS/Level-1'          (Join-Path $gr 'Level-1')        ''          'AOD1B'  $false
Crawl 'grace/DOCUMENTS/GENERAL'          (Join-Path $gr 'GENERAL')        ''          ''       $false
Crawl 'grace/DOCUMENTS/ANCILLARY'        (Join-Path $gr 'ANCILLARY')      ''          ''       $false
Crawl 'grace/DOCUMENTS/TECHNICAL_NOTES'  (Join-Path $gr 'TECHNICAL_NOTES') '^TN-0[1-4]_' ''     $false
Crawl 'grace/DOCUMENTS/RELEASE_NOTES'    (Join-Path $gr 'RELEASE_NOTES')  '_L1_'      ''       $false
Crawl 'grace/DOCUMENTS/NEWSLETTER'       (Join-Path $gr 'NEWSLETTER')     '\.pdf$'    ''       $true
# manifest over the files this run is responsible for (existing TN-01 dated folders are not touched)
$lines = foreach ($p in ($written | Sort-Object -Unique)) { if (Test-Path -LiteralPath $p) { "{0}  {1}" -f (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower(), $p.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/') } }
$mf = Join-Path $Root ("GRACEFO\DOCUMENTS\SHA256SUMS_documents_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")
if (Test-Path -LiteralPath $mf) { $mf = $mf -replace '\.txt$', ("_" + (Get-Date -Format 'HHmmss') + ".txt") }
$lines | Set-Content -LiteralPath $mf -Encoding ASCII
Write-Output "manifest: $mf ($($lines.Count) entries, GRACE-FO and GRACE documents)"
@("Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchReferenceDocs.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "Sources: $isdc/grace-fo/DOCUMENTS/ and $isdc/grace/DOCUMENTS/ (owner-named 2026-09-19); folder names kept.",
  "Skipped: AOD1B product descriptions, Level-2 documents, Level-2 technical notes. No source checksums published; SHA-256 manifest above.") |
  Set-Content -LiteralPath (Join-Path $Root ("GRACEFO\DOCUMENTS\SOURCE_documents_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")) -Encoding ASCII
Remove-Item -LiteralPath $tmpBase -Recurse -Force
Write-Output ""
$stats.GetEnumerator() | ForEach-Object { Write-Output ("{0,-12} {1}" -f $_.Key, $_.Value) }
Write-Output "Done in $([int]$sw.Elapsed.TotalMinutes) min."
if ($stats.failed -gt 0) { exit 1 }
