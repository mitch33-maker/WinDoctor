param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Execute,
    [string]$ConfirmToken = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$scanScript = Join-Path $normalizedRoot "scripts\Test-SystemErrorScan.ps1"
$repairScript = Join-Path $normalizedRoot "scripts\Invoke-AllowedRepair.ps1"
$policyPath = Join-Path $normalizedRoot "scripts\repair-safety-policy.json"

$decisionEngineVersion = 4
$repairPlanVersion = 4
$safeBatchPolicy = "policy-approved only; reversible, dry-run impact, local evidence, no critical interruption, rollback guidance, RUN gate; stop on first failure"

function Invoke-JsonScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $ScriptPath @Arguments -Json
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $ScriptPath"
    }
    ($raw | Out-String) | ConvertFrom-Json
}

function New-ConsoleText {
    param([int[]]$Codes)
    [string]::Concat([char[]]$Codes)
}

function Get-RepairRiskLevel {
    param(
        [string]$ScriptName,
        $Safety
    )

    if ($Safety -and $Safety.PSObject.Properties.Name -contains "riskLevel") {
        return [string]$Safety.riskLevel
    }

    if ($ScriptName -match "BCD|Boot|SystemIntegrity|SystemMaintenance") {
        return "manual_review"
    }
    if ($ScriptName -match "WUSoftwareDistribution") {
        return "medium"
    }
    return "low"
}

function Get-RepairSafetyPolicy {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Repair safety policy not found: $Path"
    }
    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function Get-RepairSafety {
    param(
        $Policy,
        [string]$ScriptName
    )

    $item = @($Policy.scripts | Where-Object { [string]$_.scriptName -eq $ScriptName }) | Select-Object -First 1
    if ($item) { return $item }

    [PSCustomObject]@{
        scriptName = $ScriptName
        riskLevel = "manual_review"
        reversible = $false
        dryRunImpactAvailable = $false
        localValidationStatus = "MISSING_POLICY"
        criticalInterruption = $true
        rollbackGuidanceAvailable = $false
        allowlistReviewStatus = "MISSING_POLICY"
        autoBatchAllowed = $false
        runGateRequired = $true
        rollbackGuidance = "Missing safety policy. Manual review required before execution."
    }
}

function Test-AutoBatchSafety {
    param(
        $Policy,
        $Safety
    )

    if (-not $Safety) { return $false }
    if ([bool]$Safety.autoBatchAllowed -ne $true) { return $false }
    if ([string]$Safety.allowlistReviewStatus -ne [string]$Policy.minimumAutoBatchReviewStatus) { return $false }
    if ([bool]$Safety.reversible -ne $true) { return $false }
    if ([bool]$Safety.dryRunImpactAvailable -ne $true) { return $false }
    if ([string]$Safety.localValidationStatus -ne "PASS") { return $false }
    if ([bool]$Safety.criticalInterruption -eq $true) { return $false }
    if ([bool]$Safety.rollbackGuidanceAvailable -ne $true) { return $false }
    if ([bool]$Safety.runGateRequired -ne $true) { return $false }
    if ([string]$Safety.riskLevel -eq "high") { return $false }
    return $true
}

function Get-SafetyBlockReason {
    param(
        $Policy,
        $Safety
    )

    $reasons = New-Object System.Collections.Generic.List[string]
    if (-not $Safety) {
        $reasons.Add("missing safety policy") | Out-Null
        return @($reasons.ToArray())
    }
    if ([bool]$Safety.autoBatchAllowed -ne $true) { $reasons.Add("autoBatchAllowed is false") | Out-Null }
    if ([string]$Safety.allowlistReviewStatus -ne [string]$Policy.minimumAutoBatchReviewStatus) { $reasons.Add("allowlist review is not approved") | Out-Null }
    if ([bool]$Safety.reversible -ne $true) { $reasons.Add("action is not proven reversible") | Out-Null }
    if ([bool]$Safety.dryRunImpactAvailable -ne $true) { $reasons.Add("dry-run impact is missing") | Out-Null }
    if ([string]$Safety.localValidationStatus -ne "PASS") { $reasons.Add("local validation evidence is not PASS") | Out-Null }
    if ([bool]$Safety.criticalInterruption -eq $true) { $reasons.Add("may interrupt critical service or device") | Out-Null }
    if ([bool]$Safety.rollbackGuidanceAvailable -ne $true) { $reasons.Add("rollback guidance is missing") | Out-Null }
    if ([bool]$Safety.runGateRequired -ne $true) { $reasons.Add("RUN gate is not required") | Out-Null }
    if ([string]$Safety.riskLevel -eq "high") { $reasons.Add("high-risk repairs cannot run in auto batch") | Out-Null }
    @($reasons.ToArray())
}

