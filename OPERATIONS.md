# WindowsDoctor Operations

Last updated: `2026-05-17`

## 1. Start Services
Windows double-click launchers:
```text
E:\WindowsDoctor\Start-WindowsDoctor-Silent.vbs
E:\WindowsDoctor\Stop-WindowsDoctor-Silent.vbs
E:\WindowsDoctor\Start-WindowsDoctor-LowResource-Silent.vbs
E:\WindowsDoctor\Start-WindowsDoctor-DevGui-Silent.vbs
```

Desktop shortcuts:
```text
E:\桌面\WindowsDoctor 啟動.lnk
E:\桌面\WindowsDoctor 停止.lnk
```

Low-resource Broker-only console:
```text
E:\WindowsDoctor\Start-WindowsDoctor-LowResource-Silent.vbs
E:\WindowsDoctor\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html
```

USB low-resource entry:
```text
F:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3\Start-WindowsDoctor-LowResource-Silent.vbs
```

Default user launch is low-resource mode. Next dev GUI is development-only:
```text
E:\WindowsDoctor\Start-WindowsDoctor-DevGui-Silent.vbs
```

Low-resource startup resource test:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-LowResourceStartup.ps1 -ReportPath E:\WindowsDoctor\logs\low-resource-startup.latest.json -Json
```

Recommended single entry:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -RestartBroker -Verify
```
`-Verify` defaults to fast verification without production build. Use `-FullVerify` only when enough memory is available.

Restart both GUI and Broker:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -RestartBroker -RestartGui
```

Manual start:
```powershell
Start-Process -FilePath node -ArgumentList 'E:\WindowsDoctor\gui\broker.js' -WorkingDirectory 'E:\WindowsDoctor\gui'
Start-Process -FilePath npm -ArgumentList 'run dev -- -p 3000' -WorkingDirectory 'E:\WindowsDoctor\gui'
```

## 2. Restart Broker Safely
```powershell
$pid3001 = (netstat -ano | findstr :3001 | findstr LISTENING) -replace '.*\s+(\d+)$','$1' | Select-Object -First 1; if($pid3001){ taskkill /F /PID $pid3001 }; Start-Process -FilePath node -ArgumentList 'E:\WindowsDoctor\gui\broker.js' -WorkingDirectory 'E:\WindowsDoctor\gui'
```

## 3. Verify Baseline
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipBuild
```

Fast service verification without production build:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -Verify -SkipBuild
```

Low-risk baseline without service smoke or production build:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild
```

Machine-readable low-risk baseline:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -Json
```

Machine-readable low-risk baseline with a JSON report file:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json
```

Sequential low-risk task queue with resource gates between every task:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-WDSequentialTaskQueue.ps1 -ReportPath E:\WindowsDoctor\logs\sequential-task-queue.latest.json -Json
```

Sequential targeted tasks:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "& 'E:\WindowsDoctor\scripts\Invoke-WDSequentialTaskQueue.ps1' -Task @('resource-safety','version-policy') -ReportPath 'E:\WindowsDoctor\logs\sequential-task-queue.targeted.json' -Json"
```

Machine-readable baseline without nested Pester or lint, useful inside tests:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -SkipPester -SkipLint -Json
```

Full Pester baseline is explicit because it can be slow:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -FullPester -ReportPath E:\WindowsDoctor\logs\system-baseline.full-pester.json -Json
```

Machine-readable service status:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -NoGui -NoBroker -Json
```

Machine-readable service status with a JSON report file:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -NoGui -NoBroker -ReportPath E:\WindowsDoctor\logs\service-status.latest.json -Json
```

Resource snapshot before heavy tasks:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Get-WDResourceSnapshot.ps1 -Json
```

Resource snapshot before heavy tasks with a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Get-WDResourceSnapshot.ps1 -ReportPath E:\WindowsDoctor\logs\resource-snapshot.latest.json -Json
```

Resource safety gate:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1
```

Resource safety gate JSON:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```

Resource safety gate JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -ReportPath E:\WindowsDoctor\logs\resource-safety.latest.json -Json
```

MIS Windows event log analysis:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Analyze-WindowsEventLogs.ps1 -Root E:\WindowsDoctor -RecentHours 24 -MaxEvents 120 -Top 10 -ReportPath E:\WindowsDoctor\logs\windows-event-log-analysis.latest.json -CsvPath E:\WindowsDoctor\logs\windows-event-log-analysis.latest.csv -Json
```

