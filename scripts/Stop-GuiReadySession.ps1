param(
    [string]$Root = "",
    [int[]]$Ports = @(3000, 3001),
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = Join-Path $env:LOCALAPPDATA "WindowsDoctorPortable\GUIREADY\WindowsDoctor"
}

$stopped = New-Object System.Collections.Generic.List[object]

if (Test-Path -LiteralPath (Join-Path $Root "scripts\Stop-WDGuiDevWorkers.ps1")) {
    & powershell -NoProfile -ExecutionPolicy RemoteSigned -File (Join-Path $Root "scripts\Stop-WDGuiDevWorkers.ps1") -IncludeDevServer | Out-Null
}

foreach ($port in $Ports) {
    $line = netstat -ano | findstr ":$port" | findstr "LISTENING" | Select-Object -First 1
    if (-not $line) {
        $stopped.Add([PSCustomObject]@{ Port = $port; Pid = ""; Status = "SKIP"; Detail = "No listener" })
        continue
    }

    $pidText = ($line -replace ".*\s+(\d+)$", '$1').Trim()
    if ($pidText) {
        taskkill /F /PID $pidText | Out-Null
        $stopped.Add([PSCustomObject]@{ Port = $port; Pid = $pidText; Status = "PASS"; Detail = "Stopped listener" })
    }
}

$result = [PSCustomObject]@{
    Status = "PASS"
    Root = $Root
    Ports = $stopped.ToArray()
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result.Ports | Format-Table -AutoSize
}
