param(
    [ValidateSet("Menu", "Broker")]
    [string]$StartupMode = "Menu",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("")
$lines.Add("REM --- Start WindowsDoctor ---")
$lines.Add("wpeinit")
$lines.Add("set WD_ROOT_DIR=X:\WindowsDoctor")
$lines.Add("set WD_USE_OFFLINE_DB=1")

if ($StartupMode -eq "Broker") {
    $lines.Add("cd /d X:\WindowsDoctor\gui")
    $lines.Add("start /b X:\WindowsDoctor\gui\node.exe broker.js")
    $lines.Add("echo WindowsDoctor Broker is ready on port 3001.")
}
else {
    $lines.Add("cd /d X:\WindowsDoctor")
    $lines.Add("powershell -NoProfile -ExecutionPolicy RemoteSigned -File X:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -Root X:\WindowsDoctor")
}

$lineArray = @($lines.ToArray())

if ($OutputPath) {
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllLines($OutputPath, $lineArray, [System.Text.Encoding]::ASCII)
}

$result = [PSCustomObject]@{
    Status = "PASS"
    StartupMode = $StartupMode
    OutputPath = $OutputPath
    ReportPath = $ReportPath
    Lines = $lineArray
}

if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $jsonText = $result | ConvertTo-Json -Depth 4
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $lineArray
}