This is read-only. It reads event logs, summarizes Provider/Event ID hot spots, joins reviewed KB recommendations, and never executes repairs.

Validate and package optional repair/diagnostic tools:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-RepairToolPackageManifest.ps1 -ManifestPath E:\WindowsDoctor\incoming\repair-tools\manifest.json -ReportPath E:\WindowsDoctor\logs\repair-tool-package-manifest.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-RepairToolPackage.ps1 -ManifestPath E:\WindowsDoctor\incoming\repair-tools\manifest.json -OutputRoot E:\WindowsDoctor\releases\repair-tools -ReportPath E:\WindowsDoctor\logs\repair-tool-package.latest.json -Json
```

Tool packaging validates source trust, HTTPS source URL, SHA-256, license metadata, and no-autorun policy. It does not install, execute, or add tools to the repair allowlist.

Download and package Microsoft official offline diagnostic tools:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Save-OfflineRepairTools.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\offline-repair-tools-acquisition.latest.json -Json
```

This downloads SetupDiag and a restricted set of Microsoft Sysinternals diagnostic tools, checks SHA-256 and Authenticode signatures, excludes high-risk tools such as PsExec/PsKill/SDelete/PsShutdown, and keeps all tools non-autorun.

Validate offline tool auto-selection for the offline UI:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-OfflineToolAutomation.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\offline-tool-automation.latest.json -Json
```

The offline UI can automatically select the most relevant packaged diagnostic tools for the user's problem and show a sequential command preview. This is preview-only: it does not install tools, execute tools, update the repair allowlist, or perform repair actions without a separate RUN-gated execution path.

Real data import readiness gate:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-RealDataImportReadiness.ps1 -CreateDirectories -ReportPath E:\WindowsDoctor\logs\real-data-import-readiness.latest.json -Json
```

TASK_HANDOFF archive readiness gate:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-TaskHandoffArchiveReadiness.ps1 -ReportPath E:\WindowsDoctor\logs\task-handoff-archive-readiness.latest.json -Json
```

Task completion record:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Add-TaskCompletionRecord.ps1 -Title "task title" -Status PASS -Summary "short summary" -EvidencePath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -ReportPath E:\WindowsDoctor\logs\task-completion-record.latest.json -Json
```

Documentation memory system validation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationMemorySystem.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -Json
```

Microsoft official source update and repair coverage goal:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Update-MicrosoftOfficialRepairSources.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\microsoft-official-sources.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-NormalizedKBDatabase.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\normalized-kb-export.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-NormalizedKBDatabase.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-RepairCoverageGoal.ps1 -Root E:\WindowsDoctor -TargetPercent 80 -ReportPath E:\WindowsDoctor\logs\repair-coverage-goal.latest.json -Json
```

Auto repair safety policy validation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-AutoRepairSafetyPolicy.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\auto-repair-safety-policy.latest.json -Json
```

Visual operation manual:
```powershell
E:\WindowsDoctor\docs\WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html
```

Portable USB zip manifest compare:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbZipManifest.ps1 -ZipPath E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ReportPath E:\WindowsDoctor\logs\acceptance-oneclickv3\zip-manifest.json -Json
```

Portable USB zip manifest compare with SHA-256 hash verification for small packages:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbZipManifest.ps1 -ZipPath E:\WindowsDoctor\releases\portable-usb\small-package.zip -PackageRoot E:\WindowsDoctor\releases\portable-usb\small-package -Hash -ReportPath E:\WindowsDoctor\logs\zip-manifest.hash.latest.json -Json
```

Low-resource portable incremental patch:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-PortableIncrementalPatch.ps1 -PackageRoot E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ReportPath E:\WindowsDoctor\logs\portable-incremental-patch.latest.json -Json
```

Verify low-resource portable incremental patch:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableIncrementalPatch.ps1 -PatchZipPath E:\WindowsDoctor\releases\portable-usb\incremental-patches\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-20260509-LowResource.zip -PackageRoot E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ReportPath E:\WindowsDoctor\logs\portable-incremental-patch.verify.latest.json -Json
```

Verify USB low-resource entry without launching services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-UsbLowResourceEntry.ps1 -UsbRoot F:\ -ReportPath E:\WindowsDoctor\logs\usb-low-resource-entry.latest.json -Json
```