function Get-PriorityRank {
    param(
        [string]$RiskLevel,
        [int]$Confidence
    )

    if ($RiskLevel -eq "low" -and $Confidence -ge 70) { return 1 }
    if ($RiskLevel -eq "low") { return 2 }
    if ($RiskLevel -eq "medium") { return 3 }
    return 9
}

function Get-PriorityLabel {
    param([int]$PriorityRank)

    if ($PriorityRank -eq 1) { return "first" }
    if ($PriorityRank -eq 2) { return "normal" }
    if ($PriorityRank -eq 3) { return "later" }
    return "manual"
}

function Get-RepairDecisionState {
    param(
        [int]$ActiveEvidenceCount,
        [string]$RiskLevel,
        [string]$ScriptName,
        [int]$Confidence
    )

    if ($ActiveEvidenceCount -le 0) { return "observation" }
    if ($RiskLevel -ne "low") { return "manual_review_required" }
    if ($ScriptName -notin $safeBatchScripts) { return "manual_review_required" }
    if ($Confidence -lt 70) { return "preview_repair_only" }
    return "auto_repair_allowed"
}

function New-SafeBatchExecutionRecord {
    param(
        [string]$ScriptName,
        [string]$Status,
        [int]$ExitCode,
        [string]$Detail = ""
    )

    [PSCustomObject]@{
        Script = $ScriptName
        Status = $Status
        ExitCode = $ExitCode
        Detail = $Detail
        Timestamp = (Get-Date).ToString("o")
    }
}

if (-not (Test-Path -LiteralPath $scanScript)) { throw "Scan script not found: $scanScript" }
if (-not (Test-Path -LiteralPath $repairScript)) { throw "Repair wrapper not found: $repairScript" }

$safetyPolicy = Get-RepairSafetyPolicy -Path $policyPath
$safeBatchScripts = @($safetyPolicy.scripts | Where-Object { Test-AutoBatchSafety -Policy $safetyPolicy -Safety $_ } | Select-Object -ExpandProperty scriptName -Unique)
$scan = Invoke-JsonScript -ScriptPath $scanScript -Arguments @("-Root", $normalizedRoot, "-RecentHours", "24", "-MaxEvents", "80")
$recommendationMap = @{}
foreach ($finding in @($scan.Findings)) {
    foreach ($match in @($finding.KbMatches)) {
        if ($match.repairAllowed -ne $true -or -not $match.script -or $match.script -eq "N/A") {
            continue
        }

        $key = "$($match.id)|$($match.script)"
        if (-not $recommendationMap.ContainsKey($key)) {
            $recommendationMap[$key] = [PSCustomObject]@{
                id = $match.id
                title = $match.title
                actionType = $match.actionType
                script = $match.script
                EvidenceCount = 0
                FindingNames = New-Object System.Collections.Generic.List[string]
                FindingStatuses = New-Object System.Collections.Generic.List[string]
                MaxKbScore = 0
            }
        }

        $item = $recommendationMap[$key]
        $item.EvidenceCount = [int]$item.EvidenceCount + 1
        $item.FindingNames.Add([string]$finding.Name)
        $item.FindingStatuses.Add([string]$finding.Status)
        if ([int]$match.score -gt [int]$item.MaxKbScore) {
            $item.MaxKbScore = [int]$match.score
        }
    }
}

