param(
    [string]$GuiUrl = "http://localhost:3000",
    [string]$BrokerUrl = "http://localhost:3001",
    [int]$TimeoutSec = 5,
    [double]$MinFreeMemoryGB = 4,
    [switch]$AllowOffline,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail = ""
    )
    $script:results.Add([PSCustomObject]@{ Name = $Name; Status = $Status; Detail = $Detail })
}

function Assert-FreeMemory {
    $os = Get-CimInstance Win32_OperatingSystem
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    if ($free -lt $MinFreeMemoryGB) {
        throw "Insufficient free memory for GUI smoke. Free=${free}GB Required=${MinFreeMemoryGB}GB"
    }
}

function Test-HttpJson {
    param(
        [string]$Name,
        [string]$Uri
    )
    try {
        $response = Invoke-RestMethod -Uri $Uri -TimeoutSec $TimeoutSec
        if ($response.ok -ne $true) { throw "Response envelope ok=true not found" }
        Add-Result -Name $Name -Status "PASS" -Detail "ok"
        return $response
    }
    catch {
        Add-Result -Name $Name -Status "FAIL" -Detail $_.Exception.Message
        return $null
    }
}

Assert-FreeMemory

try {
    $gui = Invoke-WebRequest -Uri $GuiUrl -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($gui.StatusCode -eq 200 -and $gui.Content -match "WindowsDoctor") {
        Add-Result -Name "gui-home" -Status "PASS" -Detail "WindowsDoctor marker found"
    }
    else {
        Add-Result -Name "gui-home" -Status "FAIL" -Detail "Unexpected GUI response"
    }
}
catch {
    if ($AllowOffline) {
        Add-Result -Name "gui-home" -Status "SKIP" -Detail "GUI offline: $($_.Exception.Message)"
    }
    else {
        Add-Result -Name "gui-home" -Status "FAIL" -Detail $_.Exception.Message
    }
}

$rules = Test-HttpJson -Name "broker-rules" -Uri "$BrokerUrl/api/rules"
$allowlist = Test-HttpJson -Name "broker-allowlist" -Uri "$BrokerUrl/api/repair/allowlist"

if ($rules -and $rules.data.Count -gt 0) {
    Add-Result -Name "rules-nonempty" -Status "PASS" -Detail "$($rules.data.Count) rules"
}
elseif ($rules) {
    Add-Result -Name "rules-nonempty" -Status "FAIL" -Detail "No rules returned"
}

if ($allowlist -and $allowlist.data.scripts.Count -gt 0) {
    Add-Result -Name "allowlist-nonempty" -Status "PASS" -Detail "$($allowlist.data.scripts.Count) scripts"
}
elseif ($allowlist) {
    Add-Result -Name "allowlist-nonempty" -Status "FAIL" -Detail "No allowlist scripts returned"
}

if ($AllowOffline) {
    $results | Where-Object { $_.Name -like "broker-*" -and $_.Status -eq "FAIL" } | ForEach-Object {
        $_.Status = "SKIP"
        $_.Detail = "Broker offline: $($_.Detail)"
    }
}

$resultArray = @($results.ToArray())
$result = [PSCustomObject]@{
    Status = if ($resultArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    GuiUrl = $GuiUrl
    BrokerUrl = $BrokerUrl
    AllowOffline = [bool]$AllowOffline
    ReportPath = $ReportPath
    Results = $resultArray
}

$resultJson = $result | ConvertTo-Json -Depth 6
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
    $resultArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
