param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$SourceRoot = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")
$resolvedSourceRoot = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd("\")
$targetWdRoot = Join-Path $resolvedPackageRoot "WindowsDoctor"
$targetScripts = Join-Path $targetWdRoot "scripts"

if (-not (Test-Path -LiteralPath $targetWdRoot)) {
    throw "Target WindowsDoctor root not found: $targetWdRoot"
}
if (-not (Test-Path -LiteralPath $targetScripts)) {
    throw "Target scripts directory not found: $targetScripts"
}

$scriptNames = @(
    "Test-GuiReadyTargetPreflight.ps1",
    "Test-GuiReadyCache.ps1",
    "Test-ResourceSafety.ps1",
    "Stop-GuiReadySession.ps1",
    "Stop-WindowsDoctorServices.ps1",
    "Start-WindowsDoctor.ps1",
    "Test-LowResourceStartup.ps1",
    "New-UsbPackageSelectorPage.ps1",
    "Invoke-WDSequentialTaskQueue.ps1",
    "Invoke-RecommendedRepairPlan.ps1",
    "Test-PortableUsbPayload.ps1",
    "Test-PortableRuntimeSelfTest.ps1",
    "Test-PortableUsbReleaseValidation.ps1",
    "Test-PortableUsbZipManifest.ps1",
    "New-PortableIncrementalPatch.ps1",
    "Test-PortableIncrementalPatch.ps1",
    "Test-UsbLowResourceEntry.ps1",
    "Test-UsbLowResourceAcceptance.ps1",
    "Invoke-PortableUsbAcceptance.ps1",
    "Publish-PortableUsbPackage.ps1",
    "Test-DocumentationSync.ps1",
    "Add-TaskCompletionRecord.ps1",
    "Test-DocumentationMemorySystem.ps1",
    "Test-RepairCoverageGoal.ps1",
    "Test-AutoRepairSafetyPolicy.ps1",
    "Test-SpecializedIssueDiagnostics.ps1",
    "Test-WindowsResourceOrganizerCapability.ps1",
    "Test-ManagementSystemReadiness.ps1",
    "Analyze-WindowsEventLogs.ps1",
    "Test-RepairToolPackageManifest.ps1",
    "New-RepairToolPackage.ps1",
    "Save-OfflineRepairTools.ps1",
    "Test-OfflineToolAutomation.ps1",
    "Test-OfflineDiagnosticRunnerSkill.ps1",
    "Test-OfflineDiagnosticNaturalLanguageBatch.ps1",
    "Invoke-OfflineDiagnosticTools.ps1",
    "Convert-OfflineDiagnosticToolOutput.ps1",
    "New-OfflineDiagnosticUserReport.ps1",
    "Update-MicrosoftOfficialRepairSources.ps1",
    "Export-NormalizedKBDatabase.ps1",
    "Test-NormalizedKBDatabase.ps1",
    "Test-RealDataImportReadiness.ps1",
    "Test-TaskHandoffArchiveReadiness.ps1",
    "Watch-WDResourceSafety.ps1"
)

foreach ($scriptName in $scriptNames) {
    $source = Join-Path (Join-Path $resolvedSourceRoot "scripts") $scriptName
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source script not found: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $targetScripts $scriptName) -Force
}

$scriptDataFiles = @(
    "repair-allowlist.json",
    "repair-safety-policy.json"
)

foreach ($scriptDataFile in $scriptDataFiles) {
    $source = Join-Path (Join-Path $resolvedSourceRoot "scripts") $scriptDataFile
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source script data file not found: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $targetScripts $scriptDataFile) -Force
}

$repairScriptFiles = @(
    "Repair-BCDBoot.bat",
    "Repair-NetworkStack.bat",
    "Repair-Services.bat",
    "Repair-SystemIntegrity.bat",
    "Repair-SystemMaintenance.bat",
    "Repair-WDReportCache.bat",
    "Repair-WUSoftwareDistribution.bat"
)