$recommended = @($recommendationMap.Values | ForEach-Object {
    $safety = Get-RepairSafety -Policy $safetyPolicy -ScriptName $_.script
    $risk = Get-RepairRiskLevel -ScriptName $_.script -Safety $safety
    $nonPassCount = @($_.FindingStatuses | Where-Object { $_ -ne "PASS" }).Count
    $confidence = 25 + ([int]$_.EvidenceCount * 8) + ([int]$_.MaxKbScore * 2)
    if ($nonPassCount -gt 0) {
        $confidence += 35
    }
    $policyApproved = Test-AutoBatchSafety -Policy $safetyPolicy -Safety $safety
    if ($policyApproved) {
        $confidence += 5
    }
    if ($nonPassCount -eq 0 -and $confidence -gt 49) {
        $confidence = 49
    }
    if ($confidence -gt 95) {
        $confidence = 95
    }
    $priorityRank = Get-PriorityRank -RiskLevel $risk -Confidence $confidence
    $decisionState = Get-RepairDecisionState -ActiveEvidenceCount $nonPassCount -RiskLevel $risk -ScriptName $_.script -Confidence $confidence
    if ($decisionState -eq "auto_repair_allowed" -and -not $policyApproved) {
        $decisionState = "manual_review_required"
    }
    $state = if ($decisionState -eq "observation") { "observation" } else { "recommended" }
    $autoBatchEligible = ($decisionState -eq "auto_repair_allowed")
    $blockReasons = Get-SafetyBlockReason -Policy $safetyPolicy -Safety $safety

    [PSCustomObject]@{
        id = $_.id
        title = $_.title
        actionType = $_.actionType
        script = $_.script
        EvidenceCount = [int]$_.EvidenceCount
        ActiveEvidenceCount = [int]$nonPassCount
        FindingNames = @($_.FindingNames.ToArray() | Select-Object -Unique)
        FindingStatuses = @($_.FindingStatuses.ToArray() | Select-Object -Unique)
        MaxKbScore = [int]$_.MaxKbScore
        Confidence = [int]$confidence
        RiskLevel = $risk
        PriorityRank = [int]$priorityRank
        Priority = Get-PriorityLabel -PriorityRank $priorityRank
        RecommendationState = $state
        RepairDecisionState = $decisionState
        AutoBatchEligible = $autoBatchEligible
        AutoRepairSafety = [PSCustomObject]@{
            RiskLevel = [string]$safety.riskLevel
            Reversible = [bool]$safety.reversible
            DryRunImpactAvailable = [bool]$safety.dryRunImpactAvailable
            LocalValidationStatus = [string]$safety.localValidationStatus
            CriticalInterruption = [bool]$safety.criticalInterruption
            RollbackGuidanceAvailable = [bool]$safety.rollbackGuidanceAvailable
            AllowlistReviewStatus = [string]$safety.allowlistReviewStatus
            AutoBatchPolicyApproved = [bool]$policyApproved
            RunGateRequired = [bool]$safety.runGateRequired
            BlockReasons = $blockReasons
            RollbackGuidance = [string]$safety.rollbackGuidance
        }
        ExecutionGate = if ($autoBatchEligible) { "RUN_REQUIRED" } elseif ($decisionState -eq "preview_repair_only") { "PREVIEW_ONLY" } elseif ($decisionState -eq "manual_review_required") { "MANUAL_REVIEW" } else { "NONE" }
    }
} | Sort-Object PriorityRank, @{ Expression = "Confidence"; Descending = $true }, script, id)

$safe = @($recommended | Where-Object { $_.AutoBatchEligible -eq $true } | Sort-Object PriorityRank, @{ Expression = "Confidence"; Descending = $true }, script, id)
$previewOnly = @($recommended | Where-Object { $_.RepairDecisionState -eq "preview_repair_only" } | Sort-Object PriorityRank, @{ Expression = "Confidence"; Descending = $true }, script, id)
$manual = @($recommended | Where-Object { $_.RepairDecisionState -eq "manual_review_required" } | Sort-Object PriorityRank, @{ Expression = "Confidence"; Descending = $true }, script, id)
$observations = @($recommended | Where-Object { $_.RecommendationState -eq "observation" } | Sort-Object script, id)
$safeScripts = @($safe | Select-Object -ExpandProperty script -Unique)
$executions = New-Object System.Collections.Generic.List[object]

if ($Execute -and $ConfirmToken -ne "RUN") {
    throw "Execution requires -ConfirmToken RUN"
}

if ($Execute) {
    foreach ($scriptName in $safeScripts) {
        $executions.Add((New-SafeBatchExecutionRecord -ScriptName $scriptName -Status "STARTED" -ExitCode -1 -Detail "safe batch execution started"))
        try {
            $repairResult = Invoke-JsonScript -ScriptPath $repairScript -Arguments @("-Root", $normalizedRoot, "-ScriptName", $scriptName, "-Execute", "-ConfirmToken", "RUN")
            $exitCode = if ($repairResult.PSObject.Properties.Name -contains "ExitCode") { [int]$repairResult.ExitCode } else { 0 }
            $executions.Add((New-SafeBatchExecutionRecord -ScriptName $scriptName -Status $repairResult.Status -ExitCode $exitCode -Detail "safe batch execution completed"))
            if ($repairResult.Status -ne "PASS" -or $exitCode -ne 0) {
                $executions.Add((New-SafeBatchExecutionRecord -ScriptName $scriptName -Status "STOPPED" -ExitCode $exitCode -Detail "stopped on first failed repair"))
                break
            }
        }
        catch {
            $executions.Add((New-SafeBatchExecutionRecord -ScriptName $scriptName -Status "FAIL" -ExitCode 1 -Detail $_.Exception.Message))
            $executions.Add((New-SafeBatchExecutionRecord -ScriptName $scriptName -Status "STOPPED" -ExitCode 1 -Detail "stopped on first exception"))
            break
        }
    }
}

