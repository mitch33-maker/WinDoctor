@echo off
setlocal
set "WD_ROOT=%~dp0"
set "WD_ROOT=%WD_ROOT:~0,-1%"
powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "%WD_ROOT%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_ROOT%" -RestartBroker -NoGui -SkipBuild -Hidden -MaxGuiNodeProcesses 4 -MaxWindowsDoctorTotalWorkingSetMB 512 -MaxWindowsDoctorProcessWorkingSetMB 256 -NodeMaxOldSpaceSizeMB 192 -ProcessPriority BelowNormal
if errorlevel 1 (
  echo WindowsDoctor Broker startup failed.
  pause
  exit /b 1
)
start "" "%WD_ROOT%\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html"
endlocal
