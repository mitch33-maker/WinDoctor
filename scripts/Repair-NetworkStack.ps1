# Repair-NetworkStack.ps1
# 網路堆疊徹底重置 (針對 DNS, TCP/IP 錯亂)

Write-Host ">>> 正在重置 Winsock 目錄..."
netsh winsock reset

Write-Host ">>> 正在重置 TCP/IP 通訊協定..."
netsh int ip reset

Write-Host ">>> 正在釋放與更新 IP 位址、清除 DNS 快取..."
ipconfig /release
ipconfig /renew
ipconfig /flushdns

Write-Host ">>> 網路堆疊重置完畢，建議您稍後重新啟動電腦。" -ForegroundColor Cyan