$executionArray = @($executions.ToArray())
$result = [PSCustomObject]@{
    Status = if ($executionArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Mode = if ($Execute) { "execute" } else { "preview" }
    Root = $normalizedRoot
    ScanStatus = $scan.Status
    FindingCount = @($scan.Findings).Count
    RecommendedRepairCount = $recommended.Count
    ActiveRecommendedRepairCount = @($recommended | Where-Object { $_.RecommendationState -eq "recommended" }).Count
    ObservationCount = $observations.Count
    PreviewOnlyCount = $previewOnly.Count
    ManualReviewCount = $manual.Count
    SafeBatchScriptCount = $safeScripts.Count
    SafeBatchScripts = $safeScripts
    RepairPlanVersion = $repairPlanVersion
    DecisionEngineVersion = $decisionEngineVersion
    RepairSafetyPolicyPath = $policyPath
    RepairPlanScoring = [PSCustomObject]@{
        ConfidenceScale = "0-100"
        PriorityOrder = "first, normal, later, manual"
        SafeBatchPolicy = $safeBatchPolicy
        ActiveEvidenceRequired = $true
        MinimumAutoRepairConfidence = 70
        RequiredAutoRepairGates = @("reversible", "dry-run impact", "local validation PASS", "no critical interruption", "rollback guidance", "allowlist review APPROVED", "RUN gate")
    }
    SafeBatchExecutionPolicy = [PSCustomObject]@{
        DefaultMode = "preview"
        ExecuteRequires = "-Execute -ConfirmToken RUN"
        StopOnFirstFailure = $true
        AllowedScripts = $safeBatchScripts
        AutoBatchReviewStatusRequired = $safetyPolicy.minimumAutoBatchReviewStatus
        ExcludedByDefault = @("Repair-BCDBoot.bat", "Repair-SystemIntegrity.bat", "Repair-SystemMaintenance.bat", "Repair-WUSoftwareDistribution.bat")
    }
    OperatorGuidance = [PSCustomObject]@{
        EvidenceScoring = "Confidence combines KB match score, evidence count, non-PASS active evidence, and safe-batch allowlist membership. Observation-only findings are capped below auto-repair confidence."
        DryRunImpact = "Preview mode does not execute repair scripts. It only reports eligible safe-batch scripts, preview-only items, manual-review items, and observations."
        RunGate = "Execution is blocked unless -Execute -ConfirmToken RUN is supplied. GUI execution also requires the operator to type RUN."
        RollbackGuidance = "Before RUN on a real target, capture current diagnostics and ensure restore/backout is available. Manual-review and excluded scripts are not executed by safe batch."
        StopPolicy = "Safe batch stops on the first failed script and never executes boot, system-integrity, system-maintenance, or Windows Update cache reset scripts by default."
    }
    PrioritizedRecommendations = $recommended
    SafeRecommendations = $safe
    PreviewOnlyRecommendations = $previewOnly
    ManualReviewRecommendations = $manual
    ObservationRecommendations = $observations
    Executed = [bool]$Execute
    Executions = $executionArray
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

if ($Json) {
    $resultJson
}
else {
    $title = New-ConsoleText @(0x4e00,0x9375,0x6383,0x63cf,0x8207,0x4fee,0x5fa9,0x5efa,0x8b70)
    $safeLabel = New-ConsoleText @(0x53ef,0x6279,0x6b21,0x57f7,0x884c)
    $manualLabel = New-ConsoleText @(0x9700,0x4eba,0x5de5,0x78ba,0x8a8d)
    $modeLabel = New-ConsoleText @(0x6a21,0x5f0f)

    Write-Host $title
    Write-Host ("{0}: {1}" -f $modeLabel, $result.Mode)
    Write-Host ("{0}: {1}" -f $safeLabel, ($safeScripts -join ", "))
    foreach ($item in $safe) {
        Write-Host ("  - {0} | {1} | {2} | confidence={3} priority={4}" -f $item.script, $item.id, $item.title, $item.Confidence, $item.Priority)
    }
    Write-Host ("{0}: {1}" -f $manualLabel, @($manual).Count)
    foreach ($item in $manual) {
        Write-Host ("  - {0} | {1} | {2} | confidence={3} risk={4}" -f $item.script, $item.id, $item.title, $item.Confidence, $item.RiskLevel)
    }
}

if ($result.Status -eq "FAIL") { exit 1 }
