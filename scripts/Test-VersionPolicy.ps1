param(
    [string]$PackageJson = "E:\WindowsDoctor\gui\package.json",
    [string]$PageFile = "E:\WindowsDoctor\gui\src\app\page.tsx",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Test-Version {
    param([string]$Version)
    if ($Version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') {
        throw "Invalid version format: $Version"
    }
    $base = ($Version -split '-', 2)[0]
    $parts = $base.Split('.') | ForEach-Object { [int]$_ }
    if ($parts.Count -ne 3) { throw "Version must use MAJOR.MINOR.PATCH: $Version" }
    if ($parts[1] -gt 9 -or $parts[2] -gt 9) {
        throw "MINOR and PATCH must not exceed 9: $Version"
    }
}

$package = Get-Content -Raw -Path $PackageJson | ConvertFrom-Json
$packageVersion = [string]$package.version
Test-Version -Version $packageVersion

$page = Get-Content -Raw -Path $PageFile
$uiMatch = [regex]::Match($page, 'v(\d+\.\d+\.\d+)(-[A-Za-z0-9.-]+)?')
if (-not $uiMatch.Success) { throw "UI version marker not found: $PageFile" }

$uiVersion = $uiMatch.Groups[1].Value
Test-Version -Version $uiVersion

if ($uiVersion -ne $packageVersion) {
    throw "Package/UI version mismatch. package=$packageVersion ui=$uiVersion"
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Version = $packageVersion
    PackageJson = $PackageJson
    PageFile = $PageFile
    ReportPath = $ReportPath
}

if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $jsonText = $result | ConvertTo-Json -Depth 4
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result
}
