param(
    [string]$Root = "E:\WindowsDoctor",
    [int]$DurationSeconds = 600,
    [int]$IntervalSeconds = 5,
    [double]$MinFreeMemoryGB = 4,
    [int]$MaxPostCssWorkers = 1,
    [int]$MaxPostCssWorkerSeconds = 45,
    [int]$MaxWindowsDoctorNodeProcesses = 8,
    [int]$MaxWindowsDoctorTotalWorkingSetMB = 1200,
    [int]$MaxWindowsDoctorProcessWorkingSetMB = 512,
    [int]$GuiPort = 3000,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$events = New-Object System.Collections.Generic.List[object]
$startedAt = Get-Date
$deadline = $startedAt.AddSeconds($DurationSeconds)

function Add-Event {
    param([string]$Status, [string]$Detail)
    $script:events.Add([PSCustomObject]@{
        Time = (Get-Date).ToString("o")
        Status = $Status
        Detail = $Detail
    })
}

function Get-PortListenerPid {
    param([int]$Port)
    $line = netstat -ano | findstr ":$Port" | findstr "LISTENING" | Select-Object -First 1
    if (-not $line) { return $null }
    return ($line -replace ".*\s+(\d+)$", '$1').Trim()
}

function Stop-PortListener {
    param([int]$Port)
    $listenerPid = Get-PortListenerPid -Port $Port
    if ($listenerPid) {
        taskkill /F /PID $listenerPid | Out-Null
    }
}

$finalStatus = "PASS"
$postCssSeenAt = $null
Add-Event -Status "START" -Detail "DurationSeconds=$DurationSeconds IntervalSeconds=$IntervalSeconds"

while ((Get-Date) -lt $deadline) {
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Test-ResourceSafety.ps1" `
        -Root $resolvedRoot `
        -MinFreeMemoryGB $MinFreeMemoryGB `
        -MaxPostCssWorkers $MaxPostCssWorkers `
        -MaxWindowsDoctorNodeProcesses $MaxWindowsDoctorNodeProcesses `
        -MaxWindowsDoctorTotalWorkingSetMB $MaxWindowsDoctorTotalWorkingSetMB `
        -MaxWindowsDoctorProcessWorkingSetMB $MaxWindowsDoctorProcessWorkingSetMB `
        -Json
    $safety = ($raw | Out-String) | ConvertFrom-Json
    Add-Event -Status $safety.Status -Detail "Free=$($safety.FreeMemoryGB)GB PostCss=$($safety.PostCssWorkerCount) Node=$($safety.WindowsDoctorNodeProcessCount) TotalWS=$($safety.WindowsDoctorTotalWorkingSetMB)MB MaxWS=$($safety.WindowsDoctorMaxProcessWorkingSetMB)MB"

    if ($safety.PostCssWorkerCount -gt 0 -and -not $postCssSeenAt) {
        $postCssSeenAt = Get-Date
    }
    if ($safety.PostCssWorkerCount -eq 0) {
        $postCssSeenAt = $null
    }
    $postCssExpired = $false
    if ($postCssSeenAt) {
        $postCssAge = [int]((Get-Date) - $postCssSeenAt).TotalSeconds
        $postCssExpired = $postCssAge -gt $MaxPostCssWorkerSeconds
        if ($postCssExpired) {
            Add-Event -Status "FAIL" -Detail "PostCSS worker persisted for ${postCssAge}s; max ${MaxPostCssWorkerSeconds}s."
        }
    }

    if ($safety.Status -ne "PASS" -or $postCssExpired) {
        & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Stop-WDGuiDevWorkers.ps1" -Root $resolvedRoot -IncludeDevServer | Out-Null
        Stop-PortListener -Port $GuiPort
        $finalStatus = "STOPPED"
        Add-Event -Status "STOPPED" -Detail "Resource safety failed; GUI dev server stopped."
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}

$result = [PSCustomObject]@{
    Status = $finalStatus
    Root = $resolvedRoot
    StartedAt = $startedAt.ToString("o")
    EndedAt = (Get-Date).ToString("o")
    DurationSeconds = $DurationSeconds
    IntervalSeconds = $IntervalSeconds
    MinFreeMemoryGB = $MinFreeMemoryGB
    MaxPostCssWorkers = $MaxPostCssWorkers
    MaxPostCssWorkerSeconds = $MaxPostCssWorkerSeconds
    MaxWindowsDoctorNodeProcesses = $MaxWindowsDoctorNodeProcesses
    MaxWindowsDoctorTotalWorkingSetMB = $MaxWindowsDoctorTotalWorkingSetMB
    MaxWindowsDoctorProcessWorkingSetMB = $MaxWindowsDoctorProcessWorkingSetMB
    Events = @($events.ToArray())
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
    $result | Format-List
}
