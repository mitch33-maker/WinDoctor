param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$Root = "E:\WindowsDoctor",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$allowedTrustLevels = @(
    "microsoft_official",
    "vendor_official",
    "enterprise_tool",
    "notebooklm_export",
    "local_learned",
    "community_unverified"
)

$allowedAdapters = @(
    "setupdiag",
    "gethelpcmd",
    "dism",
    "sfc",
    "eventlog",
    "intune-remediation-export",
    "wazuh-vulnerability-export",
    "rmm-export",
    "manual-external"
)

function Normalize-Id {
    param(
        [string]$Value,
        [string]$Prefix
    )
    $normalized = ($Value -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
    if (-not $normalized) { throw "Id is required" }
    if ($normalized -notmatch "^$Prefix") { $normalized = "$Prefix$normalized" }
    return $normalized
}

function Get-StringArray {
    param([object]$Value)
    @($Value) | Where-Object { $_ } | ForEach-Object { [string]$_ } | Where-Object { $_.Trim() } | Select-Object -Unique
}

function Get-IntArray {
    param([object]$Value)
    @($Value) | Where-Object { $_ -ne $null -and "$_" -match '^\d+$' } | ForEach-Object { [int]$_ } | Select-Object -Unique
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $OutputPath) {
    $OutputPath = Join-Path $normalizedRoot "offline_database\external-diagnostic-sources.json"
}
if (-not (Test-Path -LiteralPath $InputPath)) { throw "InputPath not found: $InputPath" }

$input = Get-Content -Raw -Encoding UTF8 -LiteralPath $InputPath | ConvertFrom-Json
$inputSources = @($input.sources)
$inputFindings = @($input.findings)
if ($inputFindings.Count -eq 0) { throw "External diagnostics pack contains no findings" }

$sourceMap = @{}
$sources = New-Object System.Collections.Generic.List[object]
foreach ($source in $inputSources) {
    $sourceId = Normalize-Id -Value ([string]$source.id) -Prefix "EXT-SRC-"
    if ($sourceMap.ContainsKey($sourceId)) { continue }

    $url = [string]$source.url
    if ($url -and $url -notmatch '^(https?|file)://') {
        throw "Unsupported source URL for ${sourceId}: $url"
    }

    $trustLevel = if ($source.sourceTrustLevel) { [string]$source.sourceTrustLevel } elseif ($source.trustLevel) { [string]$source.trustLevel } else { "vendor_official" }
    if ($trustLevel -notin $allowedTrustLevels) {
        throw "Invalid sourceTrustLevel for ${sourceId}: $trustLevel"
    }

    $sourceMap[$sourceId] = $true
    $sources.Add([PSCustomObject]@{
        id = $sourceId
        vendor = if ($source.vendor) { [string]$source.vendor } else { "External" }
        title = if ($source.title) { [string]$source.title } else { $sourceId }
        url = $url
        sourceType = if ($source.sourceType) { [string]$source.sourceType } else { "external_diagnostic" }
        sourceTrustLevel = $trustLevel
        retrievedDate = if ($source.retrievedDate) { [string]$source.retrievedDate } else { (Get-Date).ToString("yyyy-MM-dd") }
    })
}

$findings = New-Object System.Collections.Generic.List[object]
foreach ($finding in $inputFindings) {
    $findingId = Normalize-Id -Value ([string]$finding.id) -Prefix "EXT-"

    $adapterName = if ($finding.adapterName) { [string]$finding.adapterName } else { "manual-external" }
    if ($adapterName -notin $allowedAdapters) {
        throw "Invalid adapterName for ${findingId}: $adapterName"
    }

    $trustLevel = if ($finding.sourceTrustLevel) { [string]$finding.sourceTrustLevel } else { "vendor_official" }
    if ($trustLevel -notin $allowedTrustLevels) {
        throw "Invalid sourceTrustLevel for ${findingId}: $trustLevel"
    }

    $riskLevel = if ($finding.riskLevel) { [string]$finding.riskLevel } else { "manual_review" }
    if ($riskLevel -notin @("low", "medium", "manual_review")) {
        throw "Invalid riskLevel for ${findingId}: $riskLevel"
    }

    $sourceIds = @(Get-StringArray -Value $finding.sourceIds | ForEach-Object { Normalize-Id -Value $_ -Prefix "EXT-SRC-" })
    foreach ($sourceId in $sourceIds) {
        if (-not $sourceMap.ContainsKey($sourceId)) {
            throw "Finding $findingId references missing source: $sourceId"
        }
    }

    $findings.Add([PSCustomObject]@{
        id = $findingId
        adapterName = $adapterName
        sourceTrustLevel = $trustLevel
        title = if ($finding.title) { [string]$finding.title } else { $findingId }
        component = if ($finding.component) { [string]$finding.component } else { "system" }
        symptoms = @(Get-StringArray -Value $finding.symptoms)
        errorCodes = @(Get-StringArray -Value $finding.errorCodes)
        eventIds = @(Get-IntArray -Value $finding.eventIds)
        triggerTerms = @(Get-StringArray -Value $finding.triggerTerms)
        evidence = @(Get-StringArray -Value $finding.evidence)
        recommendedActions = @(Get-StringArray -Value $finding.recommendedActions)
        riskLevel = $riskLevel
        repairAllowed = $false
        script = "N/A"
        actionType = "manual_review"
        sourceIds = $sourceIds
    })
}

$output = [PSCustomObject]@{
    schemaVersion = 1
    packageTitle = if ($input.packageTitle) { [string]$input.packageTitle } else { "External Diagnostics Sources" }
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    sources = @($sources.ToArray() | Sort-Object id)
    findings = @($findings.ToArray() | Sort-Object id)
}

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
    New-Item -Path $outputParent -ItemType Directory -Force | Out-Null
}
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, ($output | ConvertTo-Json -Depth 10), $utf8NoBom)

$summary = [PSCustomObject]@{
    Status = "PASS"
    InputPath = $InputPath
    OutputPath = $OutputPath
    SourceCount = @($output.sources).Count
    FindingCount = @($output.findings).Count
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
