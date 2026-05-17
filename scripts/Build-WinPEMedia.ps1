<#
.SYNOPSIS
    Build a WindowsDoctor WinPE USB or ISO image.
.DESCRIPTION
    Requires Windows ADK and Windows PE add-on. Run elevated.
    Use -CheckOnly first to validate prerequisites without modifying WIM files.
.EXAMPLE
    .\Build-WinPEMedia.ps1 -CheckOnly
    .\Build-WinPEMedia.ps1 -Architecture amd64 -OutputPath "E:\WindowsDoctor_Rescue.iso"
    .\Build-WinPEMedia.ps1 -Architecture amd64 -USBPath "F:"
#>
param(
    [ValidateSet("amd64", "x86")]
    [string]$Architecture = "amd64",

    [ValidateSet("Menu", "Broker")]
    [string]$StartupMode = "Menu",

    [string]$OutputPath = "E:\WindowsDoctor_Rescue.iso",
    [string]$USBPath = "",
    [string]$SourceDir = "E:\WindowsDoctor",
    [string]$NodeExePath = "",
    [string]$ReportPath = "",
    [switch]$CheckOnly,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$AdkPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
$DandISetEnvPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\DandISetEnv.bat"
$CopypePath = Join-Path $AdkPath "copype.cmd"
$MakeWinPEMediaPath = Join-Path $AdkPath "MakeWinPEMedia.cmd"
$PackageRoot = Join-Path $AdkPath "$Architecture\WinPE_OCs"
$WorkingDir = "C:\WinPE_WD_$Architecture"

function Assert-NativeSuccess {
    param([string]$Step)
    if ($LASTEXITCODE -ne 0) {
        throw "$Step failed with exit code $LASTEXITCODE"
    }
}

$validationErrors = New-Object System.Collections.Generic.List[string]
if (-not (Test-Path $AdkPath)) { $validationErrors.Add("Windows ADK WinPE path not found: $AdkPath") }
if (-not (Test-Path $DandISetEnvPath)) { $validationErrors.Add("DandISetEnv.bat not found: $DandISetEnvPath") }
if (-not (Test-Path $CopypePath)) { $validationErrors.Add("copype.cmd not found: $CopypePath") }
if (-not (Test-Path $MakeWinPEMediaPath)) { $validationErrors.Add("MakeWinPEMedia.cmd not found: $MakeWinPEMediaPath") }
if (-not (Test-Path $PackageRoot)) { $validationErrors.Add("WinPE package root not found: $PackageRoot") }
if (-not (Test-Path $SourceDir)) { $validationErrors.Add("SourceDir not found: $SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "gui\broker.js"))) { $validationErrors.Add("Broker not found under SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "knowledge_base"))) { $validationErrors.Add("knowledge_base not found under SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "scripts\Export-OfflineKBDatabase.ps1"))) { $validationErrors.Add("Offline KB export script not found under SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "scripts\Start-WinPEOfflineMenu.ps1"))) { $validationErrors.Add("WinPE offline menu script not found under SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "scripts\Invoke-AllowedRepair.ps1"))) { $validationErrors.Add("Allowed repair wrapper not found under SourceDir") }
if (-not (Test-Path (Join-Path $SourceDir "scripts\New-WinPEStartNet.ps1"))) { $validationErrors.Add("WinPE startnet generator not found under SourceDir") }
if ($NodeExePath -and -not (Test-Path $NodeExePath)) { $validationErrors.Add("NodeExePath not found: $NodeExePath") }
if ($StartupMode -eq "Broker" -and -not $NodeExePath -and -not (Get-Command node -ErrorAction SilentlyContinue)) { $validationErrors.Add("node.exe not found; provide -NodeExePath") }

if ($validationErrors.Count -gt 0) {
    $validationErrors | ForEach-Object { Write-Error $_ }
    exit 1
}

$ResolvedNodeExe = if ($NodeExePath) { $NodeExePath } elseif (Get-Command node -ErrorAction SilentlyContinue) { (Get-Command node).Source } else { "" }
$OfflineDbPath = Join-Path $SourceDir "offline_database\windowsdoctor-kb.json"
& powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $SourceDir "scripts\Export-OfflineKBDatabase.ps1") -Root $SourceDir -OutputPath $OfflineDbPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Offline KB database export failed: $OfflineDbPath"
}

if ($CheckOnly) {
    $result = [PSCustomObject]@{
        Status       = "Ready"
        Architecture = $Architecture
        SourceDir    = $SourceDir
        OutputPath   = $OutputPath
        USBPath      = $USBPath
        StartupMode  = $StartupMode
        ADKPath      = $AdkPath
        NodeExePath  = $ResolvedNodeExe
        PackageRoot  = $PackageRoot
        OfflineDbPath = $OfflineDbPath
        ReportPath   = $ReportPath
    }

    if ($ReportPath) {
        $reportParent = Split-Path -Parent $ReportPath
        if ($reportParent -and -not (Test-Path $reportParent)) {
            New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
        }
        $jsonText = $result | ConvertTo-Json -Depth 4
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
    }

    if ($Json) {
        $result | ConvertTo-Json -Depth 4
    }
    else {
        $result | Format-List
    }
    exit 0
}