Full USB low-resource acceptance:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-UsbLowResourceAcceptance.ps1 -UsbRoot F:\ -ReportPath E:\WindowsDoctor\logs\usb-low-resource-acceptance.latest.json -Json
```

Portable USB acceptance wrapper:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-PortableUsbAcceptance.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ZipPath E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip -UsbRoot G:\ -ReportPath E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper.latest.json -Json
```

Portable USB acceptance summary only:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-PortableUsbAcceptance.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ZipPath E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip -UsbRoot G:\ -ReportPath E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper.summary.latest.json -SummaryOnly -Json
```

Resume interrupted portable USB publishing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Publish-PortableUsbPackage.ps1 -USBPath G:\ -PackageName WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -IncludeNodeModules -IncludeNodeRuntime -NodeRuntimePath "C:\Program Files\nodejs" -ResumeExistingTarget -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-resume.latest.json -Json
```

Resource safety Pester tests:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path 'E:\WindowsDoctor\scripts\ResourceSafety.Tests.ps1'"
```

Generate a continuation prompt for a new conversation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-ContinuationPrompt.ps1 -Json
```

Generate a continuation prompt and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-ContinuationPrompt.ps1 -ReportPath E:\WindowsDoctor\logs\continuation-prompt.latest.json -Json
```

Generate and copy the continuation prompt to clipboard:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-ContinuationPrompt.ps1 -CopyToClipboard -Json
```

GUI dev worker cleanup dry-run:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Stop-WDGuiDevWorkers.ps1 -WhatIf
```

GUI dev worker cleanup dry-run JSON:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Stop-WDGuiDevWorkers.ps1 -WhatIf -Json
```

GUI dev worker cleanup dry-run JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Stop-WDGuiDevWorkers.ps1 -WhatIf -ReportPath E:\WindowsDoctor\logs\gui-dev-workers.whatif.latest.json -Json
```

Safe startup guard defaults:
- `Start-WindowsDoctor.ps1` runs resource safety checks before GUI startup.
- Broker and GUI startup are sequenced. Broker must bind to port `3001`, then the script waits and reruns resource safety before starting GUI.
- Started Broker/GUI parent processes are set to `BelowNormal` priority by default.
- Node child processes inherit `NODE_OPTIONS=--max-old-space-size=384` by default from the launcher.
- Resource safety checks enforce both process count and working-set budgets:
  - `MaxWindowsDoctorNodeProcesses=8` for launcher/watchdog paths.
  - `MaxWindowsDoctorTotalWorkingSetMB=1200`.
  - `MaxWindowsDoctorProcessWorkingSetMB=512`.
- During GUI startup, watchdog allows up to `1` PostCSS worker for at most `45` seconds to permit first-load compilation without allowing worker runaway.
- After GUI startup, it waits `5` seconds and rechecks resource safety.
- After GUI startup, `Watch-WDResourceSafety.ps1` monitors resource safety for the first `600` seconds by default and stops the GUI dev server if memory, PostCSS worker, or WindowsDoctor node-process limits fail.
- If WindowsDoctor PostCSS workers or node process count exceed limits, it stops GUI dev workers and the GUI listener.
- Use `-DisableGuiStartupGuard` only for controlled debugging.

WinPE offline KB check:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly
```

WinPE media defaults to text menu startup:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly -StartupMode Menu
```

WinPE media preflight report without building ISO or USB:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly -ReportPath E:\WindowsDoctor\logs\winpe-media-checkonly.latest.json -Json
```

Preview generated WinPE `startnet.cmd` lines for menu startup:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-WinPEStartNet.ps1 -StartupMode Menu -Json
```

Preview generated WinPE `startnet.cmd` lines for Broker startup:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-WinPEStartNet.ps1 -StartupMode Broker -Json
```

Preview generated WinPE `startnet.cmd` lines and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-WinPEStartNet.ps1 -StartupMode Menu -ReportPath E:\WindowsDoctor\logs\winpe-startnet.latest.json -Json
```

WinPE Broker startup is explicit:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly -StartupMode Broker
```

Export WinPE offline KB JSON:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-OfflineKBDatabase.ps1 -Json
```

Export WinPE offline KB JSON and write a summary report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-export.latest.json -Json
```

