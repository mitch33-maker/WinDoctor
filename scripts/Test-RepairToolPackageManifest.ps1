param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [string]$InputRoot = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )
    $Checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }) | Out-Null
}

function Test-Sha256Text {
    param([string]$Value)
    return ($Value -match '^[A-Fa-f0-9]{64}$')
}

function Test-ApprovedUrl {
    param([string]$Url)
    if (-not $Url) { return $false }
    try {
        $uri = [System.Uri]$Url
        if ($uri.Scheme -ne "https") { return $false }
        $urlHost = $uri.Host.ToLowerInvariant()
        $approvedSuffixes = @(
            "microsoft.com",
            "download.microsoft.com",
            "learn.microsoft.com",
            "support.microsoft.com",
            "sysinternals.com",
            "live.sysinternals.com"
        )
        foreach ($suffix in $approvedSuffixes) {
            if ($urlHost -eq $suffix -or $urlHost.EndsWith("." + $suffix)) { return $true }
        }
        return $false
    }
    catch {
        return $false
    }
}

$resolvedManifest = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $resolvedManifest)) {
    throw "Manifest not found: $resolvedManifest"
}
if (-not $InputRoot) {
    $InputRoot = Split-Path -Parent $resolvedManifest
}
$resolvedInputRoot = [System.IO.Path]::GetFullPath($InputRoot).TrimEnd("\")

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedManifest | ConvertFrom-Json
$checks = New-Object System.Collections.Generic.List[object]
$allowedTrust = @("microsoft_official", "vendor_official", "enterprise_internal")
$allowedExecution = @("manual_only", "diagnostic_only")

Add-Check $checks "schema-version" ($manifest.schemaVersion -eq 1) "schemaVersion=1"
Add-Check $checks "package-id" (-not [string]::IsNullOrWhiteSpace($manifest.packageId)) "packageId"
$tools = @($manifest.tools)
Add-Check $checks "tools-present" ($tools.Count -gt 0) "tools=$($tools.Count)"

$toolReports = New-Object System.Collections.Generic.List[object]
foreach ($tool in $tools) {
    $toolChecks = New-Object System.Collections.Generic.List[object]
    $toolId = [string]$tool.id
    Add-Check $toolChecks "id" (-not [string]::IsNullOrWhiteSpace($toolId)) "id=$toolId"
    Add-Check $toolChecks "name" (-not [string]::IsNullOrWhiteSpace([string]$tool.name)) "name"
    Add-Check $toolChecks "version" (-not [string]::IsNullOrWhiteSpace([string]$tool.version)) "version"
    Add-Check $toolChecks "publisher" (-not [string]::IsNullOrWhiteSpace([string]$tool.publisher)) "publisher"
    Add-Check $toolChecks "source-url-approved" (Test-ApprovedUrl -Url ([string]$tool.sourceUrl)) ([string]$tool.sourceUrl)
    Add-Check $toolChecks "trust-level" (([string]$tool.sourceTrustLevel) -in $allowedTrust) ([string]$tool.sourceTrustLevel)
    Add-Check $toolChecks "expected-sha256" (Test-Sha256Text -Value ([string]$tool.expectedSha256)) "tool hash"
    Add-Check $toolChecks "license" (-not [string]::IsNullOrWhiteSpace([string]$tool.license)) "license"
    Add-Check $toolChecks "allowed-use" (-not [string]::IsNullOrWhiteSpace([string]$tool.allowedUse)) "allowedUse"
    Add-Check $toolChecks "execution-policy" (([string]$tool.executionPolicy) -in $allowedExecution) ([string]$tool.executionPolicy)
    Add-Check $toolChecks "auto-run-disabled" (-not [bool]$tool.autoRunAllowed) "autoRunAllowed=$($tool.autoRunAllowed)"

    $fileReports = New-Object System.Collections.Generic.List[object]
    foreach ($file in @($tool.files)) {
        $relative = [string]$file.relativePath
        $expected = [string]$file.expectedSha256
        $candidate = [System.IO.Path]::GetFullPath((Join-Path $resolvedInputRoot $relative))
        $underRoot = $candidate.StartsWith($resolvedInputRoot, [System.StringComparison]::OrdinalIgnoreCase)
        $exists = $underRoot -and (Test-Path -LiteralPath $candidate)
        $actual = ""
        if ($exists) {
            $actual = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $hashOk = $exists -and (Test-Sha256Text -Value $expected) -and ($actual -eq $expected.ToLowerInvariant())
        $fileReports.Add([PSCustomObject]@{
            relativePath = $relative
            path = $candidate
            underInputRoot = $underRoot
            exists = $exists
            expectedSha256 = $expected
            actualSha256 = $actual
            hashOk = $hashOk
        }) | Out-Null
    }
    Add-Check $toolChecks "files-present" (@($tool.files).Count -gt 0) "files=$(@($tool.files).Count)"
    Add-Check $toolChecks "files-hash-ok" (@($fileReports | Where-Object { -not $_.hashOk }).Count -eq 0 -and $fileReports.Count -gt 0) "invalid=$(@($fileReports | Where-Object { -not $_.hashOk }).Count)"

    $toolStatus = if (@($toolChecks | Where-Object { $_.Status -ne "PASS" }).Count -eq 0) { "PASS" } else { "FAIL" }
    $toolReports.Add([PSCustomObject]@{
        id = $toolId
        status = $toolStatus
        checks = @($toolChecks.ToArray())
        files = @($fileReports.ToArray())
    }) | Out-Null
}

$allChecks = @($checks.ToArray())
$failedTop = @($allChecks | Where-Object { $_.Status -ne "PASS" })
$failedTools = @($toolReports | Where-Object { $_.status -ne "PASS" })
$result = [PSCustomObject]@{
    Status = if ($failedTop.Count -eq 0 -and $failedTools.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "repair-tool-package-manifest-validation"
    ManifestPath = $resolvedManifest
    InputRoot = $resolvedInputRoot
    ToolCount = $tools.Count
    Checks = $allChecks
    Tools = @($toolReports.ToArray())
    SafetyPolicy = [PSCustomObject]@{
        NoInstall = $true
        NoExecute = $true
        HashRequired = $true
        AutoRunAllowed = $false
    }
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 12
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $result | Format-List }
if ($result.Status -eq "FAIL") { exit 1 }
