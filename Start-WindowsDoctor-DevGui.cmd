@echo off
setlocal
set "WD_ROOT=%~dp0"
set "WD_ROOT=%WD_ROOT:~0,-1%"
powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "%WD_ROOT%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_ROOT%" -RestartBroker -RestartGui -SkipBuild -Hidden -MaxGuiNodeProcesses 8 -MaxStartupPostCssWorkers 1 -MaxPostCssWorkerSeconds 45 -MaxWindowsDoctorTotalWorkingSetMB 1200 -MaxWindowsDoctorProcessWorkingSetMB 512 -NodeMaxOldSpaceSizeMB 384 -ResourceWatchSeconds 900 -StartupStepDelaySeconds 5 -ProcessPriority BelowNormal
if errorlevel 1 (
  echo WindowsDoctor dev GUI startup failed.
  pause
  exit /b 1
)
start "" "http://localhost:3000"
endlocal