Write-Host ">>> 1. Initialize WinPE working directory..." -ForegroundColor Cyan
if (Test-Path $WorkingDir) {
    Remove-Item -Path $WorkingDir -Recurse -Force
}
& cmd.exe /d /c "call ""$DandISetEnvPath"" && ""$CopypePath"" $Architecture ""$WorkingDir"""
Assert-NativeSuccess -Step "copype"

$MountDir = Join-Path $WorkingDir "mount"

Write-Host ">>> 2. Mount boot.wim..." -ForegroundColor Cyan
Dism /Mount-Image /ImageFile:"$WorkingDir\media\sources\boot.wim" /index:1 /MountDir:$MountDir
Assert-NativeSuccess -Step "DISM mount"

Write-Host ">>> 3. Add WinPE packages..." -ForegroundColor Cyan
Dism /Add-Package /Image:$MountDir /PackagePath:"$PackageRoot\WinPE-WMI.cab"
Assert-NativeSuccess -Step "DISM add WinPE-WMI"
Dism /Add-Package /Image:$MountDir /PackagePath:"$PackageRoot\WinPE-NetFX.cab"
Assert-NativeSuccess -Step "DISM add WinPE-NetFX"
Dism /Add-Package /Image:$MountDir /PackagePath:"$PackageRoot\WinPE-Scripting.cab"
Assert-NativeSuccess -Step "DISM add WinPE-Scripting"
Dism /Add-Package /Image:$MountDir /PackagePath:"$PackageRoot\WinPE-PowerShell.cab"
Assert-NativeSuccess -Step "DISM add WinPE-PowerShell"

$ZhTwWmiPackage = Join-Path $PackageRoot "zh-tw\WinPE-WMI_zh-tw.cab"
if (Test-Path $ZhTwWmiPackage) {
    Dism /Add-Package /Image:$MountDir /PackagePath:$ZhTwWmiPackage
    Assert-NativeSuccess -Step "DISM add zh-tw WinPE-WMI"
}

Write-Host ">>> 4. Inject WindowsDoctor files..." -ForegroundColor Cyan
$TargetWdDir = Join-Path $MountDir "WindowsDoctor"
New-Item -Path $TargetWdDir -ItemType Directory -Force | Out-Null
Copy-Item -Path "$SourceDir\gui" -Destination $TargetWdDir -Recurse -Force
Copy-Item -Path "$SourceDir\scripts" -Destination $TargetWdDir -Recurse -Force
Copy-Item -Path "$SourceDir\knowledge_base" -Destination $TargetWdDir -Recurse -Force
Copy-Item -Path "$SourceDir\offline_database" -Destination $TargetWdDir -Recurse -Force
if (Test-Path (Join-Path $SourceDir "templates")) {
    Copy-Item -Path "$SourceDir\templates" -Destination $TargetWdDir -Recurse -Force
}
Copy-Item -Path "$SourceDir\*.md" -Destination $TargetWdDir -Force
if ($ResolvedNodeExe) {
    Copy-Item -Path $ResolvedNodeExe -Destination "$TargetWdDir\gui\node.exe" -Force
}

Write-Host ">>> 5. Configure startnet.cmd..." -ForegroundColor Cyan
$StartNetPath = Join-Path $MountDir "Windows\System32\startnet.cmd"
& powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $SourceDir "scripts\New-WinPEStartNet.ps1") -StartupMode $StartupMode -OutputPath $StartNetPath | Out-Null

Write-Host ">>> 6. Commit image..." -ForegroundColor Cyan
Dism /Unmount-Image /MountDir:$MountDir /Commit
Assert-NativeSuccess -Step "DISM commit"

if ($USBPath) {
    Write-Host ">>> 7. Write USB media: $USBPath" -ForegroundColor Cyan
    & cmd.exe /d /c "call ""$DandISetEnvPath"" && ""$MakeWinPEMediaPath"" /UFD /F ""$WorkingDir"" $USBPath"
    Assert-NativeSuccess -Step "MakeWinPEMedia USB"
    Write-Host "WindowsDoctor WinPE USB is ready." -ForegroundColor Green
}
else {
    Write-Host ">>> 7. Build ISO: $OutputPath" -ForegroundColor Cyan
    & cmd.exe /d /c "call ""$DandISetEnvPath"" && ""$MakeWinPEMediaPath"" /ISO ""$WorkingDir"" ""$OutputPath"""
    Assert-NativeSuccess -Step "MakeWinPEMedia ISO"
    Write-Host "WindowsDoctor WinPE ISO is ready: $OutputPath" -ForegroundColor Green
}
