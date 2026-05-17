param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string]$Query = "",
    [string]$RuleId = "",
    [string]$PreviewRepair = "",
    [string]$RunRepair = "",
    [string]$ReportPath = "",
    [switch]$ScanSystem,
    [switch]$SelfTest,
    [switch]$StatusSummary,
    [switch]$RecommendedRepair,
    [switch]$RunRecommendedRepair,
    [switch]$ListCategories,
    [switch]$ValidateDatabase,
    [switch]$ListAllowedRepairs,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
}

$searchScript = Join-Path $normalizedRoot "scripts\Search-OfflineKB.ps1"
$validateScript = Join-Path $normalizedRoot "scripts\Test-OfflineKBDatabase.ps1"
$repairScript = Join-Path $normalizedRoot "scripts\Invoke-AllowedRepair.ps1"
$scanScript = Join-Path $normalizedRoot "scripts\Test-SystemErrorScan.ps1"
$selfTestScript = Join-Path $normalizedRoot "scripts\Test-PortableRuntimeSelfTest.ps1"
$statusScript = Join-Path $normalizedRoot "scripts\Get-PortableRuntimeStatus.ps1"
$recommendedRepairScript = Join-Path $normalizedRoot "scripts\Invoke-RecommendedRepairPlan.ps1"

function Invoke-ChildScript {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $allArguments = @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", $Path) + $Arguments
    if ($ReportPath) { $allArguments += @("-ReportPath", $ReportPath) }
    if ($Json) { $allArguments += "-Json" }
    & powershell @allArguments
}

function New-UiText {
    param([int[]]$Codes)
    [string]::Concat([char[]]$Codes)
}

$uiTitle = New-UiText @(0x0057,0x0069,0x006e,0x0064,0x006f,0x0077,0x0073,0x0044,0x006f,0x0063,0x0074,0x006f,0x0072,0x0020,0x96e2,0x7dda,0x4fee,0x5fa9,0x9078,0x55ae)
$uiM1 = New-UiText @(0x0031,0x002e,0x0020,0x67e5,0x8a62,0x96e2,0x7dda,0x6545,0x969c,0x8cc7,0x6599,0x5eab)
$uiM2 = New-UiText @(0x0032,0x002e,0x0020,0x5217,0x51fa,0x6545,0x969c,0x5206,0x985e)
$uiM3 = New-UiText @(0x0033,0x002e,0x0020,0x986f,0x793a,0x898f,0x5247,0x8a73,0x7d30,0x5167,0x5bb9)
$uiM4 = New-UiText @(0x0034,0x002e,0x0020,0x9a57,0x8b49,0x96e2,0x7dda,0x6545,0x969c,0x8cc7,0x6599,0x5eab)
$uiM5 = New-UiText @(0x0035,0x002e,0x0020,0x5217,0x51fa,0x5141,0x8a31,0x57f7,0x884c,0x7684,0x4fee,0x5fa9,0x8173,0x672c)
$uiM6 = New-UiText @(0x0036,0x002e,0x0020,0x9810,0x89bd,0x4fee,0x5fa9,0x8173,0x672c,0x5167,0x5bb9)
$uiM7 = New-UiText @(0x0037,0x002e,0x0020,0x57f7,0x884c,0x5141,0x8a31,0x6e05,0x55ae,0x5167,0x7684,0x4fee,0x5fa9,0x8173,0x672c)
$uiM8 = New-UiText @(0x0038,0x002e,0x0020,0x6383,0x63cf,0x672c,0x6a5f,0x7cfb,0x7d71,0x8207,0x7db2,0x8def,0x932f,0x8aa4)
$uiM9 = New-UiText @(0x0039,0x002e,0x0020,0x57f7,0x884c,0x53ef,0x651c,0x7248,0x81ea,0x6211,0x6aa2,0x6e2c)
$uiM10 = New-UiText @(0x0031,0x0030,0x002e,0x0020,0x986f,0x793a,0x7248,0x672c,0x8207,0x72c0,0x614b,0x6458,0x8981)
$uiM11 = New-UiText @(0x0031,0x0031,0x002e,0x0020,0x4e00,0x9375,0x6383,0x63cf,0x4e26,0x5efa,0x8b70,0x4fee,0x5fa9)
$uiM0 = New-UiText @(0x0030,0x002e,0x0020,0x96e2,0x958b)
$uiSelect = New-UiText @(0x8acb,0x9078,0x64c7)
$uiQuery = New-UiText @(0x8acb,0x8f38,0x5165,0x932f,0x8aa4,0x78bc,0x6216,0x95dc,0x9375,0x5b57)
$uiPause = New-UiText @(0x6309,0x0020,0x0045,0x006e,0x0074,0x0065,0x0072,0x0020,0x8fd4,0x56de,0x9078,0x55ae)
$uiRuleId = New-UiText @(0x8acb,0x8f38,0x5165,0x898f,0x5247,0x0020,0x0049,0x0044)
$uiScriptName = New-UiText @(0x8acb,0x8f38,0x5165,0x4fee,0x5fa9,0x8173,0x672c,0x6a94,0x540d)
$uiConfirm = New-UiText @(0x82e5,0x78ba,0x8a8d,0x8981,0x57f7,0x884c,0xff0c,0x8acb,0x8f38,0x5165,0x0020,0x0052,0x0055,0x004e)

