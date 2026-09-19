# fetchDocsAlt.ps1 - GUIDE Stage B data D-4 (ISDC technical notes TN-01 SOE, TN-01a SCE, TN-01b KBR/GPS stats)
# and D-6 (AEI alternative LRI1B and RTC1B v52, Leibniz University Hannover, CC BY 3.0) into the owner's DATAPOOL.
# Never overwrites or deletes an existing file; SHA-256 manifests and SOURCE notes next to the data; idempotent.
# Written with Claude Opus 5 (Anthropic), 2026-09-19.
param([string]$Root = $env:READING_DATA_POOL)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { throw "Root '$Root' is not a folder" }
$tmpBase = Join-Path $env:RUNNER_TEMP ("fetch_" + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $tmpBase | Out-Null
$stats = [ordered]@{ downloaded=0; skipped=0; failed=0; sizeMismatch=0; extracted=0; extractSkippedSame=0; conflicts=0 }
function Fetch([string]$url, [string]$dest, [int64]$expectSize = -1) {
  if (Test-Path -LiteralPath $dest) { $script:stats.skipped++; return $true }
  $tmp = Join-Path $tmpBase ([IO.Path]::GetFileName($dest) + '.part')
  & curl.exe --fail --silent --show-error --location --retry 3 --retry-delay 5 -o $tmp $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { $script:stats.failed++; Write-Output "  FAILED $url"; return $false }
  $len = (Get-Item -LiteralPath $tmp).Length
  if ($expectSize -ge 0 -and $len -ne $expectSize) { $script:stats.sizeMismatch++; Write-Output "  SIZE MISMATCH $([IO.Path]::GetFileName($dest)): $len B, catalogue says $expectSize B"; Remove-Item -LiteralPath $tmp; return $false }
  Move-Item -LiteralPath $tmp -Destination $dest; $script:stats.downloaded++; return $true
}
function Place([string]$src, [string]$dstDir) {
  New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  foreach ($f in Get-ChildItem -LiteralPath $src -File -Recurse) {
    $t = Join-Path $dstDir $f.Name
    if (Test-Path -LiteralPath $t) {
      if ((Get-FileHash -LiteralPath $t -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) { $script:stats.extractSkippedSame++ }
      else { $script:stats.conflicts++; Write-Output "  CONFLICT kept existing $t" }
    } else { Move-Item -LiteralPath $f.FullName -Destination $t; $script:stats.extracted++ }
  }
}
function Write-Manifest([string]$dir, [string]$name) {
  $files = Get-ChildItem -LiteralPath $dir -File -Recurse | Where-Object { $_.Name -notlike 'SHA256SUMS_*' -and $_.Name -notlike 'SOURCE_*' }
  $lines = foreach ($f in ($files | Sort-Object FullName)) { "{0}  {1}" -f (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower(), $f.FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/') }
  $file = Join-Path $dir $name
  if (Test-Path -LiteralPath $file) { $file = $file -replace '\.txt$', ("_" + (Get-Date -Format 'yyyyMMddHHmmss') + ".txt") }
  $lines | Set-Content -LiteralPath $file -Encoding ASCII
  Write-Output "manifest: $file ($($lines.Count) entries)"
}

# ---------------- D-4: technical notes; each version kept in a folder named after the server's Last-Modified date
$tnBase = 'https://isdc-data.gfz.de/grace-fo/DOCUMENTS/TECHNICAL_NOTES'
$tnRoot = Join-Path $Root 'GRACEFO\DOCUMENTS\TECHNICAL_NOTES'
foreach ($n in @('TN-01_SOE.txt','TN-01a_SCE.txt','TN-01b_KBR_GPS_stats.txt')) {
  $hdr = (& curl.exe --fail --silent --show-error --location -I "$tnBase/$n") -join "`n"
  $m = [regex]::Match($hdr, '(?im)^last-modified:\s*(.+)$')
  $stamp = if ($m.Success) { ([DateTime]::Parse($m.Groups[1].Value.Trim(), [Globalization.CultureInfo]::InvariantCulture)).ToUniversalTime().ToString('yyyy-MM-dd') } else { 'undated' }
  $dir = Join-Path $tnRoot $stamp; New-Item -ItemType Directory -Force -Path $dir | Out-Null
  [void](Fetch "$tnBase/$n" (Join-Path $dir $n))
  Write-Output "D-4 $n -> $stamp"
}
Write-Manifest $tnRoot "SHA256SUMS_$(Get-Date -Format 'yyyy-MM-dd').txt"
@("Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchDocsAlt.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "Source: $tnBase/ ; each version sits in a folder named after the server's Last-Modified date (UTC); no source checksums published.") |
  Set-Content -LiteralPath (Join-Path $tnRoot "SOURCE_$(Get-Date -Format 'yyyy-MM-dd').txt") -Encoding ASCII

# ---------------- D-6: AEI LRI1B and RTC1B v52, 2020 Q1 (+ release notes, Misfeldt et al. 2023)
$aeiRoot = Join-Path $Root 'GRACEFO\L1B\AEI_v52'; New-Item -ItemType Directory -Force -Path $aeiRoot | Out-Null
$ds = 'https://data.uni-hannover.de/dataset/01c7d467-26d9-4dd7-8346-848a01bba388/resource'
$items = @(
  @{ n='AEI-LRI1B_v52_2020_q1.zip'; u="$ds/2fe38795-04d0-433c-80a0-6cf69ba294a0/download/aei-lri1b_v52_2020_q1.zip"; s=312225774; p='LRI1B' },
  @{ n='AEI-RTC1B_v52_2020_q1.zip'; u="$ds/b1781a7f-ec8e-4c32-9503-11a137094dd1/download/aei-rtc1b_v52_2020_q1.zip"; s=293387419; p='RTC1B' },
  @{ n='AEI_LRI1B_release_notes.pdf'; u="$ds/6538961a-43d0-42df-a472-d7531c97629f/download/aei_lri1b_release_notes.pdf"; s=3614487; p='' },
  @{ n='Misfeldt2023_ScaleFactor_LRI_ThermalCorrection.pdf'; u="$ds/eee1a3a7-3785-4897-b64f-556dc8eff1b2/download/misfeldt2023-scale-factor-determination-for-the-grace-follow-on-laser-ranging-interferometer-inc.pdf"; s=4696704; p='' }
)
foreach ($it in $items) {
  $dest = Join-Path $aeiRoot $it.n
  if (-not (Fetch $it.u $dest $it.s)) { continue }
  Write-Output "D-6 $($it.n)"
  if ($it.p) {
    $x = Join-Path $tmpBase $it.p; New-Item -ItemType Directory -Force -Path $x | Out-Null
    & tar.exe -xf $dest -C $x
    foreach ($tgz in Get-ChildItem -LiteralPath $x -File -Filter '*.tgz') {
      $mo = [regex]::Match($tgz.Name, '\d{4}-\d{2}').Value
      $y = Join-Path $tmpBase ($it.p + '_' + $mo); New-Item -ItemType Directory -Force -Path $y | Out-Null
      & tar.exe -xzf $tgz.FullName -C $y
      Place $y (Join-Path $aeiRoot "$($it.p)\$mo")
      Write-Output ("     {0} {1}: {2} file(s)" -f $it.p, $mo, (Get-ChildItem -LiteralPath (Join-Path $aeiRoot "$($it.p)\$mo") -File).Count)
    }
  }
}
Write-Manifest $aeiRoot 'SHA256SUMS_2020-Q1.txt'
@("Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchDocsAlt.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "Source: https://data.uni-hannover.de/dataset/aei-lri1b-v52 (Alternative GRACE-FO LRI Ranging Datasets: AEI-LRI1B and AEI-RTC1B v52; licence CC BY 3.0 - attribution required; supplementary to Misfeldt et al. 2023, Remote Sensing 15:570).",
  "Integrity: download sizes checked against the catalogue sizes; no source checksums published; SHA-256 manifest SHA256SUMS_2020-Q1.txt.") |
  Set-Content -LiteralPath (Join-Path $aeiRoot 'SOURCE_2020-Q1.txt') -Encoding ASCII

Remove-Item -LiteralPath $tmpBase -Recurse -Force
Write-Output ""
$stats.GetEnumerator() | ForEach-Object { Write-Output ("{0,-20} {1}" -f $_.Key, $_.Value) }
Write-Output "Done in $([int]$sw.Elapsed.TotalMinutes) min."
if ($stats.failed -gt 0 -or $stats.sizeMismatch -gt 0) { exit 1 }
