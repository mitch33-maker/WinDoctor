param(
    [switch]$Preview,
    [switch]$Execute,
    [string]$ConfirmToken = "",
    [switch]$ForceLogoffDisconnectedUsers,
    [int]$MinIdleMinutes = 30,
    [switch]$CleanDisk,
    [int]$TempFileMinAgeHours = 24,
    [switch]$ReleaseMemory,
    [switch]$SystemMaintenance,
    [string]$LogPath = "E:\WindowsDoctor\logs\windows-maintenance.log",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $Preview -and -not $Execute) { $Preview = $true }
if ($Execute -and $ConfirmToken -ne "RUN") { throw "Execution requires -ConfirmToken RUN" }

function New-Action {
    param(
        [string]$Name,
        [string]$Mode,
        [string]$Status,
        [string]$Detail
    )
    [PSCustomObject]@{
        Name = $Name
        Mode = $Mode
        Status = $Status
        Detail = $Detail
    }
}

function Write-MaintenanceLog {
    param([string]$Message)
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -Encoding UTF8 -LiteralPath $LogPath -Value $line
}

function Convert-IdleTimeToMinutes {
    param([string]$Value)
    if (-not $Value -or $Value -eq ".") { return 0 }
    if ($Value -match '^(?<days>\d+)\+(?<hours>\d+):(?<minutes>\d+)$') {
        return ([int]$Matches.days * 1440) + ([int]$Matches.hours * 60) + [int]$Matches.minutes
    }
    if ($Value -match '^(?<hours>\d+):(?<minutes>\d+)$') {
        return ([int]$Matches.hours * 60) + [int]$Matches.minutes
    }
    if ($Value -match '^\d+$') { return [int]$Value }
    return 0
}

function Get-UserSessions {
    $raw = & quser 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) { return @() }

    @($raw | Select-Object -Skip 1 | ForEach-Object {
            $line = [string]$_
            $normalized = ($line.Trim() -replace '\s+', ' ')
            if (-not $normalized) { return }
            $parts = $normalized -split ' '
            if ($parts.Count -lt 5) { return }

            $current = $parts[0].StartsWith(">")
            $userName = $parts[0].TrimStart(">")
            $sessionName = ""
            $idIndex = 1
            if ($parts[1] -notmatch '^\d+$') {
                $sessionName = $parts[1]
                $idIndex = 2
            }
            if ($parts[$idIndex] -notmatch '^\d+$') { return }
            $id = [int]$parts[$idIndex]
            $state = $parts[$idIndex + 1]
            $idle = $parts[$idIndex + 2]

            [PSCustomObject]@{
                UserName = $userName
                SessionName = $sessionName
                Id = $id
                State = $state
                IdleTime = $idle
                IdleMinutes = Convert-IdleTimeToMinutes -Value $idle
                IsCurrent = $current
            }
        })
}

function Get-DirectoryCleanupSummary {
    param(
        [string]$Path,
        [datetime]$OlderThan
    )
    if (-not (Test-Path $Path)) {
        return [PSCustomObject]@{ Path = $Path; Exists = $false; FileCount = 0; Bytes = 0 }
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $OlderThan })
    $bytes = 0
    foreach ($file in $files) { $bytes += [int64]$file.Length }
    [PSCustomObject]@{
        Path = $Path
        Exists = $true
        FileCount = $files.Count
        Bytes = $bytes
    }
}

function Remove-OldFiles {
    param(
        [string]$Path,
        [datetime]$OlderThan
    )
    if (-not (Test-Path $Path)) { return 0 }
    $removed = 0
    Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $OlderThan } |
        ForEach-Object {
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                $removed += 1
            }
            catch {
            }
        }
    return $removed
}

$actions = New-Object System.Collections.Generic.List[object]
$mode = if ($Execute) { "execute" } else { "preview" }

if ($ForceLogoffDisconnectedUsers) {
    $sessions = @(Get-UserSessions)
    $targets = @($sessions | Where-Object {
            -not $_.IsCurrent -and
            $_.State -match 'Disc|Disconnected' -and
            [int]$_.IdleMinutes -ge $MinIdleMinutes
        })

    if ($Execute) {
        foreach ($session in $targets) {
            & logoff $session.Id 2>$null
            Write-MaintenanceLog -Message "logoff session id=$($session.Id) user=$($session.UserName)"
        }
    }

    $actions.Add((New-Action -Name "force-logoff-disconnected-users" -Mode $mode -Status "PASS" -Detail "targets=$($targets.Count) minIdleMinutes=$MinIdleMinutes"))
}

if ($CleanDisk) {
    $olderThan = (Get-Date).AddHours(-1 * $TempFileMinAgeHours)
    $paths = @(
        $env:TEMP,
        "$env:WINDIR\Temp"
    ) | Where-Object { $_ } | Select-Object -Unique

    $summaries = @($paths | ForEach-Object { Get-DirectoryCleanupSummary -Path $_ -OlderThan $olderThan })
    $totalFiles = (@($summaries | Measure-Object -Property FileCount -Sum).Sum)
    $totalBytes = (@($summaries | Measure-Object -Property Bytes -Sum).Sum)

    if ($Execute) {
        $removed = 0
        foreach ($path in $paths) { $removed += Remove-OldFiles -Path $path -OlderThan $olderThan }
        try {
            Clear-RecycleBin -Force -ErrorAction Stop
            Write-MaintenanceLog -Message "clear recycle bin"
        }
        catch {
        }
        Write-MaintenanceLog -Message "disk cleanup removedFiles=$removed olderThan=$($olderThan.ToString('s'))"
        $actions.Add((New-Action -Name "clean-disk-space" -Mode $mode -Status "PASS" -Detail "removedFiles=$removed previewFiles=$totalFiles previewBytes=$totalBytes"))
    }
    else {
        $actions.Add((New-Action -Name "clean-disk-space" -Mode $mode -Status "PASS" -Detail "previewFiles=$totalFiles previewBytes=$totalBytes minAgeHours=$TempFileMinAgeHours"))
    }
}

if ($ReleaseMemory) {
    if ($Execute) {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        Write-MaintenanceLog -Message "requested dotnet garbage collection for maintenance shell"
    }
    $os = Get-CimInstance Win32_OperatingSystem
    $freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $actions.Add((New-Action -Name "release-memory" -Mode $mode -Status "PASS" -Detail "freeMemoryGB=$freeGb note=close unused apps or log off disconnected sessions for meaningful memory recovery"))
}

if ($SystemMaintenance) {
    $commands = @(
        "dism /Online /Cleanup-Image /ScanHealth",
        "sfc /verifyonly",
        "chkdsk C: /scan"
    )
    if ($Execute) {
        foreach ($command in $commands) {
            Write-MaintenanceLog -Message "run $command"
            & cmd.exe /c $command | Out-Null
        }
    }
    $actions.Add((New-Action -Name "system-maintenance" -Mode $mode -Status "PASS" -Detail ($commands -join "; ")))
}

if ($actions.Count -eq 0) {
    $actions.Add((New-Action -Name "no-actions-selected" -Mode $mode -Status "PASS" -Detail "select one or more switches: -ForceLogoffDisconnectedUsers -CleanDisk -ReleaseMemory -SystemMaintenance"))
}

$actionArray = @($actions.ToArray())
$result = [PSCustomObject]@{
    Status = if ($actionArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Mode = $mode
    Executed = [bool]$Execute
    GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    ReportPath = $ReportPath
    Actions = $actionArray
}

$resultJson = $result | ConvertTo-Json -Depth 8
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
    $actionArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
