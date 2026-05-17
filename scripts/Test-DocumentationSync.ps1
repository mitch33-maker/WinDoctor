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
    $checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

function Test-TextMatch {
    param(
        [string]$Name,
        [string]$Content,
        [string]$Pattern
    )
    Add-Check -Name $Name -Passed ($Content -match $Pattern) -Detail $Pattern
}

$commonPath = Join-Path $Root "COMMON_WINDOWS_ERRORS.md"
$operationsPath = Join-Path $Root "OPERATIONS.md"
$handoffPath = Join-Path $Root "TASK_HANDOFF.md"
$errorHistoryPath = Join-Path $Root "SYSTEM_ERROR_HISTORY.md"
$databasePath = Join-Path $Root "offline_database\windowsdoctor-kb.json"

if (-not (Test-Path -LiteralPath $commonPath)) {
    throw "Missing COMMON_WINDOWS_ERRORS.md"
}
if (-not (Test-Path -LiteralPath $operationsPath)) {
    throw "Missing OPERATIONS.md"
}
if (-not (Test-Path -LiteralPath $handoffPath)) {
    throw "Missing TASK_HANDOFF.md"
}
if (-not (Test-Path -LiteralPath $errorHistoryPath)) {
    throw "Missing SYSTEM_ERROR_HISTORY.md"
}
if (-not (Test-Path -LiteralPath $databasePath)) {
    throw "Missing offline KB database"
}

$common = Get-Content -Raw -Encoding UTF8 -LiteralPath $commonPath
$operations = Get-Content -Raw -Encoding UTF8 -LiteralPath $operationsPath
$handoff = Get-Content -Raw -Encoding UTF8 -LiteralPath $handoffPath
$errorHistory = Get-Content -Raw -Encoding UTF8 -LiteralPath $errorHistoryPath
$database = Get-Content -Raw -Encoding UTF8 -LiteralPath $databasePath | ConvertFrom-Json

Test-TextMatch -Name "common-total-rules" -Content $common -Pattern "Reviewed KB rules: ``$($database.stats.totalRules)``"
Test-TextMatch -Name "common-auto-repair-rules" -Content $common -Pattern "Allowlist .*: ``$($database.stats.autoRepairRules)``"
Test-TextMatch -Name "common-guided-rules" -Content $common -Pattern "``$($database.stats.guidedRules)``"
Test-TextMatch -Name "common-maintenance-trigger" -Content $common -Pattern "SYSTEM_MAINTENANCE"
Test-TextMatch -Name "operations-resource-gate-json" -Content $operations -Pattern "Test-ResourceSafety\.ps1 -Json"
Test-TextMatch -Name "operations-baseline-report" -Content $operations -Pattern "Test-SystemBaseline\.ps1 -SkipServiceSmoke -SkipBuild -ReportPath"
Test-TextMatch -Name "operations-sequential-task-queue" -Content $operations -Pattern "Invoke-WDSequentialTaskQueue\.ps1"
Test-TextMatch -Name "operations-service-status-report" -Content $operations -Pattern "Start-WindowsDoctor\.ps1 -NoGui -NoBroker -ReportPath"
Test-TextMatch -Name "operations-gui-smoke-offline-report" -Content $operations -Pattern "Test-GuiSmoke\.ps1 -AllowOffline -ReportPath"
Test-TextMatch -Name "operations-portable-usb-readiness-report" -Content $operations -Pattern "Test-PortableUsbReadiness\.ps1 -ReportPath"
Test-TextMatch -Name "operations-portable-usb-payload-report" -Content $operations -Pattern "New-PortableUsbPayload\.ps1 -ReportPath"
Test-TextMatch -Name "operations-portable-usb-payload-validate-report" -Content $operations -Pattern "Test-PortableUsbPayload\.ps1 -PackageRoot"
Test-TextMatch -Name "operations-portable-usb-release-validation-report" -Content $operations -Pattern "Test-PortableUsbReleaseValidation\.ps1 -PackageRoot"
Test-TextMatch -Name "operations-normalized-kb-export-report" -Content $operations -Pattern "Export-NormalizedKBDatabase\.ps1 -ReportPath"
Test-TextMatch -Name "operations-notebooklm-import-report" -Content $operations -Pattern "Import-NotebookLMSourcePack\.ps1 -InputPath"
Test-TextMatch -Name "operations-notebooklm-validate-report" -Content $operations -Pattern "Test-NotebookLMSourcePack\.ps1 -InputPath"
Test-TextMatch -Name "operations-external-diagnostics-template" -Content $operations -Pattern "EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE\.json"
Test-TextMatch -Name "operations-external-diagnostics-import-report" -Content $operations -Pattern "Import-ExternalDiagnosticsPack\.ps1 -InputPath"
Test-TextMatch -Name "operations-external-diagnostics-validate-report" -Content $operations -Pattern "Test-ExternalDiagnosticsPack\.ps1 -InputPath"
Test-TextMatch -Name "operations-official-diagnostics-convert-report" -Content $operations -Pattern "Convert-OfficialDiagnosticsToExternalPack\.ps1"
Test-TextMatch -Name "operations-intune-remediation-export-report" -Content $operations -Pattern "Export-IntuneRemediationPackage\.ps1"
Test-TextMatch -Name "operations-intune-remediation-validate-report" -Content $operations -Pattern "Test-IntuneRemediationPackage\.ps1"
Test-TextMatch -Name "operations-normalized-kb-validate-report" -Content $operations -Pattern "Test-NormalizedKBDatabase\.ps1 -ReportPath"
Test-TextMatch -Name "operations-task-handoff-archive-readiness" -Content $operations -Pattern "Test-TaskHandoffArchiveReadiness\.ps1"
Test-TextMatch -Name "operations-portable-usb-publish-zip-flow" -Content $operations -Pattern "Publish-PortableUsbPackage\.ps1 -USBPath"
Test-TextMatch -Name "operations-maintenance-confirmation" -Content $operations -Pattern "Invoke-WindowsMaintenance\.ps1 -Execute -ConfirmToken RUN"
Test-TextMatch -Name "operations-last-updated" -Content $operations -Pattern "Last updated: ``2026-05-17``"
Test-TextMatch -Name "common-last-updated" -Content $common -Pattern "Last updated: ``2026-04-29``"
Test-TextMatch -Name "handoff-last-updated" -Content $handoff -Pattern "Last updated: ``2026-04-29``"
Test-TextMatch -Name "error-history-last-updated" -Content $errorHistory -Pattern "Last updated: ``2026-05-17``"
Test-TextMatch -Name "handoff-current-total-rules" -Content $handoff -Pattern "$($database.stats.totalRules).*reviewed"
Test-TextMatch -Name "handoff-current-auto-repair-rules" -Content $handoff -Pattern "$($database.stats.autoRepairRules).*allowlist"
Test-TextMatch -Name "handoff-current-maintenance-trigger" -Content $handoff -Pattern "SYSTEM_MAINTENANCE"

$staleStats = ($common -match "Reviewed KB rules: ``42``") -or ($common -match "Allowlist .*: ``12``")
Add-Check -Name "common-no-stale-stats" -Passed (-not $staleStats) -Detail "Reject stale 42/12 coverage stats"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $Root
    CommonPath = $commonPath
    OperationsPath = $operationsPath
    HandoffPath = $handoffPath
    ErrorHistoryPath = $errorHistoryPath
    DatabasePath = $databasePath
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
    $checkArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
