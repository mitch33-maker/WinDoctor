# Maintenance Script: Daily Optimization Suite
Write-Host ">>> Starting Daily Maintenance..." -ForegroundColor Blue

Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -Force

# 1. System Cleanup
Optimize-WDSystem -CleanTemp -FlushDNS

# 2. Disk Health Check & Optimize
Optimize-WDDisk -Drive "C"

# 3. Registry Cleanup (Placeholder for safe cleanup)
# Clear-WDRegistryStaleMRU

Write-Host ">>> Maintenance Cycle Finished." -ForegroundColor Green
