param([string]$Base = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn")
$ErrorActionPreference = "Stop"
$work = "$Base\work"
$pairs = @(
  @("$work\en-toolkit\en-US", "$work\zh-toolkit\en-US"),
  @("$work\en-browser",          "$work\zh-browser")
)
$probs = New-Object System.Collections.ArrayList
foreach ($pair in $pairs) {
  $srcRoot = $pair[0]; $zhRoot = $pair[1]
  Get-ChildItem -LiteralPath $srcRoot -Recurse -File -Include *.dtd, *.properties | ForEach-Object {
    $rel = $_.FullName.Substring($srcRoot.Length + 1)
    $zp = Join-Path $zhRoot $rel
    if (-not (Test-Path -LiteralPath $zp)) { [void]$probs.Add("MISSING  $rel"); return }
    $a = [System.IO.File]::ReadAllLines($_.FullName, [System.Text.Encoding]::UTF8)
    $b = [System.IO.File]::ReadAllLines($zp, [System.Text.Encoding]::UTF8)
    if ($a.Count -ne $b.Count) { [void]$probs.Add("LINECOUNT  $rel  $($a.Count)/$($b.Count)") }
    if ($_.Extension -eq '.dtd') {
      $ka = @($a | Where-Object { $_ -match '<!ENTITY\s+(\S+)' } | ForEach-Object { $Matches[1] })
      $kb = @($b | Where-Object { $_ -match '<!ENTITY\s+(\S+)' } | ForEach-Object { $Matches[1] })
    } else {
      $ka = @($a | Where-Object { $_ -match '^\s*([^#\s;][^=]*?)=' } | ForEach-Object { $Matches[1].Trim() })
      $kb = @($b | Where-Object { $_ -match '^\s*([^#\s;][^=]*?)=' } | ForEach-Object { $Matches[1].Trim() })
    }
    if (($ka -join '|') -ne ($kb -join '|')) { [void]$probs.Add("KEYORDER  $rel") }
    # 多行 DTD 实体：引数为奇数时必须与英文原文逐字一致
    for ($i = 0; $i -lt $a.Count; $i++) {
      $q = ([regex]::Matches($a[$i], '(?<!\\)"')).Count
      if ($q % 2 -ne 0) {
        if ($i -ge $b.Count -or $b[$i] -ne $a[$i]) { [void]$probs.Add("MULTILINE-DTD  ${rel}:$($i + 1)") }
      }
    }
    # 续行残留：properties 里出现没有 key 的英文续行
    for ($i = 1; $i -lt $b.Count; $i++) {
      if ($b[$i] -match '^[A-Z][A-Za-z]*( [A-Za-z]+)*[.,]$' -and $a[$i - 1].TrimEnd().EndsWith('\')) { [void]$probs.Add("RESIDUAL  ${rel}:$($i + 1)") }
    }
    $bytes = [System.IO.File]::ReadAllBytes($zp)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { [void]$probs.Add("BOM  $rel") }
    if ($bytes.Length -gt 0) {
      try { [void](New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { [void]$probs.Add("UTF8  $rel") }
    }
    # properties 续行（尾部反斜杠）结构必须一致
    for ($i = 0; $i -lt $a.Count; $i++) {
      if ($i -ge $b.Count -or $b[$i].Trim() -eq '') { continue }
      $ca = $a[$i].TrimEnd().EndsWith('\')
      $cb = $b[$i].TrimEnd().EndsWith('\')
      if ($cb -and -not $ca) { [void]$probs.Add("CONTINUATION  ${rel}:$($i + 1)") }
    }
  }
}
if ($probs.Count -eq 0) { Write-Host "QA: 0 problems" -ForegroundColor Green }
else { Write-Host "QA problems: $($probs.Count)" -ForegroundColor Yellow; $probs | Select-Object -First 40 }