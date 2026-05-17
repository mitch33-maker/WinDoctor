@echo off
REM Repair-SystemMaintenance.bat
REM Safe preview entry for Windows maintenance. Execution requires Invoke-WindowsMaintenance.ps1 -Execute -ConfirmToken RUN.

powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Invoke-WindowsMaintenance.ps1" -Preview -ForceLogoffDisconnectedUsers -CleanDisk -ReleaseMemory -SystemMaintenance
exit /b %ERRORLEVEL%
