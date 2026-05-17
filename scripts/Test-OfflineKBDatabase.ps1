param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string]$ReportPath = "",
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
$allowlist = @($database.allowlist)
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

Add-Check -Name "schema-version" -Pass ($database.schemaVersion -eq 1) -Detail "schemaVersion=$($database.schemaVersion)"
Add-Check -Name "rules-present" -Pass ($rules.Count -gt 0) -Detail "rules=$($rules.Count)"
Add-Check -Name "stats-total" -Pass ([int]$database.stats.totalRules -eq $rules.Count) -Detail "stats=$($database.stats.totalRules) actual=$($rules.Count)"
Add-Check -Name "stats-reviewed" -Pass ([int]$database.stats.reviewedRules -eq @($rules | Where-Object { $_.category -eq 'reviewed' }).Count) -Detail "reviewed=$($database.stats.reviewedRules)"
Add-Check -Name "stats-learned" -Pass ([int]$database.stats.learnedRules -eq @($rules | Where-Object { $_.category -eq 'learned' }).Count) -Detail "learned=$($database.stats.learnedRules)"
Add-Check -Name "stats-auto-repair" -Pass ([int]$database.stats.autoRepairRules -eq @($rules | Where-Object { $_.repairAllowed -eq $true }).Count) -Detail "autoRepair=$($database.stats.autoRepairRules)"

$missingFields = @($rules | Where-Object {
        -not $_.id -or
        -not $_.title -or
        -not $_.category -or
        -not $_.triggers -or
        -not $_.script -or
        -not $_.actionType -or
        -not $_.sourceFile
    })
Add-Check -Name "rule-required-fields" -Pass ($missingFields.Count -eq 0) -Detail "missing=$($missingFields.Count)"

$invalidCategories = @($rules | Where-Object { $_.category -notin @("reviewed", "learned") })
Add-Check -Name "rule-categories" -Pass ($invalidCategories.Count -eq 0) -Detail "invalid=$($invalidCategories.Count)"

$invalidActions = @($rules | Where-Object { $_.actionType -notin @("auto_repair", "guided", "manual_review") })
Add-Check -Name "rule-action-types" -Pass ($invalidActions.Count -eq 0) -Detail "invalid=$($invalidActions.Count)"

$mojibakePattern = '[�]|[?][]|[蝬蝟撣摰靽雿隞餈璈甇銝][^\x00-\x7F]{1,8}[?]'
$mojibakeRules = @($rules | Where-Object {
        $fields = @(
            [string]$_.title
            [string]$_.details
            (@($_.triggers) -join " ")
        ) -join " "
        $fields -match $mojibakePattern
    })
Add-Check -Name "rule-readable-text" -Pass ($mojibakeRules.Count -eq 0) -Detail "suspect=$($mojibakeRules.Count)"

$invalidScripts = @($rules | Where-Object { $_.script -ne "N/A" -and $_.script -notmatch '^Repair-[A-Za-z0-9_.-]+\.bat$' })
Add-Check -Name "rule-script-names" -Pass ($invalidScripts.Count -eq 0) -Detail "invalid=$($invalidScripts.Count)"

$missingSourceFiles = @($rules | Where-Object { -not (Test-Path (Join-Path $normalizedRoot ($_.sourceFile -replace '/', '\'))) })
Add-Check -Name "rule-source-files" -Pass ($missingSourceFiles.Count -eq 0) -Detail "missing=$($missingSourceFiles.Count)"

$invalidAllowlist = @($allowlist | Where-Object { $_ -notmatch '^Repair-[A-Za-z0-9_.-]+\.bat$' })
Add-Check -Name "allowlist-script-names" -Pass ($invalidAllowlist.Count -eq 0) -Detail "invalid=$($invalidAllowlist.Count)"

$missingAllowlistFiles = @($allowlist | Where-Object { -not (Test-Path (Join-Path $normalizedRoot "scripts\$_")) })
Add-Check -Name "allowlist-files" -Pass ($missingAllowlistFiles.Count -eq 0) -Detail "missing=$($missingAllowlistFiles.Count)"

$unlistedAutoRepair = @($rules | Where-Object { $_.repairAllowed -eq $true -and $_.script -notin $allowlist })
Add-Check -Name "auto-repair-allowlist-match" -Pass ($unlistedAutoRepair.Count -eq 0) -Detail "unlisted=$($unlistedAutoRepair.Count)"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if (@($checkArray | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0) { "FAIL" } else { "PASS" }
    DatabasePath = $DatabasePath
    TotalRules = $rules.Count
    ReportPath = $ReportPath
    Checks = $checkArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
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
    $checks | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
