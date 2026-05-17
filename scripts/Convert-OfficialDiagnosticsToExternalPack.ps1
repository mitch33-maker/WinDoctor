param(
    [string]$SetupDiagPath = "",
    [string]$DismLogPath = "",
    [string]$SfcLogPath = "",
    [string]$GetHelpPath = "",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-LogText {
    param([string]$Path)
    if (-not $Path) { return "" }
    if (-not (Test-Path -LiteralPath $Path)) { throw "Input log not found: $Path" }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

function Get-ErrorCodes {
    param([string]$Text)
    @([regex]::Matches($Text, '(?i)0x[0-9a-f]{4,8}') | ForEach-Object { $_.Value.ToUpperInvariant() } | Select-Object -Unique)
}

function Get-FirstMatch {
    param(
        [string]$Text,
        [string[]]$Patterns
    )
    foreach ($pattern in $Patterns) {
        $match = [regex]::Match($Text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            if ($match.Groups.Count -gt 1) { return $match.Groups[1].Value.Trim() }
            return $match.Value.Trim()
        }
    }
    return ""
}

function Add-Source {
    param(
        [System.Collections.Generic.List[object]]$Sources,
        [string]$Id,
        [string]$Title,
        [string]$Url
    )
    $Sources.Add([PSCustomObject]@{
        id = $Id
        vendor = "Microsoft"
        title = $Title
        url = $Url
        sourceType = "microsoft_official"
        sourceTrustLevel = "microsoft_official"
        retrievedDate = (Get-Date).ToString("yyyy-MM-dd")
    })
}

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$Findings,
        [string]$Id,
        [string]$AdapterName,
        [string]$Title,
        [string]$Component,
        [string[]]$Symptoms,
        [string[]]$ErrorCodes,
        [string[]]$TriggerTerms,
        [string[]]$Evidence,
        [string[]]$RecommendedActions,
        [string]$SourceId
    )
    $Findings.Add([PSCustomObject]@{
        id = $Id
        adapterName = $AdapterName
        sourceTrustLevel = "microsoft_official"
        title = $Title
        component = $Component
        symptoms = @($Symptoms | Where-Object { $_ } | Select-Object -Unique)
        errorCodes = @($ErrorCodes | Where-Object { $_ } | Select-Object -Unique)
        eventIds = @()
        triggerTerms = @($TriggerTerms | Where-Object { $_ } | Select-Object -Unique)
        evidence = @($Evidence | Where-Object { $_ } | Select-Object -First 8)
        recommendedActions = @($RecommendedActions | Where-Object { $_ } | Select-Object -Unique)
        riskLevel = "manual_review"
        sourceIds = @($SourceId)
    })
}

if (-not $OutputPath) {
    $OutputPath = "E:\WindowsDoctor\logs\official-diagnostics-pack.latest.json"
}

$sources = New-Object System.Collections.Generic.List[object]
$findings = New-Object System.Collections.Generic.List[object]

if ($SetupDiagPath) {
    $text = Get-LogText -Path $SetupDiagPath
    Add-Source -Sources $sources -Id "MS-SETUPDIAG" -Title "SetupDiag Windows upgrade failure result" -Url "https://learn.microsoft.com/en-in/windows/deployment/upgrade/setupdiag"

    $codes = @(Get-ErrorCodes -Text $text)
    $ruleName = Get-FirstMatch -Text $text -Patterns @('(?m)^\s*Rule(Name)?\s*[:=]\s*(.+)$', '(?m)^\s*Matching Profile found\s*[:=]\s*(.+)$')
    if ($ruleName -match '^(RuleName|Rule)\s*[:=]\s*(.+)$') { $ruleName = $Matches[2].Trim() }
    if (-not $ruleName) { $ruleName = "SetupDiag result" }
    $evidenceLines = @($text -split "`r?`n" | Where-Object { $_ -match '(?i)(rule|error|failure|rollback|profile|setupdiag|0x[0-9a-f]{4,8})' } | Select-Object -First 8)
    Add-Finding -Findings $findings -Id "SETUPDIAG-$(@($codes + 'RESULT')[0])" -AdapterName "setupdiag" -Title $ruleName -Component "windows_update" -Symptoms @("Windows upgrade or setup diagnostic finding") -ErrorCodes $codes -TriggerTerms @("SetupDiag", $ruleName) -Evidence $evidenceLines -RecommendedActions @("Review SetupDiag evidence before retrying Windows upgrade") -SourceId "MS-SETUPDIAG"
}

