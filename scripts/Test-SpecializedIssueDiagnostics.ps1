param(
    [string]$Root = "E:\WindowsDoctor",
    [ValidateSet("printer", "windows_update", "network", "boot", "performance", "hardware", "system_integrity", "general")]
    [string]$Component = "general",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail,
        [object]$Data = $null
    )
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
        Data = $Data
    })
}

function Add-ServiceCheck {
    param([string[]]$Names)
    foreach ($name in $Names) {
        try {
            $service = Get-Service -Name $name -ErrorAction Stop
            Add-Check -Name "service-$name" -Status "PASS" -Detail "status=$($service.Status) startType=$($service.StartType)" -Data ([PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = [string]$service.Status
                StartType = [string]$service.StartType
            })
        }
        catch {
            Add-Check -Name "service-$name" -Status "WARN" -Detail $_.Exception.Message
        }
    }
}

switch ($Component) {
    "printer" {
        Add-ServiceCheck -Names @("Spooler")
        $queuePath = "C:\Windows\System32\spool\PRINTERS"
        try {
            $queueFiles = @(Get-ChildItem -LiteralPath $queuePath -File -ErrorAction SilentlyContinue)
            Add-Check -Name "printer-queue-files" -Status "PASS" -Detail "files=$($queueFiles.Count)" -Data ([PSCustomObject]@{ Path = $queuePath; Count = $queueFiles.Count })
        }
        catch {
            Add-Check -Name "printer-queue-files" -Status "WARN" -Detail $_.Exception.Message
        }
    }
    "windows_update" {
        Add-ServiceCheck -Names @("wuauserv", "BITS", "CryptSvc", "msiserver")
        foreach ($folder in @("C:\Windows\SoftwareDistribution", "C:\Windows\System32\catroot2")) {
            Add-Check -Name ("path-" + (Split-Path -Leaf $folder)) -Status "PASS" -Detail "exists=$(Test-Path -LiteralPath $folder)" -Data ([PSCustomObject]@{ Path = $folder; Exists = (Test-Path -LiteralPath $folder) })
        }
    }
    "network" {
        try {
            $configs = @(Get-NetIPConfiguration -ErrorAction Stop)
            $withGateway = @($configs | Where-Object { $_.IPv4DefaultGateway -or $_.IPv6DefaultGateway })
            $apipa = @($configs | Where-Object { @($_.IPv4Address.IPAddress) -match '^169\.254\.' })
            $status = if ($withGateway.Count -eq 0 -or $apipa.Count -gt 0) { "WARN" } else { "PASS" }
            Add-Check -Name "network-ip-configuration" -Status $status -Detail "interfaces=$($configs.Count) defaultGateway=$($withGateway.Count) apipa=$($apipa.Count)"
        }
        catch {
            Add-Check -Name "network-ip-configuration" -Status "WARN" -Detail $_.Exception.Message
        }
        try {
            $proxy = (& netsh winhttp show proxy | Out-String).Trim() -replace "\s+", " "
            Add-Check -Name "network-winhttp-proxy" -Status "PASS" -Detail $proxy
        }
        catch {
            Add-Check -Name "network-winhttp-proxy" -Status "WARN" -Detail $_.Exception.Message
        }
    }
    "boot" {
        foreach ($path in @("C:\Windows\System32\winload.efi", "C:\Windows\System32\winload.exe")) {
            Add-Check -Name ("boot-file-" + (Split-Path -Leaf $path)) -Status "PASS" -Detail "exists=$(Test-Path -LiteralPath $path)" -Data ([PSCustomObject]@{ Path = $path; Exists = (Test-Path -LiteralPath $path) })
        }
    }
    "performance" {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $freeGb = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            Add-Check -Name "performance-free-memory" -Status (if ($freeGb -ge 4) { "PASS" } else { "WARN" }) -Detail "freeMemoryGB=$freeGb"
        }
        catch {
            Add-Check -Name "performance-free-memory" -Status "WARN" -Detail $_.Exception.Message
        }
    }
    "hardware" {
        try {
            $problemDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.ConfigManagerErrorCode -ne 0 })
            Add-Check -Name "hardware-device-manager-codes" -Status (if ($problemDevices.Count -gt 0) { "WARN" } else { "PASS" }) -Detail "problemDevices=$($problemDevices.Count)" -Data (@($problemDevices | Select-Object -First 10 Name, ConfigManagerErrorCode, PNPDeviceID))
        }
        catch {
            Add-Check -Name "hardware-device-manager-codes" -Status "WARN" -Detail $_.Exception.Message
        }
    }
    "system_integrity" {
        foreach ($path in @("C:\Windows\Logs\CBS\CBS.log", "C:\Windows\Logs\DISM\dism.log")) {
            Add-Check -Name ("integrity-log-" + (Split-Path -Leaf $path)) -Status "PASS" -Detail "exists=$(Test-Path -LiteralPath $path)" -Data ([PSCustomObject]@{ Path = $path; Exists = (Test-Path -LiteralPath $path) })
        }
    }
    default {
        Add-Check -Name "general-component" -Status "PASS" -Detail "No specialized component selected"
    }
}

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if ($checkArray.Status -contains "WARN") { "WARN" } elseif ($checkArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Phase = "specialized-issue-diagnostics"
    Root = $normalizedRoot
    Component = $Component
    CheckCount = $checkArray.Count
    Checks = $checkArray
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $result }
