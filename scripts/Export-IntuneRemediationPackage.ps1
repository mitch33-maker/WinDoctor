param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$DatabasePath = "",
    [string]$AllowlistPath = "",
    [string]$OutputRoot = "",
    [string]$PackageName = "WindowsDoctor-IntuneRemediations",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafeName {
    param([string]$Value)
    $safe = ($Value -replace '[^A-Za-z0-9_.-]', '-').Trim('-')
    if (-not $safe) { return "item" }
    return $safe
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $DatabasePath) {
    $DatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb-normalized.json"
}
if (-not $AllowlistPath) {
    $AllowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
}
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $normalizedRoot "releases\intune"
}

if (-not (Test-Path -LiteralPath $DatabasePath)) { throw "Normalized database not found: $DatabasePath" }
if (-not (Test-Path -LiteralPath $AllowlistPath)) { throw "Allowlist not found: $AllowlistPath" }

$database = Get-Content -Raw -Encoding UTF8 -LiteralPath $DatabasePath | ConvertFrom-Json
$allowlist = Get-Content -Raw -Encoding UTF8 -LiteralPath $AllowlistPath | ConvertFrom-Json
$allowedScripts = @($allowlist.scripts)
$excludedScriptPattern = '(?i)(BCD|Boot|SystemIntegrity|SystemMaintenance)'

$candidateRecords = @($database.records | Where-Object {
        $_.action -and
        $_.action.repairAllowed -eq $true -and
        $_.action.actionType -eq "auto_repair" -and
        $_.action.riskLevel -eq "low" -and
        $_.action.script -in $allowedScripts -and
        $_.action.script -notmatch $excludedScriptPattern -and
        $_.provenance.sourceType -notin @("notebooklm_export", "external_diagnostic_import")
    })

$groups = @($candidateRecords | Group-Object { $_.action.script } | Sort-Object Name)
$packageRoot = Join-Path $OutputRoot $PackageName
if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
New-Item -Path $packageRoot -ItemType Directory -Force | Out-Null

$manifestItems = New-Object System.Collections.Generic.List[object]
foreach ($group in $groups) {
    $scriptName = [string]$group.Name
    $repairScriptPath = Join-Path $normalizedRoot "scripts\$scriptName"
    if (-not (Test-Path -LiteralPath $repairScriptPath)) {
        throw "Repair script not found: $repairScriptPath"
    }

    $safeScriptName = ConvertTo-SafeName -Value ([System.IO.Path]::GetFileNameWithoutExtension($scriptName))
    $itemRoot = Join-Path $packageRoot $safeScriptName
    New-Item -Path $itemRoot -ItemType Directory -Force | Out-Null

    $rules = @($group.Group | Sort-Object id)
    $ruleIds = @($rules | ForEach-Object { [string]$_.id })
    $terms = @($rules | ForEach-Object { @($_.triggerTerms) + @($_.errorCodes) } | Where-Object { $_ } | Select-Object -Unique)
    $batContent = Get-Content -Raw -Encoding UTF8 -LiteralPath $repairScriptPath

    $detectionData = @{
        GeneratedBy = "WindowsDoctor"
        PackageType = "IntuneRemediationDetection"
        RepairScript = $scriptName
        RuleIds = $ruleIds
        TriggerTerms = $terms
    } | ConvertTo-Json -Depth 8

    $detection = @"
# WindowsDoctor Intune detection script
# Generated from normalized KB. Does not modify the system.
`$ErrorActionPreference = "Stop"
`$payload = @'
$detectionData
'@ | ConvertFrom-Json
`$terms = @(`$payload.TriggerTerms | Where-Object { `$_ })
if (`$terms.Count -eq 0) {
    Write-Output "WindowsDoctor detection has no trigger terms."
    exit 0
}
`$since = (Get-Date).AddDays(-1)
`$matched = `$false
foreach (`$logName in @("System", "Application")) {
    try {
        `$events = Get-WinEvent -FilterHashtable @{ LogName = `$logName; StartTime = `$since } -MaxEvents 300 -ErrorAction Stop
        foreach (`$event in `$events) {
            `$message = [string]`$event.Message
            foreach (`$term in `$terms) {
                if (`$term -and (`$message -like "*`$term*" -or [string]`$event.Id -eq `$term)) {
                    Write-Output "WindowsDoctor match: `$(`$payload.RepairScript) term=`$term event=`$(`$event.Id) log=`$logName"
                    `$matched = `$true
                    break
                }
            }
            if (`$matched) { break }
        }
    }
    catch {
        Write-Output "WindowsDoctor detection skipped `${logName}: `$(`$_.Exception.Message)"
    }
    if (`$matched) { break }
}
if (`$matched) { exit 1 }
Write-Output "WindowsDoctor no matching evidence found."
exit 0
"@

    $remediationData = @{
        GeneratedBy = "WindowsDoctor"
        PackageType = "IntuneRemediationRemediation"
        RepairScript = $scriptName
        RuleIds = $ruleIds
        RiskLevel = "low"
        ActionType = "auto_repair"
    } | ConvertTo-Json -Depth 8

    $remediation = @"
