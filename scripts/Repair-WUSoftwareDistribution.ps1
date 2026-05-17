# Repair Script: Windows Update SoftwareDistribution Reset
# Standard procedure for 0x80070005 and 0x80244018 errors.

Write-Host ">>> Starting Repair: Windows Update Components" -ForegroundColor Blue

# 1. Stop Services
$services = @("wuauserv", "bits", "cryptsvc", "msiserver")
foreach ($s in $services) {
    Write-Host "Stopping $s..."
    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
}

# 2. Rename Folders
$sd = "C:\Windows\SoftwareDistribution"
$cd = "C:\Windows\System32\catroot2"

if (Test-Path $sd) {
    Write-Host "Renaming SoftwareDistribution..."
    $oldSd = "$sd.old.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Rename-Item -Path $sd -NewName (Split-Path $oldSd -Leaf) -Force
}

# 3. Start Services
foreach ($s in $services) {
    Write-Host "Starting $s..."
    Start-Service -Name $s -ErrorAction SilentlyContinue
}

Write-Host ">>> Repair Complete. Please restart Windows Update check." -ForegroundColor Green
