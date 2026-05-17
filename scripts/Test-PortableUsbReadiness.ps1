param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$USBPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$steps = New-Object System.Collections.Generic.List[object]

function Add-Step {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail = ""
    )
    $script:steps.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    })
}

function Invoke-JsonScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    $raw = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $ScriptPath @Arguments -Json
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $ScriptPath"
    }
    ($raw | Out-String) | ConvertFrom-Json
}

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Command
    )
    try {
        $detail = & $Command
        Add-Step -Name $Name -Status "PASS" -Detail ([string]$detail)
    }
    catch {
        Add-Step -Name $Name -Status "FAIL" -Detail $_.Exception.Message
    }
}

$kbEncodingScript = Join-Path $Root "scripts\Test-KBMarkdownEncoding.ps1"
$exportScript = Join-Path $Root "scripts\Export-OfflineKBDatabase.ps1"
$validateScript = Join-Path $Root "scripts\Test-OfflineKBDatabase.ps1"
$normalizedExportScript = Join-Path $Root "scripts\Export-NormalizedKBDatabase.ps1"
$normalizedValidateScript = Join-Path $Root "scripts\Test-NormalizedKBDatabase.ps1"
$searchScript = Join-Path $Root "scripts\Search-OfflineKB.ps1"
$repairScript = Join-Path $Root "scripts\Invoke-AllowedRepair.ps1"
$menuScript = Join-Path $Root "scripts\Start-WinPEOfflineMenu.ps1"
$startnetScript = Join-Path $Root "scripts\New-WinPEStartNet.ps1"
$mediaScript = Join-Path $Root "scripts\Build-WinPEMedia.ps1"
$statusScript = Join-Path $Root "scripts\Start-WindowsDoctor.ps1"
$scanScript = Join-Path $Root "scripts\Test-SystemErrorScan.ps1"
$selfTestScript = Join-Path $Root "scripts\Test-PortableRuntimeSelfTest.ps1"

Test-Step -Name "portable-release-order" -Command { "portable-usb-first; installer-deferred" }
Test-Step -Name "kb-markdown-encoding" -Command {
    $result = Invoke-JsonScript -ScriptPath $kbEncodingScript
    if ($result.Status -ne "PASS") { throw "KB markdown encoding failed" }
    "$($result.TotalFiles) files"
}
Test-Step -Name "offline-kb-export" -Command {
    $result = Invoke-JsonScript -ScriptPath $exportScript
    if ($result.Status -ne "PASS") { throw "Offline KB export failed" }
    "$($result.TotalRules) rules"
}
Test-Step -Name "offline-kb-validate" -Command {
    $result = Invoke-JsonScript -ScriptPath $validateScript
    if ($result.Status -ne "PASS") { throw "Offline KB validation failed" }
    "$($result.TotalRules) rules"
}
Test-Step -Name "normalized-kb-export" -Command {
    $result = Invoke-JsonScript -ScriptPath $normalizedExportScript
    if ($result.Status -ne "PASS") { throw "Normalized KB export failed" }
    "$($result.TotalRecords) records sources=$($result.SourceCount)"
}
Test-Step -Name "normalized-kb-validate" -Command {
    $result = Invoke-JsonScript -ScriptPath $normalizedValidateScript
    if ($result.Status -ne "PASS") { throw "Normalized KB validation failed" }
    "$($result.TotalRecords) records public=$($result.PublicReferenceRecords)"
}
Test-Step -Name "offline-kb-maintenance-search" -Command {
    $result = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-Query", "SYSTEM_MAINTENANCE")
    if ($result.Status -ne "PASS" -or [int]$result.MatchCount -lt 1) { throw "SYSTEM_MAINTENANCE rule missing" }
    "$($result.MatchCount) matches"
}
Test-Step -Name "allowlisted-repairs" -Command {
    $result = Invoke-JsonScript -ScriptPath $repairScript -Arguments @("-List")
    if ($result.Status -ne "PASS" -or [int]$result.Count -lt 1) { throw "No allowlisted repairs found" }
    "$($result.Count) repairs"
}
Test-Step -Name "winpe-menu-repairs" -Command {
    $result = Invoke-JsonScript -ScriptPath $menuScript -Arguments @("-ListAllowedRepairs")
    if ($result.Status -ne "PASS" -or [int]$result.Count -lt 1) { throw "WinPE menu repair list failed" }
    "$($result.Count) repairs"
}
Test-Step -Name "system-network-scan" -Command {
    $result = Invoke-JsonScript -ScriptPath $scanScript -Arguments @("-Root", $Root, "-RecentHours", "1", "-MaxEvents", "20")
    if ($result.Status -notin @("PASS", "WARN")) { throw "System/network scan failed" }
    "$($result.Status) findings=$(@($result.Findings).Count)"
}
Test-Step -Name "portable-runtime-self-test" -Command {
    $result = Invoke-JsonScript -ScriptPath $selfTestScript -Arguments @("-Root", $Root)
    if ($result.Status -ne "PASS") { throw "Portable runtime self-test failed" }
    "$(@($result.Checks).Count) checks"
}
Test-Step -Name "winpe-startnet-menu" -Command {
    $result = Invoke-JsonScript -ScriptPath $startnetScript -Arguments @("-StartupMode", "Menu")
    $content = @($result.Lines) -join "`n"
    if ($result.Status -ne "PASS") { throw "startnet generation failed" }
    if ($content -notmatch "Start-WinPEOfflineMenu.ps1") { throw "menu startup missing" }
    if ($content -match "broker.js") { throw "broker startup should not be in menu mode" }
    "menu startup"
}
Test-Step -Name "winpe-media-checkonly-menu" -Command {
    $arguments = @("-CheckOnly", "-StartupMode", "Menu")
    if ($USBPath) { $arguments += @("-USBPath", $USBPath) }
    $result = Invoke-JsonScript -ScriptPath $mediaScript -Arguments $arguments
    if ($result.Status -ne "Ready") { throw "WinPE media check failed" }
    "ready startup=$($result.StartupMode)"
}
Test-Step -Name "services-remain-offline" -Command {
    $result = Invoke-JsonScript -ScriptPath $statusScript -Arguments @("-NoGui", "-NoBroker")
    if ($result.GuiPid -or $result.BrokerPid) { throw "GUI or Broker listener is active" }
    "guiPid=null brokerPid=null"
}

$stepArray = @($steps.ToArray())
$result = [PSCustomObject]@{
    Status = if ($stepArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $Root
    Phase = "portable-usb"
    InstallerPhase = "deferred"
    USBPath = $USBPath
    ReportPath = $ReportPath
    Steps = $stepArray
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
    $stepArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
