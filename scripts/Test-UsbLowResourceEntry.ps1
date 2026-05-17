param(
    [Parameter(Mandatory = $true)]
    [string]$UsbRoot,
    [string]$PackageName = "WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$resolvedUsbRoot = [System.IO.Path]::GetFullPath($UsbRoot).TrimEnd("\")
$packageRoot = Join-Path $resolvedUsbRoot $PackageName
$wdRoot = Join-Path $packageRoot "WindowsDoctor"
$startHere = Join-Path $resolvedUsbRoot "START_HERE.html"
$lowResourceCmd = Join-Path $packageRoot "Start-WindowsDoctor-LowResource.cmd"
$lowResourceVbs = Join-Path $packageRoot "Start-WindowsDoctor-LowResource-Silent.vbs"
$lowResourceStop = Join-Path $packageRoot "Stop-WindowsDoctor-LowResource.cmd"
$guiReadyCmd = Join-Path $packageRoot "Start-WindowsDoctor-GUI-Ready.cmd"
$nodeRuntime = Join-Path $packageRoot "node-runtime\node.exe"
$startScript = Join-Path $wdRoot "scripts\Start-WindowsDoctor.ps1"
$resourceSafetyScript = Join-Path $wdRoot "scripts\Test-ResourceSafety.ps1"
$workService = Join-Path $wdRoot "gui\broker\services\work.js"

Add-Check -Name "usb-root-exists" -Passed (Test-Path -LiteralPath $resolvedUsbRoot) -Detail $resolvedUsbRoot
Add-Check -Name "package-root-exists" -Passed (Test-Path -LiteralPath $packageRoot) -Detail $packageRoot
Add-Check -Name "start-here-exists" -Passed (Test-Path -LiteralPath $startHere) -Detail $startHere
Add-Check -Name "low-resource-cmd-exists" -Passed (Test-Path -LiteralPath $lowResourceCmd) -Detail $lowResourceCmd
Add-Check -Name "low-resource-vbs-exists" -Passed (Test-Path -LiteralPath $lowResourceVbs) -Detail $lowResourceVbs
Add-Check -Name "low-resource-stop-exists" -Passed (Test-Path -LiteralPath $lowResourceStop) -Detail $lowResourceStop
Add-Check -Name "gui-ready-cmd-exists" -Passed (Test-Path -LiteralPath $guiReadyCmd) -Detail $guiReadyCmd
Add-Check -Name "node-runtime-exists" -Passed (Test-Path -LiteralPath $nodeRuntime) -Detail $nodeRuntime
Add-Check -Name "start-script-exists" -Passed (Test-Path -LiteralPath $startScript) -Detail $startScript
Add-Check -Name "resource-safety-script-exists" -Passed (Test-Path -LiteralPath $resourceSafetyScript) -Detail $resourceSafetyScript
Add-Check -Name "work-service-exists" -Passed (Test-Path -LiteralPath $workService) -Detail $workService

$startHereText = Read-Text -Path $startHere
$lowIndex = $startHereText.IndexOf("Start-WindowsDoctor-LowResource-Silent.vbs", [System.StringComparison]::OrdinalIgnoreCase)
$guiIndex = $startHereText.IndexOf("Start-WindowsDoctor-GUI-Ready.cmd", [System.StringComparison]::OrdinalIgnoreCase)
Add-Check -Name "start-here-low-resource-listed" -Passed ($lowIndex -ge 0) -Detail "index=$lowIndex"
Add-Check -Name "start-here-gui-ready-listed" -Passed ($guiIndex -ge 0) -Detail "index=$guiIndex"
Add-Check -Name "start-here-low-resource-before-gui" -Passed ($lowIndex -ge 0 -and $guiIndex -ge 0 -and $lowIndex -lt $guiIndex) -Detail "low=$lowIndex gui=$guiIndex"
$hasReplacementChar = $startHereText.IndexOf([string][char]0xFFFD, [System.StringComparison]::Ordinal) -ge 0
Add-Check -Name "start-here-no-replacement-char" -Passed (-not $hasReplacementChar) -Detail $startHere

$lowCmdText = Read-Text -Path $lowResourceCmd
$lowVbsText = Read-Text -Path $lowResourceVbs
$startScriptText = Read-Text -Path $startScript

Add-Check -Name "low-resource-cmd-uses-nogui" -Passed ($lowCmdText -match "-NoGui") -Detail "Start-WindowsDoctor-LowResource.cmd"
Add-Check -Name "low-resource-cmd-no-restart-gui" -Passed (-not ($lowCmdText -match "-RestartGui")) -Detail "Start-WindowsDoctor-LowResource.cmd"
Add-Check -Name "low-resource-cmd-skip-build" -Passed ($lowCmdText -match "-SkipBuild") -Detail "Start-WindowsDoctor-LowResource.cmd"
Add-Check -Name "low-resource-cmd-budget-512" -Passed ($lowCmdText -match "MaxWindowsDoctorTotalWorkingSetMB 512") -Detail "Start-WindowsDoctor-LowResource.cmd"
Add-Check -Name "low-resource-vbs-uses-nogui" -Passed ($lowVbsText -match "-NoGui") -Detail "Start-WindowsDoctor-LowResource-Silent.vbs"
Add-Check -Name "low-resource-vbs-no-restart-gui" -Passed (-not ($lowVbsText -match "-RestartGui")) -Detail "Start-WindowsDoctor-LowResource-Silent.vbs"
Add-Check -Name "start-script-portable-node-detection" -Passed ($startScriptText -match "node-runtime\\node\.exe") -Detail "Start-WindowsDoctor.ps1"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    UsbRoot = $resolvedUsbRoot
    PackageRoot = $packageRoot
    ReportPath = $ReportPath
    Checks = $checkArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $checkArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
