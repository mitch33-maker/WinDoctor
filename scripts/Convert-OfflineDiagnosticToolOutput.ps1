param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$InputRoot = "",
    [string]$ExternalPackPath = "",
    [string]$PackageTitle = "WindowsDoctor Offline Diagnostic Evidence",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Read-TextIfExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return "" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) { return "" }
    $sampleLength = [Math]::Min($bytes.Length, 200)
    $zeroCount = 0
    for ($i = 0; $i -lt $sampleLength; $i++) {
        if ($bytes[$i] -eq 0) { $zeroCount++ }
    }
    if ($zeroCount -gt [Math]::Max(4, [int]($sampleLength / 4))) {
        return [System.Text.Encoding]::Unicode.GetString($bytes)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-FirstRegexValue {
    param(
        [string]$Text,
        [string[]]$Patterns
    )
    foreach ($pattern in $Patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) {
            if ($match.Groups.Count -gt 1) { return $match.Groups[1].Value.Trim() }
            return $match.Value.Trim()
        }
    }
    return ""
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$ToolId,
        [string]$SourcePath,
        [string]$Component,
        [string]$Evidence,
        [string]$ErrorCode = "",
        [string]$RepairState = "manual_review",
        [string]$Recommendation = "Import as diagnostic evidence. Do not convert directly to automatic repair.",
        [string[]]$TriggerTerms = @()
    )
    $List.Add([PSCustomObject]@{
        ToolId = $ToolId
        SourcePath = $SourcePath
        Status = "FOUND"
        Component = $Component
        Evidence = $Evidence
        ErrorCode = $ErrorCode
        RepairState = $RepairState
        Recommendation = $Recommendation
        TriggerTerms = $TriggerTerms
    }) | Out-Null
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
    $errorCode = Get-FirstRegexValue -Text $setupDiagText -Patterns @("(?i)(0x[0-9a-f]{8})")
    $failureData = Get-FirstRegexValue -Text $setupDiagText -Patterns @(
        "(?im)(SetupDiag was unable to find a relevant log file\.)",
        "(?im)^\s*FailureData\s*[:=]\s*(.+)$",
        "(?im)^\s*Error\s*[:=]\s*(.+)$",
        "(?im)^\s*Result\s*[:=]\s*(.+)$"
    )
    $profile = Get-FirstRegexValue -Text $setupDiagText -Patterns @(
        "(?im)^\s*(?:Matching Profile|ProfileName|Profile)\s*[:=]\s*(.+)$",
        "(?im)^\s*RuleId\s*[:=]\s*(.+)$"
    )
    $recommendation = Get-FirstRegexValue -Text $setupDiagText -Patterns @("(?im)^\s*Recommendation\s*[:=]\s*(.+)$")
    $firstLine = ($setupDiagText -split "\r?\n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    $evidenceParts = @($failureData, $profile, $recommendation, $firstLine) | Where-Object { $_ } | Select-Object -Unique
    Add-Finding -List $findings -ToolId "setupdiag" -SourcePath $setupDiagPath -Component "windows_update" -Evidence (($evidenceParts -join " | ")) -ErrorCode $errorCode -RepairState "preview_required" -Recommendation "Import SetupDiag evidence into WindowsDoctor KB matching. Any Windows Update repair still requires dry-run, rollback guidance, and RUN gate." -TriggerTerms @("setupdiag", "windows update", "upgrade", $errorCode, $profile)
}

$sigcheckDir = Join-Path $resolvedInputRoot "sigcheck"
if (Test-Path -LiteralPath $sigcheckDir) {
    $sigcheckFiles = @(Get-ChildItem -LiteralPath $sigcheckDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @("sigcheck.txt", "sigcheck.csv") })
    $sigcheckText = ($sigcheckFiles | Select-Object -First 5 | ForEach-Object { Read-TextIfExists -Path $_.FullName }) -join "`n"
    $unsignedCount = ([regex]::Matches($sigcheckText, "(?im)\b(unsigned|not signed)\b")).Count
    $invalidCount = ([regex]::Matches($sigcheckText, "(?im)\b(invalid|revoked|untrusted)\b")).Count
    $publisher = Get-FirstRegexValue -Text $sigcheckText -Patterns @("(?im)^\s*Publisher\s*[:=]\s*(.+)$", "(?im)^\s*Verified\s*[:=]\s*(.+)$")
    Add-Finding -List $findings -ToolId "sigcheck" -SourcePath $sigcheckDir -Component "system_integrity" -Evidence "sigcheck files=$($sigcheckFiles.Count); unsigned=$unsignedCount; invalid=$invalidCount; publisher=$publisher" -RepairState "manual_review" -Recommendation "Review signature evidence manually. Do not delete or replace files automatically." -TriggerTerms @("sigcheck", "signature", "unsigned", "invalid")
}

$tcpViewDir = Join-Path $resolvedInputRoot "tcpview"
if (Test-Path -LiteralPath $tcpViewDir) {
    $tcpFiles = @(Get-ChildItem -LiteralPath $tcpViewDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @("tcpview.txt", "tcpview.csv") })
    $tcpText = ($tcpFiles | Select-Object -First 5 | ForEach-Object { Read-TextIfExists -Path $_.FullName }) -join "`n"
    $establishedCount = ([regex]::Matches($tcpText, "(?im)\bESTABLISHED\b")).Count
    $listeningCount = ([regex]::Matches($tcpText, "(?im)\bLISTENING\b")).Count
    Add-Finding -List $findings -ToolId "tcpview" -SourcePath $tcpViewDir -Component "network" -Evidence "tcpview files=$($tcpFiles.Count); established=$establishedCount; listening=$listeningCount" -RepairState "manual_review" -Recommendation "Use connection summary as network evidence only. Do not close connections automatically." -TriggerTerms @("tcpview", "network", "connection")
}

