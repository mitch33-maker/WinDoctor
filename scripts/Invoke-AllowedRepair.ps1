param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ScriptName = "",
    [switch]$List,
    [switch]$Preview,
    [switch]$Execute,
    [string]$ConfirmToken = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$allowlistPath = Join-Path $normalizedRoot "scripts\repair-allowlist.json"
$policyPath = Join-Path $normalizedRoot "scripts\repair-safety-policy.json"

function Get-AllowlistedRepair {
    if (-not (Test-Path $allowlistPath)) { throw "Repair allowlist not found: $allowlistPath" }
    $allowlist = Get-Content -Raw -Encoding UTF8 -LiteralPath $allowlistPath | ConvertFrom-Json
    @($allowlist.scripts | ForEach-Object {
            $name = [string]$_
            $path = Join-Path $normalizedRoot "scripts\$name"
            [PSCustomObject]@{
                name = $name
                path = $path
                exists = Test-Path $path
            }
        })
}

function Resolve-AllowlistedRepair {
    param([Parameter(Mandatory = $true)][string]$Name)

    $repairs = @(Get-AllowlistedRepair)
    $repair = @($repairs | Where-Object { $_.name -eq $Name }) | Select-Object -First 1
    if (-not $repair) { throw "Repair script is not allowlisted: $Name" }
    if (-not $repair.exists) { throw "Repair script file not found: $($repair.path)" }
    $repair
}

function Get-RepairSafety {
    param([string]$Name)

    if (-not (Test-Path -LiteralPath $policyPath)) {
        return $null
    }

    $policy = Get-Content -Raw -Encoding UTF8 -LiteralPath $policyPath | ConvertFrom-Json
    @($policy.scripts | Where-Object { [string]$_.scriptName -eq $Name }) | Select-Object -First 1
}

function Write-Result {
    param([Parameter(Mandatory = $true)]$Value)

    if ($Value.PSObject.Properties.Name -notcontains "ReportPath") {
        $Value | Add-Member -NotePropertyName ReportPath -NotePropertyValue $ReportPath
    }
    $resultJson = $Value | ConvertTo-Json -Depth 8
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
        $Value
    }
}

if ($List -or -not $ScriptName) {
    $repairs = @(Get-AllowlistedRepair)
    Write-Result -Value ([PSCustomObject]@{
            Status = "PASS"
            Mode = "list"
            Root = $normalizedRoot
            Count = $repairs.Count
            Repairs = $repairs
        })
    return
}

$repair = Resolve-AllowlistedRepair -Name $ScriptName
$safety = Get-RepairSafety -Name $ScriptName

if ($Preview -or -not $Execute) {
    $content = [string](Get-Content -Raw -Encoding UTF8 -LiteralPath $repair.path)
    Write-Result -Value ([PSCustomObject]@{
            Status = "PASS"
            Mode = "preview"
            Repair = $repair
            Safety = $safety
            Command = "cmd.exe /c `"$($repair.path)`""
            Content = $content
        })
    return
}

if ($ConfirmToken -ne "RUN") {
    throw "Execution requires -ConfirmToken RUN"
}

& cmd.exe /c $repair.path
$exitCode = $LASTEXITCODE
Write-Result -Value ([PSCustomObject]@{
        Status = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
        Mode = "execute"
        Repair = $repair
        ExitCode = $exitCode
    })
exit $exitCode
