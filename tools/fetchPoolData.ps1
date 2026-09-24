# fetchPoolData.ps1 - download GUIDE Stage B data D-2 (GRACE-FO L1B RL04 daily archives, GFZ ISDC mirror)
# and D-3 (TU Graz ITSG operational products) for one month into the owner's DATAPOOL layout.
# Never overwrites or deletes an existing file; verifies the source MD5 of every extracted L1B file;
# writes SHA-256 manifests and a SOURCE note next to the data. Idempotent: a re-run only fills gaps.
# Written with Claude Opus 5 (Anthropic), 2026-09-19. -SkipItsg added 2026-09-24 (D-9 second month, L1B only).
param(
  [string]$Root  = $env:READING_DATA_POOL,
  [string]$Month = '2020-01',
  [switch]$SkipItsg
)
$ErrorActionPreference = 'Stop'
$sw = [Diagnostics.Stopwatch]::StartNew()
if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { throw "Root '$Root' is not a folder" }
$year = $Month.Substring(0,4)
$days = 1..([DateTime]::DaysInMonth([int]$year, [int]$Month.Substring(5,2))) | ForEach-Object { '{0}-{1:D2}' -f $Month, $_ }
$tmpBase = Join-Path $env:RUNNER_TEMP ("fetch_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpBase | Out-Null
$stats = [ordered]@{ downloaded=0; downloadSkipped=0; downloadFailed=0; extracted=0; extractSkippedSame=0; conflicts=0; md5ok=0; md5bad=0; itsgDownloaded=0; itsgSkipped=0; itsgFailed=0 }
function Fetch([string]$url, [string]$dest) {
  $tmp = Join-Path $tmpBase ([IO.Path]::GetFileName($dest) + '.part')
  & curl.exe --fail --silent --show-error --location --retry 3 --retry-delay 5 -o $tmp $url
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { return $false }
  Move-Item -LiteralPath $tmp -Destination $dest
  return $true
}

# ---------------- D-2: L1B RL04 daily archives -> GRACEFO\L1B\RL04\<yyyy>\ and extracted into <yyyy-mm-dd>\
$l1bDir = Join-Path $Root "GRACEFO\L1B\RL04\$year"
New-Item -ItemType Directory -Force -Path $l1bDir | Out-Null
$base = "https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/$year"
foreach ($d in $days) {
  $dayDir = Join-Path $l1bDir $d
  New-Item -ItemType Directory -Force -Path $dayDir | Out-Null
  $line = "$d :"
  foreach ($kind in @('noLRI','LRI','ACX')) {
    $name = "gracefo_1B_${d}_RL04.ascii.$kind.tgz"
    $arc = Join-Path $l1bDir $name
    if ((Test-Path -LiteralPath $arc) -and ((Get-Item -LiteralPath $arc).Length -gt 0)) { $stats.downloadSkipped++; $line += " $kind=have" }
    elseif (Fetch "$base/$name" $arc) { $stats.downloaded++; $line += " $kind=got" }
    else { $stats.downloadFailed++; $line += " $kind=MISSING"; continue }
    # extract into a temp folder, verify the source MD5, then move file by file without overwriting
    $x = Join-Path $tmpBase "$d.$kind"; New-Item -ItemType Directory -Path $x | Out-Null
    & tar.exe -xzf $arc -C $x
    if ($LASTEXITCODE -ne 0) { $line += "(tar failed)"; continue }
    $ck = Join-Path $x 'checksum'
    $want = @{}
    if (Test-Path -LiteralPath $ck) {
      foreach ($l in Get-Content -LiteralPath $ck) { $p = $l -split '\s+'; if ($p.Count -ge 2 -and $p[0].Length -eq 32) { $want[$p[-1]] = $p[0].ToLower() } }
      Rename-Item -LiteralPath $ck -NewName "checksum.$kind.md5"
    }
    foreach ($f in Get-ChildItem -LiteralPath $x -File) {
      if ($want.ContainsKey($f.Name)) {
        $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm MD5).Hash.ToLower()
        if ($h -eq $want[$f.Name]) { $stats.md5ok++ } else { $stats.md5bad++; Write-Output "  MD5 MISMATCH $d $kind $($f.Name)" }
      }
      $target = Join-Path $dayDir $f.Name
      if (Test-Path -LiteralPath $target) {
        $a = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash; $b = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        if ($a -eq $b) { $stats.extractSkippedSame++ } else { $stats.conflicts++; Write-Output "  CONFLICT kept existing $target" }
      } else { Move-Item -LiteralPath $f.FullName -Destination $target; $stats.extracted++ }
    }
    Remove-Item -LiteralPath $x -Recurse -Force
  }
  Write-Output $line
}

