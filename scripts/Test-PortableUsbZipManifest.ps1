param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$ReportPath = "",
    [int]$MaxIssueCount = 50,
    [switch]$Hash,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertTo-RelativePackagePath {
    param(
        [string]$EntryName,
        [string]$PackageName
    )
    $normalized = $EntryName.Replace("/", "\").TrimStart("\")
    $prefix = "$PackageName\"
    if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $normalized.Substring($prefix.Length)
    }
    return $normalized
}

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

$resolvedZipPath = [System.IO.Path]::GetFullPath($ZipPath)
$resolvedPackageRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd("\")
$packageName = Split-Path -Leaf $resolvedPackageRoot

if (-not (Test-Path -LiteralPath $resolvedZipPath)) {
    throw "ZipPath not found: $ZipPath"
}
if (-not (Test-Path -LiteralPath $resolvedPackageRoot)) {
    throw "PackageRoot not found: $PackageRoot"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$missing = New-Object System.Collections.Generic.List[object]
$sizeMismatch = New-Object System.Collections.Generic.List[object]
$hashMismatch = New-Object System.Collections.Generic.List[object]
$checkedCount = 0
$zipBytes = [int64]0
$missingCount = 0
$sizeMismatchCount = 0
$hashComparedCount = 0
$hashMismatchCount = 0

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedZipPath)
try {
    foreach ($entry in $archive.Entries) {
        if (-not $entry.Name) { continue }

        $checkedCount++
        $zipBytes += [int64]$entry.Length
        $relative = ConvertTo-RelativePackagePath -EntryName $entry.FullName -PackageName $packageName
        $target = Join-Path $resolvedPackageRoot $relative

        if (-not (Test-Path -LiteralPath $target)) {
            $missingCount++
            if ($missing.Count -lt $MaxIssueCount) {
                $missing.Add([PSCustomObject]@{
                    Path = $relative
                    ExpectedBytes = [int64]$entry.Length
                })
            }
            continue
        }

        $targetItem = Get-Item -LiteralPath $target
        if ([int64]$targetItem.Length -ne [int64]$entry.Length) {
            $sizeMismatchCount++
            if ($sizeMismatch.Count -lt $MaxIssueCount) {
                $sizeMismatch.Add([PSCustomObject]@{
                    Path = $relative
                    ExpectedBytes = [int64]$entry.Length
                    ActualBytes = [int64]$targetItem.Length
                })
            }
            continue
        }

        if ($Hash) {
            $entryStream = $entry.Open()
            try {
                $zipHash = Get-Sha256HexFromStream -Stream $entryStream
            }
            finally {
                $entryStream.Dispose()
            }
            $fileHash = Get-Sha256HexFromFile -Path $target
            $hashComparedCount++
            if ($zipHash -ne $fileHash) {
                $hashMismatchCount++
                if ($hashMismatch.Count -lt $MaxIssueCount) {
                    $hashMismatch.Add([PSCustomObject]@{
                        Path = $relative
                        ZipSha256 = $zipHash
                        FileSha256 = $fileHash
                    })
                }
            }
        }
    }
}
finally {
    $archive.Dispose()
}

$targetFiles = @(Get-ChildItem -LiteralPath $resolvedPackageRoot -Recurse -Force -File)
$targetBytes = [int64]0
foreach ($file in $targetFiles) {
    $targetBytes += [int64]$file.Length
}

$result = [PSCustomObject]@{
    Status = if ($missingCount -eq 0 -and $sizeMismatchCount -eq 0 -and $hashMismatchCount -eq 0) { "PASS" } else { "FAIL" }
    Phase = "portable-usb"
    Check = "zip-manifest"
    ZipPath = $resolvedZipPath
    PackageRoot = $resolvedPackageRoot
    HashEnabled = [bool]$Hash
    ZipFileCount = $checkedCount
    ZipBytes = $zipBytes
    TargetFileCount = $targetFiles.Count
    TargetBytes = $targetBytes
    MissingCount = $missingCount
    SizeMismatchCount = $sizeMismatchCount
    HashComparedCount = $hashComparedCount
    HashMismatchCount = $hashMismatchCount
    Missing = $missing.ToArray()
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
