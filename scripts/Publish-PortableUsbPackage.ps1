param(
    [string]$Root = "E:\WindowsDoctor",
    [Parameter(Mandatory = $true)]
    [string]$USBPath,
    [string]$PackageName = "",
    [string]$ReportPath = "",
    [switch]$IncludeNodeModules,
    [switch]$IncludeNodeRuntime,
    [string]$NodeRuntimePath = "C:\Program Files\nodejs",
    [switch]$KeepZipOnUsb,
    [switch]$ResumeExistingTarget,
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
        At = (Get-Date).ToString("o")
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

function Write-PublishReport {
    param(
        [string]$Status,
        [string]$ErrorMessage = ""
    )

    $stepArray = @($script:steps.ToArray())
    $targetFiles = @()
    $targetBytes = [int64]0
    if ($script:targetPackageRoot -and (Test-Path -LiteralPath $script:targetPackageRoot)) {
        $targetFiles = @(Get-ChildItem -LiteralPath $script:targetPackageRoot -Recurse -Force -File)
        foreach ($file in $targetFiles) { $targetBytes += [int64]$file.Length }
    }

    $zipBytes = [int64]0
    if ($script:zipPath -and (Test-Path -LiteralPath $script:zipPath)) {
        $zipBytes = [int64](Get-Item -LiteralPath $script:zipPath).Length
    }

    $result = [PSCustomObject]@{
        Status = $Status
        Phase = "portable-usb"
        InstallerPhase = "deferred"
        Error = $ErrorMessage
        Root = $script:Root
        USBPath = $script:usbRoot
        PackageName = $script:PackageName
        SourcePackageRoot = if ($script:payload) { $script:payload.PackageRoot } else { "" }
        TargetPackageRoot = $script:targetPackageRoot
        ZipPath = $script:zipPath
        UsbZipPath = if ($script:KeepZipOnUsb -or (Test-Path -LiteralPath $script:usbZipPath -ErrorAction SilentlyContinue)) { $script:usbZipPath } else { "" }
        ZipBytes = $zipBytes
        TargetFileCount = $targetFiles.Count
        TargetBytes = $targetBytes
        IncludeNodeModules = [bool]$script:IncludeNodeModules
        IncludeNodeRuntime = [bool]$script:IncludeNodeRuntime
        ResumeExistingTarget = [bool]$script:ResumeExistingTarget
        CopiedByZip = [bool]$script:copiedByZip
        ExpandedOnUsb = [bool]$script:expandedOnUsb
        ManifestComparisonReport = $script:manifestReport
        ManifestComparisonStatus = if ($script:manifestCompare) { $script:manifestCompare.Status } else { "" }
        ValidationReport = $script:validationReport
        PayloadValidationReport = if ($script:validation) { $script:validation.PayloadValidationReport } else { "" }
        RuntimeSelfTestReport = if ($script:validation) { $script:validation.RuntimeSelfTestReport } else { "" }
        RecommendedRepairPreviewReport = if ($script:validation) { $script:validation.RecommendedRepairPreviewReport } else { "" }
        SelectorPagePath = if ($script:selector) { $script:selector.OutputPath } else { "" }
        SelectorPackageCount = if ($script:selector) { $script:selector.PackageCount } else { 0 }
        SelectorReport = $script:selectorReport
        ReportPath = $script:ReportPath
        Steps = $stepArray
    }

    $resultJson = $result | ConvertTo-Json -Depth 8
    if ($script:ReportPath) {
        $reportParent = Split-Path -Parent $script:ReportPath
        if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
            New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($script:ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
    }
    return $result
}

if (-not $PackageName) {
    $PackageName = "WindowsDoctor-PortableUSB-Minimal-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$script:Root = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$script:PackageName = $PackageName
$script:ReportPath = $ReportPath
$script:IncludeNodeModules = [bool]$IncludeNodeModules
$script:IncludeNodeRuntime = [bool]$IncludeNodeRuntime
$script:KeepZipOnUsb = [bool]$KeepZipOnUsb
$script:ResumeExistingTarget = [bool]$ResumeExistingTarget
$script:payload = $null
$script:validation = $null
$script:selector = $null
$script:manifestCompare = $null
$script:copiedByZip = $false
$script:expandedOnUsb = $false

$script:usbRoot = $USBPath.TrimEnd('\')
if ($script:usbRoot -match '^[A-Za-z]:$') {
    $script:usbRoot = "$($script:usbRoot)\"
}
$script:zipPath = Join-Path $script:Root "releases\portable-usb\$PackageName.zip"
$script:targetPackageRoot = Join-Path $script:usbRoot $PackageName
$script:usbZipPath = Join-Path $script:usbRoot "$PackageName.zip"

$reportRoot = if ($ReportPath) {
    Split-Path -Parent $ReportPath
}
else {
    Join-Path $script:Root "logs"
}
if (-not $reportRoot) {
    $reportRoot = Join-Path $script:Root "logs"
}

$script:payloadReport = Join-Path $reportRoot "portable-usb-publish-payload.json"
$script:manifestReport = Join-Path $reportRoot "portable-usb-publish-zip-manifest.json"
$script:validationReport = Join-Path $reportRoot "portable-usb-publish-validate.json"
$script:selectorReport = Join-Path $reportRoot "usb-package-selector.latest.json"

try {
    if (-not (Test-Path -LiteralPath $script:usbRoot)) {
        throw "USBPath not found: $USBPath"
    }
    Add-Step -Name "usb-root" -Status "PASS" -Detail $script:usbRoot

    if ((Test-Path -LiteralPath $script:targetPackageRoot) -and -not $ResumeExistingTarget) {
        throw "Target package already exists on USB: $($script:targetPackageRoot)"
    }
    if ((Test-Path -LiteralPath $script:usbZipPath) -and -not $ResumeExistingTarget) {
        throw "Target zip already exists on USB: $($script:usbZipPath)"
    }
    if (Test-Path -LiteralPath $script:targetPackageRoot) {
        Add-Step -Name "target-existing" -Status "PASS" -Detail "Resume target: $($script:targetPackageRoot)"
    }

    $reuseLocalZip = ($ResumeExistingTarget -and (Test-Path -LiteralPath $script:zipPath))
    if (-not $reuseLocalZip) {
        if (Test-Path -LiteralPath $script:zipPath) {
            Remove-Item -LiteralPath $script:zipPath -Force
            Add-Step -Name "local-zip-cleanup" -Status "PASS" -Detail $script:zipPath
        }

        $payloadArgs = @(
            "-Root", $script:Root,
            "-PackageName", $PackageName,
            "-ReportPath", $script:payloadReport
        )
        if (-not $IncludeNodeModules) {
            $payloadArgs += "-SkipNodeModules"
        }
        if ($IncludeNodeRuntime) {
            $payloadArgs += "-IncludeNodeRuntime"
            $payloadArgs += "-NodeRuntimePath"
            $payloadArgs += $NodeRuntimePath
        }

        $script:payload = Invoke-JsonScript -ScriptPath (Join-Path $script:Root "scripts\New-PortableUsbPayload.ps1") -Arguments $payloadArgs
        if ($script:payload.Status -ne "PASS") {
            throw "Portable payload status is $($script:payload.Status)"
        }
        Add-Step -Name "payload" -Status "PASS" -Detail $script:payload.PackageRoot -ReportPath $script:payloadReport
        Write-PublishReport -Status "RUNNING" | Out-Null

        Compress-Archive -LiteralPath $script:payload.PackageRoot -DestinationPath $script:zipPath -CompressionLevel Optimal -Force
        Add-Step -Name "zip-compress" -Status "PASS" -Detail $script:zipPath
        Write-PublishReport -Status "RUNNING" | Out-Null
    }
    else {
        Add-Step -Name "zip-reuse" -Status "PASS" -Detail $script:zipPath
    }

    if ((Test-Path -LiteralPath $script:usbZipPath) -and $ResumeExistingTarget) {
        Add-Step -Name "usb-zip-reuse" -Status "PASS" -Detail $script:usbZipPath
    }
    else {
        Copy-Item -LiteralPath $script:zipPath -Destination $script:usbZipPath -Force
        $script:copiedByZip = $true
        Add-Step -Name "usb-zip-copy" -Status "PASS" -Detail $script:usbZipPath
        Write-PublishReport -Status "RUNNING" | Out-Null
    }

    Expand-Archive -LiteralPath $script:usbZipPath -DestinationPath $script:usbRoot -Force
    $script:expandedOnUsb = $true
    Add-Step -Name "usb-expand" -Status "PASS" -Detail $script:targetPackageRoot
    Write-PublishReport -Status "RUNNING" | Out-Null

    $script:manifestCompare = Invoke-JsonScript -ScriptPath (Join-Path $script:Root "scripts\Test-PortableUsbZipManifest.ps1") -Arguments @("-ZipPath", $script:zipPath, "-PackageRoot", $script:targetPackageRoot, "-ReportPath", $script:manifestReport)
    Add-Step -Name "zip-manifest" -Status $script:manifestCompare.Status -Detail "zipFiles=$($script:manifestCompare.ZipFileCount) missing=$($script:manifestCompare.MissingCount) sizeMismatch=$($script:manifestCompare.SizeMismatchCount)" -ReportPath $script:manifestReport
    if ($script:manifestCompare.Status -ne "PASS") {
        throw "USB zip manifest comparison status is $($script:manifestCompare.Status)"
    }
    Write-PublishReport -Status "RUNNING" | Out-Null

    $script:validation = Invoke-JsonScript -ScriptPath (Join-Path $script:Root "scripts\Test-PortableUsbReleaseValidation.ps1") -Arguments @("-PackageRoot", $script:targetPackageRoot, "-ZipPath", $script:zipPath, "-ReportPath", $script:validationReport)
    if ($script:validation.Status -ne "PASS") {
        throw "USB release validation status is $($script:validation.Status)"
    }
    Add-Step -Name "release-validation" -Status "PASS" -Detail "steps=$(@($script:validation.Steps).Count)" -ReportPath $script:validationReport
    Write-PublishReport -Status "RUNNING" | Out-Null

    if (-not $KeepZipOnUsb) {
        Remove-Item -LiteralPath $script:usbZipPath -Force
        Add-Step -Name "usb-zip-cleanup" -Status "PASS" -Detail "Removed after validation PASS: $($script:usbZipPath)"
    }
    else {
        Add-Step -Name "usb-zip-cleanup" -Status "SKIP" -Detail "KeepZipOnUsb enabled: $($script:usbZipPath)"
    }
    Write-PublishReport -Status "RUNNING" | Out-Null

    $script:selector = Invoke-JsonScript -ScriptPath (Join-Path $script:Root "scripts\New-UsbPackageSelectorPage.ps1") -Arguments @("-UsbRoot", $script:usbRoot, "-OutputPath", (Join-Path $script:usbRoot "START_HERE.html"), "-ReportPath", $script:selectorReport)
    if ($script:selector.Status -ne "PASS") {
        throw "USB selector page status is $($script:selector.Status)"
    }
    Add-Step -Name "usb-selector" -Status "PASS" -Detail "packages=$($script:selector.PackageCount)" -ReportPath $script:selectorReport

    $result = Write-PublishReport -Status "PASS"
    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        $result | Format-List
    }
}
catch {
    Add-Step -Name "publish-error" -Status "FAIL" -Detail $_.Exception.Message
    $result = Write-PublishReport -Status "FAIL" -ErrorMessage $_.Exception.Message
    if ($Json) {
        $result | ConvertTo-Json -Depth 8
    }
    else {
        $result | Format-List
    }
    exit 1
}
