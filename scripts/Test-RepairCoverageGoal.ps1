param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [int]$TargetPercent = 80,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $resolvedRoot "offline_database\windowsdoctor-kb-normalized.json"
}
if (-not (Test-Path -LiteralPath $DatabasePath)) {
    throw "Normalized KB database not found: $DatabasePath"
}

$db = Get-Content -Raw -Encoding UTF8 -LiteralPath $DatabasePath | ConvertFrom-Json
$records = @($db.records)
$components = @("windows_update", "system_integrity", "network", "storage", "boot", "printer", "application", "system", "hardware")
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }) | Out-Null
}

$coveredComponents = @($components | Where-Object {
        $component = $_
        @($records | Where-Object { $_.component -eq $component }).Count -gt 0
    })
$officialComponents = @($components | Where-Object {
        $component = $_
        @($records | Where-Object { $_.component -eq $component -and $_.provenance.sourceTrustLevel -eq "microsoft_official" }).Count -gt 0
    })

$coveragePercent = [math]::Round(($coveredComponents.Count / $components.Count) * 100, 2)
$officialCoveragePercent = [math]::Round(($officialComponents.Count / $components.Count) * 100, 2)
$autoRepairCount = @($records | Where-Object { $_.action.actionType -eq "auto_repair" -and $_.action.repairAllowed -eq $true }).Count
$guidedCount = @($records | Where-Object { $_.action.actionType -eq "guided" }).Count
$manualReviewCount = @($records | Where-Object { $_.action.riskLevel -eq "manual_review" }).Count
$officialCount = @($records | Where-Object { $_.provenance.sourceTrustLevel -eq "microsoft_official" }).Count
$unsafeOfficialAutoRepair = @($records | Where-Object {
        $_.provenance.sourceTrustLevel -eq "microsoft_official" -and
        $_.provenance.sourceType -eq "public_official_reference" -and
        $_.action.repairAllowed -eq $true -and
        $_.action.riskLevel -ne "low"
    })

Add-Check -Name "component-coverage-target" -Pass ($coveragePercent -ge $TargetPercent) -Detail "coverage=$coveragePercent target=$TargetPercent covered=$($coveredComponents.Count)/$($components.Count)"
Add-Check -Name "official-reference-growth" -Pass ($officialCount -ge 20) -Detail "officialRecords=$officialCount"
Add-Check -Name "guided-or-manual-coverage" -Pass (($guidedCount + $manualReviewCount) -gt 0) -Detail "guided=$guidedCount manualReview=$manualReviewCount"
Add-Check -Name "unsafe-official-autorepair-blocked" -Pass ($unsafeOfficialAutoRepair.Count -eq 0) -Detail "unsafe=$($unsafeOfficialAutoRepair.Count)"
Add-Check -Name "auto-repair-not-required-for-coverage" -Pass ($autoRepairCount -ge 0) -Detail "autoRepair=$autoRepairCount"

$result = [PSCustomObject]@{
    Status = if (@($checks | Where-Object { $_.Status -ne "PASS" }).Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "repair-coverage-goal"
    Root = $resolvedRoot
    DatabasePath = $DatabasePath
    TargetPercent = $TargetPercent
    CoveragePercent = $coveragePercent
    OfficialCoveragePercent = $officialCoveragePercent
    Components = $components
    CoveredComponents = $coveredComponents
    OfficialCoveredComponents = $officialComponents
    TotalRecords = $records.Count
    OfficialRecords = $officialCount
    AutoRepairRecords = $autoRepairCount
    GuidedRecords = $guidedCount
    ManualReviewRecords = $manualReviewCount
    Checks = @($checks.ToArray())
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
if ($result.Status -eq "FAIL") { exit 1 }
