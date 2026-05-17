param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$allowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
$policyPath = Join-Path $normalizedRoot "scripts\repair-safety-policy.json"

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )
    [PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }
}

if (-not (Test-Path -LiteralPath $allowlistPath)) { throw "Allowlist not found: $allowlistPath" }
if (-not (Test-Path -LiteralPath $policyPath)) { throw "Safety policy not found: $policyPath" }

$allowlist = Get-Content -Raw -Encoding UTF8 -LiteralPath $allowlistPath | ConvertFrom-Json
$policy = Get-Content -Raw -Encoding UTF8 -LiteralPath $policyPath | ConvertFrom-Json
$allowlistedScripts = @($allowlist.scripts | ForEach-Object { [string]$_ })
$policyScripts = @($policy.scripts)
$policyNames = @($policyScripts | ForEach-Object { [string]$_.scriptName })

$missingPolicy = @($allowlistedScripts | Where-Object { $_ -notin $policyNames })
$unknownPolicy = @($policyNames | Where-Object { $_ -notin $allowlistedScripts })
$autoBatch = @($policyScripts | Where-Object { [bool]$_.autoBatchAllowed -eq $true })
$unsafeAutoBatch = @($autoBatch | Where-Object {
        [string]$_.allowlistReviewStatus -ne [string]$policy.minimumAutoBatchReviewStatus -or
        [bool]$_.reversible -ne $true -or
        [bool]$_.dryRunImpactAvailable -ne $true -or
        [string]$_.localValidationStatus -ne "PASS" -or
        [bool]$_.criticalInterruption -eq $true -or
        [bool]$_.rollbackGuidanceAvailable -ne $true -or
        [bool]$_.runGateRequired -ne $true
    })
$highRiskAutoBatch = @($autoBatch | Where-Object { [string]$_.riskLevel -eq "high" })
$missingRollback = @($policyScripts | Where-Object { -not $_.rollbackGuidance -or [string]$_.rollbackGuidance -eq "" })
$missingRunGate = @($policyScripts | Where-Object { [bool]$_.runGateRequired -ne $true })

$checks = @(
    Add-Check -Name "schema-version" -Pass ([int]$policy.schemaVersion -ge 1) -Detail "schemaVersion=$($policy.schemaVersion)"
    Add-Check -Name "allowlist-policy-coverage" -Pass ($missingPolicy.Count -eq 0) -Detail "missing=$($missingPolicy -join ',')"
    Add-Check -Name "policy-no-unknown-scripts" -Pass ($unknownPolicy.Count -eq 0) -Detail "unknown=$($unknownPolicy -join ',')"
    Add-Check -Name "auto-batch-safety-gates" -Pass ($unsafeAutoBatch.Count -eq 0) -Detail "unsafe=$($unsafeAutoBatch.scriptName -join ',')"
    Add-Check -Name "high-risk-auto-batch-blocked" -Pass ($highRiskAutoBatch.Count -eq 0) -Detail "highRisk=$($highRiskAutoBatch.scriptName -join ',')"
    Add-Check -Name "rollback-guidance-present" -Pass ($missingRollback.Count -eq 0) -Detail "missing=$($missingRollback.scriptName -join ',')"
    Add-Check -Name "run-gate-required" -Pass ($missingRunGate.Count -eq 0) -Detail "missing=$($missingRunGate.scriptName -join ',')"
)

$failed = @($checks | Where-Object { $_.Status -ne "PASS" })
$result = [PSCustomObject]@{
    Status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "auto-repair-safety-policy"
    Root = $normalizedRoot
    AllowlistPath = $allowlistPath
    PolicyPath = $policyPath
    AllowlistedCount = $allowlistedScripts.Count
    PolicyScriptCount = $policyScripts.Count
    AutoBatchAllowedCount = $autoBatch.Count
    Checks = $checks
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

if ($Json) { $resultJson } else { $result }
if ($result.Status -ne "PASS") { exit 1 }
