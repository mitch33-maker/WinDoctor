@echo off
setlocal
set "WD_ROOT=%~dp0"
set "WD_ROOT=%WD_ROOT:~0,-1%"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_ROOT%\scripts\Stop-WindowsDoctorServices.ps1" -Root "%WD_ROOT%"
endlocal
