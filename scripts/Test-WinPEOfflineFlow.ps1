param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ProbeQuery = "0x80070035",
    [string]$ProbeRuleId = "RULE-SMB-0x0035",
    [string]$MaintenanceQuery = "SYSTEM_MAINTENANCE",
    [string]$MaintenanceRuleId = "RULE-SYS-MAINTENANCE",
    [string]$ProbeRepair = "Repair-NetworkStack.bat",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$steps = New-Object System.Collections.Generic.List[object]

function Add-Step {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )
    $script:steps.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

function Invoke-JsonScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $allArguments = @("-NoProfile", "-ExecutionPolicy", "RemoteSigned", "-File", $ScriptPath) + $Arguments + @("-Json")
    $raw = & powershell @allArguments
    if ($LASTEXITCODE -ne 0) { throw "Script failed: $ScriptPath" }
    ($raw | Out-String) | ConvertFrom-Json
}

$kbEncodingScript = Join-Path $normalizedRoot "scripts\Test-KBMarkdownEncoding.ps1"
$exportScript = Join-Path $normalizedRoot "scripts\Export-OfflineKBDatabase.ps1"
$validateScript = Join-Path $normalizedRoot "scripts\Test-OfflineKBDatabase.ps1"
$searchScript = Join-Path $normalizedRoot "scripts\Search-OfflineKB.ps1"
$repairScript = Join-Path $normalizedRoot "scripts\Invoke-AllowedRepair.ps1"
$menuScript = Join-Path $normalizedRoot "scripts\Start-WinPEOfflineMenu.ps1"
$startnetScript = Join-Path $normalizedRoot "scripts\New-WinPEStartNet.ps1"
$buildScript = Join-Path $normalizedRoot "scripts\Build-WinPEMedia.ps1"

foreach ($path in @($kbEncodingScript, $exportScript, $validateScript, $searchScript, $repairScript, $menuScript, $startnetScript, $buildScript)) {
    if (-not (Test-Path $path)) { throw "Required WinPE offline flow script not found: $path" }
}

try {
    $kb = Invoke-JsonScript -ScriptPath $kbEncodingScript -Arguments @("-Root", $normalizedRoot)
    Add-Step -Name "kb-markdown-encoding" -Pass ($kb.Status -eq "PASS") -Detail "files=$($kb.TotalFiles)"
}
catch {
    Add-Step -Name "kb-markdown-encoding" -Pass $false -Detail $_.Exception.Message
}

try {
    $export = Invoke-JsonScript -ScriptPath $exportScript -Arguments @("-Root", $normalizedRoot)
    Add-Step -Name "offline-kb-export" -Pass ($export.Status -eq "PASS") -Detail "rules=$($export.TotalRules)"
}
catch {
    Add-Step -Name "offline-kb-export" -Pass $false -Detail $_.Exception.Message
}

try {
    $validation = Invoke-JsonScript -ScriptPath $validateScript -Arguments @("-Root", $normalizedRoot)
    Add-Step -Name "offline-kb-validate" -Pass ($validation.Status -eq "PASS") -Detail "rules=$($validation.TotalRules)"
}
catch {
    Add-Step -Name "offline-kb-validate" -Pass $false -Detail $_.Exception.Message
}

try {
    $search = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-Root", $normalizedRoot, "-Query", $ProbeQuery)
    $matched = @($search.Matches | Where-Object { $_.id -eq $ProbeRuleId }).Count -gt 0
    Add-Step -Name "offline-kb-search" -Pass ($search.Status -eq "PASS" -and $matched) -Detail "query=$ProbeQuery matched=$matched"
}
catch {
    Add-Step -Name "offline-kb-search" -Pass $false -Detail $_.Exception.Message
}

try {
    $maintenanceSearch = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-Root", $normalizedRoot, "-Query", $MaintenanceQuery)
    $matched = @($maintenanceSearch.Matches | Where-Object { $_.id -eq $MaintenanceRuleId -and $_.script -eq "Repair-SystemMaintenance.bat" }).Count -gt 0
    Add-Step -Name "offline-kb-maintenance-search" -Pass ($maintenanceSearch.Status -eq "PASS" -and $matched) -Detail "query=$MaintenanceQuery matched=$matched"
}
catch {
    Add-Step -Name "offline-kb-maintenance-search" -Pass $false -Detail $_.Exception.Message
}

