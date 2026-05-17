param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

function Invoke-JsonScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $ScriptPath @Arguments -Json
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $ScriptPath"
    }
    ($raw | Out-String) | ConvertFrom-Json
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$databasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
$normalizedDatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb-normalized.json"
$allowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
$menuScript = Join-Path $normalizedRoot "scripts\Start-WinPEOfflineMenu.ps1"
$searchScript = Join-Path $normalizedRoot "scripts\Search-OfflineKB.ps1"
$validateScript = Join-Path $normalizedRoot "scripts\Test-OfflineKBDatabase.ps1"
$normalizedValidateScript = Join-Path $normalizedRoot "scripts\Test-NormalizedKBDatabase.ps1"
$repairScript = Join-Path $normalizedRoot "scripts\Invoke-AllowedRepair.ps1"
$scanScript = Join-Path $normalizedRoot "scripts\Test-SystemErrorScan.ps1"
$statusScript = Join-Path $normalizedRoot "scripts\Get-PortableRuntimeStatus.ps1"
$recommendedRepairScript = Join-Path $normalizedRoot "scripts\Invoke-RecommendedRepairPlan.ps1"
$guiReadyPreflightScript = Join-Path $normalizedRoot "scripts\Test-GuiReadyTargetPreflight.ps1"
$guiReadyCacheScript = Join-Path $normalizedRoot "scripts\Test-GuiReadyCache.ps1"
$guiReadyStopScript = Join-Path $normalizedRoot "scripts\Stop-GuiReadySession.ps1"
$selectorScript = Join-Path $normalizedRoot "scripts\New-UsbPackageSelectorPage.ps1"

Add-Check -Name "root-exists" -Passed (Test-Path -LiteralPath $normalizedRoot) -Detail $normalizedRoot
Add-Check -Name "database-exists" -Passed (Test-Path -LiteralPath $databasePath) -Detail $databasePath
Add-Check -Name "normalized-database-exists" -Passed (Test-Path -LiteralPath $normalizedDatabasePath) -Detail $normalizedDatabasePath
Add-Check -Name "allowlist-exists" -Passed (Test-Path -LiteralPath $allowlistPath) -Detail $allowlistPath
Add-Check -Name "menu-script-exists" -Passed (Test-Path -LiteralPath $menuScript) -Detail $menuScript
Add-Check -Name "search-script-exists" -Passed (Test-Path -LiteralPath $searchScript) -Detail $searchScript
Add-Check -Name "scan-script-exists" -Passed (Test-Path -LiteralPath $scanScript) -Detail $scanScript
Add-Check -Name "status-script-exists" -Passed (Test-Path -LiteralPath $statusScript) -Detail $statusScript
Add-Check -Name "recommended-repair-script-exists" -Passed (Test-Path -LiteralPath $recommendedRepairScript) -Detail $recommendedRepairScript
Add-Check -Name "gui-ready-preflight-script-exists" -Passed (Test-Path -LiteralPath $guiReadyPreflightScript) -Detail $guiReadyPreflightScript
Add-Check -Name "gui-ready-cache-script-exists" -Passed (Test-Path -LiteralPath $guiReadyCacheScript) -Detail $guiReadyCacheScript
Add-Check -Name "gui-ready-stop-script-exists" -Passed (Test-Path -LiteralPath $guiReadyStopScript) -Detail $guiReadyStopScript
Add-Check -Name "usb-selector-script-exists" -Passed (Test-Path -LiteralPath $selectorScript) -Detail $selectorScript

try {
    $db = Invoke-JsonScript -ScriptPath $validateScript -Arguments @("-Root", $normalizedRoot, "-DatabasePath", $databasePath)
    Add-Check -Name "offline-db-validation" -Passed ($db.Status -eq "PASS" -and [int]$db.TotalRules -ge 60) -Detail "status=$($db.Status) rules=$($db.TotalRules)"
}
catch {
    Add-Check -Name "offline-db-validation" -Passed $false -Detail $_.Exception.Message
}

