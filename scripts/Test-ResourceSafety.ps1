param(
    [string]$Root = "E:\WindowsDoctor",
    [double]$MinFreeMemoryGB = 4,
    [int]$MaxPostCssWorkers = 0,
    [int]$MaxWindowsDoctorNodeProcesses = 20,
    [int]$MaxWindowsDoctorTotalWorkingSetMB = 1200,
    [int]$MaxWindowsDoctorProcessWorkingSetMB = 512,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$escapedRoot = [regex]::Escape($normalizedRoot)
$postCssPattern = "$escapedRoot\\gui\\\.next\\dev\\build\\postcss\.js"
$rootPattern = "$escapedRoot\\"

$os = Get-CimInstance Win32_OperatingSystem
$freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)

$wdNodeProcesses = @(Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -and
        $_.CommandLine -match $rootPattern
    })

$postCssWorkers = @($wdNodeProcesses |
    Where-Object { $_.CommandLine -match $postCssPattern })

$wdWorkingSetTotalMb = [math]::Round((($wdNodeProcesses | Measure-Object -Property WorkingSetSize -Sum).Sum) / 1MB, 2)
$maxWdProcessWorkingSetMb = 0
if ($wdNodeProcesses.Count -gt 0) {
    $maxWdProcessWorkingSetMb = [math]::Round((($wdNodeProcesses | Measure-Object -Property WorkingSetSize -Maximum).Maximum) / 1MB, 2)
}

$checks = @(
    [PSCustomObject]@{
        Name = "free-memory"
        Status = if ($freeGb -ge $MinFreeMemoryGB) { "PASS" } else { "FAIL" }
        Detail = "Free=${freeGb}GB Required=${MinFreeMemoryGB}GB"
    },
    [PSCustomObject]@{
        Name = "postcss-workers"
        Status = if ($postCssWorkers.Count -le $MaxPostCssWorkers) { "PASS" } else { "FAIL" }
        Detail = "Count=$($postCssWorkers.Count) Max=$MaxPostCssWorkers"
    },
    [PSCustomObject]@{
        Name = "windowsdoctor-node-processes"
        Status = if ($wdNodeProcesses.Count -le $MaxWindowsDoctorNodeProcesses) { "PASS" } else { "FAIL" }
        Detail = "Count=$($wdNodeProcesses.Count) Max=$MaxWindowsDoctorNodeProcesses"
    },
    [PSCustomObject]@{
        Name = "windowsdoctor-node-working-set-total"
        Status = if ($wdWorkingSetTotalMb -le $MaxWindowsDoctorTotalWorkingSetMB) { "PASS" } else { "FAIL" }
        Detail = "Total=${wdWorkingSetTotalMb}MB Max=${MaxWindowsDoctorTotalWorkingSetMB}MB"
    },
    [PSCustomObject]@{
        Name = "windowsdoctor-node-working-set-process"
        Status = if ($maxWdProcessWorkingSetMb -le $MaxWindowsDoctorProcessWorkingSetMB) { "PASS" } else { "FAIL" }
        Detail = "MaxProcess=${maxWdProcessWorkingSetMb}MB Max=${MaxWindowsDoctorProcessWorkingSetMB}MB"
    }
)

$result = [PSCustomObject]@{
    Status = if ($checks.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $normalizedRoot
    FreeMemoryGB = $freeGb
    PostCssWorkerCount = $postCssWorkers.Count
    WindowsDoctorNodeProcessCount = $wdNodeProcesses.Count
    WindowsDoctorTotalWorkingSetMB = $wdWorkingSetTotalMb
    WindowsDoctorMaxProcessWorkingSetMB = $maxWdProcessWorkingSetMb
    Checks = $checks
}

if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $result | Add-Member -NotePropertyName ReportPath -NotePropertyValue $ReportPath
    $jsonText = $result | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
}
else {
    $checks | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
