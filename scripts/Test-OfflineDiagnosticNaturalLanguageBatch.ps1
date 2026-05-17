param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Passed,
        [string]$Detail = ""
    )
    $Checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }) | Out-Null
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$checks = [System.Collections.Generic.List[object]]::new()

$offlineToolsPath = Join-Path $resolvedRoot "gui\broker\services\offlineTools.js"
$issuePlannerPath = Join-Path $resolvedRoot "gui\broker\services\issuePlanner.js"
$workPath = Join-Path $resolvedRoot "gui\broker\services\work.js"
$routesPath = Join-Path $resolvedRoot "gui\broker\routes.js"
$apiPath = Join-Path $resolvedRoot "gui\src\lib\windowsDoctorApi.ts"
$typesPath = Join-Path $resolvedRoot "gui\src\types\windows-doctor.ts"
$problemPanelPath = Join-Path $resolvedRoot "gui\src\components\ProblemSolverPanel.tsx"
$workPanelPath = Join-Path $resolvedRoot "gui\src\components\WorkStatusPanel.tsx"
$runnerPath = Join-Path $resolvedRoot "scripts\Invoke-OfflineDiagnosticTools.ps1"

$offlineTools = Read-Text -Path $offlineToolsPath
$issuePlanner = Read-Text -Path $issuePlannerPath
$work = Read-Text -Path $workPath
$routes = Read-Text -Path $routesPath
$api = Read-Text -Path $apiPath
$types = Read-Text -Path $typesPath
$problemPanel = Read-Text -Path $problemPanelPath
$workPanel = Read-Text -Path $workPanelPath
$runner = Read-Text -Path $runnerPath

Add-Check -Checks $checks -Name "safe-cli-map-exported" -Passed ($offlineTools -match 'SAFE_CLI_TOOL_MAP' -and $offlineTools -match 'getSafeCliToolIdsForComponent' -and $offlineTools -match "network:\s*\['tcpview', 'handle'\]") -Detail $offlineToolsPath
Add-Check -Checks $checks -Name "issue-plan-safe-cli-batch" -Passed ($issuePlanner -match 'SafeCliDiagnosticBatch' -and $issuePlanner -match 'sequential-run-gated' -and $issuePlanner -match 'NoCleanupExecuted') -Detail $issuePlannerPath
Add-Check -Checks $checks -Name "work-natural-language-routing" -Passed ($work -match 'problemText' -and $work -match 'classifyIssue' -and $work -match 'getSafeCliToolIdsForComponent') -Detail $workPath
Add-Check -Checks $checks -Name "work-progress-path" -Passed ($work -match 'ProgressPath' -and $work -match 'readProgressFile' -and $work -match 'CurrentToolId') -Detail $workPath
Add-Check -Checks $checks -Name "route-and-api-problem-text" -Passed ($routes -match 'problemText' -and $api -match 'problemText\?: string') -Detail $routesPath
Add-Check -Checks $checks -Name "types-safe-cli-batch" -Passed ($types -match 'SafeCliDiagnosticBatch' -and $types -match 'ProgressPath\?: string') -Detail $typesPath
Add-Check -Checks $checks -Name "ui-safe-cli-batch" -Passed ($problemPanel -match 'SafeCliDiagnosticBatch' -and $problemPanel -match 'PreviewCommandHint') -Detail $problemPanelPath
Add-Check -Checks $checks -Name "ui-diagnostic-state-labels" -Passed ($workPanel -match 'diagnosticStateLabels' -and $workPanel -match 'repair_candidate_preview_only' -and $workPanel -match 'blocked_by_policy') -Detail $workPanelPath
Add-Check -Checks $checks -Name "runner-progress-state" -Passed ($runner -match 'ProgressPath' -and $runner -match 'Write-ProgressState' -and $runner -match 'CurrentToolId') -Detail $runnerPath

$failed = @($checks | Where-Object { $_.Status -ne "PASS" })
$result = [PSCustomObject]@{
    Status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "offline-diagnostic-natural-language-batch"
    Root = $resolvedRoot
    CheckCount = $checks.Count
    FailedCount = $failed.Count
    Checks = $checks
    SafetyPolicy = [PSCustomObject]@{
        NoExternalToolExecuted = $true
        NoRepairExecuted = $true
        NoCleanupExecuted = $true
        NoGuiBrokerStarted = $true
    }
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
} else {
    $result
}

if ($failed.Count -gt 0) { exit 1 }
