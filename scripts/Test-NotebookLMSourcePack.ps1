param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
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

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

if (-not (Test-Path -LiteralPath $InputPath)) { throw "InputPath not found: $InputPath" }

$input = Get-Content -Raw -Encoding UTF8 -LiteralPath $InputPath | ConvertFrom-Json
$inputSources = @($input.sources)
$inputRecords = @($input.records)

Add-Check -Name "sources-present" -Passed ($inputSources.Count -gt 0) -Detail "sources=$($inputSources.Count)"
Add-Check -Name "records-present" -Passed ($inputRecords.Count -gt 0) -Detail "records=$($inputRecords.Count)"

$sourceMap = @{}
$sourceErrors = New-Object System.Collections.Generic.List[string]
foreach ($source in $inputSources) {
    try {
        $sourceId = Normalize-SourceId -Value ([string]$source.id)
        $url = [string]$source.url
        if ($url -and $url -notmatch '^(https?|file)://') {
            $sourceErrors.Add("Unsupported source URL for ${sourceId}: $url")
            continue
        }
        if ($sourceMap.ContainsKey($sourceId)) {
            $sourceErrors.Add("Duplicate source id: $sourceId")
            continue
        }
        $sourceMap[$sourceId] = $true
    }
    catch {
        $sourceErrors.Add($_.Exception.Message)
    }
}
Add-Check -Name "source-shape" -Passed ($sourceErrors.Count -eq 0) -Detail "errors=$($sourceErrors.Count)"

$recordIds = @{}
$recordErrors = New-Object System.Collections.Generic.List[string]
$missingSourceRefs = New-Object System.Collections.Generic.List[string]
$recordsWithSignals = 0
foreach ($record in $inputRecords) {
    try {
        $recordId = Normalize-RecordId -Value ([string]$record.id)
        if ($recordIds.ContainsKey($recordId)) {
            $recordErrors.Add("Duplicate record id: $recordId")
            continue
        }
        $recordIds[$recordId] = $true

        $sourceIds = @(Get-StringArray -Value $record.sourceIds | ForEach-Object { Normalize-SourceId -Value $_ })
        foreach ($sourceId in $sourceIds) {
            if (-not $sourceMap.ContainsKey($sourceId)) {
                $missingSourceRefs.Add("$recordId -> $sourceId")
            }
        }

        $actionType = if ($record.actionType) { [string]$record.actionType } else { "guided" }
        if ($actionType -notin @("auto_repair", "guided", "manual_review")) {
            $recordErrors.Add("Invalid actionType for ${recordId}: $actionType")
        }

        $riskLevel = if ($record.riskLevel) { [string]$record.riskLevel } else { "manual_review" }
        if ($riskLevel -notin @("low", "medium", "manual_review")) {
            $recordErrors.Add("Invalid riskLevel for ${recordId}: $riskLevel")
        }

        $script = if ($record.script) { [string]$record.script } else { "N/A" }
        if ($script -ne "N/A" -and $script -notmatch '^Repair-[A-Za-z0-9_.-]+\.bat$') {
            $recordErrors.Add("Invalid repair script for ${recordId}: $script")
        }

        $signalCount = @(Get-StringArray -Value $record.symptoms).Count +
            @(Get-StringArray -Value $record.errorCodes).Count +
            @(Get-IntArray -Value $record.eventIds).Count +
            @(Get-StringArray -Value $record.triggerTerms).Count
        if ($signalCount -gt 0) {
            $recordsWithSignals += 1
        }
    }
    catch {
        $recordErrors.Add($_.Exception.Message)
    }
}

Add-Check -Name "record-shape" -Passed ($recordErrors.Count -eq 0) -Detail "errors=$($recordErrors.Count)"
Add-Check -Name "source-reference-integrity" -Passed ($missingSourceRefs.Count -eq 0) -Detail "missingRefs=$($missingSourceRefs.Count)"
Add-Check -Name "diagnostic-signals" -Passed ($recordsWithSignals -eq $inputRecords.Count -and $inputRecords.Count -gt 0) -Detail "withSignals=$recordsWithSignals records=$($inputRecords.Count)"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    InputPath = $InputPath
    SourceCount = $inputSources.Count
    RecordCount = $inputRecords.Count
    ReportPath = $ReportPath
    Checks = $checkArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
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
    $checkArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
