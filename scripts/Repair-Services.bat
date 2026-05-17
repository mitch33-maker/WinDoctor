@echo off
REM Repair-Services.bat
REM 修復因為系統當機或錯誤遺失而導致無法啟動的服務 (Event 7000)

echo ^>^>^> 正在驗證與重置 Windows 服務控制管理員...

REM 1. 確保基本系統服務啟動類型正確
sc config W32Time start= auto
sc config BITS start= demand
sc config wuauserv start= demand
sc config CryptSvc start= auto

REM 2. 強制重啟常見的相依服務
echo 正在重啟 W32Time...
net stop W32Time /y 2>nul
net start W32Time

echo 正在重啟 BITS...
net stop BITS /y 2>nul
net start BITS

echo 正在重啟 wuauserv...
net stop wuauserv /y 2>nul
net start wuauserv

echo 正在重啟 CryptSvc...
net stop CryptSvc /y 2>nul
net start CryptSvc

echo 系統服務重置程序完成。
exit /b 0
