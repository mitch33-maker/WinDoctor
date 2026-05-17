param(
    [string]$Root = "E:\WindowsDoctor",
    [int]$GuiPort = 3000,
    [int]$BrokerPort = 3001,
    [switch]$RestartBroker,
    [switch]$RestartGui,
    [switch]$Verify,
    [switch]$SkipBuild,
    [switch]$NoGui,
    [switch]$NoBroker,
    [string]$ReportPath = "",
    [switch]$Json,
    [switch]$Hidden,
    [switch]$FullVerify,
    [switch]$DisableGuiStartupGuard,
    [switch]$DisableResourceWatchdog,
    [int]$GuiStartupGuardSeconds = 5,
    [int]$ResourceWatchSeconds = 600,
    [int]$ResourceWatchIntervalSeconds = 5,
    [int]$MaxStartupPostCssWorkers = 1,
    [int]$MaxPostCssWorkerSeconds = 45,
    [int]$StartupStepDelaySeconds = 3,
    [int]$MaxGuiNodeProcesses = 8,
    [int]$MaxWindowsDoctorTotalWorkingSetMB = 1200,
    [int]$MaxWindowsDoctorProcessWorkingSetMB = 512,
    [int]$NodeMaxOldSpaceSizeMB = 384,
    [double]$MinFreeMemoryGB = 4,
    [string]$ProcessPriority = "BelowNormal",
    [string]$NodePath = "",
    [string]$NpmPath = ""
)

$ErrorActionPreference = "Stop"

function Get-PortListenerPid {
    param([int]$Port)
    $line = netstat -ano | findstr ":$Port" | findstr "LISTENING" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace ".*\s+(\d+)$", '$1').Trim()
}

function Get-FreeMemoryGB {
    $os = Get-CimInstance Win32_OperatingSystem
    return [math]::Round($os.FreePhysicalMemory / 1MB, 2)
}

function Assert-FreeMemory {
    param([string]$Action)
    $free = Get-FreeMemoryGB
    if ($free -lt $MinFreeMemoryGB) {
        throw "Insufficient free memory for $Action. Free=${free}GB Required=${MinFreeMemoryGB}GB"
    }
}

function Stop-PortListener {
    param([int]$Port)
    $listenerPid = Get-PortListenerPid -Port $Port
    if ($listenerPid) {
        taskkill /F /PID $listenerPid | Out-Null
    }
}

function Set-StartedProcessPriority {
    param([object]$Process, [string]$Priority)
    if ($Process -and $Priority) {
        try {
            $Process.PriorityClass = $Priority
        }
        catch {
            Write-Warning "Unable to set process priority to $Priority for PID $($Process.Id): $($_.Exception.Message)"
        }
    }
}

