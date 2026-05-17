param(
    [string]$PackageRoot,
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

if (-not $PackageRoot) {
    throw "PackageRoot is required"
}

$manifestPath = Join-Path $PackageRoot "portable-usb-manifest.json"
$launcherPath = Join-Path $PackageRoot "Start-WindowsDoctor-Portable.cmd"
$guiReadyLauncherPath = Join-Path $PackageRoot "Start-WindowsDoctor-GUI-Ready.cmd"
$guiReadyStopLauncherPath = Join-Path $PackageRoot "Stop-WindowsDoctor-GUI-Ready.cmd"
$wdRoot = Join-Path $PackageRoot "WindowsDoctor"
$offlineDb = Join-Path $wdRoot "offline_database\windowsdoctor-kb.json"
$normalizedDb = Join-Path $wdRoot "offline_database\windowsdoctor-kb-normalized.json"
$menuScript = Join-Path $wdRoot "scripts\Start-WinPEOfflineMenu.ps1"
$guiReadyPreflightScript = Join-Path $wdRoot "scripts\Test-GuiReadyTargetPreflight.ps1"
$guiReadyCacheScript = Join-Path $wdRoot "scripts\Test-GuiReadyCache.ps1"
$guiReadyStopScript = Join-Path $wdRoot "scripts\Stop-GuiReadySession.ps1"
$selectorScript = Join-Path $wdRoot "scripts\New-UsbPackageSelectorPage.ps1"
$allowlistPath = Join-Path $wdRoot "scripts\repair-allowlist.json"
$nextBuildPath = Join-Path $wdRoot "gui\.next"

Add-Check -Name "package-root-exists" -Passed (Test-Path -LiteralPath $PackageRoot) -Detail $PackageRoot
Add-Check -Name "manifest-exists" -Passed (Test-Path -LiteralPath $manifestPath) -Detail $manifestPath
Add-Check -Name "launcher-exists" -Passed (Test-Path -LiteralPath $launcherPath) -Detail $launcherPath
Add-Check -Name "gui-ready-launcher-exists" -Passed (Test-Path -LiteralPath $guiReadyLauncherPath) -Detail $guiReadyLauncherPath
Add-Check -Name "gui-ready-stop-launcher-exists" -Passed (Test-Path -LiteralPath $guiReadyStopLauncherPath) -Detail $guiReadyStopLauncherPath
Add-Check -Name "windowsdoctor-root-exists" -Passed (Test-Path -LiteralPath $wdRoot) -Detail $wdRoot
Add-Check -Name "offline-db-exists" -Passed (Test-Path -LiteralPath $offlineDb) -Detail $offlineDb
Add-Check -Name "normalized-db-exists" -Passed (Test-Path -LiteralPath $normalizedDb) -Detail $normalizedDb
Add-Check -Name "menu-script-exists" -Passed (Test-Path -LiteralPath $menuScript) -Detail $menuScript
Add-Check -Name "gui-ready-preflight-script-exists" -Passed (Test-Path -LiteralPath $guiReadyPreflightScript) -Detail $guiReadyPreflightScript
Add-Check -Name "gui-ready-cache-script-exists" -Passed (Test-Path -LiteralPath $guiReadyCacheScript) -Detail $guiReadyCacheScript
Add-Check -Name "gui-ready-stop-script-exists" -Passed (Test-Path -LiteralPath $guiReadyStopScript) -Detail $guiReadyStopScript
Add-Check -Name "usb-selector-script-exists" -Passed (Test-Path -LiteralPath $selectorScript) -Detail $selectorScript
Add-Check -Name "allowlist-exists" -Passed (Test-Path -LiteralPath $allowlistPath) -Detail $allowlistPath
Add-Check -Name "no-next-build-cache" -Passed (-not (Test-Path -LiteralPath $nextBuildPath)) -Detail $nextBuildPath

if (Test-Path -LiteralPath $manifestPath) {
    $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
    Add-Check -Name "manifest-phase" -Passed ($manifest.Phase -eq "portable-usb") -Detail ([string]$manifest.Phase)
    Add-Check -Name "manifest-installer-deferred" -Passed ($manifest.InstallerPhase -eq "deferred") -Detail ([string]$manifest.InstallerPhase)
    Add-Check -Name "manifest-file-count" -Passed ([int]$manifest.FileCount -gt 0) -Detail ([string]$manifest.FileCount)
}

if (Test-Path -LiteralPath $offlineDb) {
    $database = Get-Content -Raw -Encoding UTF8 -LiteralPath $offlineDb | ConvertFrom-Json
    Add-Check -Name "offline-db-rules" -Passed ([int]$database.stats.totalRules -gt 0) -Detail ([string]$database.stats.totalRules)
    Add-Check -Name "offline-db-auto-repairs" -Passed ([int]$database.stats.autoRepairRules -gt 0) -Detail ([string]$database.stats.autoRepairRules)
}

if (Test-Path -LiteralPath $normalizedDb) {
    $normalizedDatabase = Get-Content -Raw -Encoding UTF8 -LiteralPath $normalizedDb | ConvertFrom-Json
    Add-Check -Name "normalized-db-records" -Passed ([int]$normalizedDatabase.stats.totalRecords -ge 70) -Detail ([string]$normalizedDatabase.stats.totalRecords)
    Add-Check -Name "normalized-db-public-sources" -Passed ([int]$normalizedDatabase.stats.sourceCount -ge 6) -Detail ([string]$normalizedDatabase.stats.sourceCount)
}

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    PackageRoot = $PackageRoot
    ReportPath = $ReportPath
    Checks = $checkArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
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
