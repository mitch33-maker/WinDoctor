param(
    [switch]$SkipBuild,
    [switch]$SkipServiceSmoke,
    [switch]$SkipPester,
    [switch]$FullPester,
    [switch]$SkipLint,
    [double]$MinFreeMemoryGB = 4,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$root = "E:\WindowsDoctor"
$steps = New-Object System.Collections.Generic.List[object]

function Invoke-BaselineStep {
    param(
        [string]$Name,
        [scriptblock]$Command
    )
    try {
        $global:LASTEXITCODE = 0
        if ($Json) {
            & $Command *> $null
        }
        else {
            & $Command
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Command exited with code $LASTEXITCODE"
        }
        $script:steps.Add([PSCustomObject]@{ Name = $Name; Status = "PASS" })
    }
    catch {
        $script:steps.Add([PSCustomObject]@{ Name = $Name; Status = "FAIL"; Detail = $_.Exception.Message })
    }
}

function Assert-FreeMemory {
    param([string]$StepName)
    $os = Get-CimInstance Win32_OperatingSystem
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    if ($free -lt $MinFreeMemoryGB) {
        throw "Insufficient free memory before $StepName. Free=${free}GB Required=${MinFreeMemoryGB}GB"
    }
}

Assert-FreeMemory -StepName "baseline"
Invoke-BaselineStep -Name "resource-safety" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-ResourceSafety.ps1" -MinFreeMemoryGB $MinFreeMemoryGB }
Invoke-BaselineStep -Name "kb-markdown-encoding" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-KBMarkdownEncoding.ps1" -Json }
Invoke-BaselineStep -Name "offline-kb-export" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Export-OfflineKBDatabase.ps1" -Json }
Invoke-BaselineStep -Name "offline-kb-validate" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-OfflineKBDatabase.ps1" -Json }
Invoke-BaselineStep -Name "normalized-kb-export" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Export-NormalizedKBDatabase.ps1" -Json }
Invoke-BaselineStep -Name "normalized-kb-validate" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-NormalizedKBDatabase.ps1" -Json }
Invoke-BaselineStep -Name "documentation-sync" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-DocumentationSync.ps1" -Json }
Invoke-BaselineStep -Name "winpe-offline-flow" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-WinPEOfflineFlow.ps1" -Json }
Invoke-BaselineStep -Name "portable-usb-readiness" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-PortableUsbReadiness.ps1" -Json }
Invoke-BaselineStep -Name "version-policy" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-VersionPolicy.ps1" }
if (-not $SkipServiceSmoke) {
    Invoke-BaselineStep -Name "broker-smoke" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-BrokerSmoke.ps1" }
}
Invoke-BaselineStep -Name "gui-smoke-offline" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Test-GuiSmoke.ps1" -AllowOffline }
if (-not $SkipPester) {
    if ($FullPester) {
        Invoke-BaselineStep -Name "pester-full" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path '$root\core\WindowsDoctor.Tests.ps1', '$root\scripts\ResourceSafety.Tests.ps1'" }
    }
    else {
        Invoke-BaselineStep -Name "pester-safety-parse" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path '$root\scripts\ResourceSafety.Tests.ps1' -FullName '*parses safety scripts*'" }
    }
}
Invoke-BaselineStep -Name "winpe-check" -Command { powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$root\scripts\Build-WinPEMedia.ps1" -CheckOnly }
Invoke-BaselineStep -Name "broker-services" -Command { npm run test:broker --prefix "$root\gui" }
if (-not $SkipLint) {
    Invoke-BaselineStep -Name "lint" -Command { npm run lint --prefix "$root\gui" }
}
if (-not $SkipBuild) {
    Assert-FreeMemory -StepName "production build"
    Invoke-BaselineStep -Name "build" -Command { npm run build --prefix "$root\gui" }
}

$stepArray = @($steps.ToArray())
$result = [PSCustomObject]@{
    Status = if ($stepArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $root
    SkipBuild = [bool]$SkipBuild
    SkipServiceSmoke = [bool]$SkipServiceSmoke
    SkipPester = [bool]$SkipPester
    FullPester = [bool]$FullPester
    SkipLint = [bool]$SkipLint
    MinFreeMemoryGB = $MinFreeMemoryGB
    ReportPath = $ReportPath
    Steps = $stepArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, $utf8NoBom)
}

if ($Json) {
    $resultJson
}
else {
    $stepArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