Validate WinPE offline KB JSON:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-OfflineKBDatabase.ps1 -Json
```

Validate WinPE offline KB JSON and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-validate.latest.json -Json
```

Export normalized Windows repair KB schema v2:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-export.latest.json -Json
```

Import NotebookLM exported repair source pack:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Import-NotebookLMSourcePack.ps1 -InputPath <NOTEBOOKLM_SOURCE_PACK_JSON> -ReportPath E:\WindowsDoctor\logs\notebooklm-import.latest.json -Json
```

NotebookLM source pack template:
```powershell
E:\WindowsDoctor\templates\NOTEBOOKLM_SOURCE_PACK_TEMPLATE.json
```

Validate NotebookLM source pack before import:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-NotebookLMSourcePack.ps1 -InputPath <NOTEBOOKLM_SOURCE_PACK_JSON> -ReportPath E:\WindowsDoctor\logs\notebooklm-source-pack-validate.latest.json -Json
```

NotebookLM import uses an exported JSON interchange file. It does not require live NotebookLM API access.

GUI NotebookLM import:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WindowsDoctor.ps1 -RestartBroker -RestartGui -SkipBuild
```

Then open:
```text
http://localhost:3000
```

Use the `NotebookLM` panel to select or paste a source pack JSON and click `匯入並重建`.

GUI-ready USB for other Windows computers:
```text
G:\WindowsDoctor-PortableUSB-GUI-READY-20260503\Start-WindowsDoctor-GUI-Ready.cmd
```

GUI-ready USB behavior:
- Includes `node-runtime`.
- Includes GUI `node_modules`.
- Copies the USB package to `%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY`.
- Starts Broker and GUI from the local cache.
- Broker and GUI bind to `127.0.0.1` to reduce Windows Firewall prompts.
- Opens `http://localhost:3000`.

GUI-ready target preflight without starting GUI/Broker:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiReadyTargetPreflight.ps1 -Root E:\WindowsDoctor -NodeRuntimePath <PACKAGE_ROOT>\node-runtime -CacheRoot "$env:LOCALAPPDATA\WindowsDoctorPortable\GUIREADY" -Json
```

GUI-ready cache self-verify without copying:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiReadyCache.ps1 -UsbRoot <PACKAGE_ROOT> -CacheRoot "$env:LOCALAPPDATA\WindowsDoctorPortable\GUIREADY" -Json
```

GUI-ready cache self-repair from USB package:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiReadyCache.ps1 -UsbRoot <PACKAGE_ROOT> -CacheRoot "$env:LOCALAPPDATA\WindowsDoctorPortable\GUIREADY" -Repair -Json
```

GUI-ready cleanup launcher:
```text
<PACKAGE_ROOT>\Stop-WindowsDoctor-GUI-Ready.cmd
```

GUI-ready safety:
- Preflight checks free memory, cache write permission, ports `3000/3001`, bundled `node-runtime`, and PowerShell readiness.
- Cache self-repair only mirrors the USB package into `%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY`.
- Stop launcher only stops WindowsDoctor GUI dev workers and listeners on ports `3000/3001`.

NotebookLM direct API note:
- Google Pro access is suitable for NotebookLM web usage and source export/import workflows.
- Direct programmatic API integration requires NotebookLM Enterprise on Google Cloud with project number, location, IAM, and access token.
- Consumer NotebookLM direct connection is not used by WindowsDoctor.

Capture unknown or no-repair findings into learned KB and rebuild databases:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Capture-UnknownErrorToKB.ps1 -FromScan -IncludeNoRepairMatches -ReportPath E:\WindowsDoctor\logs\unknown-error-capture.latest.json -Json
```

Capture one manually supplied unknown error:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Capture-UnknownErrorToKB.ps1 -Title "未知 Windows 錯誤" -ErrorCode "0x00000000" -Description "診斷描述" -ReportPath E:\WindowsDoctor\logs\unknown-error-capture.latest.json -Json
```

Unknown-error capture safety:
- Writes only `knowledge_base\learned\LEARN-*.md`.
- Generated learned records use `Script: "N/A"`.
- Rebuilds and validates `offline_database\windowsdoctor-kb.json` and `offline_database\windowsdoctor-kb-normalized.json`.
- Does not update `scripts\repair-allowlist.json`.
- Does not execute repairs.

Validate normalized Windows repair KB schema v2:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.latest.json -Json
```

