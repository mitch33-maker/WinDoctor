param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [ValidateSet("PASS", "WAITING", "BLOCKED", "PARTIAL")]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Summary,

    [string[]]$EvidencePath = @(),
    [string[]]$ChangedPath = @(),
    [string[]]$NextAction = @(),
    [string]$Root = "E:\WindowsDoctor",
    [string]$LogPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Resolve-UnderRoot {
    param(
        [string]$RootPath,
        [string]$Candidate
    )
    if (-not $Candidate) { return $Candidate }
    if ([System.IO.Path]::IsPathRooted($Candidate)) {
        return [System.IO.Path]::GetFullPath($Candidate)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RootPath $Candidate))
}

function Expand-PathArgument {
    param([string[]]$Value)
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Value) {
        if ($item -and $item.Contains(",")) {
            foreach ($part in ($item -split ",")) {
                if ($part.Trim()) { $items.Add($part.Trim()) | Out-Null }
            }
        }
        elseif ($item) {
            $items.Add($item) | Out-Null
        }
    }
    return @($items)
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $LogPath) {
    $LogPath = Join-Path $resolvedRoot "TASK_COMPLETION_LOG.md"
}
$resolvedLogPath = Resolve-UnderRoot -RootPath $resolvedRoot -Candidate $LogPath

if (-not (Test-Path -LiteralPath $resolvedRoot)) {
    throw "Root not found: $resolvedRoot"
}
if (-not (Test-Path -LiteralPath $resolvedLogPath)) {
    throw "Task completion log not found: $resolvedLogPath"
}

$missingEvidence = New-Object System.Collections.Generic.List[string]
$EvidencePath = Expand-PathArgument -Value $EvidencePath
$ChangedPath = Expand-PathArgument -Value $ChangedPath
$resolvedEvidence = @()
foreach ($path in $EvidencePath) {
    $resolved = Resolve-UnderRoot -RootPath $resolvedRoot -Candidate $path
    $resolvedEvidence += $resolved
    if (-not (Test-Path -LiteralPath $resolved)) {
        $missingEvidence.Add($resolved) | Out-Null
    }
}

if ($missingEvidence.Count -gt 0) {
    throw "Evidence path not found: $($missingEvidence -join '; ')"
}

$resolvedChanged = @()
foreach ($path in $ChangedPath) {
    $resolvedChanged += (Resolve-UnderRoot -RootPath $resolvedRoot -Candidate $path)
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"
$dateKey = Get-Date -Format "yyyyMMdd-HHmmss"

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("## [$dateKey] $Title") | Out-Null
$lines.Add(('- Time: `{0}`' -f $timestamp)) | Out-Null
$lines.Add(('- Status: `{0}`' -f $Status)) | Out-Null
$lines.Add("- Summary: $Summary") | Out-Null
if ($resolvedEvidence.Count -gt 0) {
    $lines.Add("- Evidence:") | Out-Null
    foreach ($path in $resolvedEvidence) {
        $lines.Add(('  - `{0}`' -f $path)) | Out-Null
    }
}
if ($resolvedChanged.Count -gt 0) {
    $lines.Add("- Changed paths:") | Out-Null
    foreach ($path in $resolvedChanged) {
        $lines.Add(('  - `{0}`' -f $path)) | Out-Null
    }
}
if ($NextAction.Count -gt 0) {
    $lines.Add("- Next actions:") | Out-Null
    foreach ($item in $NextAction) {
        $lines.Add("  - $item") | Out-Null
    }
}
$lines.Add("") | Out-Null

$content = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedLogPath
$marker = "<!-- New records are inserted below this line by scripts\Add-TaskCompletionRecord.ps1. -->"
if ($content -notmatch [regex]::Escape($marker)) {
    throw "Completion log marker not found: $resolvedLogPath"
}

$newBlock = ($lines -join [Environment]::NewLine)
$updated = $content.Replace($marker, "$marker$([Environment]::NewLine)$([Environment]::NewLine)$newBlock")
$today = Get-Date -Format "yyyy-MM-dd"
$updated = [regex]::Replace($updated, "Last updated: ``\d{4}-\d{2}-\d{2}``", "Last updated: ``$today``", 1)
[System.IO.File]::WriteAllText($resolvedLogPath, $updated, [System.Text.UTF8Encoding]::new($false))

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "task-completion-record"
    Root = $resolvedRoot
    LogPath = $resolvedLogPath
    Title = $Title
    RecordStatus = $Status
    EvidenceCount = $resolvedEvidence.Count
    ChangedPathCount = $resolvedChanged.Count
    MissingEvidenceCount = 0
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 5
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
