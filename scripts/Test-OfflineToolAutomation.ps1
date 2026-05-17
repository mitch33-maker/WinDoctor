param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [string]$Status,
        [string]$Detail
    )
    $Checks.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    }) | Out-Null
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$servicePath = Join-Path $resolvedRoot "gui\broker\services\offlineTools.js"
$issuePlannerPath = Join-Path $resolvedRoot "gui\broker\services\issuePlanner.js"
$componentPath = Join-Path $resolvedRoot "gui\src\components\ProblemSolverPanel.tsx"
$repairToolsRoot = Join-Path $resolvedRoot "releases\repair-tools"
$checks = [System.Collections.Generic.List[object]]::new()

if (-not (Test-Path -LiteralPath $servicePath)) {
    Add-Check -Checks $checks -Name "offline-tools-service" -Status "FAIL" -Detail "Missing $servicePath"
}
else {
    $serviceSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $servicePath
    Add-Check -Checks $checks -Name "offline-tools-service" -Status "PASS" -Detail "Service exists"
    Add-Check -Checks $checks -Name "no-exec-api" -Status ($(if ($serviceSource -notmatch "\bspawn\(" -and $serviceSource -notmatch "\bexec\(") { "PASS" } else { "FAIL" })) -Detail "offlineTools.js must not spawn or exec tools"
    Add-Check -Checks $checks -Name "autorun-disabled" -Status ($(if ($serviceSource -match "AutoRunAllowed:\s*false" -and $serviceSource -match "NoToolExecuted:\s*true") { "PASS" } else { "FAIL" })) -Detail "Service exposes preview-only safety policy"
    Add-Check -Checks $checks -Name "component-map" -Status ($(if ($serviceSource -match "COMPONENT_TOOL_MAP" -and $serviceSource -match "performance" -and $serviceSource -match "windows_update") { "PASS" } else { "FAIL" })) -Detail "Component-to-tool mapping exists"
}

if (Test-Path -LiteralPath $issuePlannerPath) {
    $issueSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $issuePlannerPath
    Add-Check -Checks $checks -Name "issue-planner-integration" -Status ($(if ($issueSource -match "selectToolsForComponent" -and $issueSource -match "OfflineToolPlan") { "PASS" } else { "FAIL" })) -Detail "Issue planner includes offline tool plan"
}
else {
    Add-Check -Checks $checks -Name "issue-planner-integration" -Status "FAIL" -Detail "Missing issue planner"
}

if (Test-Path -LiteralPath $componentPath) {
    $componentSource = Get-Content -Raw -Encoding UTF8 -LiteralPath $componentPath
    Add-Check -Checks $checks -Name "ui-integration" -Status ($(if ($componentSource -match "OfflineToolPlan" -and $componentSource -match "commandPreview") { "PASS" } else { "FAIL" })) -Detail "Problem solver panel shows selected tools and command preview"
}
else {
    Add-Check -Checks $checks -Name "ui-integration" -Status "FAIL" -Detail "Missing ProblemSolverPanel"
}

$latestPackage = $null
if (Test-Path -LiteralPath $repairToolsRoot) {
    $latestPackage = Get-ChildItem -LiteralPath $repairToolsRoot -Directory |
        Where-Object { $_.Name -like "windowsdoctor-offline-microsoft-diagnostics-*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

if (-not $latestPackage) {
    Add-Check -Checks $checks -Name "offline-tool-package" -Status "WAITING" -Detail "No offline Microsoft diagnostics package found"
}
else {
    $manifestPath = Join-Path $latestPackage.FullName "repair-tool-package-manifest.json"
    Add-Check -Checks $checks -Name "offline-tool-package" -Status "PASS" -Detail $latestPackage.FullName
    if (Test-Path -LiteralPath $manifestPath) {
        $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
        $tools = @($manifest.tools)
        $autorun = @($tools | Where-Object { $_.autoRunAllowed -ne $false })
        $nonMicrosoft = @($tools | Where-Object { $_.sourceTrustLevel -ne "microsoft_official" })
        Add-Check -Checks $checks -Name "manifest-tool-count" -Status ($(if ($tools.Count -ge 1) { "PASS" } else { "FAIL" })) -Detail "ToolCount=$($tools.Count)"
        Add-Check -Checks $checks -Name "manifest-no-autorun" -Status ($(if ($autorun.Count -eq 0) { "PASS" } else { "FAIL" })) -Detail "AutoRunAllowedCount=$($autorun.Count)"
        Add-Check -Checks $checks -Name "manifest-microsoft-only" -Status ($(if ($nonMicrosoft.Count -eq 0) { "PASS" } else { "FAIL" })) -Detail "NonMicrosoftCount=$($nonMicrosoft.Count)"
    }
    else {
        Add-Check -Checks $checks -Name "offline-tool-manifest" -Status "FAIL" -Detail "Missing manifest"
    }
}

$failed = @($checks | Where-Object { $_.Status -eq "FAIL" })
$result = [PSCustomObject]@{
    Status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "offline-tool-automation"
    Root = $resolvedRoot
    LatestPackage = if ($latestPackage) { $latestPackage.FullName } else { $null }
    CheckCount = $checks.Count
    Checks = $checks.ToArray()
    SafetyPolicy = [PSCustomObject]@{
        NoToolExecuted = $true
        NoInstall = $true
        NoRepairAllowlistChange = $true
        RunGateRequired = $true
    }
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

if ($result.Status -ne "PASS") {
    exit 1
}
