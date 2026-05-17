@echo off
REM Repair-WDReportCache.bat
REM Low-risk WindowsDoctor-only repair. Moves the latest AI workflow report cache to a timestamped backup.

setlocal EnableExtensions
set "ROOT=%~dp0.."
set "LOG_DIR=%ROOT%\logs"
set "TARGET=%LOG_DIR%\gui-work-issue-diagnostic.latest.json"
set "BACKUP_DIR=%ROOT%\.wd-backup\report-cache"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set "STAMP=%DATE:/=-%-%TIME::=-%"
set "STAMP=%STAMP: =0%"
set "BACKUP=%BACKUP_DIR%\gui-work-issue-diagnostic.%STAMP%.json"

if exist "%TARGET%" (
  move /Y "%TARGET%" "%BACKUP%" >nul
  echo moved="%TARGET%" backup="%BACKUP%"
  echo copy /Y "%BACKUP%" "%TARGET%" > "%BACKUP%.rollback.cmd"
) else (
  echo target_not_found="%TARGET%"
)

echo WindowsDoctor report cache repair completed.
exit /b 0
