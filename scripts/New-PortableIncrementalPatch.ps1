param(
    [string]$PackageRoot = "E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3",
    [string]$OutputRoot = "E:\WindowsDoctor\releases\portable-usb\incremental-patches",
    [string]$PatchName = "",
    [string]$ReportPath = "",
    [switch]$NoZip,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-Sha256Hex {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $bytes = $sha.ComputeHash($stream)
        return ([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function Assert-ChildPath {
    param(
        [string]$Parent,
        [string]$Child
    )
    $parentFull = [System.IO.Path]::GetFullPath($Parent).TrimEnd("\") + "\"
    $childFull = [System.IO.Path]::GetFullPath($Child)
    if (-not $childFull.StartsWith($parentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path outside output root: $childFull"
    }
}

$resolvedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")

if (-not (Test-Path -LiteralPath $resolvedPackageRoot)) {
    throw "PackageRoot not found: $PackageRoot"
}

if (-not $PatchName) {
    $PatchName = "$(Split-Path -Leaf $resolvedPackageRoot)-IncrementalPatch-$(Get-Date -Format yyyyMMdd-HHmmss)"
}

$patchRoot = Join-Path $resolvedOutputRoot $PatchName
$zipPath = "$patchRoot.zip"

if (Test-Path -LiteralPath $patchRoot) {
    Assert-ChildPath -Parent $resolvedOutputRoot -Child $patchRoot
    Remove-Item -LiteralPath $patchRoot -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Assert-ChildPath -Parent $resolvedOutputRoot -Child $zipPath
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -Path $patchRoot -ItemType Directory -Force | Out-Null

$relativePaths = @(
    "Start-WindowsDoctor-GUI-Ready.cmd",
    "Stop-WindowsDoctor-GUI-Ready.cmd",
    "Start-WindowsDoctor-LowResource.cmd",
    "Start-WindowsDoctor-LowResource-Silent.vbs",
    "Stop-WindowsDoctor-LowResource.cmd",
    "WindowsDoctor\INDEX.md",
    "WindowsDoctor\DOCUMENTATION_ARCHITECTURE.md",
    "WindowsDoctor\DOCS_ARCHITECTURE_AUDIT.md",
    "WindowsDoctor\MEMORY_SYSTEM.md",
    "WindowsDoctor\TASK_COMPLETION_LOG.md",
    "WindowsDoctor\AUTO_REPAIR_SAFETY_POLICY.md",
    "WindowsDoctor\WINDOWS_RESOURCE_ORGANIZER_PLAN.md",
    "WindowsDoctor\MANAGEMENT_SYSTEM.md",
    "WindowsDoctor\EVENT_LOG_ANALYSIS.md",
    "WindowsDoctor\REPAIR_TOOL_PACKAGING_POLICY.md",
    "WindowsDoctor\REPAIR_COVERAGE_ROADMAP.md",
    "WindowsDoctor\THIRD_PARTY_REPAIR_REFERENCE.md",
    "WindowsDoctor\PERFORMANCE_POLICY.md",
    "WindowsDoctor\OPERATIONS.md",
    "WindowsDoctor\SECURITY_POLICY.md",
    "WindowsDoctor\TASK_HANDOFF.md",
    "WindowsDoctor\NEXT_CHAT_PROMPT.md",
    "WindowsDoctor\COMMON_WINDOWS_ERRORS.md",
    "WindowsDoctor\SYSTEM_ERROR_HISTORY.md",
    "WindowsDoctor\EXTERNAL_REPAIR_TOOLS_STRATEGY.md",
    "WindowsDoctor\offline_database\known-windows-repair-sources.json",
    "WindowsDoctor\offline_database\windowsdoctor-kb-normalized.json",
    "WindowsDoctor\offline_database\windowsdoctor-kb.json",
    "WindowsDoctor\skills\windowsdoctor-documentation-system\SKILL.md",
    "WindowsDoctor\docs\WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html",
    "WindowsDoctor\docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html",
    "WindowsDoctor\scripts\Test-GuiReadyTargetPreflight.ps1",
    "WindowsDoctor\scripts\Test-GuiReadyCache.ps1",
    "WindowsDoctor\scripts\Test-ResourceSafety.ps1",
    "WindowsDoctor\scripts\Stop-GuiReadySession.ps1",
    "WindowsDoctor\scripts\Stop-WindowsDoctorServices.ps1",
    "WindowsDoctor\scripts\Start-WindowsDoctor.ps1",
    "WindowsDoctor\scripts\Test-LowResourceStartup.ps1",
    "WindowsDoctor\scripts\New-UsbPackageSelectorPage.ps1",
    "WindowsDoctor\scripts\Invoke-WDSequentialTaskQueue.ps1",
    "WindowsDoctor\scripts\Invoke-RecommendedRepairPlan.ps1",
    "WindowsDoctor\scripts\repair-safety-policy.json",
    "WindowsDoctor\scripts\repair-allowlist.json",
    "WindowsDoctor\scripts\Repair-WDReportCache.bat",
    "WindowsDoctor\scripts\Test-PortableUsbPayload.ps1",
    "WindowsDoctor\scripts\Test-PortableRuntimeSelfTest.ps1",
    "WindowsDoctor\scripts\Test-PortableUsbReleaseValidation.ps1",
    "WindowsDoctor\scripts\Test-PortableUsbZipManifest.ps1",
    "WindowsDoctor\scripts\Invoke-PortableUsbAcceptance.ps1",
    "WindowsDoctor\scripts\Test-UsbLowResourceEntry.ps1",
    "WindowsDoctor\scripts\Test-UsbLowResourceAcceptance.ps1",
    "WindowsDoctor\scripts\Publish-PortableUsbPackage.ps1",
    "WindowsDoctor\scripts\Test-DocumentationSync.ps1",
    "WindowsDoctor\scripts\Add-TaskCompletionRecord.ps1",
    "WindowsDoctor\scripts\Test-DocumentationMemorySystem.ps1",
    "WindowsDoctor\scripts\Test-RepairCoverageGoal.ps1",
    "WindowsDoctor\scripts\Test-AutoRepairSafetyPolicy.ps1",
    "WindowsDoctor\scripts\Test-SpecializedIssueDiagnostics.ps1",
    "WindowsDoctor\scripts\Test-WindowsResourceOrganizerCapability.ps1",
    "WindowsDoctor\scripts\Test-ManagementSystemReadiness.ps1",
    "WindowsDoctor\scripts\Analyze-WindowsEventLogs.ps1",
    "WindowsDoctor\scripts\Test-RepairToolPackageManifest.ps1",
    "WindowsDoctor\scripts\New-RepairToolPackage.ps1",
    "WindowsDoctor\scripts\Save-OfflineRepairTools.ps1",
    "WindowsDoctor\scripts\Update-MicrosoftOfficialRepairSources.ps1",
    "WindowsDoctor\scripts\Export-NormalizedKBDatabase.ps1",
    "WindowsDoctor\scripts\Test-NormalizedKBDatabase.ps1",
    "WindowsDoctor\scripts\Test-RealDataImportReadiness.ps1",
    "WindowsDoctor\scripts\Test-TaskHandoffArchiveReadiness.ps1",
    "WindowsDoctor\scripts\Watch-WDResourceSafety.ps1",
    "WindowsDoctor\gui\broker\routes.js",
    "WindowsDoctor\gui\broker\services\admin.js",
    "WindowsDoctor\gui\broker\services\aiAssistant.js",
    "WindowsDoctor\gui\broker\services\eventLogAnalyzer.js",
    "WindowsDoctor\gui\broker\services\issuePlanner.js",
    "WindowsDoctor\gui\broker\services\repairPlan.js",
    "WindowsDoctor\gui\broker\services\work.js",
    "WindowsDoctor\gui\broker\tests\services.test.js",
    "WindowsDoctor\gui\src\app\page.tsx",
    "WindowsDoctor\gui\src\components\AiAssistantPanel.tsx",
    "WindowsDoctor\gui\src\components\EventLogAnalysisPanel.tsx",
    "WindowsDoctor\gui\src\components\OneClickRepairPanel.tsx",
    "WindowsDoctor\gui\src\components\ProblemSolverPanel.tsx",
    "WindowsDoctor\gui\src\components\SettingsPanel.tsx",
    "WindowsDoctor\gui\src\components\WorkStatusPanel.tsx",
    "WindowsDoctor\gui\src\lib\windowsDoctorApi.ts",
    "WindowsDoctor\gui\src\types\windows-doctor.ts",
    "WindowsDoctor\templates\REPAIR_TOOL_PACKAGE_MANIFEST.template.json",
    "WindowsDoctor\knowledge_base\reviewed\RULE-WD-REPORT-CACHE.md",
    "WindowsDoctor\nas\windowsdoctor-management-profile.json"
)

$entries = New-Object System.Collections.Generic.List[object]
$missing = New-Object System.Collections.Generic.List[string]
$totalBytes = [int64]0

foreach ($relativePath in $relativePaths) {
    $source = Join-Path $resolvedPackageRoot $relativePath
    if (-not (Test-Path -LiteralPath $source)) {
        $missing.Add($relativePath)
        continue
    }

    $target = Join-Path $patchRoot $relativePath
    $targetParent = Split-Path -Parent $target
    if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -Path $targetParent -ItemType Directory -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force

    $item = Get-Item -LiteralPath $target
    $totalBytes += [int64]$item.Length
    $entries.Add([PSCustomObject]@{
        Path = $relativePath
        Bytes = [int64]$item.Length
        Sha256 = Get-Sha256Hex -Path $target
    })
}

$manifest = [PSCustomObject]@{
    Status = "PASS"
    Phase = "portable-usb-incremental-patch"
    PackageRoot = $resolvedPackageRoot
    PatchRoot = $patchRoot
    ZipPath = if ($NoZip) { "" } else { $zipPath }
    FileCount = $entries.Count
    Bytes = $totalBytes
    MissingCount = $missing.Count
    Missing = $missing.ToArray()
    Entries = $entries.ToArray()
    CreatedAt = (Get-Date).ToString("o")
}

$manifestPath = Join-Path $patchRoot "incremental-patch-manifest.json"
[System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))

if (-not $NoZip) {
    Compress-Archive -Path (Join-Path $patchRoot "*") -DestinationPath $zipPath -CompressionLevel Fastest -Force
}

$zipBytes = [int64]0
if (-not $NoZip -and (Test-Path -LiteralPath $zipPath)) {
    $zipBytes = [int64](Get-Item -LiteralPath $zipPath).Length
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "portable-usb-incremental-patch"
    PackageRoot = $resolvedPackageRoot
    PatchRoot = $patchRoot
    ZipPath = if ($NoZip) { "" } else { $zipPath }
    FileCount = $entries.Count
    Bytes = $totalBytes
    ZipBytes = $zipBytes
    MissingCount = $missing.Count
    Missing = $missing.ToArray()
    ManifestPath = $manifestPath
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
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
