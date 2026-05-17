param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Description = "Reviewed WindowsDoctor repair script.",
    [switch]$AddToAllowlist,
    [string]$OutputDir = "E:\WindowsDoctor\scripts"
)

$ErrorActionPreference = "Stop"
$scriptName = if ($Name.EndsWith(".bat")) { $Name } else { "$Name.bat" }
if ($scriptName -notmatch '^Repair-[A-Za-z0-9_.-]+\.bat$') {
    throw "Repair script name must match Repair-*.bat"
}

$templatePath = "E:\WindowsDoctor\templates\REPAIR_SCRIPT_TEMPLATE.bat"
$allowlistPath = "E:\WindowsDoctor\scripts\repair-allowlist.json"
if (-not (Test-Path $templatePath)) { throw "Template not found: $templatePath" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$outPath = Join-Path $OutputDir $scriptName
if (Test-Path $outPath) { throw "Repair script already exists: $outPath" }

$content = Get-Content -Raw $templatePath
$content = $content.Replace("{{SCRIPT_NAME}}", $scriptName)
$content = $content.Replace("{{DESCRIPTION}}", $Description)
$content | Out-File -FilePath $outPath -Encoding ascii -Force

if ($AddToAllowlist) {
    if (Test-Path $allowlistPath) {
        $allowlist = Get-Content -Raw $allowlistPath | ConvertFrom-Json
    }
    else {
        $allowlist = [PSCustomObject]@{ scripts = @() }
    }
    $scripts = @($allowlist.scripts)
    if ($scripts -notcontains $scriptName) {
        $allowlist.scripts = @($scripts + $scriptName | Sort-Object -Unique)
        $allowlist | ConvertTo-Json -Depth 4 | Out-File -FilePath $allowlistPath -Encoding utf8 -Force
    }
}

[PSCustomObject]@{ Status = "Created"; Path = $outPath; Allowlisted = [bool]$AddToAllowlist }
