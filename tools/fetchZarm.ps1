# fetchZarm.ps1 - GUIDE Stage B data D-10: ZARM Bremen POD-based accelerometer calibration (Woeske et al. 2024,
# Adv. Space Res. 74:4517) and, for the reference months, ZARM's GRACE-D accelerometer transplant and modelled
# radiation accelerations, into the owner's DATAPOOL under ZARM\ (mirroring the server's folders).
# Never overwrites or deletes an existing file; SHA-256 manifest and SOURCE note; idempotent.
# Written with Claude Opus 5 (Anthropic), 2026-09-19.
param(
  [string]$Root   = $env:READING_DATA_POOL,
  [string]$Months = '2020-01,2008-07,2012-01,2017-01'
)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { throw "Root '$Root' is not a folder" }
$base = 'https://www.zarm.uni-bremen.de/zarm_daten'
$dst  = Join-Path $Root 'ZARM'
$tmpBase = Join-Path $env:RUNNER_TEMP ("fetch_" + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $tmpBase | Out-Null
$stats = [ordered]@{ downloaded=0; skipped=0; failed=0; extracted=0; extractSkippedSame=0; conflicts=0 }
$monthList = @($Months -split '[,\s]+' | Where-Object { $_ -match '^\d{4}-\d{2}$' })
function Fetch([string]$url, [string]$dest) {
  if (Test-Path -LiteralPath $dest) { $script:stats.skipped++; return $true }
  New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
  $tmp = Join-Path $tmpBase ([IO.Path]::GetFileName($dest) + '.part')
  & curl.exe --fail --silent --show-error --location --retry 3 --retry-delay 5 -o $tmp $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { $script:stats.failed++; Write-Output "  FAILED $url"; return $false }
  Move-Item -LiteralPath $tmp -Destination $dest; $script:stats.downloaded++; return $true
}
function List([string]$path) {
  $html = (& curl.exe --fail --silent --show-error --location "$base/?path=$([uri]::EscapeDataString($path))") -join "`n"
  $files = [regex]::Matches($html, 'href="([^"?]+\.(txt|tar\.gz|tgz|zip|pdf))"') | ForEach-Object { $_.Groups[1].Value }
  $dirs  = [regex]::Matches($html, 'href="\?path=([^"]+)"') | ForEach-Object { [uri]::UnescapeDataString($_.Groups[1].Value) } | Where-Object { $_ -like "$path/*" }
  return @{ files = @($files | Sort-Object -Unique); dirs = @($dirs | Sort-Object -Unique) }
}
# ACC: every file (the calibration series for the whole missions)
foreach ($y in (List 'ACC').dirs) {
  foreach ($f in (List $y).files) { if (Fetch "$base/$f" (Join-Path $dst ($f -replace '/', '\'))) { Write-Output "ACC $f" } }
}
# AccTransplant and ModRadAcc: only the reference months, any satellite
foreach ($top in @('AccTransplant','ModRadAcc')) {
  foreach ($y in (List $top).dirs) {
    if (-not ($monthList | Where-Object { $y -like "*/$($_.Substring(0,4))" })) { continue }
    foreach ($f in (List $y).files) {
      $m = [regex]::Match($f, '\d{4}-\d{2}').Value
      if ($monthList -notcontains $m) { continue }
      $dest = Join-Path $dst ($f -replace '/', '\')
      if (-not (Fetch "$base/$f" $dest)) { continue }
      $xdir = Join-Path (Split-Path $dest -Parent) ([IO.Path]::GetFileName($dest) -replace '\.tar\.gz$|\.tgz$','')
      $x = Join-Path $tmpBase ([guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $x | Out-Null
      & tar.exe -xzf $dest -C $x
      if ($LASTEXITCODE -ne 0) { Write-Output "  tar failed: $f"; continue }
      New-Item -ItemType Directory -Force -Path $xdir | Out-Null
      $n = 0
      foreach ($g in Get-ChildItem -LiteralPath $x -File -Recurse) {
        $t = Join-Path $xdir $g.Name
        if (Test-Path -LiteralPath $t) {
          if ((Get-FileHash -LiteralPath $t -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $g.FullName -Algorithm SHA256).Hash) { $stats.extractSkippedSame++ } else { $stats.conflicts++; Write-Output "  CONFLICT kept existing $t" }
        } else { Move-Item -LiteralPath $g.FullName -Destination $t; $stats.extracted++ }
        $n++
      }
      Remove-Item -LiteralPath $x -Recurse -Force
      Write-Output ("{0} {1}: {2} file(s)" -f $top, $f, $n)
    }
  }
}
$files = Get-ChildItem -LiteralPath $dst -File -Recurse | Where-Object { $_.Name -notlike 'SHA256SUMS_*' -and $_.Name -notlike 'SOURCE_*' } | Sort-Object FullName
$lines = foreach ($f in $files) { "{0}  {1}" -f (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower(), $f.FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/') }
$mf = Join-Path $dst ("SHA256SUMS_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")
if (Test-Path -LiteralPath $mf) { $mf = $mf -replace '\.txt$', ("_" + (Get-Date -Format 'HHmmss') + ".txt") }
$lines | Set-Content -LiteralPath $mf -Encoding ASCII
Write-Output "manifest: $mf ($($lines.Count) entries)"
@("Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchZarm.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "Source: $base/ (ZARM, University of Bremen; F. Woeske et al., Adv. Space Res. 74:4517, 2024, doi:10.1016/j.asr.2024.09.021).",
  "ACC: all calibration files. AccTransplant, ModRadAcc: months $Months only.",
  "Convention in the ACC files: ACC_cal = s (ACC + b) - the bias sits inside the bracket; this design's bias is s*b.",
  "No source checksums published; SHA-256 manifest above.") | Set-Content -LiteralPath (Join-Path $dst ("SOURCE_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")) -Encoding ASCII
Remove-Item -LiteralPath $tmpBase -Recurse -Force
Write-Output ""
$stats.GetEnumerator() | ForEach-Object { Write-Output ("{0,-20} {1}" -f $_.Key, $_.Value) }
Write-Output "Done in $([int]$sw.Elapsed.TotalMinutes) min."
if ($stats.failed -gt 0) { exit 1 }
