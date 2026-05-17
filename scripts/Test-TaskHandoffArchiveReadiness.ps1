param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$HandoffPath = "",
    [string]$ArchiveRoot = "",
    [int]$ThresholdLines = 3500,
    [int]$KeepLatestSections = 3,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $HandoffPath) {
    $HandoffPath = Join-Path $resolvedRoot "TASK_HANDOFF.md"
}
if (-not $ArchiveRoot) {
    $ArchiveRoot = Join-Path $resolvedRoot "docs\archive\task-handoff"
}

$resolvedHandoffPath = [System.IO.Path]::GetFullPath($HandoffPath)
$resolvedArchiveRoot = [System.IO.Path]::GetFullPath($ArchiveRoot).TrimEnd("\")
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    })
}

if (-not (Test-Path -LiteralPath $resolvedHandoffPath)) {
    Add-Check -Name "handoff-exists" -Status "FAIL" -Detail $resolvedHandoffPath
    $lines = @()
}
else {
    Add-Check -Name "handoff-exists" -Status "PASS" -Detail $resolvedHandoffPath
    $lines = @(Get-Content -LiteralPath $resolvedHandoffPath -Encoding UTF8)
}

$lineCount = $lines.Count
$datedHeadings = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(#{1,2})\s+(20\d{2}-\d{2}-\d{2})(.*)$') {
        $datedHeadings += [PSCustomObject]@{
            Line = $i + 1
            Level = $Matches[1].Length
            Date = $Matches[2]
            Title = ($Matches[3].Trim())
            Text = $lines[$i]
        }
    }
}

$firstNonEmpty = @($lines | Where-Object { $_.Trim().Length -gt 0 } | Select-Object -First 1)
$latestAtTop = ($firstNonEmpty.Count -gt 0 -and $firstNonEmpty[0] -match '^#\s+20\d{2}-\d{2}-\d{2}')
Add-Check -Name "latest-status-at-top" -Status $(if ($latestAtTop) { "PASS" } else { "FAIL" }) -Detail $(if ($firstNonEmpty.Count -gt 0) { $firstNonEmpty[0] } else { "empty file" })

$lineStatus = if ($lineCount -ge $ThresholdLines) { "ACTION_REQUIRED" } else { "WAITING" }
Add-Check -Name "archive-threshold" -Status $lineStatus -Detail "Lines=$lineCount Threshold=$ThresholdLines"

$currentSections = @($datedHeadings | Select-Object -First $KeepLatestSections)
$archiveSections = @($datedHeadings | Select-Object -Skip $KeepLatestSections)
$oldestArchiveDate = @($archiveSections | Select-Object -Last 1).Date
$newestArchiveDate = @($archiveSections | Select-Object -First 1).Date
$archiveFileName = if ($archiveSections.Count -gt 0) {
    "TASK_HANDOFF-$oldestArchiveDate-to-$newestArchiveDate.md"
}
else {
    "TASK_HANDOFF-archive.md"
}
$proposedArchivePath = Join-Path $resolvedArchiveRoot $archiveFileName

$hasFailure = @($checks.ToArray() | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0
$status = if ($hasFailure) {
    "FAIL"
}
elseif ($lineCount -ge $ThresholdLines) {
    "ACTION_REQUIRED"
}
else {
    "WAITING"
}

$result = [PSCustomObject]@{
    Status = $status
    Root = $resolvedRoot
    HandoffPath = $resolvedHandoffPath
    ArchiveRoot = $resolvedArchiveRoot
    LineCount = $lineCount
    ThresholdLines = $ThresholdLines
    KeepLatestSections = $KeepLatestSections
    DatedSectionCount = $datedHeadings.Count
    CurrentSectionHeadings = @($currentSections | Select-Object Line, Date, Title)
    ArchiveCandidateSectionCount = $archiveSections.Count
    ProposedArchivePath = $proposedArchivePath
    Checks = @($checks.ToArray())
    NextAction = if ($status -eq "ACTION_REQUIRED") {
        "Create the archive file, move older sections after the latest $KeepLatestSections dated sections, and keep the latest status at the top of TASK_HANDOFF.md."
    }
    elseif ($status -eq "WAITING") {
        "No archive action yet. Recheck when TASK_HANDOFF.md approaches or exceeds the threshold."
    }
    else {
        "Fix failed readiness checks before planning an archive."
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

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}

if ($result.Status -eq "FAIL") { exit 1 }