Update Microsoft official repair reference source pack:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Update-MicrosoftOfficialRepairSources.ps1 -ReportPath E:\WindowsDoctor\logs\microsoft-official-source-update.latest.json -Json
```

Microsoft official source update safety:
- Accepts only `learn.microsoft.com` and `support.microsoft.com` URLs.
- Adds public reference records with `sourceTrustLevel=microsoft_official`.
- Imports are diagnostic/reference only: `repairAllowed=false`, `script=N/A`, and no allowlist update.
- Rebuild normalized KB afterward with `Export-NormalizedKBDatabase.ps1`, then validate with `Test-NormalizedKBDatabase.ps1`.

External repair tool strategy:
```text
E:\WindowsDoctor\EXTERNAL_REPAIR_TOOLS_STRATEGY.md
```

External diagnostics source pack template:
```text
E:\WindowsDoctor\templates\EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE.json
```

Validate external diagnostics pack before import:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ExternalDiagnosticsPack.ps1 -InputPath <EXTERNAL_DIAGNOSTICS_PACK_JSON> -ReportPath E:\WindowsDoctor\logs\external-diagnostics-pack-validate.latest.json -Json
```

Import external diagnostics pack as diagnostic-only evidence:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Import-ExternalDiagnosticsPack.ps1 -InputPath <EXTERNAL_DIAGNOSTICS_PACK_JSON> -ReportPath E:\WindowsDoctor\logs\external-diagnostics-import.latest.json -Json
```

Convert official diagnostic logs into an external diagnostics pack:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Convert-OfficialDiagnosticsToExternalPack.ps1 -SetupDiagPath <SETUPDIAG_LOG_OR_JSON> -DismLogPath <DISM_LOG> -SfcLogPath <SFC_LOG> -GetHelpPath <GETHELP_OUTPUT> -OutputPath E:\WindowsDoctor\logs\official-diagnostics-pack.latest.json -ReportPath E:\WindowsDoctor\logs\official-diagnostics-pack.latest.report.json -Json
```

Official diagnostic sample logs:
```text
E:\WindowsDoctor\templates\SETUPDIAG_SAMPLE.log
E:\WindowsDoctor\templates\DISM_SAMPLE.log
E:\WindowsDoctor\templates\SFC_SAMPLE.log
E:\WindowsDoctor\templates\GETHELP_SAMPLE.log
```

Export safe Intune Remediations package without executing repairs:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-IntuneRemediationPackage.ps1 -OutputRoot E:\WindowsDoctor\releases\intune -PackageName WindowsDoctor-IntuneRemediations -ReportPath E:\WindowsDoctor\logs\intune-remediation-export.latest.json -Json
```

Validate Intune Remediations package:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-IntuneRemediationPackage.ps1 -PackageRoot E:\WindowsDoctor\releases\intune\WindowsDoctor-IntuneRemediations -ReportPath E:\WindowsDoctor\logs\intune-remediation-validate.latest.json -Json
```

External tool integration policy:
- Use Microsoft official diagnostics first where available.
- Import SetupDiag, Get Help command-line, DISM/SFC, Intune, Wazuh, or RMM outputs as evidence before creating repairs.
- Keep imported external findings diagnostic-only until reviewed.
- Do not add external findings to `scripts\repair-allowlist.json` automatically.
- Do not run reset, scrub, destructive repair, or third-party cleanup tools without explicit `RUN` confirmation.

Validate KB Markdown UTF-8 readability before export:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-KBMarkdownEncoding.ps1 -Json
```

Validate KB Markdown UTF-8 readability and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-KBMarkdownEncoding.ps1 -ReportPath E:\WindowsDoctor\logs\kb-markdown-encoding.latest.json -Json
```

Validate documentation sync against offline KB stats and safety commands:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationSync.ps1 -Json
```

Validate documentation sync and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json
```

Validate documentation memory system:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationMemorySystem.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -Json
```

Validate the full WinPE/offline flow without starting services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-WinPEOfflineFlow.ps1 -Json
```

Validate the full WinPE/offline flow and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-WinPEOfflineFlow.ps1 -ReportPath E:\WindowsDoctor\logs\winpe-offline-flow.latest.json -Json
```

Validate portable USB readiness without writing USB or ISO:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbReadiness.ps1 -Json
```

