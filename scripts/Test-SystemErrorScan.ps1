param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [int]$RecentHours = 24,
    [int]$MaxEvents = 80,
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"
$findings = New-Object System.Collections.Generic.List[object]
$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
}

$kbRules = @()
if (Test-Path -LiteralPath $DatabasePath) {
    try {
        $kbRules = @((Get-Content -Raw -Encoding UTF8 -LiteralPath $DatabasePath | ConvertFrom-Json).rules)
    }
    catch {
        $kbRules = @()
    }
}

function ConvertTo-KBMatch {
    param(
        [Parameter(Mandatory = $true)]$Rule,
        [int]$Score
    )

    [PSCustomObject]@{
        score = $Score
        id = $Rule.id
        title = $Rule.title
        category = $Rule.category
        actionType = $Rule.actionType
        repairAllowed = [bool]$Rule.repairAllowed
        script = $Rule.script
    }
}

function Find-KBMatches {
    param(
        [string]$Name,
        [string]$Detail,
        [string]$RuleHint
    )

    if ($script:kbRules.Count -eq 0) { return @() }

    $stopTokens = @(
        "PASS", "WARN", "FAIL", "count", "total", "down", "recentHours",
        "interfaces", "defaultGateway", "apipa", "interfacesWithDns",
        "Current", "settings", "Direct", "access", "proxy", "server"
    )
    $tokens = @(
        $Name -split '[^A-Za-z0-9_:\.\-]+'
        $Detail -split '[^A-Za-z0-9_:\.\-]+'
        $RuleHint -split '[^A-Za-z0-9_:\.\-]+'
    ) | Where-Object { $_ -and $_.Length -ge 3 -and $_ -notin $stopTokens } | Select-Object -Unique

    @($script:kbRules | ForEach-Object {
        $rule = $_
        $haystack = @(
            $rule.id
            $rule.title
            $rule.category
            $rule.script
            $rule.actionType
            $rule.details
            @($rule.triggers) -join " "
        ) -join " "

        $score = 0
        foreach ($token in $tokens) {
            if ($haystack.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 1 }
            $ruleId = if ($null -eq $rule.id) { "" } else { [string]$rule.id }
            if ($ruleId.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 3 }
            if (@($rule.triggers | Where-Object { $_.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0) { $score += 2 }
        }

        if ($score -gt 0) {
            ConvertTo-KBMatch -Rule $rule -Score $score
        }
    } | Sort-Object score, id -Descending | Select-Object -First 5)
}

function Add-Finding {
    param(
        [string]$Name,
        [string]$Status,
        [string]$Detail,
        [string]$RuleHint = ""
    )
    $matches = @(Find-KBMatches -Name $Name -Detail $Detail -RuleHint $RuleHint)
    $script:findings.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
        RuleHint = $RuleHint
        KbMatchCount = $matches.Count
        KbMatches = $matches
    })
}

function New-UiText {
    param([int[]]$Codes)
    [string]::Concat([char[]]$Codes)
}

function Write-FindingConsoleOutput {
    param([object[]]$Items)

    $labelFinding = New-UiText @(0x8a3a,0x65b7,0x9805,0x76ee)
    $labelStatus = New-UiText @(0x72c0,0x614b)
    $labelDetail = New-UiText @(0x8a73,0x7d30)
    $labelRuleHint = New-UiText @(0x898f,0x5247,0x63d0,0x793a)
    $labelKbMatches = New-UiText @(0x004b,0x0042,0x0020,0x5efa,0x8b70)
    $labelAction = New-UiText @(0x8655,0x7406,0x985e,0x578b)
    $labelRepair = New-UiText @(0x4fee,0x5fa9,0x8173,0x672c)

    foreach ($item in $Items) {
        Write-Host ("[{0}] {1}" -f $labelFinding, $item.Name)
        Write-Host ("  {0}: {1}" -f $labelStatus, $item.Status)
        Write-Host ("  {0}: {1}" -f $labelDetail, $item.Detail)
        Write-Host ("  {0}: {1}" -f $labelRuleHint, $item.RuleHint)
        Write-Host ("  {0}: {1}" -f $labelKbMatches, $item.KbMatchCount)
        foreach ($match in @($item.KbMatches)) {
            Write-Host ("    - {0} | {1} | {2}: {3} | {4}: {5}" -f $match.id, $match.title, $labelAction, $match.actionType, $labelRepair, $match.script)
        }
        Write-Host ""
    }
}

$since = (Get-Date).AddHours(-1 * $RecentHours)

