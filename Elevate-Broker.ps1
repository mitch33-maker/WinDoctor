# Utility: Elevate WindowsDoctor Broker
# Restarts the node broker with administrative privileges.

$scriptDir = "e:\WindowsDoctor\gui"
$nodePath = "node" # Assumes node is in PATH

if (-not (Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -PassThru | Select-Object -ExpandProperty ExportedFunctions | Where-Object { $_ -eq "Test-WDAdmin" })) {
    Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -Force
}

if (Test-WDAdmin) {
    Write-Host ">>> Already running as Administrator. Starting Broker..." -ForegroundColor Green
    Set-Location $scriptDir
    node broker.js
}
else {
    Write-Host ">>> Non-Admin detected. Requesting UAC Elevation..." -ForegroundColor Yellow
    # Request UAC for a new powershell process that starts the broker
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd $scriptDir; node broker.js`"" -Verb RunAs
    Write-Host ">>> Elevated Broker window should have appeared. You can close this window." -ForegroundColor Gray
}
