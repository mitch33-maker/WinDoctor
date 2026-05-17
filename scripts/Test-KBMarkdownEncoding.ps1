param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

$normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$kbRoot = Join-Path $normalizedRoot "knowledge_base"
if (-not (Test-Path $kbRoot)) { throw "knowledge_base not found: $kbRoot" }

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Pass,
        [string]$Detail
    )
    $script:checks.Add([PSCustomObject]@{
        Name = $Name
        Status = if ($Pass) { "PASS" } else { "FAIL" }
        Detail = $Detail
    })
}

$files = @()
foreach ($category in @("reviewed", "learned")) {
    $path = Join-Path $kbRoot $category
    if (Test-Path $path) {
        $files += @(Get-ChildItem -LiteralPath $path -Filter "*.md" -File)
    }
}

Add-Check -Name "markdown-files-present" -Pass ($files.Count -gt 0) -Detail "files=$($files.Count)"

$replacementCharFiles = New-Object System.Collections.Generic.List[object]
$mojibakeFiles = New-Object System.Collections.Generic.List[object]
$missingTriggerFiles = New-Object System.Collections.Generic.List[object]
$missingTitleFiles = New-Object System.Collections.Generic.List[object]

$replacementChar = [string][char]0xfffd
$privateUseAfterQuestionPattern = '[?][\uf697\uf55e\uf2e9\uf1b3\uf24c\uf386\uf423]'
$commonMojibakeLeadPattern = '[\u876c\u875f\u64a3\u6470\u977d\u96bf\u969e\u9908\u7488\u7507\u929d][^\x00-\x7F]{1,8}[?]'

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($normalizedRoot.Length + 1)
    $content = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName

    if ($content.Contains($replacementChar)) {
        $replacementCharFiles.Add([PSCustomObject]@{ Path = $relativePath })
    }
    if ($content -match $privateUseAfterQuestionPattern -or $content -match $commonMojibakeLeadPattern) {
        $mojibakeFiles.Add([PSCustomObject]@{ Path = $relativePath })
    }
    if ($content -notmatch '(?m)^\s*-?\s*Trigger:\s*\[' -and $content -notmatch '(?m)^\s*ErrorCode:\s*"?[^"\r\n]+"?') {
        $missingTriggerFiles.Add([PSCustomObject]@{ Path = $relativePath })
    }
    if ($content -notmatch '(?m)^#\s+\S+') {
        $missingTitleFiles.Add([PSCustomObject]@{ Path = $relativePath })
    }
}

Add-Check -Name "utf8-replacement-characters" -Pass ($replacementCharFiles.Count -eq 0) -Detail "files=$($replacementCharFiles.Count)"
Add-Check -Name "mojibake-patterns" -Pass ($mojibakeFiles.Count -eq 0) -Detail "files=$($mojibakeFiles.Count)"
Add-Check -Name "trigger-lines" -Pass ($missingTriggerFiles.Count -eq 0) -Detail "missing=$($missingTriggerFiles.Count)"
Add-Check -Name "title-lines" -Pass ($missingTitleFiles.Count -eq 0) -Detail "missing=$($missingTitleFiles.Count)"

$checkArray = @($checks.ToArray())
$result = [PSCustomObject]@{
    Status = if (@($checkArray | Where-Object { $_.Status -eq "FAIL" }).Count -gt 0) { "FAIL" } else { "PASS" }
    Root = $normalizedRoot
    TotalFiles = $files.Count
    ReportPath = $ReportPath
    Checks = $checkArray
    SuspectFiles = [PSCustomObject]@{
        ReplacementCharacters = @($replacementCharFiles.ToArray())
        Mojibake = @($mojibakeFiles.ToArray())
        MissingTrigger = @($missingTriggerFiles.ToArray())
        MissingTitle = @($missingTitleFiles.ToArray())
    }
}

$resultJson = $result | ConvertTo-Json -Depth 8
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
    $checkArray | Format-Table -AutoSize
}

if ($result.Status -eq "FAIL") { exit 1 }
