param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$Root = "E:\WindowsDoctor",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Normalize-RecordId {
    param([string]$Value)
    $normalized = ($Value -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
    if (-not $normalized) { throw "Record id is required" }
    if ($normalized -notmatch '^NBLM-') { $normalized = "NBLM-$normalized" }
    return $normalized
}

function Normalize-SourceId {
    param([string]$Value)
    $normalized = ($Value -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
    if (-not $normalized) { throw "Source id is required" }
    if ($normalized -notmatch '^NBLM-SRC-') { $normalized = "NBLM-SRC-$normalized" }
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
    $OutputPath = Join-Path $normalizedRoot "offline_database\notebooklm-repair-sources.json"
}
if (-not (Test-Path -LiteralPath $InputPath)) { throw "InputPath not found: $InputPath" }

$input = Get-Content -Raw -Encoding UTF8 -LiteralPath $InputPath | ConvertFrom-Json
$inputSources = @($input.sources)
$inputRecords = @($input.records)
if ($inputRecords.Count -eq 0) { throw "NotebookLM source pack contains no records" }

$sourceMap = @{}
$sources = New-Object System.Collections.Generic.List[object]
foreach ($source in $inputSources) {
    $sourceId = Normalize-SourceId -Value ([string]$source.id)
    if ($sourceMap.ContainsKey($sourceId)) { continue }
    $url = [string]$source.url
    if ($url -and $url -notmatch '^(https?|file)://') {
        throw "Unsupported source URL for ${sourceId}: $url"
    }
    $sourceMap[$sourceId] = $true
    $sources.Add([PSCustomObject]@{
        id = $sourceId
        vendor = if ($source.vendor) { [string]$source.vendor } else { "NotebookLM" }
        title = if ($source.title) { [string]$source.title } else { $sourceId }
        url = $url
        sourceType = if ($source.sourceType) { [string]$source.sourceType } else { "notebooklm_export" }
        retrievedDate = if ($source.retrievedDate) { [string]$source.retrievedDate } else { (Get-Date).ToString("yyyy-MM-dd") }
    })
}

$records = New-Object System.Collections.Generic.List[object]
foreach ($record in $inputRecords) {
    $recordId = Normalize-RecordId -Value ([string]$record.id)
    $sourceIds = @(Get-StringArray -Value $record.sourceIds | ForEach-Object { Normalize-SourceId -Value $_ })
    foreach ($sourceId in $sourceIds) {
        if (-not $sourceMap.ContainsKey($sourceId)) {
            throw "Record $recordId references missing source: $sourceId"
        }
    }

    $actionType = if ($record.actionType) { [string]$record.actionType } else { "guided" }
    if ($actionType -notin @("auto_repair", "guided", "manual_review")) {
        throw "Invalid actionType for ${recordId}: $actionType"
    }

    $riskLevel = if ($record.riskLevel) { [string]$record.riskLevel } else { "manual_review" }
    if ($riskLevel -notin @("low", "medium", "manual_review")) {
        throw "Invalid riskLevel for ${recordId}: $riskLevel"
    }

    $script = if ($record.script) { [string]$record.script } else { "N/A" }
    if ($script -ne "N/A" -and $script -notmatch '^Repair-[A-Za-z0-9_.-]+\.bat$') {
        throw "Invalid repair script for ${recordId}: $script"
    }

    $records.Add([PSCustomObject]@{
        id = $recordId
        title = if ($record.title) { [string]$record.title } else { $recordId }
        component = if ($record.component) { [string]$record.component } else { "system" }
        symptoms = @(Get-StringArray -Value $record.symptoms)
        errorCodes = @(Get-StringArray -Value $record.errorCodes)
        eventIds = @(Get-IntArray -Value $record.eventIds)
        triggerTerms = @(Get-StringArray -Value $record.triggerTerms)
        recommendedActions = @(Get-StringArray -Value $record.recommendedActions)
        script = $script
        actionType = $actionType
        repairAllowed = [bool]$record.repairAllowed
        riskLevel = $riskLevel
        sourceIds = $sourceIds
    })
}

$output = [PSCustomObject]@{
    schemaVersion = 1
    notebookTitle = if ($input.notebookTitle) { [string]$input.notebookTitle } else { "NotebookLM Repair Sources" }
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    sources = @($sources.ToArray() | Sort-Object id)
    records = @($records.ToArray() | Sort-Object id)
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
    RecordCount = @($output.records).Count
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
