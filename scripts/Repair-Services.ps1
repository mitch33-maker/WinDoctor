# Repair-Services.ps1
# 修復因為系統當機或錯誤遺失而導致無法啟動的服務 (Event 7000)

Write-Host ">>> 正在驗證與重置 Windows 服務控制管理員..."
# 1. 確保基本系統服務啟動類型正確
Set-Service -Name W32Time -StartupType Automatic
Set-Service -Name BITS -StartupType Manual
Set-Service -Name wuauserv -StartupType Manual
Set-Service -Name CryptSvc -StartupType Automatic

# 2. 強制重啟常見的相依服務
$services = @("W32Time", "BITS", "wuauserv", "CryptSvc")
foreach ($srv in $services) {
    try {
        Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
        Start-Service -Name $srv -ErrorAction Stop
        Write-Host "已成功重啟服務：$srv" -ForegroundColor Green
    }
    catch {
        Write-Warning "無法重啟服務：$srv"
    }
}

Write-Host "系統服務重置程序完成。" -ForegroundColor Cyan
