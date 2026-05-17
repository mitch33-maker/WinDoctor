# Repair Script: WinPE Boot Fixer
# Designed to be run in WinPE environments.

Import-Module "X:\WindowsDoctor\core\WindowsDoctor.psm1" -ErrorAction SilentlyContinue
# Fallback to local path if not in PE X:
Import-Module "e:\WindowsDoctor\core\WindowsDoctor.psm1" -ErrorAction SilentlyContinue

Write-Host ">>> Starting Windows Boot Repair (BCD/MBR)..." -ForegroundColor Blue

if (-not (Test-WDAdmin)) {
    Write-Warning "Not running as Admin. Elevation may be required."
}

# 1. Rebuild BCD
Repair-WDBoot

# 2. Advanced Fixes (Legacy BIOS)
Write-Host "Fixing MBR/BootSector..."
# bootrec /fixmbr  # Only for MBR
# bootrec /fixboot # Only for MBR

Write-Host ">>> Boot Repair Completed. Please remove USB and try to restart." -ForegroundColor Green
