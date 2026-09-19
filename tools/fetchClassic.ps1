# fetchClassic.ps1 - GUIDE Stage B data D-8: classic GRACE L1B from the GFZ ISDC mirror into the owner's DATAPOOL:
# RL03 monthly archives (KBR1B and SCA1B only), the GRACE-B accelerometer-transplant archive (ACT1B, RL03), and
# RL02 daily archives (the full product set: ACC1B, AHK1B, GNV1B, MAS1B, THR1B, ...).
# Never overwrites or deletes an existing file; SHA-256 manifest and SOURCE note next to the data; idempotent.
# Written with Claude Opus 5 (Anthropic), 2026-09-19.
param(
  [string]$Root   = $env:READING_DATA_POOL,
  [string]$Months = '2008-07,2012-01,2017-01',
  [string]$RL02Months = '',
  [switch]$Transplant
)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { throw "Root '$Root' is not a folder" }
$base = 'https://isdc-data.gfz.de/grace/Level-1B/JPL/INSTRUMENT/RL03'
$dst  = Join-Path $Root 'GRACE\L1B\JPL\RL03'
$tmpBase = Join-Path $env:RUNNER_TEMP ("fetch_" + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $tmpBase | Out-Null
$stats = [ordered]@{ downloaded=0; skipped=0; failed=0; extracted=0; extractSkippedSame=0; conflicts=0 }
function Fetch([string]$url, [string]$dest) {
  if (Test-Path -LiteralPath $dest) { $script:stats.skipped++; return $true }
  $tmp = Join-Path $tmpBase ([IO.Path]::GetFileName($dest) + '.part')
  & curl.exe --fail --silent --show-error --location --retry 3 --retry-delay 5 -o $tmp $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { $script:stats.failed++; Write-Output "  FAILED $url"; return $false }
  Move-Item -LiteralPath $tmp -Destination $dest; $script:stats.downloaded++; return $true
}
function PlaceFile([IO.FileInfo]$f, [string]$dir) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $t = Join-Path $dir $f.Name
  if (Test-Path -LiteralPath $t) {
    if ((Get-FileHash -LiteralPath $t -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) { $script:stats.extractSkippedSame++ }
    else { $script:stats.conflicts++; Write-Output "  CONFLICT kept existing $t" }
  } else { Move-Item -LiteralPath $f.FullName -Destination $t; $script:stats.extracted++ }
}
$archives = @()
foreach ($m in ($Months -split '[,\s]+' | Where-Object { $_ -match '^\d{4}-\d{2}$' })) {
  $archives += @{ name = "grace_1B_${m}_03.tar.gz"; kind = 'month'; month = $m }
}
if ($Transplant) { $archives += @{ name = 'grace_ACC1B_transplant_2016-11-13_2017-06-29_03.tar.gz'; kind = 'transplant'; month = '' } }
# ---------------- RL02 daily archives (full product set) -> GRACE\L1B\JPL\RL02\<yyyy>\ and <yyyy-mm-dd>\
$b2 = 'https://isdc-data.gfz.de/grace/Level-1B/JPL/INSTRUMENT/RL02'
$d2 = Join-Path $Root 'GRACE\L1B\JPL\RL02'
foreach ($m in ($RL02Months -split '[,\s]+' | Where-Object { $_ -match '^\d{4}-\d{2}$' })) {
  $y = $m.Substring(0,4); $yd = Join-Path $d2 $y; New-Item -ItemType Directory -Force -Path $yd | Out-Null
  $listing = (& curl.exe --fail --silent --show-error --location "$b2/$y/") -join "`n"
  $names = [regex]::Matches($listing, "href=`"(grace_1B_$m-\d\d_02\.tar\.gz)`"") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  $cnt = 0
  foreach ($n in $names) {
    $arc = Join-Path $yd $n
    if (-not (Fetch "$b2/$y/$n" $arc)) { continue }
    $day = [regex]::Match($n, '\d{4}-\d{2}-\d{2}').Value
    $x = Join-Path $tmpBase "rl02_$day"; New-Item -ItemType Directory -Force -Path $x | Out-Null
    & tar.exe -xzf $arc -C $x
    if ($LASTEXITCODE -ne 0) { Write-Output "  tar failed: $n"; continue }
    foreach ($f in Get-ChildItem -LiteralPath $x -File -Recurse) { PlaceFile $f (Join-Path $yd $day) }
    Remove-Item -LiteralPath $x -Recurse -Force; $cnt++
  }
  Write-Output ("D-8 RL02 {0}: {1} of {2} daily archive(s) listed" -f $m, $cnt, $names.Count)
}
foreach ($a in $archives) {
  $year = if ($a.kind -eq 'month') { $a.month.Substring(0,4) } else { 'transplant' }
  $arcDir = if ($a.kind -eq 'month') { Join-Path $dst $year } else { $dst }
  New-Item -ItemType Directory -Force -Path $arcDir | Out-Null
  $arc = Join-Path $arcDir $a.name
  if (-not (Fetch "$base/$($a.name)" $arc)) { continue }
  $x = Join-Path $tmpBase ([IO.Path]::GetFileNameWithoutExtension($a.name)); New-Item -ItemType Directory -Force -Path $x | Out-Null
  & tar.exe -xzf $arc -C $x
  if ($LASTEXITCODE -ne 0) { Write-Output "  tar failed: $($a.name)"; continue }
  $n = 0
  foreach ($f in Get-ChildItem -LiteralPath $x -File -Recurse) {
    if ($a.kind -eq 'transplant') { PlaceFile $f (Join-Path $dst 'ACT1B_transplant_2016-11-13_2017-06-29') }
    else {
      $d = [regex]::Match($f.Name, '\d{4}-\d{2}-\d{2}').Value
      if ($d) { PlaceFile $f (Join-Path $arcDir $d) } else { PlaceFile $f (Join-Path $arcDir ('misc_' + $a.month)) }
    }
    $n++
  }
  Write-Output ("D-8 {0}: {1} file(s) in the archive" -f $a.name, $n)
  Remove-Item -LiteralPath $x -Recurse -Force
}
$files = @(Get-ChildItem -LiteralPath $dst -File -Recurse) + @(if (Test-Path -LiteralPath $d2) { Get-ChildItem -LiteralPath $d2 -File -Recurse }) | Where-Object { $_.Name -notlike 'SHA256SUMS_*' -and $_.Name -notlike 'SOURCE_*' } | Sort-Object FullName
$lines = foreach ($f in $files) { "{0}  {1}" -f (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower(), $f.FullName.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/') }
$mf = Join-Path $dst ("SHA256SUMS_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")
if (Test-Path -LiteralPath $mf) { $mf = $mf -replace '\.txt$', ("_" + (Get-Date -Format 'HHmmss') + ".txt") }
$lines | Set-Content -LiteralPath $mf -Encoding ASCII
Write-Output "manifest: $mf ($($lines.Count) entries)"
@("Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchClassic.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "Source: $base/ (JPL GRACE L1B RL03: monthly archives with KBR1B and SCA1B only; the GRACE-B accelerometer transplant 2016-11-13..2017-06-29 as ACT1B) and $b2/ (RL02 daily archives, full product set; RL02 months: $RL02Months).",
  "Months: $Months ; transplant: $([bool]$Transplant). No source checksums published; SHA-256 manifest above.",
  "Note: the .dat files carry an ASCII header that declares 'FILE FORMAT 0=BINARY 1=ASCII : 0' - the data records are binary.") |
  Set-Content -LiteralPath (Join-Path $dst ("SOURCE_" + (Get-Date -Format 'yyyy-MM-dd') + ".txt")) -Encoding ASCII
Remove-Item -LiteralPath $tmpBase -Recurse -Force
Write-Output ""
$stats.GetEnumerator() | ForEach-Object { Write-Output ("{0,-20} {1}" -f $_.Key, $_.Value) }
Write-Output "Done in $([int]$sw.Elapsed.TotalMinutes) min."
if ($stats.failed -gt 0) { exit 1 }
