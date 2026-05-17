param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$InputDatabasePath = "",
    [string]$SourcePackPath = "",
    [string]$NotebookLMPackPath = "",
    [string]$ExternalDiagnosticsPackPath = "",
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Get-ErrorCodes {
    param([object[]]$Values)
    @($Values | Where-Object { $_ -match '(?i)^0x[0-9a-f]{4,8}$' } | Select-Object -Unique)
}

function Get-RiskLevel {
    param(
        [string]$Script,
        [string]$ActionType
    )

    if ($Script -match "BCD|Boot|SystemIntegrity|SystemMaintenance") { return "manual_review" }
    if ($Script -match "WUSoftwareDistribution") { return "medium" }
    if ($ActionType -eq "auto_repair") { return "low" }
    return "manual_review"
}

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $InputDatabasePath) {
    $InputDatabasePath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb.json"
}
if (-not $SourcePackPath) {
    $SourcePackPath = Join-Path $normalizedRoot "offline_database\known-windows-repair-sources.json"
}
if (-not $NotebookLMPackPath) {
    $NotebookLMPackPath = Join-Path $normalizedRoot "offline_database\notebooklm-repair-sources.json"
}
if (-not $ExternalDiagnosticsPackPath) {
    $ExternalDiagnosticsPackPath = Join-Path $normalizedRoot "offline_database\external-diagnostic-sources.json"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $normalizedRoot "offline_database\windowsdoctor-kb-normalized.json"
}

if (-not (Test-Path -LiteralPath $InputDatabasePath)) { throw "Input database not found: $InputDatabasePath" }
if (-not (Test-Path -LiteralPath $SourcePackPath)) { throw "Source pack not found: $SourcePackPath" }

$inputDb = Get-Content -Raw -Encoding UTF8 -LiteralPath $InputDatabasePath | ConvertFrom-Json
$sourcePack = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePackPath | ConvertFrom-Json
$records = New-Object System.Collections.Generic.List[object]

foreach ($rule in @($inputDb.rules)) {
    $triggers = @($rule.triggers | Where-Object { $_ } | Select-Object -Unique)
    $script = [string]$rule.script
    $actionType = [string]$rule.actionType
    $records.Add([PSCustomObject]@{
        id = [string]$rule.id
        title = [string]$rule.title
        component = if ($rule.id -match "NET|SMB") { "network" } elseif ($rule.id -match "BOOT|BCD") { "boot" } elseif ($rule.id -match "DISK|STORAGE") { "storage" } elseif ($rule.id -match "WU|UPDATE") { "windows_update" } else { "system" }
        symptoms = @([string]$rule.title)
        errorCodes = @(Get-ErrorCodes -Values $triggers)
        eventIds = @()
        triggerTerms = $triggers
        recommendedActions = @([string]$rule.details)
        action = [PSCustomObject]@{
            script = $script
            actionType = $actionType
            repairAllowed = [bool]$rule.repairAllowed
            riskLevel = Get-RiskLevel -Script $script -ActionType $actionType
        }
        provenance = [PSCustomObject]@{
            sourceType = "local_reviewed_kb"
            sourceTrustLevel = "local_learned"
            sourceFile = [string]$rule.sourceFile
            sourceIds = @()
        }
    })
}

foreach ($rule in @($sourcePack.rules)) {
    $records.Add([PSCustomObject]@{
        id = [string]$rule.id
        title = [string]$rule.title
        component = [string]$rule.component
        symptoms = @($rule.symptoms)
        errorCodes = @($rule.errorCodes)
        eventIds = @($rule.eventIds)
        triggerTerms = @($rule.triggerTerms)
        recommendedActions = @($rule.recommendedActions)
        action = [PSCustomObject]@{
            script = [string]$rule.script
            actionType = [string]$rule.actionType
            repairAllowed = [bool]$rule.repairAllowed
            riskLevel = [string]$rule.riskLevel
        }
        provenance = [PSCustomObject]@{
            sourceType = "public_official_reference"
            sourceTrustLevel = "microsoft_official"
            sourceFile = ""
            sourceIds = @($rule.sourceIds)
        }
    })
}

$notebookLmSources = @()
if (Test-Path -LiteralPath $NotebookLMPackPath) {
    $notebookLmPack = Get-Content -Raw -Encoding UTF8 -LiteralPath $NotebookLMPackPath | ConvertFrom-Json
    $notebookLmSources = @($notebookLmPack.sources)
    foreach ($rule in @($notebookLmPack.records)) {
        $records.Add([PSCustomObject]@{
            id = [string]$rule.id
            title = [string]$rule.title
            component = [string]$rule.component
            symptoms = @($rule.symptoms)
            errorCodes = @($rule.errorCodes)
            eventIds = @($rule.eventIds)
            triggerTerms = @($rule.triggerTerms)
            recommendedActions = @($rule.recommendedActions)
            action = [PSCustomObject]@{
                script = [string]$rule.script
                actionType = [string]$rule.actionType
                repairAllowed = [bool]$rule.repairAllowed
                riskLevel = [string]$rule.riskLevel
            }
            provenance = [PSCustomObject]@{
                sourceType = "notebooklm_export"
                sourceTrustLevel = "notebooklm_export"
                sourceFile = $NotebookLMPackPath
                sourceIds = @($rule.sourceIds)
            }
        })
    }
}

