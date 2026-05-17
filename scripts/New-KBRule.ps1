param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$ErrorCode,
    [Parameter(Mandatory = $true)][string[]]$Triggers,
    [string]$Script = "N/A",
    [string]$Details = "Pending reviewed remediation details.",
    [string]$OutputDir = "E:\WindowsDoctor\knowledge_base"
)

$ErrorActionPreference = "Stop"
$safeId = ($Id -replace '[^A-Za-z0-9_.-]', '-')
$templatePath = "E:\WindowsDoctor\templates\KB_RULE_TEMPLATE.md"
if (-not (Test-Path $templatePath)) { throw "Template not found: $templatePath" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$triggerText = ($Triggers | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ", "
$content = Get-Content -Raw $templatePath
$content = $content.Replace("{{TITLE}}", $Title)
$content = $content.Replace("{{ERROR_CODE}}", $ErrorCode)
$content = $content.Replace("{{TRIGGERS}}", $triggerText)
$content = $content.Replace("{{SCRIPT}}", $Script)
$content = $content.Replace("{{DETAILS}}", $Details)

$outPath = Join-Path $OutputDir "$safeId.md"
if (Test-Path $outPath) { throw "KB rule already exists: $outPath" }
$content | Out-File -FilePath $outPath -Encoding utf8 -Force
[PSCustomObject]@{ Status = "Created"; Path = $outPath }
