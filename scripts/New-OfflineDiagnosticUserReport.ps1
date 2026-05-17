param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DiagnosticRunReportPath = "",
    [string]$ConversionReportPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    return (Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json)
}

function Get-FindingState {
    param([object]$Finding)
    $toolId = [string]$Finding.ToolId
    $evidence = [string]$Finding.Evidence
    $repairState = [string]$Finding.RepairState
    if ($toolId -eq "setupdiag" -and $evidence -match "unable to find a relevant log file") {
        return "no_issue_detected"
    }
    if ($repairState -eq "preview_required") {
        return "repair_candidate_preview_only"
    }
    if ($repairState -eq "manual_review") {
        return "manual_review_required"
    }
    if ($evidence) {
        return "evidence_found"
    }
    return "blocked_by_policy"
}

function Get-FindingTitle {
    param([object]$Finding)
    switch ([string]$Finding.ToolId) {
        "setupdiag" { return "Windows Update / SetupDiag" }
        "sigcheck" { return "Driver and signature evidence" }
        "tcpview" { return "Network connection snapshot" }
        "handle" { return "Handle and locked-file evidence" }
        "autoruns" { return "Startup entry evidence" }
        default { return "$($Finding.ToolId) evidence" }
    }
}

function Get-UserMessage {
    param(
        [object]$Finding,
        [string]$State
    )
    $evidence = [string]$Finding.Evidence
    switch ($State) {
        "no_issue_detected" { return "No actionable diagnostic log or failure record was found by this tool." }
        "repair_candidate_preview_only" { return "Diagnostic evidence was found, but repair may only proceed through preview gates." }
        "manual_review_required" { return "Diagnostic evidence was found and requires MIS or technician review." }
        "evidence_found" { return "Diagnostic evidence was found and is retained for analysis." }
        default { return "This item is blocked by safety policy and cannot be handled automatically." }
    }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DiagnosticRunReportPath -and -not $ConversionReportPath) {
    $DiagnosticRunReportPath = Join-Path $resolvedRoot "logs\offline-diagnostic-tools-real-run.latest.json"
}

$run = Read-JsonFile -Path $DiagnosticRunReportPath
$conversion = $null
if ($ConversionReportPath) {
    $conversion = Read-JsonFile -Path $ConversionReportPath
}
elseif ($run -and $run.OutputConversion) {
    $conversion = $run.OutputConversion
}

$findings = @()
if ($conversion -and $conversion.Findings) {
    $findings = @($conversion.Findings)
}

$items = @($findings | ForEach-Object {
    $state = Get-FindingState -Finding $_
    [PSCustomObject]@{
        id = [string]$_.ToolId
        title = Get-FindingTitle -Finding $_
        component = [string]$_.Component
        state = $state
        evidence = [string]$_.Evidence
        errorCode = [string]$_.ErrorCode
        userMessage = Get-UserMessage -Finding $_ -State $state
        recommendation = [string]$_.Recommendation
        repairAllowed = $false
        script = "N/A"
    }
})

if ($items.Count -eq 0) {
    $items = @([PSCustomObject]@{
        id = "offline-diagnostics"
        title = "Offline diagnostics"
        component = "general"
        state = "no_issue_detected"
        evidence = "No diagnostic finding was produced by the current tool output."
        errorCode = ""
        userMessage = "The current tool output did not produce readable problem evidence."
        recommendation = "If symptoms remain, use a more specific component or import event log evidence."
        repairAllowed = $false
        script = "N/A"
    })
}

$stateCounts = [ordered]@{}
foreach ($state in @("no_issue_detected", "evidence_found", "manual_review_required", "repair_candidate_preview_only", "blocked_by_policy")) {
    $stateCounts[$state] = @($items | Where-Object { $_.state -eq $state }).Count
}

$nextSteps = New-Object System.Collections.Generic.List[string]
if ($stateCounts["manual_review_required"] -gt 0) {
    $nextSteps.Add("MIS should review manual evidence before creating a repair preview.") | Out-Null
}
if ($stateCounts["repair_candidate_preview_only"] -gt 0) {
    $nextSteps.Add("Repair candidates still require dry-run impact, rollback guidance, allowlist review, and RUN gate.") | Out-Null
}
if ($stateCounts["no_issue_detected"] -gt 0 -and $items.Count -eq $stateCounts["no_issue_detected"]) {
    $nextSteps.Add("No clear problem evidence was found; if symptoms remain, rerun diagnostics with event logs or a specific component.") | Out-Null
}
$nextSteps.Add("This report only classifies diagnostics; it does not repair, clean, or disable anything.") | Out-Null

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "offline-diagnostic-user-report"
    Root = $resolvedRoot
    DiagnosticRunReportPath = $DiagnosticRunReportPath
    ConversionReportPath = $ConversionReportPath
    FindingCount = $items.Count
    StateCounts = [PSCustomObject]$stateCounts
    Findings = $items
    UserReport = [PSCustomObject]@{
        Fixed = @()
        NotFixed = @($items | ForEach-Object {
            [PSCustomObject]@{
                id = $_.id
                title = $_.title
                script = "N/A"
                reason = $_.userMessage
                riskLevel = "diagnostic"
                state = $_.state
            }
        })
        NextSteps = $nextSteps.ToArray()
    }
    SafetyPolicy = [PSCustomObject]@{
        DiagnosticOnly = $true
        NoRepairExecuted = $true
        NoCleanupExecuted = $true
        NoToolExecuted = $true
        NoAllowlistChange = $true
    }
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 10
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $result | Format-List }