Validate portable USB readiness and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbReadiness.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-readiness.latest.json -Json
```

Create portable USB payload folder without writing USB or ISO:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-PortableUsbPayload.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-payload.latest.json -Json
```

Validate a portable USB payload folder:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbPayload.ps1 -PackageRoot <PACKAGE_ROOT> -ReportPath E:\WindowsDoctor\logs\portable-usb-payload-validate.latest.json -Json
```

Validate a published portable USB release package from its expanded package root:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableUsbReleaseValidation.ps1 -PackageRoot <PACKAGE_ROOT> -ReportPath E:\WindowsDoctor\logs\portable-usb-release-validation.latest.json -Json
```

This release validation runs payload validation, portable runtime self-test, and one-click recommended repair preview. It does not execute repairs.

Publish portable USB by zip-copy-expand flow:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Publish-PortableUsbPackage.ps1 -USBPath F:\ -ReportPath E:\WindowsDoctor\logs\portable-usb-publish.latest.json -Json
```

Generate USB multi-package selector/status page without publishing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-UsbPackageSelectorPage.ps1 -UsbRoot G:\ -OutputPath G:\START_HERE.html -ReportPath E:\WindowsDoctor\logs\usb-selector-g.latest.json -Json
```

Patch an existing GUI-ready USB package with the latest preflight/cache/stop launchers:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Sync-GuiReadyUsbPatch.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260503 -ReportPath E:\WindowsDoctor\logs\gui-ready-usb-patch.latest.json -Json
```

Selector/status page behavior:
- Scans USB root package folders that contain `WindowsDoctor`.
- Shows package status, entry launchers, `Stop-WindowsDoctor-GUI-Ready.cmd`, and WinPE `sources\boot.wim` status.
- Writes only `START_HERE.html` and a JSON report.

Scan local system errors and network diagnostics without repairing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SystemErrorScan.ps1 -ReportPath E:\WindowsDoctor\logs\system-error-scan.latest.json -Json
```
The scan output includes `KbMatches` from `offline_database\windowsdoctor-kb.json`; it remains diagnostic-only and does not run repairs.
Compatibility wrappers for stale or misspelled scan entrypoints:
- `scripts\Test-SystemErroeScan.ps1`
- `scripts\Test-SystemErrorsScan.ps1`

Run portable runtime self-test without repairing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableRuntimeSelfTest.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-self-test.latest.json -Json
```

Show portable runtime version and status summary without repairing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Get-PortableRuntimeStatus.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-status.latest.json -Json
```

Preview one-click recommended repair plan without repairing:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-RecommendedRepairPlan.ps1 -ReportPath E:\WindowsDoctor\logs\recommended-repair-plan.latest.json -Json
```

Broker one-click repair plan API:
```text
GET  http://localhost:3001/api/repair-plan
POST http://localhost:3001/api/repair-plan/execute
```

Broker work window API:
```text
GET  http://localhost:3001/api/work/status
POST http://localhost:3001/api/work/cancel
POST http://localhost:3001/api/work/repair-plan
```

`/api/work/repair-plan` runs repair preview or RUN-gated execution as a single active work item, records resource snapshots, and supports operator cancellation.

Broker local AI triage API:
```text
GET  http://localhost:3001/api/ai/triage
```

The local AI triage uses WindowsDoctor reviewed KB rules, recent system events, repair decision engine output, and resource safety. It does not call external AI services and does not execute repairs.

Natural-language issue plan API:
```text
POST http://localhost:3001/api/ai/plan
POST http://localhost:3001/api/work/diagnose
```

Request body:
```json
{ "problemText": "印表機不能列印，佇列卡住" }
```

This workflow classifies the user problem, matches KB rules, builds a repair preview, applies auto-repair safety policy, writes a user-readable report, and does not execute repair actions.

Read-only specialized diagnostics:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-SpecializedIssueDiagnostics.ps1 -Root E:\WindowsDoctor -Component printer -ReportPath E:\WindowsDoctor\logs\specialized-diagnostics.printer.latest.json -Json
```

Supported components: `printer`, `windows_update`, `network`, `boot`, `performance`, `hardware`, `system_integrity`, `general`. The script is diagnostic-only and does not repair Windows state.

Execution request body:
```json
{ "confirmToken": "RUN" }
```

