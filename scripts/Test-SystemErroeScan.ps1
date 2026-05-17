param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [int]$RecentHours = 24,
    [int]$MaxEvents = 80,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$target = Join-Path $PSScriptRoot "Test-SystemErrorScan.ps1"
if (-not (Test-Path -LiteralPath $target)) {
    throw "Target scan script not found: $target"
}

$arguments = @(
    "-Root", $Root,
    "-RecentHours", ([string]$RecentHours),
    "-MaxEvents", ([string]$MaxEvents)
)
if ($DatabasePath) { $arguments += @("-DatabasePath", $DatabasePath) }
if ($ReportPath) { $arguments += @("-ReportPath", $ReportPath) }
if ($Json) { $arguments += "-Json" }

& powershell -NoProfile -ExecutionPolicy RemoteSigned -File $target @arguments
exit $LASTEXITCODE
