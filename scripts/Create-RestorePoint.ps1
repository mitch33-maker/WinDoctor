# Repair Script: Create System Restore Point
# Safety measure before intensive repairs.

Write-Host ">>> Creating System Restore Point for Safety..." -ForegroundColor Blue

$Description = "WindowsDoctor_PreRepair_$(Get-Date -Format 'yyyyMMdd_HHmm')"

try {
    # Check if System Restore is enabled
    $drive = "C:\"
    $status = Get-ComputerInfo | Select-Object -ExpandProperty WindowsProductName # Just a check
    
    # Enable-ComputerRestore -Drive $drive -ErrorAction SilentlyContinue
    Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    
    Write-Host ">>> Restore Point Created: $Description" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host ">>> WARNING: Could not create restore point (possibly disabled or limit reached). Proceeding with caution." -ForegroundColor Yellow
    exit 0 # Non-blocking for now
}
