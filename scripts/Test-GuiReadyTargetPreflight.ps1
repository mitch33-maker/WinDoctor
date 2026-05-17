param(
    [string]$Root = "",
    [string]$NodeRuntimePath = "",
    [string]$CacheRoot = "",
    [int]$GuiPort = 3000,
    [int]$BrokerPort = 3001,
    [double]$MinFreeMemoryGB = 4,
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

function Get-PortListenerPid {
    param([int]$Port)
    $line = netstat -ano | findstr ":$Port" | findstr "LISTENING" | Select-Object -First 1
    if (-not $line) { return "" }
    return ($line -replace ".*\s+(\d+)$", '$1').Trim()
}

if (-not $Root) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")

if (-not $CacheRoot) {
    $CacheRoot = Join-Path $env:LOCALAPPDATA "WindowsDoctorPortable\GUIREADY"
}

if (-not $NodeRuntimePath) {
    $packageRoot = Split-Path -Parent $resolvedRoot
    $NodeRuntimePath = Join-Path $packageRoot "node-runtime"
}

$os = Get-CimInstance Win32_OperatingSystem
$freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
Add-Check -Name "free-memory" -Passed ($freeMemoryGB -ge $MinFreeMemoryGB) -Detail "Free=${freeMemoryGB}GB Required=${MinFreeMemoryGB}GB"

$cacheWriteOk = $false
$cacheWriteDetail = $CacheRoot
try {
    if (-not (Test-Path -LiteralPath $CacheRoot)) {
        New-Item -Path $CacheRoot -ItemType Directory -Force | Out-Null
    }
    $probe = Join-Path $CacheRoot ("preflight-" + [guid]::NewGuid().ToString("N") + ".tmp")
    [System.IO.File]::WriteAllText($probe, "ok", [System.Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath $probe -Force
    $cacheWriteOk = $true
}
catch {
    $cacheWriteDetail = $_.Exception.Message
}
Add-Check -Name "cache-write-permission" -Passed $cacheWriteOk -Detail $cacheWriteDetail

$guiPid = Get-PortListenerPid -Port $GuiPort
$brokerPid = Get-PortListenerPid -Port $BrokerPort
Add-Check -Name "gui-port-free" -Passed (-not $guiPid) -Detail "port=$GuiPort pid=$guiPid"
Add-Check -Name "broker-port-free" -Passed (-not $brokerPid) -Detail "port=$BrokerPort pid=$brokerPid"

$nodeExe = Join-Path $NodeRuntimePath "node.exe"
$npmCmd = Join-Path $NodeRuntimePath "npm.cmd"
Add-Check -Name "node-runtime-node" -Passed (Test-Path -LiteralPath $nodeExe) -Detail $nodeExe
Add-Check -Name "node-runtime-npm" -Passed (Test-Path -LiteralPath $npmCmd) -Detail $npmCmd

$psVersion = $PSVersionTable.PSVersion.ToString()
Add-Check -Name "powershell-version" -Passed ($PSVersionTable.PSVersion.Major -ge 5) -Detail $psVersion

$executionPolicy = Get-ExecutionPolicy -Scope Process
Add-Check -Name "powershell-execution-policy" -Passed ($executionPolicy -in @("Bypass", "RemoteSigned", "Unrestricted")) -Detail ([string]$executionPolicy)

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $resolvedRoot
    CacheRoot = $CacheRoot
    NodeRuntimePath = $NodeRuntimePath
    FreeMemoryGB = $freeMemoryGB
    GuiPort = $GuiPort
    BrokerPort = $BrokerPort
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
