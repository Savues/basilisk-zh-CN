param(
  [string]$Src    = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn\work\en-toolkit",
  [string]$Out    = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn\work\zh-toolkit",
  [string]$Fx     = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn\work\fx52zh",
  [string]$AllEnt = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn\work\all-entities.txt",
  [string]$Report = "",
  [string]$Patch  = ""
)
$ErrorActionPreference = "Stop"
$enc = New-Object System.Text.UTF8Encoding($false)

$SkipDirs  = @('branding')
$SkipFiles = @('browserconfig.properties','list.json','intl.css')

# 手工补丁字典：Firefox 52 语言包里没有的新字符串，按 key 覆盖（key>>>译文，每行一条）
$patchMap = @{}
if ($Patch -and (Test-Path -LiteralPath $Patch)) {
  foreach ($l in [System.IO.File]::ReadAllLines($Patch, [System.Text.Encoding]::UTF8)) {
    if (-not $l.Trim()) { continue }
    $k = $l.IndexOf('>>>')
    if ($k -lt 0) { continue }
    $patchMap[$l.Substring(0, $k)] = $l.Substring($k + 3)
  }
  Write-Output "patch entries: $($patchMap.Count)"
}

$entitySet = New-Object 'System.Collections.Generic.HashSet[string]'
if (Test-Path -LiteralPath $AllEnt) {
  foreach ($line in [System.IO.File]::ReadAllLines($AllEnt, [System.Text.Encoding]::UTF8)) {
    if ($line) { [void]$entitySet.Add($line) }
  }
}

$index = @{}
Get-ChildItem -LiteralPath $Fx -Recurse -File | ForEach-Object {
  $k = $_.Name.ToLowerInvariant()
  if (-not $index.ContainsKey($k)) { $index[$k] = New-Object System.Collections.ArrayList }
  [void]$index[$k].Add($_.FullName)
}

function Get-PairMap([string]$path) {
  $m = New-Object System.Collections.Specialized.OrderedDictionary
  $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
  foreach ($line in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
    if ($ext -eq '.dtd') {
      if ($line -match '^<!ENTITY\s+(\S+)\s+"(.*)("\s*>)\s*$') { if (-not $m.Contains($Matches[1])) { $m[$Matches[1]] = $Matches[2] } }
    } else {
      if ($line -match '^([^#\s;][^=]*?)=(.*)$') { $k = $Matches[1].Trim(); if (-not $m.Contains($k)) { $m[$k] = $Matches[2] } }
    }
  }
  return ,$m
}

function Best-Source([string]$rel) {
  $k = [System.IO.Path]::GetFileName($rel).ToLowerInvariant()
  if (-not $index.ContainsKey($k)) { return $null }
  $segs = @($rel -split '[\\/]')
  $best = $null; $bestScore = 0
  foreach ($cand in $index[$k]) {
    $csegs = @($cand -split '[\\/]')
    for ($i = 0; $i -lt $segs.Count; $i++) {
      $suffixLen = $segs.Count - $i
      if ($csegs.Count -lt $suffixLen) { continue }
      $tail = (@($csegs[($csegs.Count - $suffixLen)..($csegs.Count - 1)]) -join '/')
      $head = (@($segs[$i..($segs.Count - 1)]) -join '/')
      if ($tail -eq $head -and $suffixLen -gt $bestScore) { $bestScore = $suffixLen; $best = $cand }
    }
  }
  if ($bestScore -ge 2) { return $best } else { return $null }
}

function FmtSpec([string]$s) {
  $r = [regex]::Matches($s, '%\d*\$?[a-zA-Z]') | ForEach-Object { $_.Value }
  return ,((@($r) | Sort-Object) -join '|')
}
function Safe([string]$en, [string]$zh, [bool]$isDtd) {
  if ([string]::IsNullOrWhiteSpace($zh)) { return $false }
  if ((FmtSpec $en) -ne (FmtSpec $zh)) { return $false }
  if ($isDtd) {
    foreach ($r in [regex]::Matches($zh, '&([A-Za-z0-9_.]+);')) {
      if (-not $entitySet.Contains($r.Groups[1].Value)) { return $false }
    }
  }
  return $true
}

# 品牌名修正: Firefox 52 官方中文译文里硬编码了 "Firefox",
# 但 Basilisk 的英文原文要么用 &brandShortName;, 要么直接去掉了品牌名。
$BrandOverride = @{
  'syncBrand.fullName.label'             = 'Pale Moon Sync'
  'lightweightThemes.recommended-1.name' = '浏览器文艺复兴'
}

