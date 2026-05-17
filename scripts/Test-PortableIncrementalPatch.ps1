param(
    [Parameter(Mandatory = $true)]
    [string]$PatchZipPath,
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$ReportPath = "",
    [int]$MaxIssueCount = 50,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-Sha256HexFromStream {
    param([System.IO.Stream]$Stream)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash($Stream)
        return ([System.BitConverter]::ToString($bytes)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-Sha256HexFromFile {
    param([string]$Path)
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        Get-Sha256HexFromStream -Stream $stream
    }
    finally {
        $stream.Dispose()
    }
}

function Find-ZipEntry {
    param(
        [System.IO.Compression.ZipArchive]$Archive,
        [string]$Path
    )

    $normalized = $Path.TrimStart("\", "/")
    $forward = $normalized.Replace("\", "/")
    $backward = $normalized.Replace("/", "\")

    foreach ($entry in $Archive.Entries) {
        $entryName = $entry.FullName.TrimStart("\", "/")
        if (
            $entryName.Equals($normalized, [System.StringComparison]::OrdinalIgnoreCase) -or
            $entryName.Equals($forward, [System.StringComparison]::OrdinalIgnoreCase) -or
            $entryName.Equals($backward, [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            return $entry
        }
    }

    return $null
}

$resolvedPatchZipPath = [System.IO.Path]::GetFullPath($PatchZipPath)
$resolvedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")

if (-not (Test-Path -LiteralPath $resolvedPatchZipPath)) {
    throw "PatchZipPath not found: $PatchZipPath"
}
if (-not (Test-Path -LiteralPath $resolvedPackageRoot)) {
    throw "PackageRoot not found: $PackageRoot"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$missingZipEntries = New-Object System.Collections.Generic.List[object]
$missingPackageFiles = New-Object System.Collections.Generic.List[object]
$sizeMismatch = New-Object System.Collections.Generic.List[object]
$hashMismatch = New-Object System.Collections.Generic.List[object]
$checkedCount = 0
$zipBytes = [int64](Get-Item -LiteralPath $resolvedPatchZipPath).Length

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPatchZipPath)
try {
    $manifestEntry = Find-ZipEntry -Archive $archive -Path "incremental-patch-manifest.json"
    if (-not $manifestEntry) {
        throw "incremental-patch-manifest.json not found in patch zip"
    }

    $manifestStream = $manifestEntry.Open()
    try {
        $reader = [System.IO.StreamReader]::new($manifestStream, [System.Text.Encoding]::UTF8)
        try {
            $manifest = $reader.ReadToEnd() | ConvertFrom-Json
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $manifestStream.Dispose()
    }

    foreach ($entryInfo in @($manifest.Entries)) {
        $checkedCount++
        $relativePath = [string]$entryInfo.Path
        $entry = Find-ZipEntry -Archive $archive -Path $relativePath
        if (-not $entry) {
            if ($missingZipEntries.Count -lt $MaxIssueCount) {
                $missingZipEntries.Add([PSCustomObject]@{ Path = $relativePath })
            }
            continue
        }

        $packageFile = Join-Path $resolvedPackageRoot $relativePath
        if (-not (Test-Path -LiteralPath $packageFile)) {
            if ($missingPackageFiles.Count -lt $MaxIssueCount) {
                $missingPackageFiles.Add([PSCustomObject]@{ Path = $relativePath })
            }
            continue
        }

        $packageItem = Get-Item -LiteralPath $packageFile
        if ([int64]$entry.Length -ne [int64]$packageItem.Length) {
            if ($sizeMismatch.Count -lt $MaxIssueCount) {
                $sizeMismatch.Add([PSCustomObject]@{
                    Path = $relativePath
                    ZipBytes = [int64]$entry.Length
                    PackageBytes = [int64]$packageItem.Length
                })
            }
            continue
        }

        $entryStream = $entry.Open()
        try {
            $zipHash = Get-Sha256HexFromStream -Stream $entryStream
        }
        finally {
            $entryStream.Dispose()
        }
        $packageHash = Get-Sha256HexFromFile -Path $packageFile
        $manifestHash = [string]$entryInfo.Sha256
        if ($zipHash -ne $packageHash -or $zipHash -ne $manifestHash) {
            if ($hashMismatch.Count -lt $MaxIssueCount) {
                $hashMismatch.Add([PSCustomObject]@{
                    Path = $relativePath
                    ZipSha256 = $zipHash
                    PackageSha256 = $packageHash
                    ManifestSha256 = $manifestHash
                })
            }
        }
    }
}
finally {
    $archive.Dispose()
}

$issueCount = $missingZipEntries.Count + $missingPackageFiles.Count + $sizeMismatch.Count + $hashMismatch.Count
$result = [PSCustomObject]@{
    Status = if ($issueCount -eq 0) { "PASS" } else { "FAIL" }
    Phase = "portable-usb-incremental-patch"
    PatchZipPath = $resolvedPatchZipPath
    PackageRoot = $resolvedPackageRoot
    CheckedCount = $checkedCount
    ZipBytes = $zipBytes
    MissingZipEntryCount = $missingZipEntries.Count
    MissingPackageFileCount = $missingPackageFiles.Count
    SizeMismatchCount = $sizeMismatch.Count
    HashMismatchCount = $hashMismatch.Count
    MissingZipEntries = $missingZipEntries.ToArray()
    MissingPackageFiles = $missingPackageFiles.ToArray()
    SizeMismatch = $sizeMismatch.ToArray()
    HashMismatch = $hashMismatch.ToArray()
    ReportPath = $ReportPath
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
    $result | Format-List
}

if ($result.Status -eq "FAIL") { exit 1 }
