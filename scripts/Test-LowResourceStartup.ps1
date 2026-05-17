param(
    [string]$Root = "E:\WindowsDoctor",
    [int]$DurationSeconds = 60,
    [int]$IntervalSeconds = 10,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$samples = New-Object System.Collections.Generic.List[object]

function Add-Sample {
    param([object]$Safety, [bool]$BrokerListening)
    $script:samples.Add([PSCustomObject]@{
        Time = (Get-Date).ToString("o")
        Status = $Safety.Status
        FreeMemoryGB = $Safety.FreeMemoryGB
        NodeCount = $Safety.WindowsDoctorNodeProcessCount
        TotalWorkingSetMB = $Safety.WindowsDoctorTotalWorkingSetMB
        MaxProcessWorkingSetMB = $Safety.WindowsDoctorMaxProcessWorkingSetMB
        PostCssWorkers = $Safety.PostCssWorkerCount
        BrokerListening = $BrokerListening
    })
}

try {
    & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Start-WindowsDoctor.ps1" `
        -Root $resolvedRoot `
        -RestartBroker `
        -NoGui `
        -SkipBuild `
        -Hidden `
        -MaxGuiNodeProcesses 4 `
        -MaxWindowsDoctorTotalWorkingSetMB 512 `
        -MaxWindowsDoctorProcessWorkingSetMB 256 `
        -NodeMaxOldSpaceSizeMB 192 `
        -ProcessPriority BelowNormal | Out-Null

    try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:3001/api/health" -TimeoutSec 15
        $ai = Invoke-RestMethod -Uri "http://127.0.0.1:3001/api/ai/triage" -TimeoutSec 30
        $work = Invoke-RestMethod -Uri "http://127.0.0.1:3001/api/work/status" -TimeoutSec 15
    }
    catch {
        throw "Low-resource API smoke failed: $($_.Exception.Message)"
    }

    $deadline = (Get-Date).AddSeconds($DurationSeconds)
    while ((Get-Date) -lt $deadline) {
        $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Test-ResourceSafety.ps1" `
            -Root $resolvedRoot `
            -MaxWindowsDoctorNodeProcesses 4 `
            -MaxWindowsDoctorTotalWorkingSetMB 512 `
            -MaxWindowsDoctorProcessWorkingSetMB 256 `
            -Json
        $safety = ($raw | Out-String) | ConvertFrom-Json
        $brokerLine = netstat -ano | findstr ":3001" | findstr "LISTENING" | Select-Object -First 1
        Add-Sample -Safety $safety -BrokerListening ([bool]$brokerLine)
        Start-Sleep -Seconds $IntervalSeconds
    }

    $sampleArray = @($samples.ToArray())
    $status = if (($sampleArray.Status -contains "FAIL") -or ($sampleArray.BrokerListening -contains $false)) { "FAIL" } else { "PASS" }
    $result = [PSCustomObject]@{
        Status = $status
        Root = $resolvedRoot
        Mode = "low-resource-broker-only"
        HealthStatus = $health.status
        AiTriageStatus = $ai.status
        WorkStatus = $work.status
        Samples = $sampleArray
        ReportPath = $ReportPath
    }
}
finally {
    & powershell -NoProfile -ExecutionPolicy RemoteSigned -File "$resolvedRoot\scripts\Stop-WindowsDoctorServices.ps1" -Root $resolvedRoot | Out-Null
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

if ($result.Status -eq "FAIL") { exit 1 }