try {
    $systemEvents = @(Get-WinEvent -FilterHashtable @{ LogName = "System"; Level = 2, 3; StartTime = $since } -MaxEvents $MaxEvents -ErrorAction Stop)
    Add-Finding -Name "system-event-errors" -Status "PASS" -Detail "count=$($systemEvents.Count) recentHours=$RecentHours" -RuleHint "SCM, DCOM, NTFS, DISK, DNS, DHCP"
}
catch {
    if ($_.Exception.Message -match "No events were found") {
        Add-Finding -Name "system-event-errors" -Status "PASS" -Detail "count=0 recentHours=$RecentHours" -RuleHint "EVENTLOG"
    }
    else {
        Add-Finding -Name "system-event-errors" -Status "WARN" -Detail $_.Exception.Message -RuleHint "EVENTLOG"
    }
}

try {
    $applicationEvents = @(Get-WinEvent -FilterHashtable @{ LogName = "Application"; Level = 2, 3; StartTime = $since } -MaxEvents $MaxEvents -ErrorAction Stop)
    Add-Finding -Name "application-event-errors" -Status "PASS" -Detail "count=$($applicationEvents.Count) recentHours=$RecentHours" -RuleHint "MSI, APPX, WMI"
}
catch {
    if ($_.Exception.Message -match "No events were found") {
        Add-Finding -Name "application-event-errors" -Status "PASS" -Detail "count=0 recentHours=$RecentHours" -RuleHint "EVENTLOG"
    }
    else {
        Add-Finding -Name "application-event-errors" -Status "WARN" -Detail $_.Exception.Message -RuleHint "EVENTLOG"
    }
}

try {
    $adapters = @(Get-NetAdapter -ErrorAction Stop)
    $downAdapters = @($adapters | Where-Object { $_.Status -notin @("Up", "Disabled") })
    $status = if ($downAdapters.Count -gt 0) { "WARN" } else { "PASS" }
    Add-Finding -Name "network-adapters" -Status $status -Detail "total=$($adapters.Count) down=$($downAdapters.Count)" -RuleHint "RULE-NET-WIFI-ADAPTER"
}
catch {
    Add-Finding -Name "network-adapters" -Status "WARN" -Detail $_.Exception.Message -RuleHint "RULE-NET-WIFI-ADAPTER"
}

try {
    $ipConfigs = @(Get-NetIPConfiguration -ErrorAction Stop)
    $withGateway = @($ipConfigs | Where-Object { $_.IPv4DefaultGateway -or $_.IPv6DefaultGateway })
    $apipa = @($ipConfigs | Where-Object { @($_.IPv4Address.IPAddress) -match '^169\.254\.' })
    $status = if ($withGateway.Count -eq 0 -or $apipa.Count -gt 0) { "WARN" } else { "PASS" }
    Add-Finding -Name "ip-configuration" -Status $status -Detail "interfaces=$($ipConfigs.Count) defaultGateway=$($withGateway.Count) apipa=$($apipa.Count)" -RuleHint "RULE-NET-DHCP-169254"
}
catch {
    Add-Finding -Name "ip-configuration" -Status "WARN" -Detail $_.Exception.Message -RuleHint "RULE-NET-DHCP-169254"
}

try {
    $dns = @(Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { @($_.ServerAddresses).Count -gt 0 })
    $status = if ($dns.Count -gt 0) { "PASS" } else { "WARN" }
    Add-Finding -Name "dns-client" -Status $status -Detail "interfacesWithDns=$($dns.Count)" -RuleHint "RULE-NET-DNS"
}
catch {
    Add-Finding -Name "dns-client" -Status "WARN" -Detail $_.Exception.Message -RuleHint "RULE-NET-DNS"
}

try {
    $proxy = & netsh winhttp show proxy
    $proxyText = ($proxy | Out-String).Trim()
    $status = if ($proxyText -match "Direct access|no proxy") { "PASS" } else { "WARN" }
    Add-Finding -Name "winhttp-proxy" -Status $status -Detail ($proxyText -replace "\s+", " ") -RuleHint "RULE-NET-WINHTTP-PROXY"
}
catch {
    Add-Finding -Name "winhttp-proxy" -Status "WARN" -Detail $_.Exception.Message -RuleHint "RULE-NET-WINHTTP-PROXY"
}

$findingArray = @($findings.ToArray())
$result = [PSCustomObject]@{
    Status = if ($findingArray.Status -contains "WARN") { "WARN" } elseif ($findingArray.Status -contains "FAIL") { "FAIL" } else { "PASS" }
    Root = $normalizedRoot
    DatabasePath = $DatabasePath
    KbAvailable = ($kbRules.Count -gt 0)
    KbRuleCount = $kbRules.Count
    KbMatchCount = @($findingArray.KbMatches).Count
    RecentHours = $RecentHours
    MaxEvents = $MaxEvents
    ReportPath = $ReportPath
    Findings = $findingArray
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    Write-FindingConsoleOutput -Items $findingArray
}

if ($result.Status -eq "FAIL") { exit 1 }
