param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$Component = "general",
    [string[]]$ToolId = @(),
    [string]$OutputRoot = "",
    [int]$MaxToolSeconds = 120,
    [switch]$Execute,
    [string]$ConfirmToken = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-Sha256Hex {
    param([string]$Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
        $sha.Dispose()
    }
}

function Invoke-ResourceSafety {
    param([string]$RootPath)
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $RootPath "scripts\Test-ResourceSafety.ps1") -Root $RootPath -Json
    return ($raw | ConvertFrom-Json)
}

function Get-ComponentToolIds {
    param([string]$Name)
    switch ($Name) {
        "printer" { return @("process-monitor", "handle") }
        "windows_update" { return @("setupdiag", "process-monitor") }
        "network" { return @("tcpview", "process-explorer") }
        "boot" { return @("sigcheck", "autoruns") }
        "performance" { return @("rammap", "process-explorer") }
        "hardware" { return @("sigcheck", "process-explorer") }
        "system_integrity" { return @("sigcheck", "process-monitor") }
        default { return @("process-explorer", "sigcheck") }
    }
}

function New-CommandPreview {
    param(
        [string]$ToolId,
        [string]$PackagePath,
        [string]$OutRoot
    )
    $toolOut = Join-Path $OutRoot $ToolId
    if ($ToolId -eq "setupdiag") {
        return "`"$PackagePath`" /Output:`"$(Join-Path $toolOut "SetupDiagResults.log")`""
    }
    if ($PackagePath.ToLowerInvariant().EndsWith(".zip")) {
        return "Expand-Archive -LiteralPath `"$PackagePath`" -DestinationPath `"$toolOut`" -Force"
    }
    return "`"$PackagePath`""
}

function Invoke-OneTool {
    param(
        [object]$Tool,
        [string]$OutRoot,
        [int]$TimeoutSeconds
    )
    $toolOut = Join-Path $OutRoot $Tool.Id
    if (-not (Test-Path -LiteralPath $toolOut)) {
        New-Item -Path $toolOut -ItemType Directory -Force | Out-Null
    }

    if ($Tool.Id -eq "setupdiag") {
        $outputLog = Join-Path $toolOut "SetupDiagResults.log"
        $process = Start-Process -FilePath $Tool.PackagePath -ArgumentList @("/Output:$outputLog") -NoNewWindow -PassThru -Wait:$false
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            return [PSCustomObject]@{ Status = "TIMEOUT"; ExitCode = $null; OutputPath = $outputLog }
        }
        return [PSCustomObject]@{ Status = "COMPLETED"; ExitCode = $process.ExitCode; OutputPath = $outputLog }
    }

    if ($Tool.PackagePath.ToLowerInvariant().EndsWith(".zip")) {
        Expand-Archive -LiteralPath $Tool.PackagePath -DestinationPath $toolOut -Force
        return [PSCustomObject]@{ Status = "EXTRACTED_ONLY"; ExitCode = 0; OutputPath = $toolOut }
    }

    return [PSCustomObject]@{ Status = "SKIPPED"; ExitCode = $null; OutputPath = $toolOut }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $env:LOCALAPPDATA "WindowsDoctor\OfflineDiagnostics"
}
$resolvedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot).TrimEnd("\")
$repairToolsRoot = Join-Path $resolvedRoot "releases\repair-tools"
$latestPackage = Get-ChildItem -LiteralPath $repairToolsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "windowsdoctor-offline-microsoft-diagnostics-*" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestPackage) {
    throw "Offline Microsoft diagnostics package not found under $repairToolsRoot"
}

$manifestPath = Join-Path $latestPackage.FullName "repair-tool-package-manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Offline diagnostics manifest not found: $manifestPath"
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$selectedIds = if ($ToolId.Count -gt 0) { $ToolId } else { Get-ComponentToolIds -Name $Component }
$toolFileById = @{
    "setupdiag" = "SetupDiag.exe"
    "process-explorer" = "ProcessExplorer.zip"
    "process-monitor" = "ProcessMonitor.zip"
    "autoruns" = "Autoruns.zip"
    "handle" = "Handle.zip"
    "tcpview" = "TCPView.zip"
    "rammap" = "RAMMap.zip"
    "sigcheck" = "Sigcheck.zip"
}

$beforeSafety = Invoke-ResourceSafety -RootPath $resolvedRoot
if ($beforeSafety.Status -ne "PASS") {
    throw "Resource safety failed before offline diagnostics"
}

if ($Execute -and $ConfirmToken -ne "RUN") {
    throw "RUN confirmation is required before offline diagnostic tool execution"
}

$planned = New-Object System.Collections.Generic.List[object]
foreach ($id in $selectedIds) {
    $manifestTool = @($manifest.tools | Where-Object { $_.id -eq $id } | Select-Object -First 1)
    if (-not $manifestTool) {
        $planned.Add([PSCustomObject]@{ Id = $id; Status = "MISSING_MANIFEST"; Name = $id; CommandPreview = ""; PackagePath = ""; Result = $null }) | Out-Null
        continue
    }
    if ($manifestTool.autoRunAllowed -ne $false -or $manifestTool.sourceTrustLevel -ne "microsoft_official") {
        $planned.Add([PSCustomObject]@{ Id = $id; Status = "BLOCKED_BY_POLICY"; Name = $manifestTool.name; CommandPreview = ""; PackagePath = ""; Result = $null }) | Out-Null
        continue
    }
    $fileName = $toolFileById[$id]
    $packagePath = Join-Path (Join-Path (Join-Path $latestPackage.FullName "tools") $id) $fileName
    if (-not (Test-Path -LiteralPath $packagePath)) {
        $planned.Add([PSCustomObject]@{ Id = $id; Status = "MISSING_FILE"; Name = $manifestTool.name; CommandPreview = ""; PackagePath = $packagePath; Result = $null }) | Out-Null
        continue
    }
    $actualSha = Get-Sha256Hex -Path $packagePath
    if ($actualSha -ne $manifestTool.expectedSha256) {
        $planned.Add([PSCustomObject]@{ Id = $id; Status = "HASH_MISMATCH"; Name = $manifestTool.name; CommandPreview = ""; PackagePath = $packagePath; Result = $null }) | Out-Null
        continue
    }
    $planned.Add([PSCustomObject]@{
        Id = $id
        Name = $manifestTool.name
        Status = if ($Execute) { "READY_TO_RUN" } else { "PREVIEW" }
        PackagePath = $packagePath
        CommandPreview = New-CommandPreview -ToolId $id -PackagePath $packagePath -OutRoot $resolvedOutputRoot
        Result = $null
    }) | Out-Null
}

$executed = New-Object System.Collections.Generic.List[object]
if ($Execute) {
    if (-not (Test-Path -LiteralPath $resolvedOutputRoot)) {
        New-Item -Path $resolvedOutputRoot -ItemType Directory -Force | Out-Null
    }
    for ($i = 0; $i -lt $planned.Count; $i++) {
        $item = $planned[$i]
        if ($item.Status -ne "READY_TO_RUN") { continue }
        $pre = Invoke-ResourceSafety -RootPath $resolvedRoot
        if ($pre.Status -ne "PASS") {
            $executed.Add([PSCustomObject]@{ Id = $item.Id; Status = "SKIPPED_RESOURCE_SAFETY"; Detail = "Pre-tool resource safety failed" }) | Out-Null
            break
        }
        $result = Invoke-OneTool -Tool $item -OutRoot $resolvedOutputRoot -TimeoutSeconds $MaxToolSeconds
        $post = Invoke-ResourceSafety -RootPath $resolvedRoot
        $executed.Add([PSCustomObject]@{
            Id = $item.Id
            Status = $result.Status
            ExitCode = $result.ExitCode
            OutputPath = $result.OutputPath
            PreResourceStatus = $pre.Status
            PostResourceStatus = $post.Status
        }) | Out-Null
        if ($post.Status -ne "PASS") { break }
    }
}

$conversion = $null
if ($Execute) {
    $convertReport = Join-Path $resolvedRoot "logs\offline-diagnostic-output-conversion.latest.json"
    $convertRaw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $resolvedRoot "scripts\Convert-OfflineDiagnosticToolOutput.ps1") -Root $resolvedRoot -InputRoot $resolvedOutputRoot -ReportPath $convertReport -Json
    $conversion = $convertRaw | ConvertFrom-Json
}

$afterSafety = Invoke-ResourceSafety -RootPath $resolvedRoot
$blocked = @($planned | Where-Object { $_.Status -notin @("PREVIEW", "READY_TO_RUN") })
$nextSteps = New-Object System.Collections.Generic.List[string]
if ($Execute) {
    $nextSteps.Add("Review tool output conversion and WindowsDoctor KB recommendations.") | Out-Null
}
else {
    $nextSteps.Add("Enter RUN before executing diagnostic-only tools sequentially.") | Out-Null
}
$nextSteps.Add("Resource Safety runs before and after each tool.") | Out-Null
$nextSteps.Add("Repair still requires reviewed KB, dry-run, rollback guidance, allowlist review, and RUN gate.") | Out-Null
$resultObject = [PSCustomObject]@{
    Status = if ($blocked.Count -eq 0 -and $beforeSafety.Status -eq "PASS" -and $afterSafety.Status -eq "PASS") { "PASS" } else { "WARN" }
    Phase = "offline-diagnostic-tools"
    Mode = if ($Execute) { "execute" } else { "preview" }
    Component = $Component
    PackageRoot = $latestPackage.FullName
    ManifestPath = $manifestPath
    OutputRoot = $resolvedOutputRoot
    Sequential = $true
    Executed = [bool]$Execute
    ToolCount = $planned.Count
    PlannedTools = $planned.ToArray()
    ExecutedTools = $executed.ToArray()
    OutputConversion = $conversion
    BeforeResourceSafety = $beforeSafety
    AfterResourceSafety = $afterSafety
    UserReport = [PSCustomObject]@{
        Fixed = @()
        NotFixed = @($planned | ForEach-Object {
            [PSCustomObject]@{
                id = $_.Id
                title = $_.Name
                script = "N/A"
                reason = if ($Execute) { "diagnostic evidence only; repair still requires reviewed KB and RUN gate" } else { "preview only; no tool executed" }
                riskLevel = "diagnostic"
            }
        })
        NextSteps = $nextSteps.ToArray()
    }
    SafetyPolicy = [PSCustomObject]@{
        NoRepairExecuted = $true
        NoInstall = $true
        NoRepairAllowlistChange = $true
        SequentialExecution = $true
        RunGateRequired = $true
    }
    ReportPath = $ReportPath
}

$resultJson = $resultObject | ConvertTo-Json -Depth 12
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $resultObject | Format-List }