$externalDiagnosticSources = @()
if (Test-Path -LiteralPath $ExternalDiagnosticsPackPath) {
    $externalDiagnosticPack = Get-Content -Raw -Encoding UTF8 -LiteralPath $ExternalDiagnosticsPackPath | ConvertFrom-Json
    $externalDiagnosticSources = @($externalDiagnosticPack.sources)
    foreach ($finding in @($externalDiagnosticPack.findings)) {
        $actions = @($finding.recommendedActions)
        if (@($finding.evidence).Count -gt 0) {
            $actions = @($actions + @($finding.evidence | ForEach-Object { "Evidence: $_" }))
        }

        $records.Add([PSCustomObject]@{
            id = [string]$finding.id
            title = [string]$finding.title
            component = [string]$finding.component
            symptoms = @($finding.symptoms)
            errorCodes = @($finding.errorCodes)
            eventIds = @($finding.eventIds)
            triggerTerms = @($finding.triggerTerms)
            recommendedActions = $actions
            action = [PSCustomObject]@{
                script = "N/A"
                actionType = "manual_review"
                repairAllowed = $false
                riskLevel = [string]$finding.riskLevel
            }
            provenance = [PSCustomObject]@{
                sourceType = "external_diagnostic_import"
                sourceTrustLevel = [string]$finding.sourceTrustLevel
                sourceFile = $ExternalDiagnosticsPackPath
                sourceIds = @($finding.sourceIds)
                adapterName = [string]$finding.adapterName
            }
        })
    }
}

$recordArray = @($records.ToArray() | Sort-Object id)
$allSources = @($sourcePack.sources) + @($notebookLmSources) + @($externalDiagnosticSources)
$database = [PSCustomObject]@{
    schemaVersion = 2
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    root = $normalizedRoot
    sourcePack = $SourcePackPath
    notebookLMPack = if (Test-Path -LiteralPath $NotebookLMPackPath) { $NotebookLMPackPath } else { "" }
    externalDiagnosticsPack = if (Test-Path -LiteralPath $ExternalDiagnosticsPackPath) { $ExternalDiagnosticsPackPath } else { "" }
    sources = @($allSources | Sort-Object id)
    stats = [PSCustomObject]@{
        totalRecords = $recordArray.Count
        localRecords = @($recordArray | Where-Object { $_.provenance.sourceType -eq "local_reviewed_kb" }).Count
        publicReferenceRecords = @($recordArray | Where-Object { $_.provenance.sourceType -eq "public_official_reference" }).Count
        notebookLMRecords = @($recordArray | Where-Object { $_.provenance.sourceType -eq "notebooklm_export" }).Count
        externalDiagnosticRecords = @($recordArray | Where-Object { $_.provenance.sourceType -eq "external_diagnostic_import" }).Count
        sourceCount = @($allSources).Count
        autoRepairRecords = @($recordArray | Where-Object { $_.action.actionType -eq "auto_repair" }).Count
        guidedRecords = @($recordArray | Where-Object { $_.action.actionType -eq "guided" }).Count
        manualReviewRecords = @($recordArray | Where-Object { $_.action.riskLevel -eq "manual_review" }).Count
    }
    records = $recordArray
}

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent -and -not (Test-Path -LiteralPath $outputParent)) {
    New-Item -Path $outputParent -ItemType Directory -Force | Out-Null
}
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($OutputPath, ($database | ConvertTo-Json -Depth 12), $utf8NoBom)

$summary = [PSCustomObject]@{
    Status = "PASS"
    OutputPath = $OutputPath
    SchemaVersion = 2
    TotalRecords = $database.stats.totalRecords
    LocalRecords = $database.stats.localRecords
    PublicReferenceRecords = $database.stats.publicReferenceRecords
    NotebookLMRecords = $database.stats.notebookLMRecords
    ExternalDiagnosticRecords = $database.stats.externalDiagnosticRecords
    SourceCount = $database.stats.sourceCount
    ReportPath = $ReportPath
}

$summaryJson = $summary | ConvertTo-Json -Depth 5
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $summaryJson, $utf8NoBom)
}

if ($Json) { $summaryJson } else { $summary | Format-List }
