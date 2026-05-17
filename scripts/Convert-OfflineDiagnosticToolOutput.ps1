param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$InputRoot = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Read-TextIfExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $InputRoot) {
    $InputRoot = Join-Path $env:LOCALAPPDATA "WindowsDoctor\OfflineDiagnostics"
}
$resolvedInputRoot = [System.IO.Path]::GetFullPath($InputRoot).TrimEnd("\")

$findings = New-Object System.Collections.Generic.List[object]
$setupDiagPath = Join-Path $resolvedInputRoot "setupdiag\SetupDiagResults.log"
$setupDiagText = Read-TextIfExists -Path $setupDiagPath
if ($setupDiagText) {
    $errorCode = ""
    $failureData = ""
    $matchedCode = [regex]::Match($setupDiagText, "(?i)(0x[0-9a-f]{8})")
    if ($matchedCode.Success) { $errorCode = $matchedCode.Value }
    $matchedFailure = [regex]::Match($setupDiagText, "(?im)^\s*(FailureData|Error|Result|Recommendation)\s*[:=]\s*(.+)$")
    if ($matchedFailure.Success) { $failureData = $matchedFailure.Groups[2].Value.Trim() }
    $findings.Add([PSCustomObject]@{
        ToolId = "setupdiag"
        SourcePath = $setupDiagPath
        Status = "FOUND"
        Component = "windows_update"
        Evidence = if ($failureData) { $failureData } else { ($setupDiagText -split "\r?\n" | Where-Object { $_.Trim() } | Select-Object -First 1) }
        ErrorCode = $errorCode
        RepairState = "preview_required"
        Recommendation = "Import SetupDiag evidence into WindowsDoctor KB matching. Any Windows Update repair still requires dry-run, rollback guidance, and RUN gate."
    }) | Out-Null
}

$knownToolDirs = @("process-explorer", "process-monitor", "autoruns", "handle", "tcpview", "rammap", "sigcheck")
foreach ($toolId in $knownToolDirs) {
    $toolDir = Join-Path $resolvedInputRoot $toolId
    if (Test-Path -LiteralPath $toolDir) {
        $files = @(Get-ChildItem -LiteralPath $toolDir -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 20)
        $findings.Add([PSCustomObject]@{
            ToolId = $toolId
            SourcePath = $toolDir
            Status = "FOUND"
            Component = "general"
            Evidence = "Tool output directory exists; files=$($files.Count)"
            ErrorCode = ""
            RepairState = "manual_review"
            Recommendation = "Import as diagnostic evidence for MIS or parser review. Do not convert directly to automatic repair."
        }) | Out-Null
    }
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "offline-diagnostic-output-conversion"
    Root = $resolvedRoot
    InputRoot = $resolvedInputRoot
    FindingCount = $findings.Count
    Findings = $findings.ToArray()
    UserReport = [PSCustomObject]@{
        Fixed = @()
        NotFixed = @($findings | ForEach-Object {
            [PSCustomObject]@{
                id = $_.ToolId
                title = "$($_.ToolId) diagnostic evidence"
                script = "N/A"
                reason = $_.Recommendation
                riskLevel = "diagnostic"
            }
        })
        NextSteps = @(
            "Tool output has been converted into diagnostic evidence.",
            "Repair still requires reviewed KB, dry-run impact, rollback guidance, allowlist review, and RUN gate.",
            "If no output is found, check runner report and tool package availability."
        )
    }
    SafetyPolicy = [PSCustomObject]@{
        ReadOnly = $true
        NoRepairExecuted = $true
        NoToolExecuted = $true
        NoInstall = $true
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

if ($Json) { $resultJson } else { $result | Format-List }
