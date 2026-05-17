param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$IntakeRoot = "",
    [string]$ReportPath = "",
    [switch]$CreateDirectories,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
if (-not $IntakeRoot) {
    $IntakeRoot = Join-Path $resolvedRoot "incoming"
}
$resolvedIntakeRoot = [System.IO.Path]::GetFullPath($IntakeRoot).TrimEnd("\")

$notebookDir = Join-Path $resolvedIntakeRoot "notebooklm"
$externalDir = Join-Path $resolvedIntakeRoot "external-diagnostics"
$officialDir = Join-Path $resolvedIntakeRoot "official-diagnostics"
$directories = @($notebookDir, $externalDir, $officialDir)

if ($CreateDirectories) {
    foreach ($dir in $directories) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
}

$checks = New-Object System.Collections.Generic.List[object]
$candidates = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param([string]$Name, [string]$Status, [string]$Detail)
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = $Status
        Detail = $Detail
    })
}

function Add-Candidate {
    param(
        [string]$Type,
        [string]$Path,
        [string]$Status,
        [string]$Detail,
        [string]$ReportPath = ""
    )
    $script:candidates.Add([PSCustomObject]@{
        Type = $Type
        Path = $Path
        Status = $Status
        Detail = $Detail
        ReportPath = $ReportPath
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

foreach ($dir in $directories) {
    $dirStatus = if (Test-Path -LiteralPath $dir) { "PASS" } else { "WAITING" }
    Add-Check -Name ("directory-" + (Split-Path -Leaf $dir)) -Status $dirStatus -Detail $dir
}

$reportRoot = if ($ReportPath) { Split-Path -Parent $ReportPath } else { Join-Path $resolvedRoot "logs\real-data-import-readiness" }
if (-not $reportRoot) { $reportRoot = Join-Path $resolvedRoot "logs\real-data-import-readiness" }
if (-not (Test-Path -LiteralPath $reportRoot)) {
    New-Item -Path $reportRoot -ItemType Directory -Force | Out-Null
}

if (Test-Path -LiteralPath $notebookDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $notebookDir -File -Filter "*.json" -Force)) {
        $candidateReport = Join-Path $reportRoot ("notebooklm-" + $file.BaseName + ".json")
        try {
            $validation = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\Test-NotebookLMSourcePack.ps1") -Arguments @("-InputPath", $file.FullName, "-ReportPath", $candidateReport)
            Add-Candidate -Type "notebooklm" -Path $file.FullName -Status $validation.Status -Detail "sources=$($validation.SourceCount) records=$($validation.RecordCount)" -ReportPath $candidateReport
        }
        catch {
            Add-Candidate -Type "notebooklm" -Path $file.FullName -Status "FAIL" -Detail $_.Exception.Message -ReportPath $candidateReport
        }
    }
}

if (Test-Path -LiteralPath $externalDir) {
    foreach ($file in @(Get-ChildItem -LiteralPath $externalDir -File -Filter "*.json" -Force)) {
        $candidateReport = Join-Path $reportRoot ("external-" + $file.BaseName + ".json")
        try {
            $validation = Invoke-JsonScript -ScriptPath (Join-Path $resolvedRoot "scripts\Test-ExternalDiagnosticsPack.ps1") -Arguments @("-InputPath", $file.FullName, "-ReportPath", $candidateReport)
            Add-Candidate -Type "external-diagnostics" -Path $file.FullName -Status $validation.Status -Detail "sources=$($validation.SourceCount) findings=$($validation.FindingCount)" -ReportPath $candidateReport
        }
        catch {
            Add-Candidate -Type "external-diagnostics" -Path $file.FullName -Status "FAIL" -Detail $_.Exception.Message -ReportPath $candidateReport
        }
    }
}

if (Test-Path -LiteralPath $officialDir) {
    $setupDiag = @(Get-ChildItem -LiteralPath $officialDir -File -Force | Where-Object { $_.Name -match '(?i)setupdiag.*\.(log|txt)$' } | Select-Object -First 1)
    $dism = @(Get-ChildItem -LiteralPath $officialDir -File -Force | Where-Object { $_.Name -match '(?i)dism.*\.(log|txt)$' } | Select-Object -First 1)
    $sfc = @(Get-ChildItem -LiteralPath $officialDir -File -Force | Where-Object { $_.Name -match '(?i)sfc.*\.(log|txt)$' } | Select-Object -First 1)
    $getHelp = @(Get-ChildItem -LiteralPath $officialDir -File -Force | Where-Object { $_.Name -match '(?i)(gethelp|get-help).*\.(log|txt)$' } | Select-Object -First 1)
    $officialInputs = @($setupDiag + $dism + $sfc + $getHelp)
    if ($officialInputs.Count -gt 0) {
        Add-Candidate -Type "official-diagnostics-raw" -Path $officialDir -Status "PASS" -Detail "setupdiag=$($setupDiag.Count) dism=$($dism.Count) sfc=$($sfc.Count) gethelp=$($getHelp.Count)"
    }
}

$candidateArray = @($candidates.ToArray())
$readyCount = @($candidateArray | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($candidateArray | Where-Object { $_.Status -eq "FAIL" }).Count
$status = if ($failCount -gt 0) { "FAIL" } elseif ($readyCount -gt 0) { "PASS" } else { "WAITING" }

$result = [PSCustomObject]@{
    Status = $status
    Root = $resolvedRoot
    IntakeRoot = $resolvedIntakeRoot
    ReadyCount = $readyCount
    FailedCount = $failCount
    CandidateCount = $candidateArray.Count
    Directories = [PSCustomObject]@{
        NotebookLM = $notebookDir
        ExternalDiagnostics = $externalDir
        OfficialDiagnostics = $officialDir
    }
    Candidates = $candidateArray
    Checks = @($checks.ToArray())
    NextAction = if ($status -eq "WAITING") { "Place NotebookLM JSON, external diagnostics JSON, or official diagnostic logs in the intake directories." } elseif ($status -eq "PASS") { "Validate/import the ready candidates, then rebuild normalized KB." } else { "Fix failed candidate files before import." }
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}

if ($result.Status -eq "FAIL") { exit 1 }
