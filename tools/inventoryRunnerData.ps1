# inventoryRunnerData.ps1 - READ-ONLY inventory of GRACE/GRACE-FO data on the runner (GUIDE Stage B).
# Lists and classifies file NAMES; opens no file, writes nothing but this log.
# Written with Claude Opus 5 (Anthropic), 2026-09-19.
$ErrorActionPreference = 'Continue'
$sw = [Diagnostics.Stopwatch]::StartNew()
$pool = $env:READING_DATA_POOL
Write-Output "READING_DATA_POOL (organisation variable): '$pool'"
# Root 1: the DATAPOOL folder that contains the pool (walk up to the component named DATAPOOL, else the pool itself)
$roots = @()
if ($pool -and (Test-Path -LiteralPath $pool)) {
  $p = (Resolve-Path -LiteralPath $pool).Path; $r = $p
  while ($r -and ((Split-Path $r -Leaf) -notmatch '^DATAPOOL$')) { $r = Split-Path $r -Parent }
  if ($r) { $roots += $r } else { $roots += $p }
}
foreach ($extra in @('C:\actions-runner\_work')) { if (Test-Path -LiteralPath $extra) { $roots += $extra } }
Write-Output "Roots searched recursively: $($roots -join ' ; ')"
Write-Output ""
Write-Output "Fixed drives and their top-level folders (not searched):"
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
  $top = (Get-ChildItem -LiteralPath $_.Root -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join ', '
  Write-Output ("  {0}  used {1:N1} GB  free {2:N1} GB : {3}" -f $_.Root, ($_.Used/1GB), ($_.Free/1GB), $top)
}
Write-Output ""

# Iterative enumeration that survives access-denied folders
function Get-AllFiles([string]$root) {
  $stack = New-Object System.Collections.Generic.Stack[string]; $stack.Push($root)
  while ($stack.Count -gt 0) {
    $d = $stack.Pop()
    try { foreach ($f in [System.IO.Directory]::EnumerateFiles($d)) { $f } } catch {}
    try { foreach ($s in [System.IO.Directory]::EnumerateDirectories($d)) {
            if ($s -notmatch '\\(\.git|node_modules|_temp|_tool|_actions)(\\|$)') { $stack.Push($s) } } } catch {}
  }
}

$cats = [ordered]@{
  'L1B/L1A GRACE-FO file'   = '^(?<p>[A-Z]{3})1(?<l>[AB])_(?<d>\d{4}-\d{2}-\d{2})_(?<s>[CDY])_(?<r>\d{2})\.(txt|dat|asc)(\.gz)?$'
  'L1B classic GRACE file'  = '^(?<p>[A-Z]{3})1(?<l>[AB])_(?<d>\d{4}-\d{2}-\d{2})_(?<s>[ABX])_(?<r>\d{2})\.(txt|dat|asc)(\.gz)?$'
  'L1 daily archive'        = '^grace(fo)?_1[AB]_(?<d>\d{4}-\d{2}-\d{2})_.*\.(tar\.gz|tgz|tar|zip|gz)$|^grace(fo)?_1[AB]_(?<d2>\d{4}-\d{2}-\d{2})_RL\d{2}\.ascii\.(no)?LRI.*$'
  'ITSG product'            = '^GRACE(FO)?-[12AB]_(?<p>[A-Za-z]+)_(?<d>\d{4}-\d{2}(-\d{2})?)\.(txt|dat)(\.gz)?$'
  'event list (SOE/SCE/TN)' = '(SOE|SCE|TN-?0?1a?|sequence.?of.?events|maneuver|manoeuvre)'
  'space weather'           = '^(SW-All|SOLFSMY|DTCFILE|SOLRESAP|Kp_ap|kp|f107|apkp)'
  'CERES'                   = 'CERES'
  'alternative LRI1B'       = '(LRI1B.*(V50|SYSU|HUST|AEI)|(SYSU|HUST|AEI).*LRI)'
  'alternative attitude'    = '(HUGG|SCA1B.*(fus|comb|kf)|attitude.*(fus|comb))'
}
$hits = @{}; foreach ($k in $cats.Keys) { $hits[$k] = New-Object System.Collections.ArrayList }
$total = 0; $bytes = [int64]0
$dirCount = @{}
foreach ($root in $roots) {
  foreach ($f in (Get-AllFiles $root)) {
    $total++
    $name = [System.IO.Path]::GetFileName($f)
    foreach ($k in $cats.Keys) {
      if ($name -match $cats[$k]) { [void]$hits[$k].Add($f); break }
    }
    if ($root -notlike 'C:\actions-runner*') {
      $rel = $f.Substring($root.Length).TrimStart('\'); $parts = $rel.Split('\')
      $key = if ($parts.Count -gt 3) { ($parts[0..2] -join '\') } else { ($parts[0..([Math]::Max(0,$parts.Count-2))] -join '\') }
      if (-not $dirCount.ContainsKey($key)) { $dirCount[$key] = 0 }; $dirCount[$key]++
    }
  }
}
Write-Output "Files enumerated: $total in $([int]$sw.Elapsed.TotalSeconds) s"
Write-Output ""
Write-Output "Folders (first three levels below DATAPOOL) with file counts, largest 40:"
$dirCount.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 40 | ForEach-Object { Write-Output ("  {0,8}  {1}" -f $_.Value, $_.Key) }
Write-Output ""

foreach ($k in $cats.Keys) {
  $h = $hits[$k]
  Write-Output ("=== {0}: {1} file(s)" -f $k, $h.Count)
  if ($h.Count -eq 0) { continue }
  $h | ForEach-Object { Split-Path $_ -Parent } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object { Write-Output ("    {0,7}  {1}" -f $_.Count, $_.Name) }
  if ($k -like 'L1B*') {
    $rx = $cats[$k]
    $rows = foreach ($f in $h) { $n = [System.IO.Path]::GetFileName($f); if ($n -match $rx) { [pscustomobject]@{P=$Matches.p+'1'+$Matches.l; S=$Matches.s; D=$Matches.d; R=$Matches.r} } }
    $rows | Group-Object P,S,R | Sort-Object Name | ForEach-Object {
      $ds = $_.Group | Select-Object -ExpandProperty D | Sort-Object -Unique
      $jan = ($ds | Where-Object { $_ -like '2020-01-*' }).Count
      Write-Output ("    {0,-18} days {1,5}  {2} .. {3}   2020-01: {4,2}/31" -f $_.Name, $ds.Count, $ds[0], $ds[-1], $jan)
    }
  } else {
    $h | Select-Object -First 8 | ForEach-Object { Write-Output ("      e.g. {0}" -f $_) }
  }
}
Write-Output ""
Write-Output "Done in $([int]$sw.Elapsed.TotalSeconds) s. Nothing was opened or written."
