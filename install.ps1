# Basilisk 52.9.2026.09.24 zh-CN 汉化 —— 安装
# 用法: 以管理员身份运行  powershell -ExecutionPolicy Bypass -File .\install.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. 定位安装目录: 优先读注册表, 否则问用户
$dir = $null
$keys = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
       Where-Object { $_.DisplayName -like 'Basilisk*' }
if ($keys) { $dir = ($keys | Select-Object -First 1).InstallLocation }
if (-not $dir) { $dir = Read-Host '请输入 Basilisk 安装目录 (例如 F:\Progeam\Basilisk)' }
if (-not (Test-Path (Join-Path $dir 'omni.ja'))) { throw "不是有效的 Basilisk 安装目录: $dir" }

# 2. 关闭浏览器
Get-Process basilisk -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
Start-Sleep -Seconds 4
Get-Process basilisk -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# 3. 备份原始文件
foreach ($p in @(@('omni.ja','omni.ja.orig-enUS'), @('browser\omni.ja','browser\omni.ja.orig-enUS'))) {
  $src = Join-Path $dir $p[0]; $bak = Join-Path $dir $p[1]
  if ((Test-Path $src) -and -not (Test-Path $bak)) { Copy-Item $src $bak; Write-Host "备份 $($p[1])" -ForegroundColor DarkGray }
}

# 4. 覆盖
Copy-Item (Join-Path $here 'files\omni.ja')          (Join-Path $dir 'omni.ja') -Force
Copy-Item (Join-Path $here 'files\browser\omni.ja') (Join-Path $dir 'browser\omni.ja') -Force
New-Item -ItemType Directory -Path (Join-Path $dir 'defaults\pref') -Force | Out-Null
Copy-Item (Join-Path $here 'files\defaults\pref\firefox-l10n.js') (Join-Path $dir 'defaults\pref\firefox-l10n.js') -Force

Write-Host "安装完成: $dir" -ForegroundColor Green
Write-Host "启动 Basilisk 即可看到中文界面。"
