param(
    [Parameter(Mandatory = $true)]
    [string]$UsbRoot,
    [string]$PackageName = "WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3",
    [string]$PatchZipPath = "",
    [string]$ReportPath = "",
    [int]$StartupDurationSeconds = 60,
    [int]$StartupIntervalSeconds = 10,
    [switch]$SkipStartup,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$steps = New-Object System.Collections.Generic.List[object]

function Invoke-JsonFileScript {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string[]]$Arguments,
        [switch]$AllowFail
    )

    $startedAt = Get-Date
    $output = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $ScriptPath @Arguments
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    $data = $null
    if ($text) {
        $data = $text | ConvertFrom-Json
    }
    $status = if ($data -and $data.Status) { [string]$data.Status } elseif ($exitCode -eq 0) { "PASS" } else { "FAIL" }
    $script:steps.Add([PSCustomObject]@{
        Name = $Name
        Status = $status
        ExitCode = $exitCode
        Seconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
        ReportPath = if ($data -and $data.ReportPath) { [string]$data.ReportPath } else { "" }
    })
    if (-not $AllowFail -and ($exitCode -ne 0 -or $status -ne "PASS")) {
        throw "$Name failed with status=$status exitCode=$exitCode"
    }
    return $data
}

$resolvedUsbRoot = [System.IO.Path]::GetFullPath($UsbRoot).TrimEnd("\")
$packageRoot = Join-Path $resolvedUsbRoot $PackageName
$wdRoot = Join-Path $packageRoot "WindowsDoctor"
if (-not $PatchZipPath) {
    $latestPatch = Get-ChildItem -LiteralPath $resolvedUsbRoot -Filter "$PackageName-IncrementalPatch-*.zip" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestPatch) {
        $PatchZipPath = $latestPatch.FullName
    }
    else {
        $PatchZipPath = Join-Path $resolvedUsbRoot "$PackageName-IncrementalPatch-20260509-LowResource.zip"
    }
}

$logRoot = if ($ReportPath) { Split-Path -Parent $ReportPath } else { Join-Path $wdRoot "logs" }
if ($logRoot -and -not (Test-Path -LiteralPath $logRoot)) {
    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
}

$localSafetyScript = "E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1"
$entryScript = Join-Path $wdRoot "scripts\Test-UsbLowResourceEntry.ps1"
$releaseScript = "E:\WindowsDoctor\scripts\Test-PortableUsbReleaseValidation.ps1"
$patchScript = Join-Path $wdRoot "scripts\Test-PortableIncrementalPatch.ps1"
$startupScript = Join-Path $wdRoot "scripts\Test-LowResourceStartup.ps1"
$failureMessage = ""

try {
    Invoke-JsonFileScript -Name "resource-safety-before" -ScriptPath $localSafetyScript -Arguments @(
        "-Json"
    ) | Out-Null

    Invoke-JsonFileScript -Name "usb-low-resource-entry" -ScriptPath $entryScript -Arguments @(
        "-UsbRoot", $resolvedUsbRoot,
        "-PackageName", $PackageName,
        "-ReportPath", (Join-Path $logRoot "usb-low-resource-entry.acceptance.json"),
        "-Json"
    ) | Out-Null

    if (-not $SkipStartup) {
        Invoke-JsonFileScript -Name "low-resource-startup" -ScriptPath $startupScript -Arguments @(
            "-Root", $wdRoot,
            "-DurationSeconds", [string]$StartupDurationSeconds,
            "-IntervalSeconds", [string]$StartupIntervalSeconds,
            "-ReportPath", (Join-Path $logRoot "low-resource-startup.acceptance.json"),
            "-Json"
        ) | Out-Null
    }

    Invoke-JsonFileScript -Name "usb-release-validation" -ScriptPath $releaseScript -Arguments @(
        "-PackageRoot", $packageRoot,
        "-ReportPath", (Join-Path $logRoot "release-validation.acceptance.json"),
        "-Json"
    ) | Out-Null

    Invoke-JsonFileScript -Name "incremental-patch-verify" -ScriptPath $patchScript -Arguments @(
        "-PatchZipPath", $PatchZipPath,
        "-PackageRoot", $packageRoot,
        "-ReportPath", (Join-Path $logRoot "incremental-patch.acceptance.json"),
        "-Json"
    ) | Out-Null

    Invoke-JsonFileScript -Name "resource-safety-after" -ScriptPath $localSafetyScript -Arguments @(
        "-Json"
    ) | Out-Null
}
catch {
    $failureMessage = $_.Exception.Message
}
finally {
    if (Test-Path -LiteralPath (Join-Path $wdRoot "scripts\Stop-WindowsDoctorServices.ps1")) {
        & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $wdRoot "scripts\Stop-WindowsDoctorServices.ps1") -Root $wdRoot | Out-Null
    }
}

$stepArray = @($steps.ToArray())
$result = [PSCustomObject]@{
    Status = if ($failureMessage -or $stepArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Phase = "usb-low-resource-acceptance"
    UsbRoot = $resolvedUsbRoot
    PackageRoot = $packageRoot
    PatchZipPath = [System.IO.Path]::GetFullPath($PatchZipPath)
    StartupSkipped = [bool]$SkipStartup
    Error = $failureMessage
    Steps = $stepArray
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}

if ($result.Status -eq "FAIL") { exit 1 }
