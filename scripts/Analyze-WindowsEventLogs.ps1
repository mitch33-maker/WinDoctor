param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string[]]$LogName = @("System", "Application"),
    [int]$RecentHours = 24,
    [int]$MaxEvents = 120,
    [int]$Top = 10,
    [string]$InputPath = "",
    [string]$ReportPath = "",
    [string]$CsvPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Resolve-RootPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd("\")
}

function ConvertTo-KBMatch {
    param($Rule, [int]$Score)
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
        [object[]]$Rules,
        [string]$ProviderName,
        [string]$EventId,
        [string]$Message
    )
    if ($Rules.Count -eq 0) { return @() }

    $tokens = @(
        $ProviderName -split '[^A-Za-z0-9_\.\-]+'
        $EventId
        $Message -split '[^A-Za-z0-9_\.\-]+'
    ) | Where-Object { $_ -and $_.Length -ge 3 } | Select-Object -Unique

    @($Rules | ForEach-Object {
        $rule = $_
        $haystack = @(
            $rule.id
            $rule.title
            $rule.category
            $rule.actionType
            $rule.script
            $rule.details
            @($rule.triggers) -join " "
        ) -join " "

        $score = 0
        foreach ($token in $tokens) {
            if ($haystack.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 1 }
            if (@($rule.triggers | Where-Object { ([string]$_).IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -gt 0) { $score += 2 }
            if (($rule.id -as [string]) -and ([string]$rule.id).IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $score += 3 }
        }

        if ($score -gt 0) { ConvertTo-KBMatch -Rule $rule -Score $score }
    } | Sort-Object score, id -Descending | Select-Object -First 5)
}

function ConvertTo-EventRecord {
    param($Event, [object[]]$Rules)
    $message = if ($null -eq $Event.Message) { "" } else { ([string]$Event.Message) -replace "\s+", " " }
    $matches = @(Find-KBMatches -Rules $Rules -ProviderName ([string]$Event.ProviderName) -EventId ([string]$Event.Id) -Message $message)
    $firstMatch = @($matches | Select-Object -First 1)
    $firstMatch = @($matches | Select-Object -First 1)
    $repairState = if ($matches.Count -eq 0) {
        "learn_only"
    }
    elseif ($firstMatch.Count -gt 0 -and $firstMatch[0].repairAllowed) {
        "preview_required"
    }
    else {
        "guided_or_manual_review"
    }

    [PSCustomObject]@{
        TimeCreated = if ($Event.TimeCreated) { ([datetime]$Event.TimeCreated).ToString("s") } else { $null }
        LogName = [string]$Event.LogName
        ProviderName = [string]$Event.ProviderName
        EventId = [int]$Event.Id
        Level = [int]$Event.Level
        LevelDisplayName = [string]$Event.LevelDisplayName
        MachineName = [string]$Event.MachineName
        Message = if ($message.Length -gt 500) { $message.Substring(0, 500) } else { $message }
        KbMatchCount = $matches.Count
        KbMatches = $matches
        PrimaryRuleId = if ($firstMatch.Count -gt 0) { $firstMatch[0].id } else { "UNKNOWN" }
        PrimaryRecommendation = if ($firstMatch.Count -gt 0) { $firstMatch[0].title } else { "Learn-only; manual review is required before promotion." }
        RepairState = $repairState
    }
}

$normalizedRoot = Resolve-RootPath -Path $Root
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

$warnings = New-Object System.Collections.Generic.List[object]
$rawEvents = New-Object System.Collections.Generic.List[object]
$since = (Get-Date).AddHours(-1 * $RecentHours)

if ($InputPath) {
    $inputEvents = @((Get-Content -Raw -Encoding UTF8 -LiteralPath $InputPath | ConvertFrom-Json).events)
    foreach ($event in $inputEvents) { $rawEvents.Add($event) | Out-Null }
}
else {
    foreach ($log in $LogName) {
        try {
            $events = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1, 2, 3; StartTime = $since } -MaxEvents $MaxEvents -ErrorAction Stop)
            foreach ($event in $events) { $rawEvents.Add($event) | Out-Null }
        }
        catch {
            if ($_.Exception.Message -notmatch "No events were found") {
                $warnings.Add([PSCustomObject]@{ LogName = $log; Message = $_.Exception.Message }) | Out-Null
            }
        }
    }
}

