param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DownloadRoot = "",
    [string]$OutputRoot = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Write-Utf8Json {
    param([string]$Path, [object]$Value, [int]$Depth = 12)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth $Depth), [System.Text.UTF8Encoding]::new($false))
}

function Test-ApprovedUrl {
    param([string]$Url)
    try {
        $uri = [System.Uri]$Url
        if ($uri.Scheme -ne "https") { return $false }
        $urlHost = $uri.Host.ToLowerInvariant()
        $suffixes = @("microsoft.com", "download.microsoft.com", "go.microsoft.com", "sysinternals.com", "download.sysinternals.com")
        foreach ($suffix in $suffixes) {
            if ($urlHost -eq $suffix -or $urlHost.EndsWith("." + $suffix)) { return $true }
        }
        return $false
    }
    catch {
        return $false
    }
}

function Test-DownloadedSignature {
    param([string]$Path, [string]$ScratchRoot)
    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $scanRoot = $Path
    if ($extension -eq ".zip") {
        $scanRoot = Join-Path $ScratchRoot ([System.IO.Path]::GetFileNameWithoutExtension($Path))
        if (Test-Path -LiteralPath $scanRoot) { Remove-Item -LiteralPath $scanRoot -Recurse -Force }
        New-Item -Path $scanRoot -ItemType Directory -Force | Out-Null
        Expand-Archive -LiteralPath $Path -DestinationPath $scanRoot -Force
    }

    $targets = @()
    if (Test-Path -LiteralPath $scanRoot -PathType Container) {
        $targets = @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File | Where-Object { $_.Extension -in @(".exe", ".dll", ".sys") })
    }
    elseif ($extension -in @(".exe", ".dll", ".sys")) {
        $targets = @(Get-Item -LiteralPath $scanRoot)
    }

    $items = @($targets | ForEach-Object {
        $signature = Get-AuthenticodeSignature -LiteralPath $_.FullName
        [PSCustomObject]@{
            path = $_.FullName
            status = [string]$signature.Status
            signer = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { "" }
        }
    })
    [PSCustomObject]@{
        executableCount = $items.Count
        validCount = @($items | Where-Object { $_.status -eq "Valid" }).Count
        invalidCount = @($items | Where-Object { $_.status -ne "Valid" }).Count
        items = $items
    }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not $DownloadRoot) { $DownloadRoot = Join-Path $resolvedRoot "incoming\repair-tools\offline-tools-$stamp" }