if ($ListAllowedRepairs) {
    Invoke-ChildScript -Path $repairScript -Arguments @("-Root", $normalizedRoot, "-List")
    return
}

if ($PreviewRepair) {
    Invoke-ChildScript -Path $repairScript -Arguments @("-Root", $normalizedRoot, "-ScriptName", $PreviewRepair, "-Preview")
    return
}

if ($RunRepair) {
    Invoke-ChildScript -Path $repairScript -Arguments @("-Root", $normalizedRoot, "-ScriptName", $RunRepair, "-Execute", "-ConfirmToken", "RUN")
    exit $LASTEXITCODE
}

if ($ScanSystem) {
    Invoke-ChildScript -Path $scanScript -Arguments @("-Root", $normalizedRoot)
    return
}

if ($SelfTest) {
    Invoke-ChildScript -Path $selfTestScript -Arguments @("-Root", $normalizedRoot)
    return
}

if ($StatusSummary) {
    Invoke-ChildScript -Path $statusScript -Arguments @("-Root", $normalizedRoot, "-DatabasePath", $DatabasePath)
    return
}

if ($RecommendedRepair) {
    Invoke-ChildScript -Path $recommendedRepairScript -Arguments @("-Root", $normalizedRoot)
    return
}

if ($RunRecommendedRepair) {
    Invoke-ChildScript -Path $recommendedRepairScript -Arguments @("-Root", $normalizedRoot, "-Execute", "-ConfirmToken", "RUN")
    exit $LASTEXITCODE
}

if ($ValidateDatabase) {
    Invoke-ChildScript -Path $validateScript -Arguments @("-DatabasePath", $DatabasePath)
    return
}

if ($ListCategories) {
    Invoke-ChildScript -Path $searchScript -Arguments @("-DatabasePath", $DatabasePath, "-ListCategories")
    return
}

if ($RuleId) {
    Invoke-ChildScript -Path $searchScript -Arguments @("-DatabasePath", $DatabasePath, "-RuleId", $RuleId)
    return
}

if ($Query) {
    Invoke-ChildScript -Path $searchScript -Arguments @("-DatabasePath", $DatabasePath, "-Query", $Query)
    return
}

while ($true) {
    Clear-Host
    Write-Host $uiTitle
    Write-Host $uiM1
    Write-Host $uiM2
    Write-Host $uiM3
    Write-Host $uiM4
    Write-Host $uiM5
    Write-Host $uiM6
    Write-Host $uiM7
    Write-Host $uiM8
    Write-Host $uiM9
    Write-Host $uiM10
    Write-Host $uiM11
    Write-Host $uiM0
    $choice = Read-Host $uiSelect

    switch ($choice) {
        "1" {
            $text = Read-Host $uiQuery
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $searchScript -DatabasePath $DatabasePath -Query $text
            Read-Host $uiPause
        }
        "2" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $searchScript -DatabasePath $DatabasePath -ListCategories
            Read-Host $uiPause
        }
        "3" {
            $id = Read-Host $uiRuleId
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $searchScript -DatabasePath $DatabasePath -RuleId $id -Details
            Read-Host $uiPause
        }
        "4" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $validateScript -DatabasePath $DatabasePath
            Read-Host $uiPause
        }
        "5" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $repairScript -Root $normalizedRoot -List
            Read-Host $uiPause
        }
        "6" {
            $name = Read-Host $uiScriptName
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $PSCommandPath -Root $normalizedRoot -DatabasePath $DatabasePath -PreviewRepair $name
            Read-Host $uiPause
        }
        "7" {
            $name = Read-Host $uiScriptName
            $confirm = Read-Host $uiConfirm
            if ($confirm -eq "RUN") {
                & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $PSCommandPath -Root $normalizedRoot -DatabasePath $DatabasePath -RunRepair $name
            }
            Read-Host $uiPause
        }
        "8" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $scanScript -Root $normalizedRoot
            Read-Host $uiPause
        }
        "9" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $selfTestScript -Root $normalizedRoot
            Read-Host $uiPause
        }
        "10" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $statusScript -Root $normalizedRoot -DatabasePath $DatabasePath
            Read-Host $uiPause
        }
        "11" {
            & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $recommendedRepairScript -Root $normalizedRoot
            $confirm = Read-Host $uiConfirm
            if ($confirm -eq "RUN") {
                & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $recommendedRepairScript -Root $normalizedRoot -Execute -ConfirmToken RUN
            }
            Read-Host $uiPause
        }
        "0" { return }
    }
}