foreach ($repairScriptFile in $repairScriptFiles) {
    $source = Join-Path (Join-Path $resolvedSourceRoot "scripts") $repairScriptFile
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source repair script not found: $source"
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $targetScripts $repairScriptFile) -Force
}

$relativeFiles = @(
    "gui\broker\routes.js",
    "gui\broker\services\admin.js",
    "gui\broker\services\aiAssistant.js",
    "gui\broker\services\eventLogAnalyzer.js",
    "gui\broker\services\issuePlanner.js",
    "gui\broker\services\offlineTools.js",
    "gui\broker\services\repairPlan.js",
    "gui\broker\services\work.js",
    "gui\broker\tests\services.test.js",
    "gui\src\app\page.tsx",
    "gui\src\components\AiAssistantPanel.tsx",
    "gui\src\components\EventLogAnalysisPanel.tsx",
    "gui\src\components\OneClickRepairPanel.tsx",
    "gui\src\components\ProblemSolverPanel.tsx",
    "gui\src\components\SettingsPanel.tsx",
    "gui\src\components\WorkStatusPanel.tsx",
    "gui\src\lib\windowsDoctorApi.ts",
    "gui\src\types\windows-doctor.ts",
    "templates\REPAIR_TOOL_PACKAGE_MANIFEST.template.json"
)

foreach ($relativeFile in $relativeFiles) {
    $source = Join-Path $resolvedSourceRoot $relativeFile
    $target = Join-Path $targetWdRoot $relativeFile
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source GUI file not found: $source"
    }
    $targetParent = Split-Path -Parent $target
    if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
}

$rootFiles = @(
    "INDEX.md",
    "DOCUMENTATION_ARCHITECTURE.md",
    "DOCS_ARCHITECTURE_AUDIT.md",
    "MEMORY_SYSTEM.md",
    "TASK_COMPLETION_LOG.md",
    "AUTO_REPAIR_SAFETY_POLICY.md",
    "WINDOWS_RESOURCE_ORGANIZER_PLAN.md",
    "MANAGEMENT_SYSTEM.md",
    "EVENT_LOG_ANALYSIS.md",
    "REPAIR_TOOL_PACKAGING_POLICY.md",
    "REPAIR_COVERAGE_ROADMAP.md",
    "THIRD_PARTY_REPAIR_REFERENCE.md",
    "PERFORMANCE_POLICY.md",
    "OPERATIONS.md",
    "SECURITY_POLICY.md",
    "TASK_HANDOFF.md",
    "NEXT_CHAT_PROMPT.md",
    "COMMON_WINDOWS_ERRORS.md",
    "SUCCESS_EXPERIENCE.md",
    "SYSTEM_ERROR_HISTORY.md",
    "EXTERNAL_REPAIR_TOOLS_STRATEGY.md"
)