if (-not $SkipItsg) {
# ---------------- D-3: ITSG operational products -> <Root>\GRACEFO-1|2\<product>\<yyyy>\ ; READMEs -> <Root>\ITSG\
$itsg = 'https://ftp.tugraz.at/pub/ITSG/satelliteOrbitProducts/operational'
$docDir = Join-Path $Root 'ITSG'; New-Item -ItemType Directory -Force -Path $docDir | Out-Null
foreach ($r in @('README.txt','README_referenceFrames.txt')) {
  $t = Join-Path $docDir $r
  if (-not (Test-Path -LiteralPath $t)) { if (Fetch "$itsg/$r" $t) { $stats.itsgDownloaded++ } else { $stats.itsgFailed++ } } else { $stats.itsgSkipped++ }
}
foreach ($sat in @('GRACEFO-1','GRACEFO-2')) {
  foreach ($prod in @('attitude','kinematicOrbit','nonConservativeForces','reducedDynamicOrbit')) {
    $dir = Join-Path $Root "$sat\$prod\$year"; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $listing = (& curl.exe --fail --silent --show-error --location "$itsg/$sat/$prod/$year/") -join "`n"
    $names = [regex]::Matches($listing, "href=`"(${sat}_${prod}_$Month-\d\d\.txt(\.gz)?)`"") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    $got = 0
    foreach ($n in $names) {
      $t = Join-Path $dir $n
      if (Test-Path -LiteralPath $t) { $stats.itsgSkipped++ } elseif (Fetch "$itsg/$sat/$prod/$year/$n" $t) { $stats.itsgDownloaded++; $got++ } else { $stats.itsgFailed++ }
    }
    Write-Output ("{0} {1}: {2} file(s) listed for {3}, {4} downloaded" -f $sat, $prod, $names.Count, $Month, $got)
  }
}
}

# ---------------- manifests (SHA-256, paths relative to Root) and SOURCE notes
function Write-Manifest([string]$file, [string[]]$paths) {
  $lines = foreach ($p in ($paths | Sort-Object)) {
    $h = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()
    "{0}  {1}" -f $h, $p.Substring($Root.TrimEnd('\').Length + 1).Replace('\','/')
  }
  if (Test-Path -LiteralPath $file) { $file = $file -replace '\.txt$', ("_" + (Get-Date -Format 'yyyyMMddHHmmss') + ".txt") }
  $lines | Set-Content -LiteralPath $file -Encoding ASCII
  Write-Output "manifest: $file ($($lines.Count) entries)"
}
$l1bFiles = @(Get-ChildItem -LiteralPath $l1bDir -File -Filter "gracefo_1B_$Month-*") + @($days | ForEach-Object { Get-ChildItem -LiteralPath (Join-Path $l1bDir $_) -File })
Write-Manifest (Join-Path $l1bDir "SHA256SUMS_$Month.txt") ($l1bFiles | ForEach-Object { $_.FullName })
if (-not $SkipItsg) {
$itsgFiles = @(Get-ChildItem -LiteralPath $docDir -File -Filter 'README*') + @(foreach ($sat in @('GRACEFO-1','GRACEFO-2')) { foreach ($prod in @('attitude','kinematicOrbit','nonConservativeForces','reducedDynamicOrbit')) { Get-ChildItem -LiteralPath (Join-Path $Root "$sat\$prod\$year") -File -Filter "*_$Month-*" } })
Write-Manifest (Join-Path $docDir "SHA256SUMS_$Month.txt") ($itsgFiles | ForEach-Object { $_.FullName })
}
$note = @(
  "Fetched $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK') by tools/fetchPoolData.ps1 (astrobayer/timeSeriesPreparation, run $env:GITHUB_RUN_ID, commit $env:GITHUB_SHA).",
  "D-2 source: $base/ (daily .noLRI/.LRI/.ACX archives; the MD5 'checksum' file of each archive is kept as checksum.<kind>.md5 in the day folder).",
  "D-3 source: $itsg/ (ITSG operational products; no source checksums published).")
$note | Set-Content -LiteralPath (Join-Path $l1bDir "SOURCE_$Month.txt") -Encoding ASCII
if (-not $SkipItsg) { $note | Set-Content -LiteralPath (Join-Path $docDir "SOURCE_$Month.txt") -Encoding ASCII }
Remove-Item -LiteralPath $tmpBase -Recurse -Force
Write-Output ""
$stats.GetEnumerator() | ForEach-Object { Write-Output ("{0,-20} {1}" -f $_.Key, $_.Value) }
Write-Output "Done in $([int]$sw.Elapsed.TotalMinutes) min."
if ($stats.md5bad -gt 0 -or $stats.downloadFailed -gt 0 -or $stats.itsgFailed -gt 0) { exit 1 }
