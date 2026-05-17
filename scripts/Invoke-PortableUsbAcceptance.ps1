param(
    [string]$Root = "E:\WindowsDoctor",
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$ZipPath = "",
    [string]$UsbRoot = "",
    [string]$NodeRuntimePath = "",
    [string]$CacheRoot = "",
    [string]$ReportPath = "",
    [double]$MinFreeMemoryGB = 4,
    [switch]$SkipGuiReadyPreflight,
    [switch]$SkipSelector,
    [switch]$HashManifest,
    [switch]$SummaryOnly,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$steps = New-Object System.Collections.Generic.List[object]

function Add-Step {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail,
        [string]$ReportPath = ""
    )
    $script:steps.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
        ReportPath = $ReportPath
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

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$resolvedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")
if (-not $UsbRoot) {
    $UsbRoot = Split-Path -Parent $resolvedPackageRoot
}
$resolvedUsbRoot = [System.IO.Path]::GetFullPath($UsbRoot).TrimEnd("\")

$reportRoot = if ($ReportPath) {
    Split-Path -Parent $ReportPath
}
else {
    Join-Path $resolvedRoot "logs\portable-usb-acceptance"
}
if (-not $reportRoot) {
    $reportRoot = Join-Path $resolvedRoot "logs\portable-usb-acceptance"
}
if (-not (Test-Path -LiteralPath $reportRoot)) {
    New-Item -Path $reportRoot -ItemType Directory -Force | Out-Null
}

$resourceReport = Join-Path $reportRoot "resource-safety.json"
$manifestReport = Join-Path $reportRoot "zip-manifest.json"
$releaseReport = Join-Path $reportRoot "release-validation.json"
$preflightReport = Join-Path $reportRoot "gui-ready-preflight.json"
$selectorReport = Join-Path $reportRoot "usb-selector.json"

try {
    $resource = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\Test-ResourceSafety.ps1") -Arguments @("-MinFreeMemoryGB", ([string]$MinFreeMemoryGB), "-ReportPath", $resourceReport)
    Add-Step -Name "resource-safety" -Status $resource.Status -Detail "freeMemoryGB=$($resource.FreeMemoryGB)" -ReportPath $resourceReport
}
catch {
    Add-Step -Name "resource-safety" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $resourceReport
}

if ($ZipPath) {
    try {
        $manifestArgs = @("-ZipPath", $ZipPath, "-PackageRoot", $resolvedPackageRoot, "-ReportPath", $manifestReport)
        if ($HashManifest) {
            $manifestArgs += "-Hash"
        }
        $manifest = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\Test-PortableUsbZipManifest.ps1") -Arguments $manifestArgs
        Add-Step -Name "zip-manifest" -Status $manifest.Status -Detail "zipFiles=$($manifest.ZipFileCount) missing=$($manifest.MissingCount) sizeMismatch=$($manifest.SizeMismatchCount) hashMismatch=$($manifest.HashMismatchCount)" -ReportPath $manifestReport
    }
    catch {
        Add-Step -Name "zip-manifest" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $manifestReport
    }
}
else {
    Add-Step -Name "zip-manifest" -Status "SKIP" -Detail "ZipPath not provided" -ReportPath ""
}

try {
    $releaseArgs = @("-PackageRoot", $resolvedPackageRoot, "-ReportPath", $releaseReport)
    if ($ZipPath) {
        $releaseArgs += "-ZipPath"
        $releaseArgs += $ZipPath
    }
    $release = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\Test-PortableUsbReleaseValidation.ps1") -Arguments $releaseArgs
    Add-Step -Name "release-validation" -Status $release.Status -Detail "steps=$(@($release.Steps).Count)" -ReportPath $releaseReport
}
catch {
    Add-Step -Name "release-validation" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $releaseReport
}

if (-not $SkipGuiReadyPreflight) {
    $preflightScript = Join-Path $resolvedPackageRoot "WindowsDoctor\scripts\Test-GuiReadyTargetPreflight.ps1"
    if (Test-Path -LiteralPath $preflightScript) {
        try {
            $preflightArgs = @("-Root", (Join-Path $resolvedPackageRoot "WindowsDoctor"), "-ReportPath", $preflightReport)
            if ($NodeRuntimePath) {
                $preflightArgs += "-NodeRuntimePath"
                $preflightArgs += $NodeRuntimePath
            }
            if ($CacheRoot) {
                $preflightArgs += "-CacheRoot"
                $preflightArgs += $CacheRoot
            }
            $preflight = Invoke-JsonScript -ScriptPath $preflightScript -Arguments $preflightArgs
            Add-Step -Name "gui-ready-preflight" -Status $preflight.Status -Detail "checks=$(@($preflight.Checks).Count)" -ReportPath $preflightReport
        }
        catch {
            Add-Step -Name "gui-ready-preflight" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $preflightReport
        }
    }
    else {
        Add-Step -Name "gui-ready-preflight" -Status "SKIP" -Detail "Script not found: $preflightScript" -ReportPath ""
    }
}
else {
    Add-Step -Name "gui-ready-preflight" -Status "SKIP" -Detail "Skipped by parameter" -ReportPath ""
}

if (-not $SkipSelector) {
    try {
        $selector = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\New-UsbPackageSelectorPage.ps1") -Arguments @("-UsbRoot", $resolvedUsbRoot, "-OutputPath", (Join-Path $resolvedUsbRoot "START_HERE.html"), "-ReportPath", $selectorReport)
        Add-Step -Name "usb-selector" -Status $selector.Status -Detail "packages=$($selector.PackageCount) winPeBootWim=$($selector.WinPEBootWim)" -ReportPath $selectorReport
    }
    catch {
        Add-Step -Name "usb-selector" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $selectorReport
    }
}
else {
    Add-Step -Name "usb-selector" -Status "SKIP" -Detail "Skipped by parameter" -ReportPath ""
}

$stepArray = @($steps.ToArray())
$failedSteps = @($stepArray | Where-Object { $_.Status -eq "FAIL" })
$skippedSteps = @($stepArray | Where-Object { $_.Status -eq "SKIP" })
$summary = [PSCustomObject]@{
    Status = if ($failedSteps.Count -gt 0) { "FAIL" } else { "PASS" }
    PackageRoot = $resolvedPackageRoot
    ZipPath = $ZipPath
    UsbRoot = $resolvedUsbRoot
    StepCount = $stepArray.Count
    FailedStepCount = $failedSteps.Count
    SkippedStepCount = $skippedSteps.Count
    ResourceSafety = (@($stepArray | Where-Object { $_.Name -eq "resource-safety" }) | Select-Object -First 1).Status
    ZipManifest = (@($stepArray | Where-Object { $_.Name -eq "zip-manifest" }) | Select-Object -First 1).Status
    ReleaseValidation = (@($stepArray | Where-Object { $_.Name -eq "release-validation" }) | Select-Object -First 1).Status
    GuiReadyPreflight = (@($stepArray | Where-Object { $_.Name -eq "gui-ready-preflight" }) | Select-Object -First 1).Status
    UsbSelector = (@($stepArray | Where-Object { $_.Name -eq "usb-selector" }) | Select-Object -First 1).Status
}
$result = [PSCustomObject]@{
    Status = $summary.Status
    Phase = "portable-usb"
    InstallerPhase = "deferred"
    Root = $resolvedRoot
    PackageRoot = $resolvedPackageRoot
    ZipPath = $ZipPath
    UsbRoot = $resolvedUsbRoot
    ReportRoot = $reportRoot
    ReportPath = $ReportPath
    Summary = $summary
    Steps = $stepArray
}

$output = if ($SummaryOnly) { $summary } else { $result }
$resultJson = $output | ConvertTo-Json -Depth 8
if ($ReportPath) {
    [System.IO.File]::WriteAllText($ReportPath, ($result | ConvertTo-Json -Depth 8), [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    if ($SummaryOnly) {
        $summary | Format-List
    }
    else {
        $stepArray | Format-Table -AutoSize
    }
}

if ($result.Status -eq "FAIL") { exit 1 }