function Normalize-Brand([string]$key, [string]$en, [string]$zh) {
  if ($BrandOverride.ContainsKey($key)) { return $BrandOverride[$key] }
  if ($en.Contains('Firefox')) { return $zh }
  $bag = New-Object System.Collections.ArrayList
  $t = $zh
  foreach ($m in [regex]::Matches($zh, 'https?://[^\s"<>]+')) { [void]$bag.Add($m.Value); $t = $t.Replace($m.Value, "<<U$($bag.Count - 1)>>") }
  $t = $t.Replace('Firefox', 'Basilisk').Replace('火狐', 'Basilisk')
  for ($i = $bag.Count - 1; $i -ge 0; $i--) { $t = $t.Replace("<<U$i>>", [string]$bag[$i]) }
  # Basilisk 把内置主题 "A Web Browser Renaissance" 显示名改成 "浏览器文艺复兴"，描述里同步
  $t = $t.Replace('A Web Browser Renaissance', '浏览器文艺复兴')
  return $t
}

if (Test-Path -LiteralPath $Out) { Remove-Item -LiteralPath $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out -Force | Out-Null

$total = 0; $hit = 0
$miss = New-Object System.Collections.ArrayList
$unmatched = New-Object System.Collections.ArrayList
$srcLen = $Src.TrimEnd('\').Length

foreach ($f in (Get-ChildItem -LiteralPath $Src -Recurse -File)) {
  $rel = $f.FullName.Substring($srcLen + 1)
  $ext = $f.Extension.ToLowerInvariant()
  $dst = Join-Path $Out $rel
  New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null

  $zhMap = $null
  $topDir = @($rel -split '[\\/]')[0]
  if (($ext -eq '.dtd' -or $ext -eq '.properties') -and $topDir -notin $SkipDirs -and $f.Name -notin $SkipFiles) {
    $cand = Best-Source $rel
    if ($cand) { $zhMap = Get-PairMap $cand } else { [void]$unmatched.Add($rel) }
  }

  $lines = [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)
  $res = @($lines)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if (-not $zhMap) { continue }
    $prefix = $null; $val = $null; $suffix = ''; $key = $null
    if ($ext -eq '.dtd') {
      if ($line -notmatch '^(<!ENTITY\s+\S+\s+")(.*)(">\s*)$') { continue }
      $prefix = $Matches[1]; $val = $Matches[2]; $suffix = $Matches[3]
      $key = @($line -split '\s+')[1]
    } else {
      if ($line -notmatch '^([^#\s;][^=]*?=)(.*)$') { continue }
      $prefix = $Matches[1]; $val = $Matches[2]
      $key = $prefix.Substring(0, $prefix.Length - 1).Trim()
    }
    # 英文原文用properties 续行（行尾反斜杠）时，把译文收成单行并清空续行，避免残留英文
    $cont = 0
    if ($ext -eq '.properties' -and $val.TrimEnd().EndsWith('\')) {
      while (($i + 1 + $cont) -lt $lines.Count -and $lines[$i + 1 + $cont].TrimEnd().EndsWith('\')) { $cont++ }
    }
    if ($val -eq '' -or $val -match '^&[A-Za-z0-9_.]+;$') { continue }
    $total++
    if ($zhMap.Contains($key)) {
      $zh = $zhMap[$key]
      if (Safe $val $zh ($ext -eq '.dtd')) {
        $zhVal = Normalize-Brand $key $val $zh
        if ($cont -gt 0) {
          $zhVal = $zhVal.TrimEnd('\').TrimEnd()
          for ($s = 1; $s -le ($cont + 1); $s++) { $res[$i + $s] = '' }
        }
        $res[$i] = $prefix + $zhVal + $suffix
        $hit++
      }
      else { [void]$miss.Add("$rel | $key | UNSAFE") }
    } elseif ($patchMap.ContainsKey($key)) {
      $zh = $patchMap[$key]
      if (Safe $val $zh ($ext -eq '.dtd')) {
        $zhVal = Normalize-Brand $key $val $zh
        if ($cont -gt 0) { $zhVal = $zhVal.TrimEnd('\').TrimEnd(); for ($s = 1; $s -le ($cont + 1); $s++) { $res[$i + $s] = '' } }
        $res[$i] = $prefix + $zhVal + $suffix
        $hit++
      } else { [void]$miss.Add("$rel | $key | UNSAFE") }
    } else { [void]$miss.Add("$rel | $key | $val") }
  }
  [System.IO.File]::WriteAllLines($dst, $res, $enc)
}

Write-Output "source: $Src"
Write-Output "value slots: $total   translated: $hit   missing: $($miss.Count)"
if ($total -gt 0) { Write-Output ("coverage: {0}%" -f [math]::Round(100.0*$hit/$total,1)) }
Write-Output "files without a zh-CN source: $($unmatched.Count)"
if ($Report -ne "") {
  [System.IO.File]::WriteAllLines($Report, (@($miss) + ($unmatched | ForEach-Object { "NOSOURCE | $_" }) | Sort-Object -Unique), $enc)
  Write-Output "report -> $Report"
}