foreach ($rootFile in $rootFiles) {
    $source = Join-Path $resolvedSourceRoot $rootFile
    $target = Join-Path $targetWdRoot $rootFile
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$skillFiles = @(
    "skills\windowsdoctor-documentation-system\SKILL.md",
    "skills\windowsdoctor-offline-diagnostic-runner\SKILL.md"
)

foreach ($skillFile in $skillFiles) {
    $source = Join-Path $resolvedSourceRoot $skillFile
    $target = Join-Path $targetWdRoot $skillFile
    if (Test-Path -LiteralPath $source) {
        $targetParent = Split-Path -Parent $target
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
            New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$docFiles = @(
    "docs\WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html",
    "docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html"
)

foreach ($docFile in $docFiles) {
    $source = Join-Path $resolvedSourceRoot $docFile
    $target = Join-Path $targetWdRoot $docFile
    if (Test-Path -LiteralPath $source) {
        $targetParent = Split-Path -Parent $target
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
            New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$databaseFiles = @(
    "offline_database\known-windows-repair-sources.json",
    "offline_database\windowsdoctor-kb-normalized.json",
    "offline_database\windowsdoctor-kb.json"
)

foreach ($databaseFile in $databaseFiles) {
    $source = Join-Path $resolvedSourceRoot $databaseFile
    $target = Join-Path $targetWdRoot $databaseFile
    if (Test-Path -LiteralPath $source) {
        $targetParent = Split-Path -Parent $target
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
            New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
        }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$knowledgeBaseFiles = @(
    "knowledge_base\reviewed\RULE-WD-REPORT-CACHE.md"
)

foreach ($knowledgeBaseFile in $knowledgeBaseFiles) {
    $source = Join-Path $resolvedSourceRoot $knowledgeBaseFile
    $target = Join-Path $targetWdRoot $knowledgeBaseFile
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source KB file not found: $source"
    }
    $targetParent = Split-Path -Parent $target
    if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
}

$managementFiles = @(
    "nas\windowsdoctor-management-profile.json"
)

foreach ($managementFile in $managementFiles) {
    $source = Join-Path $resolvedSourceRoot $managementFile
    $target = Join-Path $targetWdRoot $managementFile
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Source management file not found: $source"
    }
    $targetParent = Split-Path -Parent $target
    if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
}

$startLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_USB_ROOT=%~dp0"
set "WD_CACHE_ROOT=%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY"
set "WD_CACHE_NODE=%WD_CACHE_ROOT%\node-runtime"
set "WD_CACHE_APP=%WD_CACHE_ROOT%\WindowsDoctor"
echo [WindowsDoctor] Running GUI-ready preflight...
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_USB_ROOT%WindowsDoctor\scripts\Test-GuiReadyTargetPreflight.ps1" -Root "%WD_USB_ROOT%WindowsDoctor" -NodeRuntimePath "%WD_USB_ROOT%node-runtime" -CacheRoot "%WD_CACHE_ROOT%"
if errorlevel 1 (
  echo [WindowsDoctor] GUI-ready preflight failed.
  pause
  exit /b 1
)
echo [WindowsDoctor] Preparing local GUI cache...
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_USB_ROOT%WindowsDoctor\scripts\Test-GuiReadyCache.ps1" -UsbRoot "%WD_USB_ROOT%" -CacheRoot "%WD_CACHE_ROOT%" -Repair
if errorlevel 1 (
  echo [WindowsDoctor] GUI-ready cache verification failed.
  pause
  exit /b 1
)
set "PATH=%WD_CACHE_NODE%;%PATH%"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_CACHE_APP%" -RestartBroker -RestartGui -SkipBuild -Hidden
if errorlevel 1 (
  echo [WindowsDoctor] GUI startup failed.
  pause
  exit /b 1
)
start "" "http://localhost:3000"
endlocal
'@

$stopLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_CACHE_ROOT=%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY"
set "WD_CACHE_APP=%WD_CACHE_ROOT%\WindowsDoctor"
if exist "%WD_CACHE_APP%\scripts\Stop-WDGuiDevWorkers.ps1" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Stop-WDGuiDevWorkers.ps1" -IncludeDevServer
)
if exist "%WD_CACHE_APP%\scripts\Stop-GuiReadySession.ps1" (
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_CACHE_APP%\scripts\Stop-GuiReadySession.ps1" -Root "%WD_CACHE_APP%"
)
endlocal
'@

$lowResourceLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_USB_ROOT=%~dp0"
set "WD_APP=%WD_USB_ROOT%WindowsDoctor"
powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "%WD_APP%\scripts\Start-WindowsDoctor.ps1" -Root "%WD_APP%" -RestartBroker -NoGui -SkipBuild -Hidden -MaxGuiNodeProcesses 4 -MaxWindowsDoctorTotalWorkingSetMB 512 -MaxWindowsDoctorProcessWorkingSetMB 256 -NodeMaxOldSpaceSizeMB 192 -ProcessPriority BelowNormal
if errorlevel 1 (
  echo [WindowsDoctor] Low-resource startup failed.
  pause
  exit /b 1
)
start "" "%WD_APP%\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html"
endlocal
'@

$lowResourceSilentLauncher = @'
Option Explicit
Dim shell, fso, root, appRoot, command
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
appRoot = root & "\WindowsDoctor"
command = "powershell -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File """ & appRoot & "\scripts\Start-WindowsDoctor.ps1"" -Root """ & appRoot & """ -RestartBroker -NoGui -SkipBuild -Hidden -MaxGuiNodeProcesses 4 -MaxWindowsDoctorTotalWorkingSetMB 512 -MaxWindowsDoctorProcessWorkingSetMB 256 -NodeMaxOldSpaceSizeMB 192 -ProcessPriority BelowNormal"
shell.Run command, 0, True
shell.Run """" & appRoot & "\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html""", 1, False
'@

$lowResourceStopLauncher = @'
@echo off
chcp 65001 > nul
setlocal
set "WD_USB_ROOT=%~dp0"
set "WD_APP=%WD_USB_ROOT%WindowsDoctor"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%WD_APP%\scripts\Stop-WindowsDoctorServices.ps1" -Root "%WD_APP%"
endlocal
'@

$startPath = Join-Path $resolvedPackageRoot "Start-WindowsDoctor-GUI-Ready.cmd"
$stopPath = Join-Path $resolvedPackageRoot "Stop-WindowsDoctor-GUI-Ready.cmd"
$lowResourcePath = Join-Path $resolvedPackageRoot "Start-WindowsDoctor-LowResource.cmd"
$lowResourceSilentPath = Join-Path $resolvedPackageRoot "Start-WindowsDoctor-LowResource-Silent.vbs"
$lowResourceStopPath = Join-Path $resolvedPackageRoot "Stop-WindowsDoctor-LowResource.cmd"
[System.IO.File]::WriteAllText($startPath, $startLauncher, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($stopPath, $stopLauncher, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($lowResourcePath, $lowResourceLauncher, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($lowResourceSilentPath, $lowResourceSilentLauncher, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($lowResourceStopPath, $lowResourceStopLauncher, [System.Text.UTF8Encoding]::new($false))

$manifestPath = Join-Path $resolvedPackageRoot "portable-usb-manifest.json"
$targetFiles = @(Get-ChildItem -LiteralPath $resolvedPackageRoot -Recurse -Force -File)
$targetBytes = [int64]0
foreach ($file in $targetFiles) { $targetBytes += [int64]$file.Length }
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    $manifest.PackageRoot = $resolvedPackageRoot
    $manifest.WindowsDoctorRoot = $targetWdRoot
    $manifest.NodeRuntimePath = Join-Path $resolvedPackageRoot "node-runtime"
    $manifest.FileCount = $targetFiles.Count
    $manifest.Bytes = $targetBytes
    $manifest.ReportPath = $ReportPath
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
}

$result = [PSCustomObject]@{
    Status = "PASS"
    PackageRoot = $resolvedPackageRoot
    UpdatedScripts = $scriptNames
    UpdatedScriptDataFiles = $scriptDataFiles
    UpdatedRepairScriptFiles = $repairScriptFiles
    UpdatedGuiFiles = $relativeFiles
    UpdatedRootFiles = $rootFiles
    UpdatedSkillFiles = $skillFiles
    UpdatedDocFiles = $docFiles
    UpdatedDatabaseFiles = $databaseFiles
    UpdatedKnowledgeBaseFiles = $knowledgeBaseFiles
    UpdatedManagementFiles = $managementFiles
    StartLauncher = $startPath
    StopLauncher = $stopPath
    LowResourceLauncher = $lowResourcePath
    LowResourceSilentLauncher = $lowResourceSilentPath
    LowResourceStopLauncher = $lowResourceStopPath
    ManifestPath = $manifestPath
    FileCount = $targetFiles.Count
    Bytes = $targetBytes
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 6
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}
