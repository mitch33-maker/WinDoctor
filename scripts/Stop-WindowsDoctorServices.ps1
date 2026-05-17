param(
    [string]$Root = "E:\WindowsDoctor",
    [int]$GuiPort = 3000,
    [int]$BrokerPort = 3001,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")

function Get-PortListenerPid {
    param([int]$Port)
    $line = netstat -ano | findstr ":$Port" | findstr "LISTENING" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace ".*\s+(\d+)$", '$1').Trim()
}

function Stop-PortListener {
    param([int]$Port)
    $listenerPid = Get-PortListenerPid -Port $Port
    if ($listenerPid) {
        taskkill /F /PID $listenerPid | Out-Null
        return $listenerPid
    }
    return $null
}

$workerResultRaw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Stop-WDGuiDevWorkers.ps1" -Root $resolvedRoot -IncludeDevServer -Json
$workerResult = ($workerResultRaw | Out-String) | ConvertFrom-Json
$guiPid = Stop-PortListener -Port $GuiPort
$brokerPid = Stop-PortListener -Port $BrokerPort

$result = [PSCustomObject]@{
    Status = "PASS"
    Root = $resolvedRoot
    GuiPort = $GuiPort
    BrokerPort = $BrokerPort
    StoppedGuiDevWorkers = $workerResult.Stopped
    StoppedGuiPid = $guiPid
    StoppedBrokerPid = $brokerPid
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 5
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}
