# Basilisk zh-CN 汉化 —— 卸载 / 还原英文
$ErrorActionPreference = 'Stop'
$dir = $null
$keys = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
       Where-Object { $_.DisplayName -like 'Basilisk*' }
if ($keys) { $dir = ($keys | Select-Object -First 1).InstallLocation }
if (-not $dir) { $dir = Read-Host '请输入 Basilisk 安装目录' }

Get-Process basilisk -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep -Seconds 4
Get-Process basilisk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

foreach ($p in @(@('omni.ja.orig-enUS','omni.ja'), @('browser\omni.ja.orig-enUS','browser\omni.ja'))) {
  $bak = Join-Path $dir $p[0]
  if (Test-Path $bak) { Copy-Item $bak (Join-Path $dir $p[1]) -Force; Write-Host "已还原 $($p[1])" }
  else { Write-Host "找不到备份 $($p[0])" -ForegroundColor Yellow }
}
Remove-Item (Join-Path $dir 'defaults\pref\firefox-l10n.js') -Force -ErrorAction SilentlyContinue
Write-Host '已还原为英文界面。' -ForegroundColor Green