try {
    $details = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-Root", $normalizedRoot, "-RuleId", $ProbeRuleId)
    Add-Step -Name "offline-kb-details" -Pass ($details.Status -eq "PASS" -and [int]$details.MatchCount -eq 1) -Detail "rule=$ProbeRuleId matches=$($details.MatchCount)"
}
catch {
    Add-Step -Name "offline-kb-details" -Pass $false -Detail $_.Exception.Message
}

try {
    $categories = Invoke-JsonScript -ScriptPath $searchScript -Arguments @("-Root", $normalizedRoot, "-ListCategories")
    Add-Step -Name "offline-kb-categories" -Pass ($categories.Status -eq "PASS" -and [int]$categories.CategoryCount -gt 0) -Detail "categories=$($categories.CategoryCount)"
}
catch {
    Add-Step -Name "offline-kb-categories" -Pass $false -Detail $_.Exception.Message
}

try {
    $repairs = Invoke-JsonScript -ScriptPath $repairScript -Arguments @("-Root", $normalizedRoot, "-List")
    $repairFound = @($repairs.Repairs | Where-Object { $_.name -eq $ProbeRepair -and $_.exists -eq $true }).Count -gt 0
    Add-Step -Name "allowed-repair-list" -Pass ($repairs.Status -eq "PASS" -and $repairFound) -Detail "repair=$ProbeRepair found=$repairFound"
}
catch {
    Add-Step -Name "allowed-repair-list" -Pass $false -Detail $_.Exception.Message
}

try {
    $preview = Invoke-JsonScript -ScriptPath $repairScript -Arguments @("-Root", $normalizedRoot, "-ScriptName", $ProbeRepair, "-Preview")
    Add-Step -Name "allowed-repair-preview" -Pass ($preview.Status -eq "PASS" -and $preview.Mode -eq "preview" -and $preview.Content -match "netsh") -Detail "repair=$ProbeRepair"
}
catch {
    Add-Step -Name "allowed-repair-preview" -Pass $false -Detail $_.Exception.Message
}

try {
    $menu = Invoke-JsonScript -ScriptPath $menuScript -Arguments @("-Root", $normalizedRoot, "-PreviewRepair", $ProbeRepair)
    Add-Step -Name "winpe-menu-preview" -Pass ($menu.Status -eq "PASS" -and $menu.Mode -eq "preview") -Detail "repair=$ProbeRepair"
}
catch {
    Add-Step -Name "winpe-menu-preview" -Pass $false -Detail $_.Exception.Message
}

try {
    $startnetMenu = Invoke-JsonScript -ScriptPath $startnetScript -Arguments @("-StartupMode", "Menu")
    $startnetText = @($startnetMenu.Lines) -join "`n"
    Add-Step -Name "startnet-menu" -Pass ($startnetText -match "Start-WinPEOfflineMenu.ps1" -and $startnetText -notmatch "broker.js") -Detail "mode=Menu"
}
catch {
    Add-Step -Name "startnet-menu" -Pass $false -Detail $_.Exception.Message
}

try {
    $startnetBroker = Invoke-JsonScript -ScriptPath $startnetScript -Arguments @("-StartupMode", "Broker")
    $startnetText = @($startnetBroker.Lines) -join "`n"
    Add-Step -Name "startnet-broker" -Pass ($startnetText -match "broker.js" -and $startnetText -notmatch "Start-WinPEOfflineMenu.ps1") -Detail "mode=Broker"
}
catch {
    Add-Step -Name "startnet-broker" -Pass $false -Detail $_.Exception.Message
}

try {
    $checkOnly = & powershell -NoProfile -ExecutionPolicy RemoteSigned -File $buildScript -CheckOnly | Out-String
    Add-Step -Name "winpe-checkonly" -Pass ($checkOnly -match "Status\s+: Ready" -and $checkOnly -match "StartupMode\s+: Menu") -Detail "StartupMode=Menu"
}
catch {
    Add-Step -Name "winpe-checkonly" -Pass $false -Detail $_.Exception.Message
}

$stepArray = @($steps.ToArray())
$result = [PSCustomObject]@{
    Status = if (@($stepArray | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0) { "FAIL" } else { "PASS" }
    Root = $normalizedRoot
    ProbeQuery = $ProbeQuery
    ProbeRuleId = $ProbeRuleId
    MaintenanceQuery = $MaintenanceQuery
    MaintenanceRuleId = $MaintenanceRuleId
    ProbeRepair = $ProbeRepair
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
