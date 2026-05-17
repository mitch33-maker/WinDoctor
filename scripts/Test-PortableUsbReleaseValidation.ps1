param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$ZipPath = "",
    [string]$ReportPath = "",
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

function ConvertTo-StepStatus {
    param([bool]$Passed)
    if ($Passed) { "PASS" } else { "FAIL" }
}

$normalizedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")
$wdRoot = Join-Path $normalizedPackageRoot "WindowsDoctor"
$wdScripts = Join-Path $wdRoot "scripts"

$payloadValidationScript = Join-Path $wdScripts "Test-PortableUsbPayload.ps1"
$runtimeSelfTestScript = Join-Path $wdScripts "Test-PortableRuntimeSelfTest.ps1"
$recommendedRepairScript = Join-Path $wdScripts "Invoke-RecommendedRepairPlan.ps1"
$zipManifestScript = Join-Path $PSScriptRoot "Test-PortableUsbZipManifest.ps1"

$reportRoot = if ($ReportPath) {
    Split-Path -Parent $ReportPath
}
else {
    Join-Path $wdRoot "logs"
}
if (-not $reportRoot) {
    $reportRoot = Join-Path $wdRoot "logs"
}
if (-not (Test-Path -LiteralPath $reportRoot)) {
    New-Item -Path $reportRoot -ItemType Directory -Force | Out-Null
}

$payloadReport = Join-Path $reportRoot "portable-usb-release-payload.json"
$runtimeReport = Join-Path $reportRoot "portable-usb-release-runtime-self-test.json"
$recommendedReport = Join-Path $reportRoot "portable-usb-release-recommended-repair.json"
$zipManifestReport = Join-Path $reportRoot "portable-usb-release-zip-manifest.json"

Add-Step -Name "package-root-exists" -Status (ConvertTo-StepStatus (Test-Path -LiteralPath $normalizedPackageRoot)) -Detail $normalizedPackageRoot
Add-Step -Name "windowsdoctor-root-exists" -Status (ConvertTo-StepStatus (Test-Path -LiteralPath $wdRoot)) -Detail $wdRoot
Add-Step -Name "payload-validation-script-exists" -Status (ConvertTo-StepStatus (Test-Path -LiteralPath $payloadValidationScript)) -Detail $payloadValidationScript
Add-Step -Name "runtime-self-test-script-exists" -Status (ConvertTo-StepStatus (Test-Path -LiteralPath $runtimeSelfTestScript)) -Detail $runtimeSelfTestScript
Add-Step -Name "recommended-repair-script-exists" -Status (ConvertTo-StepStatus (Test-Path -LiteralPath $recommendedRepairScript)) -Detail $recommendedRepairScript

if (@($steps.ToArray() | Where-Object { $_.Status -eq "FAIL" }).Count -eq 0) {
    if ($ZipPath) {
        try {
            $zipManifest = Invoke-JsonScript -ScriptPath $zipManifestScript -Arguments @("-ZipPath", $ZipPath, "-PackageRoot", $normalizedPackageRoot, "-ReportPath", $zipManifestReport)
            $detail = "zipFiles=$($zipManifest.ZipFileCount) missing=$($zipManifest.MissingCount) sizeMismatch=$($zipManifest.SizeMismatchCount)"
            Add-Step -Name "zip-manifest" -Status $zipManifest.Status -Detail $detail -ReportPath $zipManifestReport
        }
        catch {
            Add-Step -Name "zip-manifest" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $zipManifestReport
        }
    }

    try {
        $payload = Invoke-JsonScript -ScriptPath $payloadValidationScript -Arguments @("-PackageRoot", $normalizedPackageRoot, "-ReportPath", $payloadReport)
        Add-Step -Name "payload-validation" -Status $payload.Status -Detail "checks=$(@($payload.Checks).Count)" -ReportPath $payloadReport
    }
    catch {
        Add-Step -Name "payload-validation" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $payloadReport
    }

    try {
        $runtime = Invoke-JsonScript -ScriptPath $runtimeSelfTestScript -Arguments @("-Root", $wdRoot, "-ReportPath", $runtimeReport)
        Add-Step -Name "runtime-self-test" -Status $runtime.Status -Detail "checks=$(@($runtime.Checks).Count)" -ReportPath $runtimeReport
    }
    catch {
        Add-Step -Name "runtime-self-test" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $runtimeReport
    }

    try {
        $recommended = Invoke-JsonScript -ScriptPath $recommendedRepairScript -Arguments @("-Root", $wdRoot, "-ReportPath", $recommendedReport)
        $detail = "mode=$($recommended.Mode) executed=$($recommended.Executed) safeScripts=$($recommended.SafeBatchScriptCount) recommended=$($recommended.RecommendedRepairCount)"
        $passed = ($recommended.Status -eq "PASS" -and $recommended.Mode -eq "preview" -and [bool]$recommended.Executed -eq $false)
        Add-Step -Name "recommended-repair-preview" -Status (ConvertTo-StepStatus $passed) -Detail $detail -ReportPath $recommendedReport
    }
    catch {
        Add-Step -Name "recommended-repair-preview" -Status "FAIL" -Detail $_.Exception.Message -ReportPath $recommendedReport
    }
}

$stepArray = @($steps.ToArray())
$result = [PSCustomObject]@{
    Status = if ($stepArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Phase = "portable-usb"
    InstallerPhase = "deferred"
    PackageRoot = $normalizedPackageRoot
    WindowsDoctorRoot = $wdRoot
    ZipPath = $ZipPath
    ZipManifestReport = if ($ZipPath) { $zipManifestReport } else { "" }
    PayloadValidationReport = $payloadReport
    RuntimeSelfTestReport = $runtimeReport
    RecommendedRepairPreviewReport = $recommendedReport
    ReportPath = $ReportPath
    Steps = $stepArray
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $stepArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
