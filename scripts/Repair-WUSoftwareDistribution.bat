@echo off
REM Repair-WUSoftwareDistribution.bat
REM 修復 Windows Update Cache Corruption

echo ^>^>^> 正在停止 Windows Update 相關服務...
net stop wuauserv /y 2>nul
net stop cryptSvc /y 2>nul
net stop bits /y 2>nul
net stop msiserver /y 2>nul

echo ^>^>^> 正在重新命名 SoftwareDistribution 備份舊快取...
ren C:\Windows\SoftwareDistribution SoftwareDistribution.old 2>nul
ren C:\Windows\System32\catroot2 catroot2.old 2>nul

echo ^>^>^> 正在重新啟動 Windows Update 相關服務...
net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo ^>^>^> Windows Update 快取重建完成。
exit /b 0
