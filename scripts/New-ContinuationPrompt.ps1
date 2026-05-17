param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$OutputPath = "",
    [string]$TemplatePath = "",
    [string]$ReportPath = "",
    [int]$TailLines = 140,
    [switch]$SkipResourceSnapshot,
    [switch]$CopyToClipboard,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $OutputPath) {
    $OutputPath = Join-Path $normalizedRoot "NEXT_CHAT_PROMPT.md"
}
if (-not $TemplatePath) {
    $TemplatePath = Join-Path $normalizedRoot "templates\CONTINUATION_PROMPT_TEMPLATE.md"
}

$handoffPath = Join-Path $normalizedRoot "TASK_HANDOFF.md"
$operationsPath = Join-Path $normalizedRoot "OPERATIONS.md"
$errorHistoryPath = Join-Path $normalizedRoot "SYSTEM_ERROR_HISTORY.md"
$commonErrorsPath = Join-Path $normalizedRoot "COMMON_WINDOWS_ERRORS.md"
$resourceScript = Join-Path $normalizedRoot "scripts\Test-ResourceSafety.ps1"

foreach ($path in @($handoffPath, $operationsPath, $errorHistoryPath, $commonErrorsPath, $resourceScript, $TemplatePath)) {
    if (-not (Test-Path $path)) { throw "Required continuation file not found: $path" }
}

function Get-TailText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Count = 140
    )
    (@(Get-Content -Encoding UTF8 -Tail $Count -LiteralPath $Path) -join [Environment]::NewLine).Trim()
}

$resourceJson = ""
if (-not $SkipResourceSnapshot) {
    $resourceJson = (& powershell -NoProfile -ExecutionPolicy RemoteSigned -File $resourceScript -Json | Out-String).Trim()
}

$replacements = @{
    "__RESOURCE_JSON__" = $resourceJson
    "__TASK_HANDOFF_TAIL__" = Get-TailText -Path $handoffPath -Count $TailLines
    "__OPERATIONS_TAIL__" = Get-TailText -Path $operationsPath -Count 80
    "__SYSTEM_ERROR_HISTORY_TAIL__" = Get-TailText -Path $errorHistoryPath -Count 80
}

$prompt = Get-Content -Raw -Encoding UTF8 -LiteralPath $TemplatePath
foreach ($key in $replacements.Keys) {
    $prompt = $prompt.Replace($key, [string]$replacements[$key])
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, $prompt, $utf8NoBom)

if ($CopyToClipboard) {
    Set-Clipboard -Value $prompt
}

$result = [PSCustomObject]@{
    Status = "PASS"
    OutputPath = $OutputPath
    TemplatePath = $TemplatePath
    CopiedToClipboard = [bool]$CopyToClipboard
    Length = $prompt.Length
    TailLines = $TailLines
    ResourceSnapshotIncluded = -not [bool]$SkipResourceSnapshot
    ReportPath = $ReportPath
}

if ($ReportPath) {
    $reportDir = Split-Path -Parent $ReportPath
    if ($reportDir -and -not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    $jsonText = $result | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result | Format-List
}