try {
    $normalizedDb = Invoke-JsonScript -ScriptPath $normalizedValidateScript -Arguments @("-Root", $normalizedRoot, "-DatabasePath", $normalizedDatabasePath)
    Add-Check -Name "normalized-db-validation" -Passed ($normalizedDb.Status -eq "PASS" -and [int]$normalizedDb.TotalRecords -ge 70 -and [int]$normalizedDb.PublicReferenceRecords -ge 8) -Detail "status=$($normalizedDb.Status) records=$($normalizedDb.TotalRecords) public=$($normalizedDb.PublicReferenceRecords)"
}
catch {
    Add-Check -Name "normalized-db-validation" -Passed $false -Detail $_.Exception.Message
}

try {
    $search = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-DatabasePath", $databasePath, "-Query", "DNS")
    Add-Check -Name "offline-search" -Passed ($search.Status -eq "PASS" -and [int]$search.MatchCount -gt 0) -Detail "matches=$($search.MatchCount)"
}
catch {
    Add-Check -Name "offline-search" -Passed $false -Detail $_.Exception.Message
}

try {
    $repairs = Invoke-JsonScript -ScriptPath $repairScript -Arguments @("-Root", $normalizedRoot, "-List")
    Add-Check -Name "allowlisted-repairs" -Passed ($repairs.Status -eq "PASS" -and [int]$repairs.Count -ge 6) -Detail "count=$($repairs.Count)"
}
catch {
    Add-Check -Name "allowlisted-repairs" -Passed $false -Detail $_.Exception.Message
}

try {
    $scan = Invoke-JsonScript -ScriptPath $scanScript -Arguments @("-Root", $normalizedRoot, "-RecentHours", "1", "-MaxEvents", "20")
    Add-Check -Name "system-network-scan" -Passed ($scan.Status -in @("PASS", "WARN") -and @($scan.Findings).Count -ge 6) -Detail "status=$($scan.Status) findings=$(@($scan.Findings).Count)"
    Add-Check -Name "scan-kb-matching" -Passed ([bool]$scan.KbAvailable -and [int]$scan.KbRuleCount -ge 60 -and [int]$scan.KbMatchCount -gt 0) -Detail "kbAvailable=$($scan.KbAvailable) rules=$($scan.KbRuleCount) matches=$($scan.KbMatchCount)"
}
catch {
    Add-Check -Name "system-network-scan" -Passed $false -Detail $_.Exception.Message
    Add-Check -Name "scan-kb-matching" -Passed $false -Detail $_.Exception.Message
}

try {
    $status = Invoke-JsonScript -ScriptPath $statusScript -Arguments @("-Root", $normalizedRoot, "-DatabasePath", $databasePath)
    Add-Check -Name "portable-status-summary" -Passed ($status.Status -eq "PASS" -and [int]$status.TotalRules -ge 60 -and [int]$status.AllowlistRepairs -ge 6) -Detail "version=$($status.Version) rules=$($status.TotalRules) repairs=$($status.AllowlistRepairs)"
}
catch {
    Add-Check -Name "portable-status-summary" -Passed $false -Detail $_.Exception.Message
}

try {
    $plan = Invoke-JsonScript -ScriptPath $recommendedRepairScript -Arguments @("-Root", $normalizedRoot)
    Add-Check -Name "recommended-repair-preview" -Passed ($plan.Status -eq "PASS" -and $plan.Mode -eq "preview" -and [bool]$plan.Executed -eq $false) -Detail "safeScripts=$($plan.SafeBatchScriptCount) recommended=$($plan.RecommendedRepairCount)"
    Add-Check -Name "recommended-repair-decision-engine-v3" -Passed ([int]$plan.RepairPlanVersion -ge 3 -and [int]$plan.DecisionEngineVersion -ge 3 -and [bool]$plan.SafeBatchExecutionPolicy.StopOnFirstFailure -eq $true) -Detail "plan=$($plan.RepairPlanVersion) engine=$($plan.DecisionEngineVersion) stopOnFailure=$($plan.SafeBatchExecutionPolicy.StopOnFirstFailure)"
}
catch {
    Add-Check -Name "recommended-repair-preview" -Passed $false -Detail $_.Exception.Message
    Add-Check -Name "recommended-repair-decision-engine-v3" -Passed $false -Detail $_.Exception.Message
}

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $normalizedRoot
    ReportPath = $ReportPath
    Checks = $checkArray
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
    $checkArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
