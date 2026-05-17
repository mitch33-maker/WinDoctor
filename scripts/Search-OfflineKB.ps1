param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string]$Query = "",
    [string]$Category = "",
    [string]$RuleId = "",
    [int]$Limit = 10,
    [string]$ReportPath = "",
    [switch]$ListCategories,
    [switch]$Details,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
}
if (-not (Test-Path $DatabasePath)) { throw "Offline KB database not found: $DatabasePath" }

$database = Get-Content -Raw -Encoding UTF8 -LiteralPath $DatabasePath | ConvertFrom-Json
$rules = @($database.rules)
$queryText = if ($null -eq $Query) { "" } else { $Query.Trim() }
$categoryText = if ($null -eq $Category) { "" } else { $Category.Trim() }
$ruleIdText = if ($null -eq $RuleId) { "" } else { $RuleId.Trim() }

function ConvertTo-SearchResult {
    param(
        [Parameter(Mandatory = $true)]$Rule,
        [int]$Score = 0
    )

    [PSCustomObject]@{
        score = $Score
        id = $Rule.id
        title = $Rule.title
        category = $Rule.category
        triggers = @($Rule.triggers)
        actionType = $Rule.actionType
        repairAllowed = [bool]$Rule.repairAllowed
        script = $Rule.script
        details = $Rule.details
        sourceFile = $Rule.sourceFile
    }
}

function Write-SearchOutput {
    param(
        [Parameter(Mandatory = $true)]$Result,
        [Parameter(Mandatory = $true)]$ConsoleOutput
    )

    $resultJson = $Result | ConvertTo-Json -Depth 8
    if ($ReportPath) {
        $reportParent = Split-Path -Parent $ReportPath
        if ($reportParent -and -not (Test-Path $reportParent)) {
            New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
        }
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($ReportPath, $resultJson, $utf8NoBom)
    }

    if ($Json) {
        $resultJson
    }
    else {
        $ConsoleOutput
    }
}

if ($ListCategories) {
    $categories = @($rules |
        Group-Object category |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                category = $_.Name
                count = $_.Count
                autoRepair = @($_.Group | Where-Object { $_.repairAllowed -eq $true }).Count
                guided = @($_.Group | Where-Object { $_.actionType -eq "guided" }).Count
                manualReview = @($_.Group | Where-Object { $_.actionType -eq "manual_review" }).Count
            }
        })

    $result = [PSCustomObject]@{
        Status = "PASS"
        Mode = "categories"
        DatabasePath = $DatabasePath
        ReportPath = $ReportPath
        TotalRules = $rules.Count
        CategoryCount = $categories.Count
        Categories = $categories
    }

    Write-SearchOutput -Result $result -ConsoleOutput ($categories | Format-Table -AutoSize)
    return
}

if ($ruleIdText) {
    $selected = @($rules | Where-Object { $_.id -eq $ruleIdText })
    $matches = @($selected | ForEach-Object { ConvertTo-SearchResult -Rule $_ -Score 100 })
}
elseif ($categoryText) {
    $matches = @($rules |
        Where-Object { $_.category -eq $categoryText } |
        Sort-Object id |
        Select-Object -First $Limit |
        ForEach-Object { ConvertTo-SearchResult -Rule $_ })
}

elseif ($queryText) {
    $tokens = @($queryText -split '\s+' | Where-Object { $_ })
    $matches = @($rules | ForEach-Object {
            $rule = $_
            $haystack = @(
                $rule.id
                $rule.title
                $rule.category
                $rule.script
                $rule.actionType
                $rule.details
                @($rule.triggers) -join " "
            ) -join " "
            $score = 0
            foreach ($token in $tokens) {
                if ($haystack.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 1 }
                if (@($rule.triggers | Where-Object { $_.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0) { $score += 2 }
                $ruleId = if ($null -eq $rule.id) { "" } else { [string]$rule.id }
                if ($ruleId.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 2 }
            }
            if ($score -gt 0) {
                ConvertTo-SearchResult -Rule $rule -Score $score
            }
        } | Sort-Object score, id -Descending | Select-Object -First $Limit)
}
else {
    $matches = @($rules | Sort-Object id | Select-Object -First $Limit | ForEach-Object {
            ConvertTo-SearchResult -Rule $_
        })
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Mode = if ($ruleIdText) { "details" } elseif ($categoryText) { "category" } elseif ($queryText) { "search" } else { "list" }
    Query = $queryText
    Category = $categoryText
    RuleId = $ruleIdText
    DatabasePath = $DatabasePath
    ReportPath = $ReportPath
    TotalRules = $rules.Count
    MatchCount = $matches.Count
    Matches = $matches
}

$consoleOutput = if ($Details -or $ruleIdText) {
    $matches | Format-List id, title, category, triggers, actionType, repairAllowed, script, details, sourceFile
}
else {
    $matches |
        Select-Object id, title, actionType, repairAllowed, script |
        Format-Table -AutoSize
}

Write-SearchOutput -Result $result -ConsoleOutput $consoleOutput
