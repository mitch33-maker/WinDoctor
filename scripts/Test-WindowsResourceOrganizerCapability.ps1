param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function New-Capability {
    param(
        [string]$Id,
        [string]$Requirement,
        [string]$CurrentStatus,
        [string]$RiskLevel,
        [string]$ExistingEntryPoint,
        [string]$ExecutionPolicy,
        [string[]]$RecommendedNextSteps = @()
    )

    [PSCustomObject]@{
        Id = $Id
        Requirement = $Requirement
        CurrentStatus = $CurrentStatus
        RiskLevel = $RiskLevel
        ExistingEntryPoint = $ExistingEntryPoint
        ExecutionPolicy = $ExecutionPolicy
        RecommendedNextSteps = $RecommendedNextSteps
    }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$maintenanceScript = Join-Path $resolvedRoot "scripts\Invoke-WindowsMaintenance.ps1"
$resourceSafetyScript = Join-Path $resolvedRoot "scripts\Test-ResourceSafety.ps1"
$recommendedRepairScript = Join-Path $resolvedRoot "scripts\Invoke-RecommendedRepairPlan.ps1"

$capabilities = @(
    New-Capability `
        -Id "domain-disconnected-session-logoff" `
        -Requirement "Log off disconnected non-current user sessions after an idle threshold in domain or multi-user environments." `
        -CurrentStatus "PARTIAL_EXISTING_PREVIEW_AND_RUN_GATED_EXECUTE" `
        -RiskLevel "high" `
        -ExistingEntryPoint "scripts\Invoke-WindowsMaintenance.ps1 -Preview/-Execute -ForceLogoffDisconnectedUsers -MinIdleMinutes" `
        -ExecutionPolicy "Only disconnected, non-current sessions over MinIdleMinutes are eligible; actual logoff requires -Execute -ConfirmToken RUN." `
        -RecommendedNextSteps @(
            "Add domain and RDS environment detection.",
            "Add JSON evidence for target user, session id, state, and idle minutes.",
            "Add exclusion allowlist for Administrator, service accounts, and current user."
        )

    New-Capability `
        -Id "memory-release" `
        -Requirement "Release memory and prevent WindowsDoctor from exhausting host resources." `
        -CurrentStatus "PARTIAL_EXISTING_LOW_RESOURCE_GUARDS" `
        -RiskLevel "medium" `
        -ExistingEntryPoint "scripts\Test-ResourceSafety.ps1; scripts\Watch-WDResourceSafety.ps1; scripts\Invoke-WindowsMaintenance.ps1 -ReleaseMemory" `
        -ExecutionPolicy "Use resource gates, WindowsDoctor process budgets, scoped GUI worker cleanup, and disconnected-session logoff; do not arbitrarily empty or kill unrelated processes." `
        -RecommendedNextSteps @(
            "Add read-only top memory process report.",
            "Keep non-WindowsDoctor process actions as recommendations only.",
            "Run maintenance actions through the sequential queue."
        )

    New-Capability `
        -Id "disk-cleanup" `
        -Requirement "Free system drive space, temp files, Windows Update cache candidates, and other junk file candidates." `
        -CurrentStatus "PARTIAL_EXISTING_TEMP_PREVIEW_AND_RUN_GATED_EXECUTE" `
        -RiskLevel "high" `
        -ExistingEntryPoint "scripts\Invoke-WindowsMaintenance.ps1 -Preview/-Execute -CleanDisk -TempFileMinAgeHours" `
        -ExecutionPolicy "Current execution is limited to user TEMP, Windows TEMP, and Recycle Bin. Windows Update cache, Delivery Optimization, and component cleanup require separate dry-run, rollback, and RUN gate." `
        -RecommendedNextSteps @(
            "Add bounded preview for TEMP, Windows TEMP, SoftwareDistribution Download, DeliveryOptimization, and Windows.old.",
            "Keep Windows Update cache reset manual and RUN-gated.",
            "Add before and after free-space reports plus failed-file list."
        )

    New-Capability `
        -Id "forced-uninstall" `
        -Requirement "Force uninstall applications and remove leftover directories and files." `
        -CurrentStatus "NOT_IMPLEMENTED_FORMAL_EXECUTION" `
        -RiskLevel "high" `
        -ExistingEntryPoint "none" `
        -ExecutionPolicy "Do not add to unattended auto repair. First add installed-app inventory, uninstall command preview, leftover path proposal, and backup guidance; execution requires RUN." `
        -RecommendedNextSteps @(
            "Prefer official winget uninstall capability when available.",
            "Add installed app inventory and risk classification.",
            "Allow leftover deletion only for explicit product paths with dry-run evidence and RUN."
        )

    New-Capability `
        -Id "market-parity-cleaner-features" `
        -Requirement "Track common cleaner features: startup apps, browser cache, update cache, crash dumps, logs, empty folders, duplicate files." `
        -CurrentStatus "REFERENCE_ONLY_NOT_FORMALIZED" `
        -RiskLevel "medium" `
        -ExistingEntryPoint "EXTERNAL_REPAIR_TOOLS_STRATEGY.md; THIRD_PARTY_REPAIR_REFERENCE.md" `
        -ExecutionPolicy "GitHub and community cleaner logic remains reference-only until reviewed KB, dry-run evidence, rollback guidance, and allowlist review exist." `
        -RecommendedNextSteps @(
            "Start with read-only inventory for startup apps, large files, crash dumps, and browser cache size.",
            "Keep browser cache, duplicate files, and registry cleaner actions out of auto repair.",
            "Require exclusion lists and rollback guidance per cleanup category."
        )

    New-Capability `
        -Id "recommended-windowsdoctor-controls" `
        -Requirement "Use WindowsDoctor-specific safe controls for resource organizer work." `
        -CurrentStatus "PARTIAL_EXISTING_AND_EXPANDABLE" `
        -RiskLevel "low" `
        -ExistingEntryPoint "scripts\Invoke-WDSequentialTaskQueue.ps1; scripts\Get-WDResourceSnapshot.ps1; gui work window" `
        -ExecutionPolicy "Run one action at a time, record resource snapshots, allow cancel, preview first, and require RUN for state changes." `
        -RecommendedNextSteps @(
            "Add a Resource Organizer panel.",
            "Create default safe batch: resource safety, inventory, cleanup preview, user report.",
            "Keep high-risk functions outside unattended default batch."
        )
)

$missingEntrypoints = @($capabilities |
    Where-Object { $_.ExistingEntryPoint -ne "none" } |
    ForEach-Object {
        $first = ($_.ExistingEntryPoint -split ';')[0].Trim()
        if ($first -match '^scripts\\') {
            $path = Join-Path $resolvedRoot $first.Split(' ')[0]
            if (-not (Test-Path -LiteralPath $path)) { $path }
        }
    } | Where-Object { $_ })

$result = [PSCustomObject]@{
    Status = if ($missingEntrypoints.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "windows-resource-organizer-capability"
    Root = $resolvedRoot
    GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    MaintenanceScriptExists = Test-Path -LiteralPath $maintenanceScript
    ResourceSafetyScriptExists = Test-Path -LiteralPath $resourceSafetyScript
    RecommendedRepairScriptExists = Test-Path -LiteralPath $recommendedRepairScript
    CapabilityCount = $capabilities.Count
    MissingEntrypoints = $missingEntrypoints
    Capabilities = $capabilities
    SafetyPolicy = [PSCustomObject]@{
        NoCleanupExecuted = $true
        NoLogoffExecuted = $true
        NoUninstallExecuted = $true
        NoThirdPartyWorkflowImported = $true
        FormalExecutionRequiresRun = $true
    }
    ReportPath = $ReportPath
}

$jsonText = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $jsonText
}
else {
    $capabilities | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
