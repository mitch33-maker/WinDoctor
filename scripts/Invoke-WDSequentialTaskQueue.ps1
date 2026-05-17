param(
    [string]$Root = "E:\WindowsDoctor",
    [string[]]$Task = @(
        "resource-safety",
        "kb-markdown-encoding",
        "offline-kb-export",
        "offline-kb-validate",
        "normalized-kb-export",
        "normalized-kb-validate",
        "documentation-sync",
        "winpe-offline-flow",
        "portable-usb-readiness",
        "version-policy",
        "gui-smoke-offline",
        "winpe-check"
    ),
    [double]$MinFreeMemoryGB = 4,
    [int]$MaxWindowsDoctorNodeProcesses = 8,
    [int]$MaxWindowsDoctorTotalWorkingSetMB = 1200,
    [int]$MaxWindowsDoctorProcessWorkingSetMB = 512,
    [switch]$ContinueOnFailure,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$results = New-Object System.Collections.Generic.List[object]

function Invoke-ResourceGate {
    param([string]$Phase)
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Test-ResourceSafety.ps1" `
        -Root $resolvedRoot `
        -MinFreeMemoryGB $MinFreeMemoryGB `
        -MaxWindowsDoctorNodeProcesses $MaxWindowsDoctorNodeProcesses `
        -MaxWindowsDoctorTotalWorkingSetMB $MaxWindowsDoctorTotalWorkingSetMB `
        -MaxWindowsDoctorProcessWorkingSetMB $MaxWindowsDoctorProcessWorkingSetMB `
        -Json
    $gate = ($raw | Out-String) | ConvertFrom-Json
    if ($gate.Status -ne "PASS") {
        throw "Resource gate failed during $Phase. Free=$($gate.FreeMemoryGB)GB PostCss=$($gate.PostCssWorkerCount) Node=$($gate.WindowsDoctorNodeProcessCount) TotalWS=$($gate.WindowsDoctorTotalWorkingSetMB)MB MaxWS=$($gate.WindowsDoctorMaxProcessWorkingSetMB)MB"
    }
    return $gate
}

function Get-TaskCommand {
    param([string]$Name)
    switch ($Name) {
        "resource-safety" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-ResourceSafety.ps1", "-Root", $resolvedRoot, "-MinFreeMemoryGB", "$MinFreeMemoryGB", "-MaxWindowsDoctorNodeProcesses", "$MaxWindowsDoctorNodeProcesses", "-Json")) }
        "kb-markdown-encoding" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-KBMarkdownEncoding.ps1", "-Json")) }
        "offline-kb-export" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Export-OfflineKBDatabase.ps1", "-Json")) }
        "offline-kb-validate" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-OfflineKBDatabase.ps1", "-Json")) }
        "normalized-kb-export" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Export-NormalizedKBDatabase.ps1", "-Json")) }
        "normalized-kb-validate" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-NormalizedKBDatabase.ps1", "-Json")) }
        "documentation-sync" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-DocumentationSync.ps1", "-Json")) }
        "winpe-offline-flow" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-WinPEOfflineFlow.ps1", "-Json")) }
        "portable-usb-readiness" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-PortableUsbReadiness.ps1", "-Json")) }
        "version-policy" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-VersionPolicy.ps1", "-Json")) }
        "gui-smoke-offline" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Test-GuiSmoke.ps1", "-AllowOffline", "-Json")) }
        "winpe-check" { return @("powershell", @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", "$resolvedRoot\scripts\Build-WinPEMedia.ps1", "-CheckOnly", "-Json")) }
        "broker-services" { return @("npm.cmd", @("run", "test:broker", "--prefix", "$resolvedRoot\gui")) }
        "lint" { return @("npm.cmd", @("run", "lint", "--prefix", "$resolvedRoot\gui")) }
        default { throw "Unknown sequential task: $Name" }
    }
}

foreach ($taskName in $Task) {
    $started = Get-Date
    try {
        $before = Invoke-ResourceGate -Phase "before $taskName"
        $command = Get-TaskCommand -Name $taskName
        $exe = $command[0]
        $args = $command[1]
        $output = & $exe @args 2>&1
        $exitCode = if ($LASTEXITCODE -ne $null) { $LASTEXITCODE } else { 0 }
        if ($exitCode -ne 0) {
            throw "Task exited with code $exitCode. $($output | Out-String)"
        }
        $after = Invoke-ResourceGate -Phase "after $taskName"
        $results.Add([PSCustomObject]@{
            Name = $taskName
            Status = "PASS"
            StartedAt = $started.ToString("o")
            EndedAt = (Get-Date).ToString("o")
            FreeMemoryBeforeGB = $before.FreeMemoryGB
            FreeMemoryAfterGB = $after.FreeMemoryGB
            WindowsDoctorNodeProcessesAfter = $after.WindowsDoctorNodeProcessCount
        })
    }
    catch {
        $results.Add([PSCustomObject]@{
            Name = $taskName
            Status = "FAIL"
            StartedAt = $started.ToString("o")
            EndedAt = (Get-Date).ToString("o")
            Detail = $_.Exception.Message
        })
        if (-not $ContinueOnFailure) {
            break
        }
    }
}

$resultArray = @($results.ToArray())
$result = [PSCustomObject]@{
    Status = if ($resultArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $resolvedRoot
    Sequential = $true
    ContinueOnFailure = [bool]$ContinueOnFailure
    MinFreeMemoryGB = $MinFreeMemoryGB
    MaxWindowsDoctorNodeProcesses = $MaxWindowsDoctorNodeProcesses
    MaxWindowsDoctorTotalWorkingSetMB = $MaxWindowsDoctorTotalWorkingSetMB
    MaxWindowsDoctorProcessWorkingSetMB = $MaxWindowsDoctorProcessWorkingSetMB
    RequestedTasks = $Task
    Results = $resultArray
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $resultArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
