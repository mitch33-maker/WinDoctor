param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$OutputRoot = "",
    [string]$PackageName = "",
    [string]$ReportPath = "",
    [switch]$SkipNodeModules,
    [switch]$IncludeNodeRuntime,
    [string]$NodeRuntimePath = "C:\Program Files\nodejs",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $Root "releases\portable-usb"
}
if (-not $PackageName) {
    $PackageName = "WindowsDoctor-PortableUSB-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$readinessScript = Join-Path $Root "scripts\Test-PortableUsbReadiness.ps1"
$readinessRaw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $readinessScript -Root $Root -Json
if ($LASTEXITCODE -ne 0) {
    throw "Portable USB readiness failed"
}
$readiness = ($readinessRaw | Out-String) | ConvertFrom-Json
if ($readiness.Status -ne "PASS") {
    throw "Portable USB readiness status is $($readiness.Status)"
}

$packageRoot = Join-Path $OutputRoot $PackageName
$targetRoot = Join-Path $packageRoot "WindowsDoctor"
if (Test-Path -LiteralPath $packageRoot) {
    throw "Package path already exists: $packageRoot"
}
New-Item -Path $targetRoot -ItemType Directory -Force | Out-Null

function Copy-DirectoryContent {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludedRelative = @()
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }

    $sourceFull = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')
    $items = Get-ChildItem -LiteralPath $Source -Recurse -Force
    foreach ($item in $items) {
        $relative = $item.FullName.Substring($sourceFull.Length).TrimStart('\')
        $skip = $false
        foreach ($excluded in $ExcludedRelative) {
            if ($relative -eq $excluded -or $relative.StartsWith("$excluded\")) {
                $skip = $true
                break
            }
        }
        if ($skip) { continue }

        $target = Join-Path $Destination $relative
        if ($item.PSIsContainer) {
            New-Item -Path $target -ItemType Directory -Force | Out-Null
        }
        else {
            $parent = Split-Path -Parent $target
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -Path $parent -ItemType Directory -Force | Out-Null
            }
            Copy-Item -LiteralPath $item.FullName -Destination $target -Force
        }
    }
}

$copiedRoots = @(
    "core",
    "docs",
    "gui",
    "knowledge_base",
    "offline_database",
    "scripts",
    "templates"
)

foreach ($relativeRoot in $copiedRoots) {
    $source = Join-Path $Root $relativeRoot
    $destination = Join-Path $targetRoot $relativeRoot
    $excluded = @()
    if ($relativeRoot -eq "gui") {
        $excluded += ".next"
        if ($SkipNodeModules) { $excluded += "node_modules" }
    }
    New-Item -Path $destination -ItemType Directory -Force | Out-Null
    Copy-DirectoryContent -Source $source -Destination $destination -ExcludedRelative $excluded
}

if ($IncludeNodeRuntime) {
    if (-not (Test-Path -LiteralPath $NodeRuntimePath)) {
        throw "Node runtime path not found: $NodeRuntimePath"
    }
    $nodeRuntimeTarget = Join-Path $packageRoot "node-runtime"
    New-Item -Path $nodeRuntimeTarget -ItemType Directory -Force | Out-Null
    Copy-DirectoryContent -Source $NodeRuntimePath -Destination $nodeRuntimeTarget
}

Get-ChildItem -LiteralPath $Root -File -Force | Where-Object {
    $_.Name -match '\.(md|ps1|txt)$'
} | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $targetRoot $_.Name) -Force
}

$launcher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_ROOT_DIR=%~dp0WindowsDoctor"
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "[Console]::InputEncoding=[System.Text.Encoding]::UTF8; [Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%WD_ROOT_DIR%\scripts\Start-WinPEOfflineMenu.ps1'"
endlocal
'@
[System.IO.File]::WriteAllText((Join-Path $packageRoot "Start-WindowsDoctor-Portable.cmd"), $launcher, [System.Text.UTF8Encoding]::new($false))

$guiLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_ROOT_DIR=%~dp0WindowsDoctor"
set "WD_GUI_DIR=%WD_ROOT_DIR%\gui"
set "WD_NODE_RUNTIME=%~dp0node-runtime"
if exist "%WD_NODE_RUNTIME%\node.exe" set "PATH=%WD_NODE_RUNTIME%;%PATH%"
where node > nul 2> nul
if errorlevel 1 (
  echo [WindowsDoctor] Node.js is required to start the GUI.
  echo [WindowsDoctor] Use Start-WindowsDoctor-Portable.cmd for the offline text menu.
  pause
  exit /b 1
)
where npm.cmd > nul 2> nul
if errorlevel 1 (
  echo [WindowsDoctor] npm is required to start the GUI.
  echo [WindowsDoctor] Use Start-WindowsDoctor-Portable.cmd for the offline text menu.
  pause
  exit /b 1
)
if not exist "%WD_GUI_DIR%\node_modules" (
  echo [WindowsDoctor] Installing GUI dependencies. This needs internet access the first time.
  pushd "%WD_GUI_DIR%"
  call npm ci --no-audit --no-fund
  if errorlevel 1 (
    popd
    echo [WindowsDoctor] GUI dependency installation failed.
    pause
    exit /b 1
  )
  popd
)
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_ROOT_DIR%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_ROOT_DIR%" -RestartBroker -RestartGui -SkipBuild -Hidden
if errorlevel 1 (
  echo [WindowsDoctor] GUI startup failed.
  pause
  exit /b 1
)
start "" "http://localhost:3000"
endlocal
'@
[System.IO.File]::WriteAllText((Join-Path $packageRoot "Start-WindowsDoctor-GUI-Portable.cmd"), $guiLauncher, [System.Text.UTF8Encoding]::new($false))

$guiReadyLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_USB_ROOT=%~dp0"
set "WD_CACHE_ROOT=%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY"
set "WD_CACHE_NODE=%WD_CACHE_ROOT%\node-runtime"
set "WD_CACHE_APP=%WD_CACHE_ROOT%\WindowsDoctor"
echo [WindowsDoctor] Running GUI-ready preflight...
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_USB_ROOT%WindowsDoctor\scripts\Test-GuiReadyTargetPreflight.ps1" -Root "%WD_USB_ROOT%WindowsDoctor" -NodeRuntimePath "%WD_USB_ROOT%node-runtime" -CacheRoot "%WD_CACHE_ROOT%"
if errorlevel 1 (
  echo [WindowsDoctor] GUI-ready preflight failed.
  pause
  exit /b 1
)
echo [WindowsDoctor] Preparing local GUI cache...
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_USB_ROOT%WindowsDoctor\scripts\Test-GuiReadyCache.ps1" -UsbRoot "%WD_USB_ROOT%" -CacheRoot "%WD_CACHE_ROOT%" -Repair
if errorlevel 1 (
  echo [WindowsDoctor] GUI-ready cache verification failed.
  pause
  exit /b 1
)
set "PATH=%WD_CACHE_NODE%;%PATH%"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_CACHE_APP%" -RestartBroker -RestartGui -SkipBuild -Hidden
if errorlevel 1 (
  echo [WindowsDoctor] GUI startup failed.
  pause
  exit /b 1
)
start "" "http://localhost:3000"
endlocal
'@
[System.IO.File]::WriteAllText((Join-Path $packageRoot "Start-WindowsDoctor-GUI-Ready.cmd"), $guiReadyLauncher, [System.Text.UTF8Encoding]::new($false))

$guiReadyStopLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_CACHE_ROOT=%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY"
set "WD_CACHE_APP=%WD_CACHE_ROOT%\WindowsDoctor"
if exist "%WD_CACHE_APP%\scripts\Stop-WDGuiDevWorkers.ps1" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Stop-WDGuiDevWorkers.ps1" -IncludeDevServer
)
if exist "%WD_CACHE_APP%\scripts\Stop-GuiReadySession.ps1" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Stop-GuiReadySession.ps1" -Root "%WD_CACHE_APP%"
)
endlocal
'@
[System.IO.File]::WriteAllText((Join-Path $packageRoot "Stop-WindowsDoctor-GUI-Ready.cmd"), $guiReadyStopLauncher, [System.Text.UTF8Encoding]::new($false))

$readme = @"
# WindowsDoctor 可攜隨身碟版

階段：可攜隨身碟版
安裝版階段：延後

啟動方式：
- Start-WindowsDoctor-Portable.cmd：離線文字選單
- Start-WindowsDoctor-GUI-Portable.cmd：正常 Windows GUI
- Start-WindowsDoctor-GUI-Ready.cmd：先同步到本機快取再啟動 GUI

安全原則：
- 預設入口不啟動 GUI 或 Broker。
- GUI 需手動執行 Start-WindowsDoctor-GUI-Portable.cmd。
- 修復執行只允許 scripts\repair-allowlist.json 內的腳本。
- 先查詢或預覽，確認後才執行修復。
- 若選單要求輸入 RUN，代表即將真正執行修復動作。

驗證指令：
- Test-PortableUsbReadiness.ps1
- Test-PortableRuntimeSelfTest.ps1
- Build-WinPEMedia.ps1 -CheckOnly -StartupMode Menu
"@
[System.IO.File]::WriteAllText((Join-Path $packageRoot "README-PORTABLE-USB.md"), $readme, [System.Text.UTF8Encoding]::new($false))

$files = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File)
$bytes = [int64]0
foreach ($file in $files) { $bytes += [int64]$file.Length }

$manifest = [PSCustomObject]@{
    Status = "PASS"
    Phase = "portable-usb"
    InstallerPhase = "deferred"
    Root = $Root
    PackageRoot = $packageRoot
    WindowsDoctorRoot = $targetRoot
    Launcher = Join-Path $packageRoot "Start-WindowsDoctor-Portable.cmd"
    GuiReadyLauncher = Join-Path $packageRoot "Start-WindowsDoctor-GUI-Ready.cmd"
    GuiReadyStopLauncher = Join-Path $packageRoot "Stop-WindowsDoctor-GUI-Ready.cmd"
    SkipNodeModules = [bool]$SkipNodeModules
    IncludeNodeRuntime = [bool]$IncludeNodeRuntime
    NodeRuntimePath = if ($IncludeNodeRuntime) { Join-Path $packageRoot "node-runtime" } else { "" }
    FileCount = $files.Count
    Bytes = $bytes
    ReadinessStepCount = @($readiness.Steps).Count
    ReportPath = $ReportPath
}

$manifestJson = $manifest | ConvertTo-Json -Depth 6
$manifestPath = Join-Path $packageRoot "portable-usb-manifest.json"
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))

if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $manifestJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $manifestJson
}
else {
    $manifest | Format-List
}
