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

function Read-JsonFile {
    param([string]$Path)
    Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
}

function New-UiText {
    param([int[]]$Codes)
    [string]::Concat([char[]]$Codes)
}

$guiPackagePath = Join-Path $normalizedRoot "gui\package.json"
$allowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
$menuScript = Join-Path $normalizedRoot "scripts\Start-WinPEOfflineMenu.ps1"
$searchScript = Join-Path $normalizedRoot "scripts\Search-OfflineKB.ps1"
$scanScript = Join-Path $normalizedRoot "scripts\Test-SystemErrorScan.ps1"
$selfTestScript = Join-Path $normalizedRoot "scripts\Test-PortableRuntimeSelfTest.ps1"
$manifestPath = Split-Path -Parent $normalizedRoot
$manifestPath = Join-Path $manifestPath "portable-usb-manifest.json"

$version = "unknown"
if (Test-Path -LiteralPath $guiPackagePath) {
    try {
        $version = (Read-JsonFile -Path $guiPackagePath).version
    }
    catch {
        $version = "unreadable"
    }
}

$ruleCount = 0
$autoRepairRules = 0
$guidedRules = 0
if (Test-Path -LiteralPath $DatabasePath) {
    try {
        $database = Read-JsonFile -Path $DatabasePath
        $ruleCount = [int]$database.stats.totalRules
        $autoRepairRules = [int]$database.stats.autoRepairRules
        $guidedRules = [int]$database.stats.guidedRules
    }
    catch {
        $ruleCount = 0
    }
}

$allowlistCount = 0
if (Test-Path -LiteralPath $allowlistPath) {
    try {
        $allowlist = Read-JsonFile -Path $allowlistPath
        if ($allowlist.scripts) {
            $allowlistCount = @($allowlist.scripts).Count
        }
        elseif ($allowlist.repairs) {
            $allowlistCount = @($allowlist.repairs).Count
        }
    }
    catch {
        $allowlistCount = 0
    }
}

$packageName = ""
if (Test-Path -LiteralPath $manifestPath) {
    try {
        $manifest = Read-JsonFile -Path $manifestPath
        $packageName = Split-Path -Leaf $manifest.PackageRoot
    }
    catch {
        $packageName = ""
    }
}

Add-Check -Name "root-exists" -Passed (Test-Path -LiteralPath $normalizedRoot) -Detail $normalizedRoot
Add-Check -Name "version-readable" -Passed ($version -notin @("unknown", "unreadable", "")) -Detail $version
Add-Check -Name "database-exists" -Passed (Test-Path -LiteralPath $DatabasePath) -Detail $DatabasePath
Add-Check -Name "database-rule-count" -Passed ($ruleCount -ge 60) -Detail "rules=$ruleCount autoRepair=$autoRepairRules guided=$guidedRules"
Add-Check -Name "allowlist-exists" -Passed (Test-Path -LiteralPath $allowlistPath) -Detail $allowlistPath
Add-Check -Name "allowlist-count" -Passed ($allowlistCount -ge 6) -Detail "count=$allowlistCount"
Add-Check -Name "menu-script-exists" -Passed (Test-Path -LiteralPath $menuScript) -Detail $menuScript
Add-Check -Name "search-script-exists" -Passed (Test-Path -LiteralPath $searchScript) -Detail $searchScript
Add-Check -Name "scan-script-exists" -Passed (Test-Path -LiteralPath $scanScript) -Detail $scanScript
Add-Check -Name "self-test-script-exists" -Passed (Test-Path -LiteralPath $selfTestScript) -Detail $selfTestScript

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Phase = "portable-usb"
    InstallerPhase = "deferred"
    Root = $normalizedRoot
    PackageName = $packageName
    Version = $version
    DatabasePath = $DatabasePath
    TotalRules = $ruleCount
    AutoRepairRules = $autoRepairRules
    GuidedRules = $guidedRules
    AllowlistRepairs = $allowlistCount
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
    $labelTitle = New-UiText @(0x0057,0x0069,0x006e,0x0064,0x006f,0x0077,0x0073,0x0044,0x006f,0x0063,0x0074,0x006f,0x0072,0x0020,0x7248,0x672c,0x8207,0x72c0,0x614b,0x6458,0x8981)
    $labelStatus = New-UiText @(0x72c0,0x614b)
    $labelVersion = New-UiText @(0x7248,0x672c)
    $labelRules = New-UiText @(0x96e2,0x7dda,0x898f,0x5247)
    $labelRepairs = New-UiText @(0x4fee,0x5fa9,0x8173,0x672c)
    $labelInstaller = New-UiText @(0x5b89,0x88dd,0x7248,0x968e,0x6bb5)
    $labelRoot = New-UiText @(0x6839,0x76ee,0x9304)

    Write-Host $labelTitle
    Write-Host ("{0}: {1}" -f $labelStatus, $result.Status)
    Write-Host ("{0}: {1}" -f $labelVersion, $result.Version)
    Write-Host ("{0}: {1} total / {2} auto / {3} guided" -f $labelRules, $result.TotalRules, $result.AutoRepairRules, $result.GuidedRules)
    Write-Host ("{0}: {1}" -f $labelRepairs, $result.AllowlistRepairs)
    Write-Host ("{0}: {1}" -f $labelInstaller, $result.InstallerPhase)
    Write-Host ("{0}: {1}" -f $labelRoot, $result.Root)
}

if ($result.Status -eq "FAIL") { exit 1 }
