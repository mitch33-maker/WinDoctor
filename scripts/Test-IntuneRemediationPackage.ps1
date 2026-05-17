param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

$manifestPath = Join-Path $PackageRoot "intune-remediations-manifest.json"
Add-Check -Name "package-root-exists" -Pass (Test-Path -LiteralPath $PackageRoot) -Detail $PackageRoot
Add-Check -Name "manifest-exists" -Pass (Test-Path -LiteralPath $manifestPath) -Detail $manifestPath

$items = @()
if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    $items = @($manifest.items)
    Add-Check -Name "schema-version" -Pass ($manifest.schemaVersion -eq 1) -Detail "schemaVersion=$($manifest.schemaVersion)"
    Add-Check -Name "items-present" -Pass ($items.Count -gt 0) -Detail "items=$($items.Count)"
    Add-Check -Name "export-does-not-execute" -Pass ($manifest.policy.executesDuringExport -eq $false) -Detail "executesDuringExport=$($manifest.policy.executesDuringExport)"
}

$missingScripts = @($items | Where-Object { -not (Test-Path -LiteralPath $_.detectionScript) -or -not (Test-Path -LiteralPath $_.remediationScript) })
Add-Check -Name "script-files-exist" -Pass ($missingScripts.Count -eq 0) -Detail "missing=$($missingScripts.Count)"

$invalidRisk = @($items | Where-Object { $_.riskLevel -ne "low" -or $_.actionType -ne "auto_repair" -or $_.repairAllowed -ne $true })
Add-Check -Name "low-risk-auto-repair-only" -Pass ($invalidRisk.Count -eq 0) -Detail "invalid=$($invalidRisk.Count)"

$highRiskNames = @($items | Where-Object { $_.repairScript -match '(?i)(BCD|Boot|SystemIntegrity|SystemMaintenance)' })
Add-Check -Name "high-risk-scripts-excluded" -Pass ($highRiskNames.Count -eq 0) -Detail "highRisk=$($highRiskNames.Count)"

$unsafeContent = @()
foreach ($item in $items) {
    if (Test-Path -LiteralPath $item.remediationScript) {
        $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $item.remediationScript
        if ($content -notmatch [regex]::Escape([string]$item.repairScript)) {
            $unsafeContent += $item.repairScript
        }
    }
}
Add-Check -Name "remediation-content-matches-manifest" -Pass ($unsafeContent.Count -eq 0) -Detail "mismatch=$($unsafeContent.Count)"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    PackageRoot = $PackageRoot
    ManifestPath = $manifestPath
    ItemCount = $items.Count
    ReportPath = $ReportPath
    Checks = $checkArray
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $checkArray | Format-Table -AutoSize }
if ($result.Status -eq "FAIL") { exit 1 }
