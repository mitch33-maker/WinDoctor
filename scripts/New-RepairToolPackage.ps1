param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [string]$InputRoot = "",
    [string]$OutputRoot = "E:\WindowsDoctor\releases\repair-tools",
    [string]$PackageName = "",
    [string]$ReportPath = "",
    [switch]$AllowDownload,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Utf8Json {
    param([string]$Path, [object]$Value, [int]$Depth = 12)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth $Depth), [System.Text.UTF8Encoding]::new($false))
}

function Test-ApprovedDownloadUrl {
    param([string]$Url)
    try {
        $uri = [System.Uri]$Url
        if ($uri.Scheme -ne "https") { return $false }
        $urlHost = $uri.Host.ToLowerInvariant()
        $suffixes = @("microsoft.com", "download.microsoft.com", "learn.microsoft.com", "support.microsoft.com", "sysinternals.com", "live.sysinternals.com")
        foreach ($suffix in $suffixes) {
            if ($urlHost -eq $suffix -or $urlHost.EndsWith("." + $suffix)) { return $true }
        }
        return $false
    }
    catch {
        return $false
    }
}

$resolvedManifest = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not $InputRoot) { $InputRoot = Split-Path -Parent $resolvedManifest }
$resolvedInputRoot = [System.IO.Path]::GetFullPath($InputRoot).TrimEnd("\")
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")

if ($AllowDownload) {
    $preManifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedManifest | ConvertFrom-Json
    foreach ($tool in @($preManifest.tools)) {
        if (-not (Test-ApprovedDownloadUrl -Url ([string]$tool.sourceUrl))) { throw "Download URL is not approved: $($tool.sourceUrl)" }
        foreach ($file in @($tool.files)) {
            $relative = [string]$file.relativePath
            $target = [System.IO.Path]::GetFullPath((Join-Path $resolvedInputRoot $relative))
            if (-not $target.StartsWith($resolvedInputRoot, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Download target escapes input root: $relative" }
            if (-not (Test-Path -LiteralPath $target)) {
                $parent = Split-Path -Parent $target
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
                Invoke-WebRequest -Uri ([string]$tool.sourceUrl) -OutFile $target -UseBasicParsing
            }
        }
    }
}

$validationReport = if ($ReportPath) { "$ReportPath.validation.json" } else { "" }
$validationJson = & "$PSScriptRoot\Test-RepairToolPackageManifest.ps1" -ManifestPath $resolvedManifest -InputRoot $resolvedInputRoot -ReportPath $validationReport -Json
$validation = $validationJson | ConvertFrom-Json
if ($validation.Status -ne "PASS") {
    throw "Manifest validation failed: $resolvedManifest"
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedManifest | ConvertFrom-Json
if (-not $PackageName) {
    $PackageName = if ($manifest.packageId) { [string]$manifest.packageId } else { "repair-tools" }
}
$safeName = ($PackageName -replace '[^A-Za-z0-9_.-]', '-').Trim("-")
if (-not $safeName) { $safeName = "repair-tools" }
$packageRoot = Join-Path $resolvedOutputRoot $safeName
$toolsRoot = Join-Path $packageRoot "tools"
New-Item -Path $toolsRoot -ItemType Directory -Force | Out-Null

$packagedFiles = New-Object System.Collections.Generic.List[object]
foreach ($tool in @($manifest.tools)) {
    $toolRoot = Join-Path $toolsRoot (($tool.id -replace '[^A-Za-z0-9_.-]', '-').Trim("-"))
    New-Item -Path $toolRoot -ItemType Directory -Force | Out-Null
    foreach ($file in @($tool.files)) {
        $relative = [string]$file.relativePath
        $source = [System.IO.Path]::GetFullPath((Join-Path $resolvedInputRoot $relative))
        if (-not (Test-Path -LiteralPath $source)) {
            if (-not $AllowDownload) { throw "Tool file missing and download disabled: $source" }
            if (-not (Test-ApprovedDownloadUrl -Url ([string]$tool.sourceUrl))) { throw "Download URL is not approved: $($tool.sourceUrl)" }
            $downloadTarget = $source
            $downloadParent = Split-Path -Parent $downloadTarget
            if ($downloadParent -and -not (Test-Path -LiteralPath $downloadParent)) { New-Item -Path $downloadParent -ItemType Directory -Force | Out-Null }
            Invoke-WebRequest -Uri ([string]$tool.sourceUrl) -OutFile $downloadTarget -UseBasicParsing
            $source = $downloadTarget
        }

        $actual = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        $expected = ([string]$file.expectedSha256).ToLowerInvariant()
        if ($actual -ne $expected) { throw "SHA256 mismatch: $relative" }

        $target = Join-Path $toolRoot ([System.IO.Path]::GetFileName($relative))
        Copy-Item -LiteralPath $source -Destination $target -Force
        $packagedFiles.Add([PSCustomObject]@{
            toolId = $tool.id
            source = $source
            target = $target
            sha256 = $actual
        }) | Out-Null
    }
}

$packageManifestPath = Join-Path $packageRoot "repair-tool-package-manifest.json"
Copy-Item -LiteralPath $resolvedManifest -Destination $packageManifestPath -Force

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "repair-tool-package"
    PackageRoot = $packageRoot
    PackageManifestPath = $packageManifestPath
    ToolCount = @($manifest.tools).Count
    FileCount = $packagedFiles.Count
    PackagedFiles = @($packagedFiles.ToArray())
    DownloadUsed = [bool]$AllowDownload
    SafetyPolicy = [PSCustomObject]@{
        NoInstall = $true
        NoExecute = $true
        HashVerified = $true
        AutoRunAllowed = $false
        RepairAllowlistUpdated = $false
    }
    ValidationReportPath = $validationReport
    ReportPath = $ReportPath
}

if ($ReportPath) { Write-Utf8Json -Path $ReportPath -Value $result }
if ($Json) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