GUI one-click repair panel:
- The GUI calls `/api/repair-plan` for preview.
- The AI problem solver panel calls `/api/ai/plan` for immediate preview and `/api/work/diagnose` for sequenced work-window execution.
- Execution stays disabled unless the operator enters `RUN`.
- Broker delegates to `Invoke-RecommendedRepairPlan.ps1`, so SafeBatch v4 policy is enforced server-side.

Recommended repair plan v4 fields:
- `RepairPlanVersion=4`
- `DecisionEngineVersion=4`
- `Confidence` uses a `0-100` scale.
- `RiskLevel` is `low`, `medium`, or `manual_review`.
- `Priority` is `first`, `normal`, `later`, or `manual`.
- `RecommendationState=recommended` is required before any item can enter the safe batch.
- `RepairDecisionState=auto_repair_allowed` is required before any item can enter the safe batch.
- PASS-only diagnostic matches are kept as `ObservationRecommendations` and are not executed by the default batch.
- `AutoRepairSafety` explains reversibility, dry-run impact, local validation, critical interruption risk, rollback guidance, allowlist review, and block reasons.
- `SafeBatchExecutionPolicy.StopOnFirstFailure=true`.
- `SafeBatchExecutionPolicy.ExecuteRequires=-Execute -ConfirmToken RUN`.

Execute one-click low-risk repairs only after explicit confirmation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-RecommendedRepairPlan.ps1 -Execute -ConfirmToken RUN -ReportPath E:\WindowsDoctor\logs\recommended-repair-execute.latest.json -Json
```

One-click repair safety:
- Preview is the default.
- Execution requires `-Execute -ConfirmToken RUN`.
- Auto batch requires `scripts\repair-safety-policy.json` approval.
- Current approved auto-batch candidate is `Repair-WDReportCache.bat` only; it moves WindowsDoctor report cache data and writes rollback guidance.
- Existing allowlisted scripts remain preview/manual unless they pass reversibility, dry-run impact, local evidence, no critical interruption, rollback guidance, allowlist review, and RUN gate checks.
- Safe batch execution stops on the first failed repair.
- Default batch execution excludes BCD/boot repair, system integrity repair, and maintenance cleanup; those remain manual-review recommendations.
- The menu option `11` previews first and asks for `RUN` before execution.

USB publishing rule:
- Always create a zip first, copy the zip to USB, then expand it on USB.
- Do not copy thousands of individual files directly to USB.
- Default publish excludes `node_modules` and `gui\.next`; include GUI dependencies only with `-IncludeNodeModules`.

Search WinPE offline KB without Broker:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -Query 0x80070035
```

Search WinPE offline KB JSON:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -Query 0x80070035 -Json
```

Search WinPE offline KB and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -Query 0x80070035 -ReportPath E:\WindowsDoctor\logs\offline-kb-search.latest.json -Json
```

Search Windows maintenance in the offline KB:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -Query SYSTEM_MAINTENANCE -Json
```

List WinPE offline KB categories:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -ListCategories -Json
```

List WinPE offline KB categories and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -ListCategories -ReportPath E:\WindowsDoctor\logs\offline-kb-categories.latest.json -Json
```

Show one WinPE offline KB rule:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Search-OfflineKB.ps1 -RuleId RULE-SMB-0x0035 -Json
```

Start WinPE text menu without GUI/Broker:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1
```

List allowlisted repair scripts without executing them:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -List -Json
```

List allowlisted repair scripts and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -List -ReportPath E:\WindowsDoctor\logs\allowed-repair-list.latest.json -Json
```

Preview an allowlisted repair script without executing it:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -ScriptName Repair-NetworkStack.bat -Preview -Json
```

Preview an allowlisted repair script and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -ScriptName Repair-NetworkStack.bat -Preview -ReportPath E:\WindowsDoctor\logs\allowed-repair-preview.latest.json -Json
```

Preview Windows maintenance actions without executing them:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-WindowsMaintenance.ps1 -Preview -ForceLogoffDisconnectedUsers -CleanDisk -ReleaseMemory -SystemMaintenance -Json
```

Preview Windows maintenance and write a JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-WindowsMaintenance.ps1 -Preview -CleanDisk -ReleaseMemory -ReportPath E:\WindowsDoctor\logs\windows-maintenance.preview.json -Json
```

Execute Windows maintenance only after explicit confirmation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-WindowsMaintenance.ps1 -Execute -ConfirmToken RUN -ForceLogoffDisconnectedUsers -CleanDisk -ReleaseMemory -SystemMaintenance
```