if (-not $OutputRoot) { $OutputRoot = Join-Path $resolvedRoot "releases\repair-tools" }
$resolvedDownloadRoot = [System.IO.Path]::GetFullPath($DownloadRoot).TrimEnd("\")
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")
$downloadDir = Join-Path $resolvedDownloadRoot "downloads"
$scratchRoot = Join-Path $resolvedDownloadRoot ".signature-scan"
New-Item -Path $downloadDir -ItemType Directory -Force | Out-Null
New-Item -Path $scratchRoot -ItemType Directory -Force | Out-Null

$tools = @(
    @{ id = "setupdiag"; name = "SetupDiag"; version = "latest"; publisher = "Microsoft"; url = "https://go.microsoft.com/fwlink/?linkid=870142"; fileName = "SetupDiag.exe"; allowedUse = "offline Windows upgrade log diagnostics"; policy = "diagnostic_only" },
    @{ id = "process-explorer"; name = "Process Explorer"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/ProcessExplorer.zip"; fileName = "ProcessExplorer.zip"; allowedUse = "offline process inspection and triage"; policy = "manual_only" },
    @{ id = "process-monitor"; name = "Process Monitor"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/ProcessMonitor.zip"; fileName = "ProcessMonitor.zip"; allowedUse = "manual event, registry, file, and process trace collection"; policy = "manual_only" },
    @{ id = "autoruns"; name = "Autoruns"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/Autoruns.zip"; fileName = "Autoruns.zip"; allowedUse = "offline startup and persistence inspection"; policy = "manual_only" },
    @{ id = "handle"; name = "Handle"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/Handle.zip"; fileName = "Handle.zip"; allowedUse = "manual locked-file diagnostics"; policy = "manual_only" },
    @{ id = "tcpview"; name = "TCPView"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/TCPView.zip"; fileName = "TCPView.zip"; allowedUse = "manual network connection inspection"; policy = "manual_only" },
    @{ id = "rammap"; name = "RAMMap"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/RAMMap.zip"; fileName = "RAMMap.zip"; allowedUse = "manual memory usage diagnostics"; policy = "manual_only" },
    @{ id = "sigcheck"; name = "Sigcheck"; version = "latest"; publisher = "Microsoft Sysinternals"; url = "https://download.sysinternals.com/files/Sigcheck.zip"; fileName = "Sigcheck.zip"; allowedUse = "manual file signature and version inspection"; policy = "manual_only" }
)

$records = New-Object System.Collections.Generic.List[object]
foreach ($tool in $tools) {
    if (-not (Test-ApprovedUrl -Url $tool.url)) { throw "URL is not approved: $($tool.url)" }
    $target = Join-Path $downloadDir $tool.fileName
    Invoke-WebRequest -Uri $tool.url -OutFile $target -UseBasicParsing
    $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    $signature = Test-DownloadedSignature -Path $target -ScratchRoot $scratchRoot
    if ($signature.executableCount -gt 0 -and $signature.invalidCount -gt 0) {
        throw "Authenticode signature validation failed: $($tool.id)"
    }
    $records.Add([PSCustomObject]@{
        id = $tool.id
        name = $tool.name
        version = $tool.version
        publisher = $tool.publisher
        sourceUrl = $tool.url
        sourceTrustLevel = "microsoft_official"
        expectedSha256 = $hash
        license = "Microsoft official download; review product terms before use"
        allowedUse = $tool.allowedUse
        executionPolicy = $tool.policy
        autoRunAllowed = $false
        files = @(@{ relativePath = "downloads\$($tool.fileName)"; expectedSha256 = $hash })
        signature = $signature
    }) | Out-Null
}

$manifest = [PSCustomObject]@{
    schemaVersion = 1
    packageId = "windowsdoctor-offline-microsoft-diagnostics-$stamp"
    packageName = "WindowsDoctor Offline Microsoft Diagnostics"
    createdBy = "WindowsDoctor"
    createdAt = (Get-Date).ToString("s")
    tools = @($records.ToArray() | ForEach-Object {
        [PSCustomObject]@{
            id = $_.id
            name = $_.name
            version = $_.version
            publisher = $_.publisher
            sourceUrl = $_.sourceUrl
            sourceTrustLevel = $_.sourceTrustLevel
            expectedSha256 = $_.expectedSha256
            license = $_.license
            allowedUse = $_.allowedUse
            executionPolicy = $_.executionPolicy
            autoRunAllowed = $_.autoRunAllowed
            files = $_.files
        }
    })
}
$manifestPath = Join-Path $resolvedDownloadRoot "manifest.json"
Write-Utf8Json -Path $manifestPath -Value $manifest

$packageReport = if ($ReportPath) { "$ReportPath.package.json" } else { Join-Path $resolvedDownloadRoot "package-report.json" }
$packageJson = & "$PSScriptRoot\New-RepairToolPackage.ps1" -ManifestPath $manifestPath -InputRoot $resolvedDownloadRoot -OutputRoot $resolvedOutputRoot -ReportPath $packageReport -Json
$package = $packageJson | ConvertFrom-Json

$result = [PSCustomObject]@{
    Status = "PASS"
    Phase = "offline-repair-tool-acquisition"
    Root = $resolvedRoot
    DownloadRoot = $resolvedDownloadRoot
    ManifestPath = $manifestPath
    PackageRoot = $package.PackageRoot
    ToolCount = $records.Count
    Tools = @($records.ToArray())
    SafetyPolicy = [PSCustomObject]@{
        MicrosoftOfficialOnly = $true
        NoInstall = $true
        NoExecute = $true
        HashRecorded = $true
        SignatureChecked = $true
        AutoRunAllowed = $false
        RepairAllowlistUpdated = $false
        ExcludedHighRiskSysinternals = @("PsExec", "PsKill", "SDelete", "PsShutdown")
    }
    PackageReportPath = $packageReport
    ReportPath = $ReportPath
}

Remove-Item -LiteralPath $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
if ($ReportPath) { Write-Utf8Json -Path $ReportPath -Value $result }
if ($Json) { $result | ConvertTo-Json -Depth 12 } else { $result | Format-List }
