param(
    [string]$Root = "E:\WindowsDoctor",
    [switch]$IncludeDevServer,
    [switch]$WhatIf,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$escapedRoot = [regex]::Escape($normalizedRoot)
$workerPattern = "$escapedRoot\\gui\\\.next\\dev\\build\\postcss\.js"
$devPattern = "$escapedRoot\\gui\\node_modules\\next\\dist\\bin\\next"

$targets = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -eq "node.exe" -and
        $_.CommandLine -and
        ($_.CommandLine -match $workerPattern -or ($IncludeDevServer -and $_.CommandLine -match $devPattern))
    } |
    Select-Object ProcessId, ParentProcessId, Name, CommandLine

foreach ($target in $targets) {
    if (-not $WhatIf) {
        Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

$result = [PSCustomObject]@{
    Root = $normalizedRoot
    IncludeDevServer = [bool]$IncludeDevServer
    WhatIf = [bool]$WhatIf
    Stopped = if ($WhatIf) { 0 } else { @($targets).Count }
    Matched = @($targets).Count
}

if ($ReportPath) {
    $result | Add-Member -NotePropertyName ReportPath -NotePropertyValue $ReportPath
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $jsonText = $result | ConvertTo-Json -Depth 4
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 4
}
else {
    $result
}
