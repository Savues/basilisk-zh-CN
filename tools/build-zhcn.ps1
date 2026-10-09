param(
  [string]$Base = "C:\Users\Savues\Documents\Codex\basilisk-zh-cn",
  [string]$Install = "F:\Progeam\Basilisk"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem
$enc = New-Object System.Text.UTF8Encoding($false)
$work = "$Base\work"

function Zh-Path([string]$p) {
  $p = $p -replace '^en-US/locale/', 'zh-CN/locale/'
  $p = $p -replace '/locale/en-US/', '/locale/zh-CN/'
  return $p
}

function Extract-Locales([string]$jar, [string]$dest) {
  Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  $z = [System.IO.Compression.ZipFile]::OpenRead($jar)
  $n = 0
  foreach ($e in $z.Entries) {
    if ($e.Length -gt 0 -and $e.FullName -match '^chrome/en-US/locale/(.+)$') {
      $dst = Join-Path $dest ($Matches[1] -replace '/','\')
      New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
      [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $dst, $true); $n++
    }
  }
  $z.Dispose()
  return $n
}

function Build-Omni([string]$srcJar, [string]$zhRoot, [string]$outJar) {
  Remove-Item -LiteralPath $outJar -Force -ErrorAction SilentlyContinue
  $src = [System.IO.Compression.ZipFile]::OpenRead($srcJar)
  $out = [System.IO.Compression.ZipFile]::Open($outJar, 'Create')
  $skipped = 0
  foreach ($e in $src.Entries) {
    $ne = $out.CreateEntry($e.FullName, [System.IO.Compression.CompressionLevel]::Optimal)
    $ns = $ne.Open()
    if ($e.FullName -eq 'chrome/chrome.manifest') {
      $sr = New-Object System.IO.StreamReader($e.Open()); $t = $sr.ReadToEnd(); $sr.Close()
      $new = ($t -split "`r?`n") | ForEach-Object {
        if ($_ -match '^locale\s+(\S+)\s+(\S+)\s+(.+?)\s*$') { "locale $($Matches[1]) zh-CN $(Zh-Path $Matches[3])" } else { $_ }
      }
      $b = $enc.GetBytes((($new -join "`r`n").TrimEnd() + "`r`n"))
      $ns.Write($b, 0, $b.Length)
    } else { $is = $e.Open(); $is.CopyTo($ns); $is.Close() }
    $ns.Close()
  }
  $src.Dispose()
  $n = 0
  $zhLen = $zhRoot.TrimEnd('\').Length
  Get-ChildItem -LiteralPath $zhRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($zhLen + 1) -replace '\\','/'
    $ne = $out.CreateEntry("chrome/" + (Zh-Path ("en-US/locale/" + $rel)), [System.IO.Compression.CompressionLevel]::Optimal)
    $ns = $ne.Open(); $bytes = [System.IO.File]::ReadAllBytes($_.FullName); $ns.Write($bytes, 0, $bytes.Length); $ns.Close(); $n++
  }
  $out.Dispose()
  return "kept original entries, added $n zh-CN entries"
}

Write-Host "[1/4] extract en-US locale trees" -ForegroundColor Cyan
$n1 = Extract-Locales "$work\browser-omni.bak.ja" "$work\en-browser"
$n2 = Extract-Locales "$Install\omni.ja.orig-enUS" "$work\en-toolkit"
Write-Host "      browser/omni.ja: $n1 files   toolkit omni.ja: $n2 files"

Write-Host "[2/4] build entity whitelist" -ForegroundColor Cyan
$ents = New-Object System.Collections.Generic.HashSet[string]
foreach ($d in "$work\en-browser","$work\en-toolkit") {
  Get-ChildItem -LiteralPath $d -Recurse -File -Filter *.dtd | ForEach-Object {
    foreach ($l in [System.IO.File]::ReadAllLines($_.FullName, [System.Text.Encoding]::UTF8)) {
      if ($l -match '<!ENTITY\s+(\S+)\s+"') { [void]$ents.Add($Matches[1]) }
    }
  }
}
foreach ($f in @("$Base\src\basilisk\branding\official\locales\en-US\chrome\brand.dtd")) {
  if (Test-Path $f) { foreach ($l in [System.IO.File]::ReadAllLines($f, [System.Text.Encoding]::UTF8)) { if ($l -match '<!ENTITY\s+(\S+)\s+"') { [void]$ents.Add($Matches[1]) } } }
}
[System.IO.File]::WriteAllLines("$work\all-entities.txt", @($ents), $enc)
Write-Host "      $($ents.Count) entity names"

Write-Host "[3/4] translate" -ForegroundColor Cyan
& "$Base\tools\translate-fx52.ps1" -Src "$work\en-toolkit" -Out "$work\zh-toolkit" -Report "$work\missing-toolkit.txt" -Patch "$Base\tools\patch-toolkit.tsv"
& "$Base\tools\translate-fx52.ps1" -Src "$work\en-browser" -Out "$work\zh-browser" -Report "$work\missing-browser.txt" -Patch "$Base\tools\patch.tsv"

Write-Host "[4/4] package omni.ja" -ForegroundColor Cyan
Write-Host ("      toolkit: " + (Build-Omni "$Install\omni.ja.orig-enUS" "$work\zh-toolkit" "$work\omni.toolkit.zh.ja"))
Write-Host ("      browser: " + (Build-Omni "$work\browser-omni.bak.ja" "$work\zh-browser" "$work\omni.browser.zh.ja"))
Write-Host "done" -ForegroundColor Green
