@echo off
REM Repair-SystemIntegrity.bat
REM 原子修復：BSOD 與系統核心檔案損毀修復

echo ^>^>^> 正在要求組件存放區執行健康狀況還原 (DISM)...
DISM /Online /Cleanup-Image /RestoreHealth

echo ^>^>^> 正在執行系統檔案完整性掃描與修復 (SFC)...
sfc /scannow

echo ^>^>^> 系統完整性修復作業已交派完成，請重新開機確認硬體狀況。
exit /b 0