$handleDir = Join-Path $resolvedInputRoot "handle"
if (Test-Path -LiteralPath $handleDir) {
    $handleFiles = @(Get-ChildItem -LiteralPath $handleDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq "handle.txt" })
    $handleText = ($handleFiles | Select-Object -First 3 | ForEach-Object { Read-TextIfExists -Path $_.FullName }) -join "`n"
    $matchCount = ([regex]::Matches($handleText, "(?im)^\s*[A-Za-z0-9_.-]+(?:\.exe)?\s+pid:")).Count
    Add-Finding -List $findings -ToolId "handle" -SourcePath $handleDir -Component "performance" -Evidence "handle files=$($handleFiles.Count); processSections=$matchCount" -RepairState "manual_review" -Recommendation "Review handle evidence manually. Do not close handles or terminate processes automatically." -TriggerTerms @("handle", "locked file", "process")
}

$autorunsDir = Join-Path $resolvedInputRoot "autoruns"
if (Test-Path -LiteralPath $autorunsDir) {
    $autorunsFiles = @(Get-ChildItem -LiteralPath $autorunsDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in @("autoruns.csv", "autoruns.txt") })
    $autorunsText = ($autorunsFiles | Select-Object -First 3 | ForEach-Object { Read-TextIfExists -Path $_.FullName }) -join "`n"
    $disabledCount = ([regex]::Matches($autorunsText, "(?im)\bdisabled\b")).Count
    $unsignedCount = ([regex]::Matches($autorunsText, "(?im)\b(unsigned|not verified|not signed)\b")).Count
    Add-Finding -List $findings -ToolId "autoruns" -SourcePath $autorunsDir -Component "startup" -Evidence "autoruns files=$($autorunsFiles.Count); disabled=$disabledCount; unsignedOrUnverified=$unsignedCount" -RepairState "manual_review" -Recommendation "Review startup evidence manually. Do not disable startup entries automatically." -TriggerTerms @("autoruns", "startup", "logon", "unsigned")
}

$knownToolDirs = @("process-explorer", "process-monitor", "rammap")
foreach ($toolId in $knownToolDirs) {
    $toolDir = Join-Path $resolvedInputRoot $toolId
    if (Test-Path -LiteralPath $toolDir) {
        $files = @(Get-ChildItem -LiteralPath $toolDir -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 20)
        Add-Finding -List $findings -ToolId $toolId -SourcePath $toolDir -Component "general" -Evidence "Tool output directory exists; files=$($files.Count)" -RepairState "manual_review" -Recommendation "Import as diagnostic evidence for MIS or parser review. Do not convert directly to automatic repair." -TriggerTerms @($toolId)
    }
}

$externalPack = $null
if ($ExternalPackPath) {
    $sourceId = "EXT-SRC-OFFLINE-DIAGNOSTIC-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))"
    $externalFindings = @($findings | ForEach-Object {
        $adapterName = if ($_.ToolId -eq "setupdiag") { "setupdiag" } else { "manual-external" }
        [PSCustomObject]@{
            id = "OFFLINE-$($_.ToolId)-$([Math]::Abs($_.SourcePath.GetHashCode()))"
            adapterName = $adapterName
            sourceTrustLevel = "microsoft_official"
            title = "$($_.ToolId) offline diagnostic evidence"
            component = $_.Component
            symptoms = @($_.Evidence)
            errorCodes = @($_.ErrorCode) | Where-Object { $_ }
            eventIds = @()
            triggerTerms = @($_.TriggerTerms) | Where-Object { $_ }
            evidence = @($_.Evidence, $_.SourcePath) | Where-Object { $_ }
            recommendedActions = @($_.Recommendation)
            riskLevel = "manual_review"
            repairAllowed = $false
            script = "N/A"
            actionType = "manual_review"
            sourceIds = @($sourceId)
        }
    })
    $externalPack = [PSCustomObject]@{
        schemaVersion = 1
        packageTitle = $PackageTitle
        sources = @(
            [PSCustomObject]@{
                id = $sourceId
                vendor = "Microsoft"
                title = "WindowsDoctor offline diagnostic tool output"
                url = "file://$($resolvedInputRoot.Replace('\','/'))"
                sourceType = "external_diagnostic"
                sourceTrustLevel = "microsoft_official"
                retrievedDate = (Get-Date).ToString("yyyy-MM-dd")
            }
        )
        findings = $externalFindings
    }
    $externalParent = Split-Path -Parent $ExternalPackPath
    if ($externalParent -and -not (Test-Path -LiteralPath $externalParent)) {
        New-Item -Path $externalParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ExternalPackPath, ($externalPack | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "offline-diagnostic-output-conversion"
    Root = $resolvedRoot
    InputRoot = $resolvedInputRoot
    ExternalPackPath = $ExternalPackPath
    FindingCount = $findings.Count
    Findings = $findings.ToArray()
    ExternalPackFindingCount = if ($externalPack) { @($externalPack.findings).Count } else { 0 }
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
