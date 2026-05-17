param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$Title = "",
    [string]$ErrorCode = "",
    [string]$Description = "",
    [string]$SourceName = "manual",
    [string]$ScanReportPath = "",
    [switch]$FromScan,
    [switch]$IncludeNoRepairMatches,
    [switch]$NoRebuild,
    [string]$OfflineDatabasePath = "",
    [string]$NormalizedDatabasePath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafeId {
    param([string]$Value)
    $normalized = ($Value -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
    if (-not $normalized) { $normalized = "UNKNOWN" }
    if ($normalized.Length -gt 80) { $normalized = $normalized.Substring(0, 80).Trim('-') }
    return "LEARN-$normalized"
}

function ConvertTo-TriggerList {
    param([string[]]$Values)
    @($Values | Where-Object { $_ } | ForEach-Object {
        '"' + (($_ -replace '"', "'").Trim()) + '"'
    } | Select-Object -Unique) -join ", "
}

function New-LearnedRecord {
    param(
        [string]$RecordTitle,
        [string]$RecordCode,
        [string]$RecordDescription,
        [string]$RecordSource
    )

    $idSeed = if ($RecordCode) { $RecordCode } else { $RecordTitle }
    $id = ConvertTo-SafeId -Value $idSeed
    $triggers = ConvertTo-TriggerList -Values @($RecordCode, $RecordTitle, $RecordSource)
    $safeTitle = ($RecordTitle -replace '"', "'").Trim()
    $safeCode = ($RecordCode -replace '"', "'").Trim()
    $safeSource = ($RecordSource -replace '"', "'").Trim()
    $createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $content = @(
        "---"
        "description: `"$safeTitle`""
        "---"
        "# $safeTitle"
        "Title: `"$safeTitle`""
        "ErrorCode: `"$safeCode`""
        "Trigger: [$triggers]"
        'Script: "N/A"'
        ""
        "## Analysis Details"
        "Source: $safeSource"
        "CreatedAt: $createdAt"
        ""
        $RecordDescription
        ""
        "This case was captured by WindowsDoctor as a learned KB item."
        "No approved repair script is attached. Default handling is diagnostic and manual review only."
    ) -join "`r`n"

    [PSCustomObject]@{
        Id = $id
        Title = $safeTitle
        ErrorCode = $safeCode
        SourceName = $safeSource
        Content = $content
    }
}

function Invoke-JsonPowerShell {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $ScriptPath @Arguments -Json
    if ($LASTEXITCODE -ne 0) { throw "Script failed: $ScriptPath" }
    return (($raw | Out-String).Trim() | ConvertFrom-Json)
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$learnedPath = Join-Path $normalizedRoot "knowledge_base\learned"
if (-not (Test-Path -LiteralPath $learnedPath)) {
    New-Item -Path $learnedPath -ItemType Directory -Force | Out-Null
}

$records = New-Object System.Collections.Generic.List[object]

if ($FromScan) {
    if (-not $ScanReportPath) {
        $ScanReportPath = Join-Path $normalizedRoot "logs\system-error-scan.latest.json"
        $scanScript = Join-Path $normalizedRoot "scripts\Test-SystemErrorScan.ps1"
        Invoke-JsonPowerShell -ScriptPath $scanScript -Arguments @(
            "-Root", $normalizedRoot,
            "-ReportPath", $ScanReportPath
        ) | Out-Null
    }
    if (-not (Test-Path -LiteralPath $ScanReportPath)) { throw "Scan report not found: $ScanReportPath" }
    $scan = Get-Content -Raw -Encoding UTF8 -LiteralPath $ScanReportPath | ConvertFrom-Json
    foreach ($finding in @($scan.Findings)) {
        $isActive = $finding.Status -in @("WARN", "FAIL")
        $hasNoMatch = [int]$finding.KbMatchCount -eq 0
        $hasNoRepair = @($finding.KbMatches).Count -gt 0 -and @($finding.KbMatches | Where-Object { $_.repairAllowed -eq $true -or $_.actionType -eq "auto_repair" }).Count -eq 0
        if ($isActive -and ($hasNoMatch -or ($IncludeNoRepairMatches -and $hasNoRepair))) {
            $recordTitle = if ($hasNoMatch) { "Unknown error: $($finding.Name)" } else { "No auto repair plan: $($finding.Name)" }
            $recordCode = if ($finding.RuleHint) { [string]$finding.RuleHint } else { [string]$finding.Name }
            $recordDescription = @(
                "Status: $($finding.Status)"
                "Detail: $($finding.Detail)"
                "KbMatchCount: $($finding.KbMatchCount)"
            ) -join "`r`n"
            $records.Add((New-LearnedRecord -RecordTitle $recordTitle -RecordCode $recordCode -RecordDescription $recordDescription -RecordSource "system-error-scan"))
        }
    }
}
else {
    if (-not $Title) { $Title = if ($ErrorCode) { "Unknown error: $ErrorCode" } else { "Unknown Windows error" } }
    if (-not $ErrorCode) { $ErrorCode = "UNKNOWN-" + (Get-Date -Format "yyyyMMddHHmmss") }
    if (-not $Description) { $Description = "No description provided." }
    $records.Add((New-LearnedRecord -RecordTitle $Title -RecordCode $ErrorCode -RecordDescription $Description -RecordSource $SourceName))
}

$written = New-Object System.Collections.Generic.List[object]
foreach ($record in @($records.ToArray())) {
    $targetPath = Join-Path $learnedPath "$($record.Id).md"
    if (Test-Path -LiteralPath $targetPath) {
        $record.Id = "$($record.Id)-" + (Get-Date -Format "yyyyMMddHHmmss")
        $targetPath = Join-Path $learnedPath "$($record.Id).md"
    }
    [System.IO.File]::WriteAllText($targetPath, $record.Content, [System.Text.UTF8Encoding]::new($false))
    $written.Add([PSCustomObject]@{
        Id = $record.Id
        Path = $targetPath
        Title = $record.Title
        Script = "N/A"
        ActionType = "guided"
        RepairAllowed = $false
    })
}

$offlineExport = $null
$offlineValidation = $null
$normalizedExport = $null
$normalizedValidation = $null

if (-not $NoRebuild -and $written.Count -gt 0) {
    if (-not $OfflineDatabasePath) { $OfflineDatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json" }
    if (-not $NormalizedDatabasePath) { $NormalizedDatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb-normalized.json" }

    $offlineExport = Invoke-JsonPowerShell -ScriptPath (Join-Path $normalizedRoot "scripts\Export-OfflineKBDatabase.ps1") -Arguments @(
        "-Root", $normalizedRoot,
        "-OutputPath", $OfflineDatabasePath,
        "-ReportPath", (Join-Path $normalizedRoot "logs\offline-kb-export.latest.json")
    )
    $offlineValidation = Invoke-JsonPowerShell -ScriptPath (Join-Path $normalizedRoot "scripts\Test-OfflineKBDatabase.ps1") -Arguments @(
        "-Root", $normalizedRoot,
        "-DatabasePath", $OfflineDatabasePath,
        "-ReportPath", (Join-Path $normalizedRoot "logs\offline-kb-validate.latest.json")
    )
    $normalizedExport = Invoke-JsonPowerShell -ScriptPath (Join-Path $normalizedRoot "scripts\Export-NormalizedKBDatabase.ps1") -Arguments @(
        "-Root", $normalizedRoot,
        "-InputDatabasePath", $OfflineDatabasePath,
        "-OutputPath", $NormalizedDatabasePath,
        "-ReportPath", (Join-Path $normalizedRoot "logs\normalized-kb-export.latest.json")
    )
    $normalizedValidation = Invoke-JsonPowerShell -ScriptPath (Join-Path $normalizedRoot "scripts\Test-NormalizedKBDatabase.ps1") -Arguments @(
        "-Root", $normalizedRoot,
        "-DatabasePath", $NormalizedDatabasePath,
        "-ReportPath", (Join-Path $normalizedRoot "logs\normalized-kb-validate.latest.json")
    )
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Root = $normalizedRoot
    Mode = if ($FromScan) { "scan" } else { "manual" }
    CapturedCount = $written.Count
    LearnedPath = $learnedPath
    Records = @($written.ToArray())
    Rebuilt = (-not $NoRebuild -and $written.Count -gt 0)
    OfflineDatabasePath = $OfflineDatabasePath
    NormalizedDatabasePath = $NormalizedDatabasePath
    OfflineExportStatus = if ($offlineExport) { $offlineExport.Status } else { "" }
    OfflineValidationStatus = if ($offlineValidation) { $offlineValidation.Status } else { "" }
    NormalizedExportStatus = if ($normalizedExport) { $normalizedExport.Status } else { "" }
    NormalizedValidationStatus = if ($normalizedValidation) { $normalizedValidation.Status } else { "" }
    Safety = "learn-only; Script=N/A; repairAllowed=false; allowlist unchanged"
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
