param(
    [int]$Top = 15,
    [string[]]$Names = @("node", "npm", "powershell", "pwsh", "cmd"),
    [string]$ReportPath = "",
    [switch]$IncludeCommandLine,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$os = Get-CimInstance Win32_OperatingSystem
$memory = [PSCustomObject]@{
    TotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    FreeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    FreePct = [math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100, 1)
}

$topProcesses = Get-Process |
    Sort-Object WorkingSet64 -Descending |
    Select-Object -First $Top Id, ProcessName, CPU, @{Name = "MemoryMB"; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 1) } }, Path

$escaped = ($Names | ForEach-Object { [regex]::Escape($_) }) -join "|"
$targetProcesses = Get-CimInstance Win32_Process |
    Where-Object { $_.Name -match "^($escaped)\.exe$" } |
    ForEach-Object {
        $proc = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
        $item = [ordered]@{
            ProcessId = $_.ProcessId
            ParentProcessId = $_.ParentProcessId
            Name = $_.Name
            MemoryMB = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB, 1) } else { $null }
            CommandLineLength = if ($_.CommandLine) { $_.CommandLine.Length } else { 0 }
        }

        if ($IncludeCommandLine) {
            $item.CommandLine = $_.CommandLine
        }

        [PSCustomObject]$item
    } |
    Sort-Object MemoryMB -Descending

$snapshot = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Memory = $memory
    TopProcesses = $topProcesses
    TargetProcesses = $targetProcesses
}

if ($ReportPath) {
    $snapshot | Add-Member -NotePropertyName ReportPath -NotePropertyValue $ReportPath
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $jsonText = $snapshot | ConvertTo-Json -Depth 6
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $snapshot | ConvertTo-Json -Depth 6
}
else {
    $snapshot
}
