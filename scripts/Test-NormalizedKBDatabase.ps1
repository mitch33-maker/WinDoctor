param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb-normalized.json"
}
if (-not (Test-Path -LiteralPath $DatabasePath)) { throw "Normalized KB database not found: $DatabasePath" }

$database = Get-Content -Raw -Encoding UTF8 -LiteralPath $DatabasePath | ConvertFrom-Json
$records = @($database.records)
$sources = @($database.sources)
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

Add-Check -Name "schema-version" -Pass ($database.schemaVersion -eq 2) -Detail "schemaVersion=$($database.schemaVersion)"
Add-Check -Name "records-present" -Pass ($records.Count -ge 60) -Detail "records=$($records.Count)"
Add-Check -Name "sources-present" -Pass ($sources.Count -gt 0) -Detail "sources=$($sources.Count)"
Add-Check -Name "stats-total" -Pass ([int]$database.stats.totalRecords -eq $records.Count) -Detail "stats=$($database.stats.totalRecords) actual=$($records.Count)"
Add-Check -Name "stats-sources" -Pass ([int]$database.stats.sourceCount -eq $sources.Count) -Detail "stats=$($database.stats.sourceCount) actual=$($sources.Count)"

$duplicateIds = @($records | Group-Object id | Where-Object { $_.Count -gt 1 })
Add-Check -Name "unique-record-ids" -Pass ($duplicateIds.Count -eq 0) -Detail "duplicates=$($duplicateIds.Count)"

$missingFields = @($records | Where-Object {
        -not $_.id -or
        -not $_.title -or
        -not $_.component -or
        -not $_.triggerTerms -or
        -not $_.action -or
        -not $_.action.actionType -or
        -not $_.action.riskLevel -or
        -not $_.provenance -or
        -not $_.provenance.sourceType -or
        -not $_.provenance.sourceTrustLevel
    })
Add-Check -Name "required-fields" -Pass ($missingFields.Count -eq 0) -Detail "missing=$($missingFields.Count)"

$invalidActions = @($records | Where-Object { $_.action.actionType -notin @("auto_repair", "guided", "manual_review") })
Add-Check -Name "action-types" -Pass ($invalidActions.Count -eq 0) -Detail "invalid=$($invalidActions.Count)"

$invalidRisks = @($records | Where-Object { $_.action.riskLevel -notin @("low", "medium", "manual_review") })
Add-Check -Name "risk-levels" -Pass ($invalidRisks.Count -eq 0) -Detail "invalid=$($invalidRisks.Count)"

$invalidTrustLevels = @($records | Where-Object { $_.provenance.sourceTrustLevel -notin @("microsoft_official", "vendor_official", "enterprise_tool", "notebooklm_export", "local_learned", "community_unverified") })
Add-Check -Name "source-trust-levels" -Pass ($invalidTrustLevels.Count -eq 0) -Detail "invalid=$($invalidTrustLevels.Count)"

$invalidOfficialUrls = @($sources | Where-Object {
        ((-not $_.sourceType) -or $_.sourceType -eq "public_official_reference" -or $_.sourceType -eq "microsoft_official") -and
        $_.url -notmatch '^https://(learn|support)\.microsoft\.com/'
    })
Add-Check -Name "official-source-urls" -Pass ($invalidOfficialUrls.Count -eq 0) -Detail "invalid=$($invalidOfficialUrls.Count)"

$invalidNotebookUrls = @($sources | Where-Object { $_.sourceType -eq "notebooklm_export" -and $_.url -and $_.url -notmatch '^(https?|file)://' })
Add-Check -Name "notebooklm-source-urls" -Pass ($invalidNotebookUrls.Count -eq 0) -Detail "invalid=$($invalidNotebookUrls.Count)"

$sourceIds = @($sources | Select-Object -ExpandProperty id)
$missingSourceRefs = @($records | Where-Object {
        $_.provenance.sourceType -in @("public_official_reference", "external_diagnostic_import") -and
        @($_.provenance.sourceIds | Where-Object { $_ -notin $sourceIds }).Count -gt 0
    })
Add-Check -Name "source-reference-integrity" -Pass ($missingSourceRefs.Count -eq 0) -Detail "missingRefs=$($missingSourceRefs.Count)"

$publicRecords = @($records | Where-Object { $_.provenance.sourceType -eq "public_official_reference" })
Add-Check -Name "public-reference-records" -Pass ($publicRecords.Count -ge 8) -Detail "publicRecords=$($publicRecords.Count)"

$notebookLmRecords = @($records | Where-Object { $_.provenance.sourceType -eq "notebooklm_export" })
Add-Check -Name "notebooklm-records" -Pass ($notebookLmRecords.Count -ge 0) -Detail "notebookLMRecords=$($notebookLmRecords.Count)"

$externalDiagnosticRecords = @($records | Where-Object { $_.provenance.sourceType -eq "external_diagnostic_import" })
Add-Check -Name "external-diagnostic-records" -Pass ($externalDiagnosticRecords.Count -ge 0) -Detail "externalDiagnosticRecords=$($externalDiagnosticRecords.Count)"

$unsafeExternalRepairs = @($externalDiagnosticRecords | Where-Object { $_.action.repairAllowed -eq $true -or $_.action.script -ne "N/A" -or $_.action.actionType -ne "manual_review" })
Add-Check -Name "external-diagnostic-safety" -Pass ($unsafeExternalRepairs.Count -eq 0) -Detail "unsafe=$($unsafeExternalRepairs.Count)"

$componentCount = @($records | Select-Object -ExpandProperty component -Unique).Count
Add-Check -Name "component-coverage" -Pass ($componentCount -ge 5) -Detail "components=$componentCount"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    DatabasePath = $DatabasePath
    TotalRecords = $records.Count
    PublicReferenceRecords = $publicRecords.Count
    NotebookLMRecords = $notebookLmRecords.Count
    ExternalDiagnosticRecords = $externalDiagnosticRecords.Count
    SourceCount = $sources.Count
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