function Wait-PortReady {
    param([int]$Port, [int]$TimeoutSeconds = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Get-PortListenerPid -Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Resolve-PortableCommand {
    param(
        [string]$ExplicitPath,
        [string[]]$CandidatePaths,
        [string]$Fallback
    )
    if ($ExplicitPath -and (Test-Path -LiteralPath $ExplicitPath)) {
        return [System.IO.Path]::GetFullPath($ExplicitPath)
    }
    foreach ($candidate in $CandidatePaths) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    return $Fallback
}

function Invoke-ResourceSafety {
    param([string]$Action)
    & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$Root\scripts\Test-ResourceSafety.ps1" `
        -MinFreeMemoryGB $MinFreeMemoryGB `
        -MaxWindowsDoctorNodeProcesses $MaxGuiNodeProcesses `
        -MaxWindowsDoctorTotalWorkingSetMB $MaxWindowsDoctorTotalWorkingSetMB `
        -MaxWindowsDoctorProcessWorkingSetMB $MaxWindowsDoctorProcessWorkingSetMB | Out-Host
    if ($LASTEXITCODE -ne 0) {
        & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$Root\scripts\Stop-WDGuiDevWorkers.ps1" -IncludeDevServer | Out-Null
        Stop-PortListener -Port $GuiPort
        throw "Resource safety check failed during $Action. GUI dev workers were stopped."
    }
}

function Start-Broker {
    Assert-FreeMemory -Action "Broker start"
    $previousNodeOptions = $env:NODE_OPTIONS
    $previousPath = $env:PATH
    $env:NODE_OPTIONS = "--max-old-space-size=$NodeMaxOldSpaceSizeMB"
    $env:NEXT_TELEMETRY_DISABLED = "1"
    $nodeDir = Split-Path -Parent $script:ResolvedNodePath
    if ($nodeDir -and (Test-Path -LiteralPath $nodeDir)) {
        $env:PATH = "$nodeDir;$previousPath"
    }
    if ($RestartBroker) {
        Stop-PortListener -Port $BrokerPort
    }
    if (-not (Get-PortListenerPid -Port $BrokerPort)) {
        $params = @{
            FilePath = $script:ResolvedNodePath
            ArgumentList = "$Root\gui\broker.js"
            WorkingDirectory = "$Root\gui"
            PassThru = $true
        }
        if ($Hidden) { $params.WindowStyle = "Hidden" }
        $process = Start-Process @params
        Set-StartedProcessPriority -Process $process -Priority $ProcessPriority
        if (-not (Wait-PortReady -Port $BrokerPort -TimeoutSeconds 20)) {
            if ($process -and -not $process.HasExited) {
                Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            }
            Stop-PortListener -Port $BrokerPort
            throw "Broker did not become ready on port $BrokerPort within timeout."
        }
    }
    $env:NODE_OPTIONS = $previousNodeOptions
    $env:PATH = $previousPath
}

function Start-Gui {
    Assert-FreeMemory -Action "GUI start"
    $previousNodeOptions = $env:NODE_OPTIONS
    $previousPath = $env:PATH
    $env:NODE_OPTIONS = "--max-old-space-size=$NodeMaxOldSpaceSizeMB"
    $env:NEXT_TELEMETRY_DISABLED = "1"
    $nodeDir = Split-Path -Parent $script:ResolvedNodePath
    if ($nodeDir -and (Test-Path -LiteralPath $nodeDir)) {
        $env:PATH = "$nodeDir;$previousPath"
    }
    & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$Root\scripts\Stop-WDGuiDevWorkers.ps1" | Out-Null
    Invoke-ResourceSafety -Action "GUI preflight"
    if ($RestartGui) {
        Stop-PortListener -Port $GuiPort
        & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$Root\scripts\Stop-WDGuiDevWorkers.ps1" -IncludeDevServer | Out-Null
    }
    if (-not (Get-PortListenerPid -Port $GuiPort)) {
        $params = @{
            FilePath = $script:ResolvedNpmPath
            ArgumentList = "run dev -- -p $GuiPort --hostname 127.0.0.1"
            WorkingDirectory = "$Root\gui"
            PassThru = $true
        }
        if ($Hidden) { $params.WindowStyle = "Hidden" }
        $process = Start-Process @params
        Set-StartedProcessPriority -Process $process -Priority $ProcessPriority
        if (-not $DisableGuiStartupGuard) {
            Start-Sleep -Seconds $GuiStartupGuardSeconds
            Invoke-ResourceSafety -Action "GUI startup guard"
        }
        if (-not $DisableResourceWatchdog) {
            $watchdogArgs = @(
                "-NoProfile",
                "-ExecutionPolicy",
                "RemoteSigned",
                "-File",
                "$Root\scripts\Watch-WDResourceSafety.ps1",
                "-Root",
                $Root,
                "-DurationSeconds",
                $ResourceWatchSeconds,
                "-IntervalSeconds",
                $ResourceWatchIntervalSeconds,
                "-MaxPostCssWorkers",
                $MaxStartupPostCssWorkers,
                "-MaxPostCssWorkerSeconds",
                $MaxPostCssWorkerSeconds,
                "-MinFreeMemoryGB",
                $MinFreeMemoryGB,
                "-MaxWindowsDoctorNodeProcesses",
                $MaxGuiNodeProcesses,
                "-MaxWindowsDoctorTotalWorkingSetMB",
                $MaxWindowsDoctorTotalWorkingSetMB,
                "-MaxWindowsDoctorProcessWorkingSetMB",
                $MaxWindowsDoctorProcessWorkingSetMB,
                "-GuiPort",
                $GuiPort,
                "-ReportPath",
                "$Root\logs\resource-watchdog.latest.json",
                "-Json"
            )
            Start-Process -FilePath "powershell" -ArgumentList $watchdogArgs -WindowStyle Hidden
        }
    }
    $env:NODE_OPTIONS = $previousNodeOptions
    $env:PATH = $previousPath
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$portableRoot = Split-Path -Parent $resolvedRoot
$script:ResolvedNodePath = Resolve-PortableCommand `
    -ExplicitPath $NodePath `
    -CandidatePaths @((Join-Path $portableRoot "node-runtime\node.exe")) `
    -Fallback "node"
$script:ResolvedNpmPath = Resolve-PortableCommand `
    -ExplicitPath $NpmPath `
    -CandidatePaths @((Join-Path $portableRoot "node-runtime\npm.cmd")) `
    -Fallback "npm.cmd"

if (-not $NoBroker) {
    Start-Broker
    if (-not $NoGui) {
        Start-Sleep -Seconds $StartupStepDelaySeconds
        Invoke-ResourceSafety -Action "between Broker and GUI startup"
    }
}

if (-not $NoGui) {
    Start-Gui
}

Start-Sleep -Seconds 2

if ($Verify) {
    Assert-FreeMemory -Action "baseline verification"
    $argsList = @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$Root\scripts\Test-SystemBaseline.ps1")
    if ($SkipBuild -or -not $FullVerify) { $argsList += "-SkipBuild" }
    if ($NoBroker) { $argsList += "-SkipServiceSmoke" }
    & powershell @argsList
}

$status = [PSCustomObject]@{
    GuiUrl = "http://localhost:$GuiPort"
    BrokerUrl = "http://localhost:$BrokerPort"
    GuiPid = Get-PortListenerPid -Port $GuiPort
    BrokerPid = Get-PortListenerPid -Port $BrokerPort
    FreeMemoryGB = Get-FreeMemoryGB
    ReportPath = $ReportPath
}

$statusJson = $status | ConvertTo-Json -Depth 3
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ReportPath, $statusJson, $utf8NoBom)
}

if ($Json) {
    $statusJson
}
else {
    $status
}
