param(
    [string]$UsbRoot = "",
    [string]$CacheRoot = "",
    [string]$ReportPath = "",
    [switch]$Repair,
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

if (-not $UsbRoot) {
    $UsbRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
if (-not $CacheRoot) {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "WindowsDoctorPortable\GUIREADY"
}

$resolvedUsbRoot = [System.IO.Path]::GetFullPath($UsbRoot).TrimEnd("\")
$resolvedCacheRoot = [System.IO.Path]::GetFullPath($CacheRoot).TrimEnd("\")
$usbAppRoot = Join-Path $resolvedUsbRoot "WindowsDoctor"
$usbNodeRoot = Join-Path $resolvedUsbRoot "node-runtime"
$cacheAppRoot = Join-Path $resolvedCacheRoot "WindowsDoctor"
$cacheNodeRoot = Join-Path $resolvedCacheRoot "node-runtime"

Add-Check -Name "usb-root-exists" -Passed (Test-Path -LiteralPath $resolvedUsbRoot) -Detail $resolvedUsbRoot
Add-Check -Name "usb-windowsdoctor-exists" -Passed (Test-Path -LiteralPath $usbAppRoot) -Detail $usbAppRoot
Add-Check -Name "usb-node-runtime-exists" -Passed (Test-Path -LiteralPath $usbNodeRoot) -Detail $usbNodeRoot

if ($Repair) {
    if (-not (Test-Path -LiteralPath $usbAppRoot)) { throw "USB WindowsDoctor root not found: $usbAppRoot" }
    if (-not (Test-Path -LiteralPath $usbNodeRoot)) { throw "USB node runtime not found: $usbNodeRoot" }
    New-Item -Path $resolvedCacheRoot -ItemType Directory -Force | Out-Null
    robocopy $usbNodeRoot $cacheNodeRoot /MIR /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Failed to sync node runtime to cache. RobocopyExit=$LASTEXITCODE" }
    robocopy $usbAppRoot $cacheAppRoot /MIR /R:2 /W:2 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Failed to sync WindowsDoctor app to cache. RobocopyExit=$LASTEXITCODE" }
}

$requiredPaths = @(
    @{ Name = "cache-root-exists"; Path = $resolvedCacheRoot },
    @{ Name = "cache-windowsdoctor-exists"; Path = $cacheAppRoot },
    @{ Name = "cache-node-runtime-exists"; Path = $cacheNodeRoot },
    @{ Name = "cache-node-exe"; Path = (Join-Path $cacheNodeRoot "node.exe") },
    @{ Name = "cache-npm-cmd"; Path = (Join-Path $cacheNodeRoot "npm.cmd") },
    @{ Name = "cache-start-script"; Path = (Join-Path $cacheAppRoot "scripts\Start-WindowsDoctor.ps1") },
    @{ Name = "cache-gui-package"; Path = (Join-Path $cacheAppRoot "gui\package.json") },
    @{ Name = "cache-gui-node-modules"; Path = (Join-Path $cacheAppRoot "gui\node_modules") }
)

foreach ($item in $requiredPaths) {
    Add-Check -Name $item.Name -Passed (Test-Path -LiteralPath $item.Path) -Detail $item.Path
}

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    UsbRoot = $resolvedUsbRoot
    CacheRoot = $resolvedCacheRoot
    Repaired = [bool]$Repair
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
