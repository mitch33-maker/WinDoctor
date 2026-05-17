# WindowsDoctor Knowledge Sync Module (NAS Enterprise)
# Goal: Bi-directional sync between local KB and NAS share

param(
    [string]$LocalPath = "e:\WindowsDoctor\knowledge_base",
    [string]$RemotePath = "\\192.168.1.135\home\WindowsDoctor\knowledge_base",
    [switch]$Force
)

Write-Host ">>> Starting Knowledge Sync with NAS: $RemotePath" -ForegroundColor Cyan

if (-not (Test-Path $RemotePath)) {
    Write-Host "Creating Remote Directory: $RemotePath" -ForegroundColor Gray
    New-Item -Path $RemotePath -ItemType Directory -Force | Out-Null
}

# 1. Pull from NAS (Newer files from others)
Write-Host "Pulling updates from NAS..." -ForegroundColor Gray
robocopy $RemotePath $LocalPath /XO /Z /R:3 /W:5 /NDL /NJH /NJS

# 2. Push to NAS (My new learning cases)
Write-Host "Pushing local updates to NAS..." -ForegroundColor Gray
robocopy $LocalPath $RemotePath /XO /Z /R:3 /W:5 /NDL /NJH /NJS

Write-Host ">>> Sync Completed Successfully." -ForegroundColor Green
return @{ Status = "Success"; Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }
