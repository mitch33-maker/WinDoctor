param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-QuotedList {
    param([string]$Value)
    if (-not $Value) { return @() }
    return $Value.Split(",") |
        ForEach-Object { $_.Trim().Trim('"').Trim("'") } |
        Where-Object { $_ }
}

function Normalize-RepairScript {
    param([string]$Script)
    $value = if ($Script) { $Script.Trim().Trim('"').Trim("'") } else { "N/A" }
    if ($value -in @("N/A", "NA", "NONE", "")) { return "N/A" }
    $leaf = ($value -replace '\\', '/') -split '/' | Select-Object -Last 1
    if ($leaf -match '^Repair-[A-Za-z0-9_.-]+\.bat$') { return $leaf }
    return "N/A"
}

function Get-RegexValue {
    param(
        [string]$Content,
        [string]$Pattern
    )
    $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$kbRoot = Join-Path $normalizedRoot "knowledge_base"
$allowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
if (-not $OutputPath) {
    $OutputPath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
}

if (-not (Test-Path $kbRoot)) { throw "knowledge_base not found: $kbRoot" }
if (-not (Test-Path $allowlistPath)) { throw "repair allowlist not found: $allowlistPath" }

$allowlist = @((Get-Content -Raw -Encoding UTF8 -LiteralPath $allowlistPath | ConvertFrom-Json).scripts)
$rules = New-Object System.Collections.Generic.List[object]

foreach ($category in @("reviewed", "learned")) {
    $categoryPath = Join-Path $kbRoot $category
    if (-not (Test-Path $categoryPath)) { continue }

    Get-ChildItem -LiteralPath $categoryPath -Filter "*.md" -File | Sort-Object Name | ForEach-Object {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
        $title = Get-RegexValue -Content $content -Pattern 'Title:\s*"?([^"\r\n]+)"?'
        if (-not $title) { $title = Get-RegexValue -Content $content -Pattern '^#\s+(.+)$' }
        if (-not $title) { $title = $_.BaseName }

        $triggerRaw = Get-RegexValue -Content $content -Pattern 'Trigger:\s*\[(.*?)\]'
        $triggers = @(Get-QuotedList -Value $triggerRaw)
        $errorCode = Get-RegexValue -Content $content -Pattern 'ErrorCode:\s*"?([^"\r\n]+)"?'
        if ($errorCode) { $triggers += $errorCode }
        $triggers = @($triggers | Select-Object -Unique)
        if ($triggers.Count -eq 0) { return }

        $scriptRaw = Get-RegexValue -Content $content -Pattern 'Script:\s*"?([^"\r\n]+)"?'
        if (-not $scriptRaw) {
            $scriptRaw = Get-RegexValue -Content $content -Pattern 'Remediation_Steps:\s*(?:scripts[\\/])?([^"\r\n]+)'
        }
        $script = Normalize-RepairScript -Script $scriptRaw

        $detail = Get-RegexValue -Content $content -Pattern '(?s)## 分析細節[\r\n]+(.+?)(?=\n#|$)'
        if (-not $detail) {
            $detail = Get-RegexValue -Content $content -Pattern '(?s)## 修復方法[\r\n]+(.+?)(?=\n#|$)'
        }
        if (-not $detail) {
            $detail = Get-RegexValue -Content $content -Pattern 'description:\s*"?([^"\r\n]+)"?'
        }
        if (-not $detail) { $detail = "Matched Knowledge Base" }

        $repairAllowed = $allowlist -contains $script
        $actionType = if ($repairAllowed) {
            "auto_repair"
        } elseif ($script -and $script -ne "N/A") {
            "manual_review"
        } else {
            "guided"
        }

        $rules.Add([PSCustomObject]@{
            id = $_.BaseName
            title = $title
            category = $category
            triggers = $triggers
            script = $script
            repairAllowed = $repairAllowed
            actionType = $actionType
            details = $detail
            sourceFile = "knowledge_base/$category/$($_.Name)"
        })
    }
}

$ruleArray = @($rules.ToArray())
$database = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    root = $normalizedRoot
    allowlist = $allowlist
    stats = [PSCustomObject]@{
        totalRules = $ruleArray.Count
        reviewedRules = @($ruleArray | Where-Object { $_.category -eq "reviewed" }).Count
        learnedRules = @($ruleArray | Where-Object { $_.category -eq "learned" }).Count
        autoRepairRules = @($ruleArray | Where-Object { $_.repairAllowed }).Count
        guidedRules = @($ruleArray | Where-Object { $_.actionType -eq "guided" }).Count
        manualReviewRules = @($ruleArray | Where-Object { $_.actionType -eq "manual_review" }).Count
    }
    rules = $ruleArray
}

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) { New-Item -Path $outputDir -ItemType Directory -Force | Out-Null }
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, ($database | ConvertTo-Json -Depth 8), $utf8NoBom)

$summary = [PSCustomObject]@{
    Status = "PASS"
    OutputPath = $OutputPath
    TotalRules = $database.stats.totalRules
    AutoRepairRules = $database.stats.autoRepairRules
    GuidedRules = $database.stats.guidedRules
    ManualReviewRules = $database.stats.manualReviewRules
    ReportPath = $ReportPath
}

$summaryJson = $summary | ConvertTo-Json -Depth 4
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $summaryJson, $utf8NoBom)
}

if ($Json) {
    $summaryJson
}
else {
    $summary | Format-List
}
