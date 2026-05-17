param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$allowedTrustLevels = @(
    "microsoft_official",
    "vendor_official",
    "enterprise_tool",
    "notebooklm_export",
    "local_learned",
    "community_unverified"
)

$allowedAdapters = @(
    "setupdiag",
    "gethelpcmd",
    "dism",
    "sfc",
    "eventlog",
    "intune-remediation-export",
    "wazuh-vulnerability-export",
    "rmm-export",
    "manual-external"
)

if (-not (Test-Path -LiteralPath $InputPath)) { throw "InputPath not found: $InputPath" }

$pack = Get-Content -Raw -Encoding UTF8 -LiteralPath $InputPath | ConvertFrom-Json
$sources = @($pack.sources)
$findings = @($pack.findings)
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

Add-Check -Name "schema-version" -Pass ($pack.schemaVersion -eq 1) -Detail "schemaVersion=$($pack.schemaVersion)"
Add-Check -Name "sources-present" -Pass ($sources.Count -gt 0) -Detail "sources=$($sources.Count)"
Add-Check -Name "findings-present" -Pass ($findings.Count -gt 0) -Detail "findings=$($findings.Count)"

$invalidSourceUrls = @($sources | Where-Object { $_.url -and $_.url -notmatch '^(https?|file)://' })
Add-Check -Name "source-urls" -Pass ($invalidSourceUrls.Count -eq 0) -Detail "invalid=$($invalidSourceUrls.Count)"

$invalidSourceTrust = @($sources | Where-Object {
        $level = if ($_.sourceTrustLevel) { [string]$_.sourceTrustLevel } elseif ($_.trustLevel) { [string]$_.trustLevel } else { "" }
        $level -notin $allowedTrustLevels
    })
Add-Check -Name "source-trust-levels" -Pass ($invalidSourceTrust.Count -eq 0) -Detail "invalid=$($invalidSourceTrust.Count)"

$invalidAdapters = @($findings | Where-Object { $_.adapterName -and [string]$_.adapterName -notin $allowedAdapters })
Add-Check -Name "adapter-names" -Pass ($invalidAdapters.Count -eq 0) -Detail "invalid=$($invalidAdapters.Count)"

$invalidFindingTrust = @($findings | Where-Object { -not $_.sourceTrustLevel -or [string]$_.sourceTrustLevel -notin $allowedTrustLevels })
Add-Check -Name "finding-trust-levels" -Pass ($invalidFindingTrust.Count -eq 0) -Detail "invalid=$($invalidFindingTrust.Count)"

$invalidRisks = @($findings | Where-Object { $_.riskLevel -and [string]$_.riskLevel -notin @("low", "medium", "manual_review") })
Add-Check -Name "risk-levels" -Pass ($invalidRisks.Count -eq 0) -Detail "invalid=$($invalidRisks.Count)"

$unsafeRepairFields = @($findings | Where-Object { $_.repairAllowed -eq $true -or ($_.script -and [string]$_.script -ne "N/A") })
Add-Check -Name "diagnostic-only" -Pass ($unsafeRepairFields.Count -eq 0) -Detail "unsafe=$($unsafeRepairFields.Count)"

$sourceIds = @($sources | ForEach-Object { ([string]$_.id -replace '[^A-Za-z0-9_.-]', '-').Trim('-') })
$missingRefs = @($findings | Where-Object {
        @($_.sourceIds | Where-Object {
                $id = ([string]$_ -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
                $id -notin $sourceIds
            }).Count -gt 0
    })
Add-Check -Name "source-reference-integrity" -Pass ($missingRefs.Count -eq 0) -Detail "missingRefs=$($missingRefs.Count)"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    InputPath = $InputPath
    SourceCount = $sources.Count
    FindingCount = $findings.Count
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

if ($Json) { $resultJson } else { $checkArray | Format-Table -AutoSize }
if ($result.Status -eq "FAIL") { exit 1 }