Windows maintenance safety:
- `-ForceLogoffDisconnectedUsers` targets disconnected sessions only, never the current session.
- `-MinIdleMinutes` defaults to `30`.
- `-CleanDisk` removes temp files older than `24` hours and clears Recycle Bin only in execute mode.
- `-SystemMaintenance` runs `DISM /ScanHealth`, `sfc /verifyonly`, and `chkdsk C: /scan` only in execute mode.
- `Repair-SystemMaintenance.bat` is an allowlisted preview entry; direct execution of destructive maintenance still requires `Invoke-WindowsMaintenance.ps1 -Execute -ConfirmToken RUN`.

Validate Windows resource organizer capability without executing cleanup:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-WindowsResourceOrganizerCapability.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\windows-resource-organizer-capability.latest.json -Json
```

Resource organizer policy:
- Domain/session logoff, disk cleanup, Windows Update cache cleanup, forced uninstall, leftover directory removal, browser cache cleanup, and registry cleanup are state-changing maintenance actions.
- These actions must stay preview-first and RUN-gated.
- GitHub/community cleaner logic may be recorded as reference only; it must not be copied into formal execution until reviewed, locally validated, rollback documented, and allowlisted.

Management system readiness:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ManagementSystemReadiness.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\management-system-readiness.latest.json -Json
```

Management system policy:
- Roles: `viewer`, `operator`, `admin`, `maintainer`.
- Admin account tokens are stored as PBKDF2-SHA256 hashes only.
- Audit events are append-only JSONL records.
- NAS is optional; local and USB operation remain supported without NAS.
- RUN-gated repair, cleanup, logoff, uninstall, USB write, and policy changes require the appropriate role and still require explicit `RUN` when state-changing.

Execute an allowlisted repair script only after explicit confirmation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -ScriptName Repair-NetworkStack.bat -Execute -ConfirmToken RUN
```

WinPE menu wrapper for repair preview:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -Json
```

WinPE menu wrapper for repair list report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -ListAllowedRepairs -ReportPath E:\WindowsDoctor\logs\winpe-menu-repairs.latest.json -Json
```

WinPE menu wrapper for repair preview report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -ReportPath E:\WindowsDoctor\logs\winpe-menu-preview.latest.json -Json
```

WinPE offline KB contents:
- `knowledge_base\reviewed`
- `knowledge_base\learned`
- `offline_database\windowsdoctor-kb.json`
- `scripts\repair-allowlist.json`
- allowlisted `scripts\Repair-*.bat`

WinPE Broker offline DB mode:
- `Build-WinPEMedia.ps1` sets `WD_USE_OFFLINE_DB=1`.
- Default `StartupMode` is `Menu`, which launches `scripts\Start-WinPEOfflineMenu.ps1` without GUI/Broker.
- Use `-StartupMode Broker` only when WinPE should start `gui\broker.js`.
- Broker reads `offline_database\windowsdoctor-kb.json` instead of scanning Markdown at runtime.
- Local default remains Markdown mode unless `WD_USE_OFFLINE_DB=1` is set.

Low-risk GUI smoke. This does not start services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline
```

Low-risk GUI smoke report. This does not start services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline -ReportPath E:\WindowsDoctor\logs\gui-smoke-offline.latest.json -Json
```

## 4. Individual Checks
```powershell
npm run lint --prefix E:\WindowsDoctor\gui
npm run build --prefix E:\WindowsDoctor\gui
npm run test:broker --prefix E:\WindowsDoctor\gui
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path E:\WindowsDoctor\core\WindowsDoctor.Tests.ps1"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-BrokerSmoke.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-VersionPolicy.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly
```

Version policy JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-VersionPolicy.ps1 -ReportPath E:\WindowsDoctor\logs\version-policy.latest.json -Json
```

## 5. Ports
- GUI: `http://localhost:3000`
- Broker: `http://localhost:3001`

## 6. WinPE Preflight
Run before creating ISO or USB media:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly
```

Machine-readable preflight report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly -ReportPath E:\WindowsDoctor\logs\winpe-media-checkonly.latest.json -Json
```