# WindowsDoctor Intune remediation script
# Generated only for allowlisted low-risk auto_repair records.
`$ErrorActionPreference = "Stop"
`$payload = @'
$remediationData
'@ | ConvertFrom-Json
`$batContent = @'
$batContent
'@
`$workRoot = Join-Path `$env:ProgramData "WindowsDoctor\IntuneRemediations"
New-Item -Path `$workRoot -ItemType Directory -Force | Out-Null
`$batPath = Join-Path `$workRoot `$payload.RepairScript
[System.IO.File]::WriteAllText(`$batPath, `$batContent, [System.Text.Encoding]::ASCII)
Write-Output "WindowsDoctor running allowlisted low-risk remediation: `$(`$payload.RepairScript)"
`$process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"`$batPath`"" -Wait -PassThru -WindowStyle Hidden
if (`$process.ExitCode -ne 0) {
    throw "WindowsDoctor remediation failed with exit code `$(`$process.ExitCode)"
}
Write-Output "WindowsDoctor remediation completed."
exit 0
"@

    $detectionPath = Join-Path $itemRoot "Detect-$safeScriptName.ps1"
    $remediationPath = Join-Path $itemRoot "Remediate-$safeScriptName.ps1"
    Write-Utf8NoBom -Path $detectionPath -Content $detection
    Write-Utf8NoBom -Path $remediationPath -Content $remediation

    $manifestItems.Add([PSCustomObject]@{
        repairScript = $scriptName
        detectionScript = $detectionPath
        remediationScript = $remediationPath
        recordCount = $rules.Count
        ruleIds = $ruleIds
        riskLevel = "low"
        actionType = "auto_repair"
        repairAllowed = $true
        excludedHighRisk = $false
    })
}

$manifest = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    packageRoot = $packageRoot
    sourceDatabase = $DatabasePath
    allowlist = $AllowlistPath
    policy = [PSCustomObject]@{
        included = "allowlisted low-risk auto_repair only"
        excluded = "BCD/Boot/SystemIntegrity/SystemMaintenance; medium/manual_review; NotebookLM; external diagnostic imports"
        executesDuringExport = $false
    }
    itemCount = $manifestItems.Count
    items = @($manifestItems.ToArray())
}

$manifestPath = Join-Path $packageRoot "intune-remediations-manifest.json"
Write-Utf8NoBom -Path $manifestPath -Content ($manifest | ConvertTo-Json -Depth 12)

$summary = [PSCustomObject]@{
    Status = "PASS"
    PackageRoot = $packageRoot
    ManifestPath = $manifestPath
    ItemCount = $manifestItems.Count
    CandidateRecordCount = $candidateRecords.Count
    ReportPath = $ReportPath
}

$summaryJson = $summary | ConvertTo-Json -Depth 8
if ($ReportPath) {
    Write-Utf8NoBom -Path $ReportPath -Content $summaryJson
}

if ($Json) { $summaryJson } else { $summary | Format-List }
