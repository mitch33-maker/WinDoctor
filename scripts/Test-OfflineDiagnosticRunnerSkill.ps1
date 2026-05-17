param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $Checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Passed) { "PASS" } else { "FAIL" }
        Detail = $Detail
    }) | Out-Null
}

function Read-Text {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
    return Get-Content -Raw -Encoding UTF8 -LiteralPath $Path
}

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$checks = [System.Collections.Generic.List[object]]::new()

$skillPath = Join-Path $resolvedRoot "skills\windowsdoctor-offline-diagnostic-runner\SKILL.md"
$runnerPath = Join-Path $resolvedRoot "scripts\Invoke-OfflineDiagnosticTools.ps1"
$converterPath = Join-Path $resolvedRoot "scripts\Convert-OfflineDiagnosticToolOutput.ps1"
$syncPath = Join-Path $resolvedRoot "scripts\Sync-GuiReadyUsbPatch.ps1"
$patchPath = Join-Path $resolvedRoot "scripts\New-PortableIncrementalPatch.ps1"
$indexPath = Join-Path $resolvedRoot "INDEX.md"
$memoryPath = Join-Path $resolvedRoot "MEMORY_SYSTEM.md"

$skill = Read-Text -Path $skillPath
$runner = Read-Text -Path $runnerPath
$converter = Read-Text -Path $converterPath
$sync = Read-Text -Path $syncPath
$patch = Read-Text -Path $patchPath
$index = Read-Text -Path $indexPath
$memory = Read-Text -Path $memoryPath

Add-Check -Checks $checks -Name "skill-frontmatter" -Passed ($skill -match 'name:\s*windowsdoctor-offline-diagnostic-runner' -and $skill -match 'description:') -Detail $skillPath
Add-Check -Checks $checks -Name "skill-resource-safety" -Passed ($skill -match 'Test-ResourceSafety\.ps1') -Detail $skillPath
Add-Check -Checks $checks -Name "skill-run-gate" -Passed ($skill -match 'ConfirmToken RUN' -and $skill -match 'explicitly provides `RUN`') -Detail $skillPath
Add-Check -Checks $checks -Name "skill-preview-default" -Passed ($skill -match 'preview-only' -and $skill -match 'Do not execute external tools') -Detail $skillPath
Add-Check -Checks $checks -Name "skill-usb-sync" -Passed ($skill -match 'Sync-GuiReadyUsbPatch\.ps1' -and $skill -match 'Test-PortableIncrementalPatch\.ps1') -Detail $skillPath
Add-Check -Checks $checks -Name "runner-requires-run" -Passed ($runner -match 'ConfirmToken -ne "RUN"' -and $runner -match 'RunGateRequired') -Detail $runnerPath
Add-Check -Checks $checks -Name "runner-resource-gated" -Passed ($runner -match 'Invoke-ResourceSafety' -and $runner -match 'Sequential') -Detail $runnerPath
Add-Check -Checks $checks -Name "converter-external-pack" -Passed ($converter -match 'ExternalPackPath' -and $converter -match 'repairAllowed = \$false' -and $converter -match 'actionType = "manual_review"') -Detail $converterPath
Add-Check -Checks $checks -Name "converter-tool-parsers" -Passed ($converter -match 'setupdiag' -and $converter -match 'sigcheck' -and $converter -match 'tcpview') -Detail $converterPath
Add-Check -Checks $checks -Name "sync-includes-skill" -Passed ($sync -match 'windowsdoctor-offline-diagnostic-runner\\SKILL\.md') -Detail $syncPath
Add-Check -Checks $checks -Name "patch-includes-skill" -Passed ($patch -match 'windowsdoctor-offline-diagnostic-runner\\SKILL\.md') -Detail $patchPath
Add-Check -Checks $checks -Name "index-includes-skill" -Passed ($index -match 'windowsdoctor-offline-diagnostic-runner') -Detail $indexPath
Add-Check -Checks $checks -Name "memory-includes-skill" -Passed ($memory -match 'windowsdoctor-offline-diagnostic-runner') -Detail $memoryPath

$failed = @($checks | Where-Object { $_.Status -ne "PASS" })
$result = [PSCustomObject]@{
    Status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
    Phase = "offline-diagnostic-runner-skill"
    Root = $resolvedRoot
    CheckCount = $checks.Count
    Checks = $checks.ToArray()
    SafetyPolicy = [PSCustomObject]@{
        NoToolExecuted = $true
        NoRepairExecuted = $true
        NoGuiBrokerStarted = $true
        NoProductionBuild = $true
    }
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $reportParent = Split-Path -Parent $ReportPath
    if ($reportParent -and -not (Test-Path -LiteralPath $reportParent)) {
        New-Item -Path $reportParent -ItemType Directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($ReportPath, $resultJson, [System.Text.UTF8Encoding]::new($false))
}

if ($Json) { $resultJson } else { $result | Format-List }
if ($result.Status -ne "PASS") { exit 1 }
