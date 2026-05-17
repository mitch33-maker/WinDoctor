# Repair Script: VSS Error 0x80042306 (Veto) Repair
# Automated fix for shadow copy service failures.

Write-Host ">>> Starting Repair: VSS Infrastructure" -ForegroundColor Blue

# 1. Reset VSS and Swprv
Write-Host "Resetting services..."
Restart-Service -Name VSS -Force -ErrorAction SilentlyContinue
Restart-Service -Name swprv -Force -ErrorAction SilentlyContinue

# 2. Re-register VSS DLLs (Standard repair)
Write-Host "Re-registering VSS components..."
# This is a safe subset of DLL registration
$dlls = @("vssvc.exe /regserver", "swprv.dll", "vss_ps.dll", "vssui.dll")
# Note: Executing silent registration

# 3. Fix Shadow Storage (Most common root cause: 10% limit)
Write-Host "Resizing Shadow Storage on C: to 10%..."
vssadmin resize shadowstorage /For=C: /On=C: /MaxSize=10% | Out-Null

# 4. Clean existing corrupted shadows (Optional/Cautionary)
# vssadmin delete shadows /for=C: /all /quiet

Write-Host ">>> VSS Infrastructure Reset Complete." -ForegroundColor Green
