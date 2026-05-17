param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
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
    }) | Out-Null
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required file: $Path"
    }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

$indexPath = Join-Path $resolvedRoot "INDEX.md"
$architecturePath = Join-Path $resolvedRoot "DOCUMENTATION_ARCHITECTURE.md"
$memoryPath = Join-Path $resolvedRoot "MEMORY_SYSTEM.md"
$completionLogPath = Join-Path $resolvedRoot "TASK_COMPLETION_LOG.md"
$operationsPath = Join-Path $resolvedRoot "OPERATIONS.md"
$skillPath = Join-Path $resolvedRoot "skills\windowsdoctor-documentation-system\SKILL.md"
$addRecordPath = Join-Path $resolvedRoot "scripts\Add-TaskCompletionRecord.ps1"

$index = Read-Text -Path $indexPath
$architecture = Read-Text -Path $architecturePath
$memory = Read-Text -Path $memoryPath
$completionLog = Read-Text -Path $completionLogPath
$operations = Read-Text -Path $operationsPath
$skill = Read-Text -Path $skillPath

Add-Check -Name "memory-system-indexed" -Passed ($index -match "MEMORY_SYSTEM\.md") -Detail $indexPath
Add-Check -Name "completion-log-indexed" -Passed ($index -match "TASK_COMPLETION_LOG\.md") -Detail $indexPath
Add-Check -Name "skill-indexed" -Passed ($index -match "windowsdoctor-documentation-system") -Detail $indexPath
Add-Check -Name "architecture-load-order-memory" -Passed ($architecture -match "MEMORY_SYSTEM\.md") -Detail $architecturePath
Add-Check -Name "memory-defines-completion-log" -Passed ($memory -match "TASK_COMPLETION_LOG\.md") -Detail $memoryPath
Add-Check -Name "memory-defines-skill-rule" -Passed ($memory -match "Skill") -Detail $memoryPath
Add-Check -Name "completion-log-marker" -Passed ($completionLog -match "New records are inserted below") -Detail $completionLogPath
Add-Check -Name "operations-add-record-command" -Passed ($operations -match "Add-TaskCompletionRecord\.ps1") -Detail $operationsPath
Add-Check -Name "skill-has-safety-gate" -Passed ($skill -match "Test-ResourceSafety\.ps1") -Detail $skillPath
Add-Check -Name "add-record-script-exists" -Passed (Test-Path -LiteralPath $addRecordPath) -Detail $addRecordPath

$status = if (@($checks | Where-Object { $_.Status -ne "PASS" }).Count -eq 0) { "PASS" } else { "FAIL" }
$result = [PSCustomObject]@{
    Status = $status
    Phase = "documentation-memory-system"
    Root = $resolvedRoot
    CheckCount = $checks.Count
    Checks = $checks
    ReportPath = $ReportPath
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
    $result | Format-List
}

if ($status -ne "PASS") {
    exit 1
}