if ($DismLogPath) {
    $text = Get-LogText -Path $DismLogPath
    Add-Source -Sources $sources -Id "MS-DISM" -Title "Repair a Windows Image" -Url "https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image"

    $codes = @(Get-ErrorCodes -Text $text)
    $evidenceLines = @($text -split "`r?`n" | Where-Object { $_ -match '(?i)(error|corrupt|repairable|restorehealth|scanhealth|component store|0x[0-9a-f]{4,8})' } | Select-Object -First 8)
    $title = if ($text -match '(?i)No component store corruption detected') { "DISM found no component store corruption" } elseif ($text -match '(?i)repairable|corrupt') { "DISM detected component store issue" } else { "DISM diagnostic output captured" }
    Add-Finding -Findings $findings -Id "DISM-$(@($codes + 'RESULT')[0])" -AdapterName "dism" -Title $title -Component "system" -Symptoms @("Windows image servicing diagnostic finding") -ErrorCodes $codes -TriggerTerms @("DISM", "ScanHealth", "RestoreHealth") -Evidence $evidenceLines -RecommendedActions @("Review DISM evidence; repair execution remains manual-review and RUN-gated") -SourceId "MS-DISM"
}

if ($SfcLogPath) {
    $text = Get-LogText -Path $SfcLogPath
    Add-Source -Sources $sources -Id "MS-SFC" -Title "Use the System File Checker tool to repair missing or corrupted system files" -Url "https://support.microsoft.com/help/929833"

    $codes = @(Get-ErrorCodes -Text $text)
    $evidenceLines = @($text -split "`r?`n" | Where-Object { $_ -match '(?i)(Windows Resource Protection|corrupt|integrity|CBS|cannot|could not|0x[0-9a-f]{4,8})' } | Select-Object -First 8)
    $title = if ($text -match '(?i)did not find any integrity violations') { "SFC found no integrity violations" } elseif ($text -match '(?i)found corrupt files') { "SFC found corrupt files" } else { "SFC diagnostic output captured" }
    Add-Finding -Findings $findings -Id "SFC-$(@($codes + 'RESULT')[0])" -AdapterName "sfc" -Title $title -Component "system" -Symptoms @("Windows protected system file diagnostic finding") -ErrorCodes $codes -TriggerTerms @("SFC", "Windows Resource Protection") -Evidence $evidenceLines -RecommendedActions @("Review SFC evidence; repair execution remains manual-review and RUN-gated") -SourceId "MS-SFC"
}

if ($GetHelpPath) {
    $text = Get-LogText -Path $GetHelpPath
    Add-Source -Sources $sources -Id "MS-GETHELP-CMD" -Title "Microsoft Get Help command-line diagnostics" -Url "https://learn.microsoft.com/en-us/troubleshoot/microsoft-365/admin/miscellaneous/get-help-command-line-overview"

    $codes = @(Get-ErrorCodes -Text $text)
    $scenario = Get-FirstMatch -Text $text -Patterns @('(?m)^\s*Scenario\s*[:=]\s*(.+)$', '(?m)^\s*Product\s*[:=]\s*(.+)$', '(?m)^\s*Issue\s*[:=]\s*(.+)$')
    if (-not $scenario) { $scenario = "Get Help command-line result" }
    $evidenceLines = @($text -split "`r?`n" | Where-Object { $_ -match '(?i)(scenario|product|issue|error|result|office|outlook|teams|activation|0x[0-9a-f]{4,8})' } | Select-Object -First 8)
    Add-Finding -Findings $findings -Id "GETHELP-$(@($codes + 'RESULT')[0])" -AdapterName "gethelpcmd" -Title $scenario -Component "microsoft_365" -Symptoms @("Microsoft 365 or app diagnostic finding") -ErrorCodes $codes -TriggerTerms @("GetHelpCmd", $scenario) -Evidence $evidenceLines -RecommendedActions @("Review Get Help output; scrub or reset actions remain manual-review and RUN-gated") -SourceId "MS-GETHELP-CMD"
}

if ($findings.Count -eq 0) {
    throw "No official diagnostic inputs were provided"
}

$pack = [PSCustomObject]@{
    schemaVersion = 1
    packageTitle = "Official Diagnostics Pack"
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    sources = @($sources.ToArray() | Sort-Object id)
    findings = @($findings.ToArray() | Sort-Object id)
}

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
    New-Item -Path $outputParent -ItemType Directory -Force | Out-Null
}
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, ($pack | ConvertTo-Json -Depth 10), $utf8NoBom)

$summary = [PSCustomObject]@{
    Status = "PASS"
    OutputPath = $OutputPath
    SourceCount = $sources.Count
    FindingCount = $findings.Count
    ReportPath = $ReportPath
}

$summaryJson = $summary | ConvertTo-Json -Depth 5
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $summaryJson, $utf8NoBom)
}

if ($Json) { $summaryJson } else { $summary | Format-List }
