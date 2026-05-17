# Repair Script: Print Spooler Reset
Write-Host ">>> Resetting Print Spooler..." -ForegroundColor Blue

Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force -ErrorAction SilentlyContinue
Start-Service -Name Spooler

Write-Host ">>> Spooler Service Restored." -ForegroundColor Green