$records = @($rawEvents.ToArray() | Select-Object -First $MaxEvents | ForEach-Object { ConvertTo-EventRecord -Event $_ -Rules $kbRules })
$critical = @($records | Where-Object { $_.Level -eq 1 })
$errors = @($records | Where-Object { $_.Level -eq 2 })
$warningsOnly = @($records | Where-Object { $_.Level -eq 3 })
$unknown = @($records | Where-Object { $_.KbMatchCount -eq 0 })
$repairReady = @($records | Where-Object { $_.RepairState -eq "preview_required" })

$providerSummary = @($records | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First $Top | ForEach-Object {
    [PSCustomObject]@{ ProviderName = $_.Name; Count = $_.Count }
})
$eventIdSummary = @($records | Group-Object LogName, ProviderName, EventId | Sort-Object Count -Descending | Select-Object -First $Top | ForEach-Object {
    $first = $_.Group | Select-Object -First 1
    [PSCustomObject]@{ LogName = $first.LogName; ProviderName = $first.ProviderName; EventId = $first.EventId; Count = $_.Count; Level = $first.LevelDisplayName }
})

$result = [PSCustomObject]@{
    Status = if ($warnings.Count -gt 0) { "WARN" } else { "PASS" }
    Phase = "windows-event-log-analysis"
    Root = $normalizedRoot
    DatabasePath = $DatabasePath
    KbAvailable = ($kbRules.Count -gt 0)
    KbRuleCount = $kbRules.Count
    LogName = $LogName
    RecentHours = $RecentHours
    MaxEvents = $MaxEvents
    EventCount = $records.Count
    Summary = [PSCustomObject]@{
        CriticalCount = $critical.Count
        ErrorCount = $errors.Count
        WarningCount = $warningsOnly.Count
        UnknownCount = $unknown.Count
        KbMatchedCount = @($records | Where-Object { $_.KbMatchCount -gt 0 }).Count
        PreviewRequiredCount = $repairReady.Count
        ManualReviewCount = @($records | Where-Object { $_.RepairState -eq "guided_or_manual_review" }).Count
    }
    ProviderSummary = $providerSummary
    EventIdSummary = $eventIdSummary
    Findings = @($records | Sort-Object Level, TimeCreated | Select-Object -First $Top)
    MisGuidance = @(
        "Review the highest Critical/Error Provider and EventId first, then use PrimaryRuleId to inspect KB.",
        "RepairState=preview_required means preview only; execution still requires allowlist, dry-run, rollback, validation, and RUN gate.",
        "UNKNOWN events remain learn-only and are never auto-repaired."
    )
    SafetyPolicy = [PSCustomObject]@{
        ReadOnly = $true
        NoRepairExecuted = $true
        NoServiceChanged = $true
        RunGateRequiredForRepair = $true
    }
    Warnings = @($warnings.ToArray())
    ReportPath = $ReportPath
    CsvPath = $CsvPath
}

if ($CsvPath) {
    $csvParent = Split-Path -Parent $CsvPath
    if ($csvParent -and -not (Test-Path -LiteralPath $csvParent)) { New-Item -Path $csvParent -ItemType Directory -Force | Out-Null }
    $records | Select-Object TimeCreated, LogName, ProviderName, EventId, LevelDisplayName, KbMatchCount, PrimaryRuleId, RepairState, PrimaryRecommendation, Message | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $CsvPath
}

$resultJson = $result | ConvertTo-Json -Depth 10
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) { New-Item -Path $reportParent -ItemType Directory -Force | Out-Null }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}
