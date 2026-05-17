# WindowsDoctor Core Module
# Version: 0.4.0
# Description: 系統資訊、診斷、自動化哨兵與效能優化核心模組

function Get-WDSystemHealth {
    [CmdletBinding()]
    param()
    process {
        $os = Get-CimInstance Win32_OperatingSystem
        $cs = Get-CimInstance Win32_ComputerSystem
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        return [PSCustomObject]@{
            Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            OS           = $os.Caption
            Version      = $os.Version
            IsAdmin      = (Test-WDAdmin)
            RAM_Total_GB = [Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
            Disks        = $disks | ForEach-Object { [PSCustomObject]@{ Drive = $_.DeviceID; FreeSpaceGB = [Math]::Round($_.FreeSpace / 1GB, 2); Health = "Healthy" } }
        }
    }
}

function Get-WDEventLogSummary {
    [CmdletBinding()]
    param([int]$Hours = 24)
    process {
        try {
            $startTime = (Get-Date).AddHours(-$Hours)
            $events = Get-WinEvent -FilterHashtable @{LogName = 'System', 'Application'; Level = 1, 2; StartTime = $startTime } -MaxEvents 50 -ErrorAction SilentlyContinue
            return $events | ForEach-Object {
                [PSCustomObject]@{
                    EventID = $_.Id
                    Source  = $_.ProviderName
                    Message = $_.Message.Split("`n")[0].Trim()
                }
            }
        }
        catch { return @() }
    }
}

function Get-WDKnowledgeBase {
    [CmdletBinding()]
    param([string]$Path = "e:\WindowsDoctor\knowledge_base")
    process {
        $kb = New-Object System.Collections.Generic.List[PSCustomObject]
        if (-not (Test-Path $Path)) { return $kb }
        Get-ChildItem -Path $Path -Filter "*.md" | ForEach-Object {
            $raw = Get-Content $_.FullName -Raw
            $parts = $raw -split "---"
            if ($parts.Count -ge 3) {
                $yaml = $parts[1]; $meta = @{}
                $yaml -split "\r?\n" | ForEach-Object {
                    if ($_ -match "^\s*([\w\-]+):\s*(.*)") { $meta[$matches[1].Trim()] = $matches[2].Trim().Trim('"').Trim("'") }
                }
                if ($meta.ContainsKey("ID")) {
                    $kb.Add([PSCustomObject]@{
                            ID          = $meta["ID"]
                            ErrorCode   = $meta["ErrorCode"]
                            AutoRepair  = $meta["AutoRepair"] -eq "true"
                            Remediation = $meta["Remediation_Steps"]
                            Title       = $meta["Title"]
                        })
                }
            }
        }
        return $kb
    }
}

function Invoke-WDAnalysis {
    [CmdletBinding()]
    param($EventData, $MockError, [string]$KBPath = "e:\WindowsDoctor\knowledge_base")
    process {
        $msg = $EventData.Message
        if ($MockError) { $msg = $MockError }
        $kb = Get-WDKnowledgeBase -Path $KBPath
        foreach ($issue in $kb) {
            if ($null -ne $issue.ErrorCode -and $msg -match [regex]::Escape($issue.ErrorCode)) {
                return $issue
            }
        }
        return $null
    }
}

function Start-WDSentry {
    [CmdletBinding()]
    param([int]$IntervalSeconds = 60)
    process {
        Write-Host ">>> WindowsDoctor Sentry Mode ACTIVE." -ForegroundColor Cyan
        while ($true) {
            $recentEvents = Get-WDEventLogSummary -Hours 1 | Select-Object -First 5
            foreach ($logEvent in $recentEvents) {
                $finding = Invoke-WDAnalysis -EventData $logEvent
                if ($null -ne $finding -and $finding.AutoRepair) {
                    $script = "e:\WindowsDoctor\$($finding.Remediation)"
                    if (Test-Path $script) {
                        powershell -ExecutionPolicy Bypass -File $script
                    }
                }
            }
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

function Optimize-WDSystem {
    [CmdletBinding()]
    param([switch]$CleanTemp, [switch]$FlushDNS)
    process {
        if ($CleanTemp) {
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        if ($FlushDNS) {
            ipconfig /flushdns | Out-Null
        }
        Write-Host "System Optimization Complete." -ForegroundColor Green
    }
}

function Optimize-WDDisk {
    [CmdletBinding()]
    param([string]$Drive = "C")
    process {
        Optimize-Volume -DriveLetter $Drive -ReTrim -Verbose
        Write-Host "Disk Optimization Complete." -ForegroundColor Green
    }
}

function Test-WDAdmin {
    [CmdletBinding()]
    param()
    process {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

function Invoke-WDAdminRequest {
    [CmdletBinding()]
    param([string]$Command = "node broker.js", [string]$WorkingDirectory = "e:\WindowsDoctor\gui")
    process {
        try {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"cd $WorkingDirectory; $Command`"" -Verb RunAs -ErrorAction Stop
        }
        catch { Write-Error "Elevation Denied." }
    }
}

function Get-WDPrinterStatus {
    [CmdletBinding()]
    param()
    process {
        return [PSCustomObject]@{
            SpoolerStatus = (Get-Service -Name Spooler).Status
            Printers      = Get-CimInstance Win32_Printer | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Status = $_.PrinterStatus; Port = $_.PortName } }
        }
    }
}

function Get-WDDeviceStatus {
    [CmdletBinding()]
    param()
    process {
        return Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
            [PSCustomObject]@{ DeviceName = $_.Name; ErrorCode = $_.ConfigManagerErrorCode; Status = $_.Status }
        }
    }
}

function New-WDLearningCase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$ErrorCode,
        [string]$Description = "AI Learned",
        [string]$RemediationScript = "scripts/Maintenance-Daily.ps1",
        [bool]$AutoRepair = $false,
        [string]$KBPath = "e:\WindowsDoctor\knowledge_base"
    )
    process {
        $id = "LEARN-" + (Get-Date -Format "yyyyMMdd-HHmm")
        $path = "$KBPath\$($id).md"
        $content = @"
---
ID: $id
Title: $Title
ErrorCode: "$ErrorCode"
AutoRepair: $($AutoRepair.ToString().ToLower())
Remediation_Steps: $RemediationScript
---
# $Title
## Details
$Description
"@
        $content | Out-File $path -Encoding utf8 -Force
        return $id
    }
}

function Repair-WDBoot {
    [CmdletBinding()]
    param()
    process {
        $vols = Get-Volume | Where-Object { $_.DriveType -eq "Fixed" }
        foreach ($v in $vols) {
            $p = "$($v.DriveLetter):\Windows"
            if (Test-Path $p) { bcdboot $p /l zh-tw; return "Fixed" }
        }
        return "Failed"
    }
}

function Get-WDBiosStatus {
    [CmdletBinding()]
    param()
    process {
        $bios = Get-CimInstance Win32_BIOS
        $secureBoot = $false
        try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $secureBoot = $false }
        return [PSCustomObject]@{
            Manufacturer = $bios.Manufacturer
            TPM_Enabled  = [bool](Get-CimInstance -Namespace root\cimv2\security\microsofttpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue)
            SecureBoot   = $secureBoot
        }
    }
}

function Set-WDCredential {
    [CmdletBinding()]
    param([string]$Username, [string]$Password, [string]$Path = "e:\WindowsDoctor\.vault\admin.cred")
    process {
        $dir = Split-Path $Path; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
        $cred = New-Object System.Management.Automation.PSCredential($Username, ($Password | ConvertTo-SecureString -AsPlainText -Force))
        $cred | Export-CliXml -Path $Path
    }
}

function Get-WDCredential {
    [CmdletBinding()]
    param([string]$Path = "e:\WindowsDoctor\.vault\admin.cred")
    process { if (Test-Path $Path) { return Import-CliXml -Path $Path }; return $null }
}

function Get-WDEnvironmentSignature {
    [CmdletBinding()]
    param()
    process {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^169\.' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
        if (-not $ip) { $ip = "0.0.0.0" }
        $subnet = "Unknown"; if ($ip -match "^(\d+\.\d+\.\d+)\.") { $subnet = $matches[1] }
        $uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
        return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$subnet|$uuid"))
    }
}

function Test-WDEnvironmentLock {
    [CmdletBinding()]
    param([string]$Path = "e:\WindowsDoctor\.vault\env.lock")
    process {
        if (-not (Test-Path $Path)) { return $true }
        $stored = (Get-Content $Path -Raw).Trim()
        $current = (Get-WDEnvironmentSignature).Trim()
        return $stored -eq $current
    }
}

function Set-WDEnvironmentLock {
    [CmdletBinding()]
    param([string]$Path = "e:\WindowsDoctor\.vault\env.lock")
    process {
        $dir = Split-Path $Path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Get-WDEnvironmentSignature | Out-File $Path -Force
    }
}

function Sync-WDEnvironment {
    [CmdletBinding()]
    param(
        [switch]$NAS,
        [switch]$Web,
        [string]$KBPath = "e:\WindowsDoctor\knowledge_base"
    )
    process {
        $results = @{}
        if ($NAS) {
            Write-Host ">>> Triggering NAS Sync..." -ForegroundColor Cyan
            $nasResult = powershell -ExecutionPolicy Bypass -File "e:\WindowsDoctor\scripts\Sync-NASKnowledge.ps1" -LocalPath $KBPath
            $results["NAS"] = $nasResult
        }
        if ($Web) {
            Write-Host ">>> Triggering Web KB Fetch..." -ForegroundColor Cyan
            $webResult = powershell -ExecutionPolicy Bypass -File "e:\WindowsDoctor\scripts\Invoke-WebKBUpdate.ps1" -OutputPath $KBPath
            $results["Web"] = "Completed"
        }
        return $results
    }
}

Export-ModuleMember -Function Get-WD*, Invoke-WD*, New-WD*, Repair-WD*, Set-WD*, Test-WD*, Start-WD*, Sync-WD*
