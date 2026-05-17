param(
    [Parameter(Mandatory = $true)]
    [string]$UsbRoot,
    [string]$OutputPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function ConvertTo-HtmlText {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Get-RelativeName {
    param(
        [string]$Base,
        [string]$Path
    )
    $baseFull = [System.IO.Path]::GetFullPath($Base).TrimEnd("\") + "\"
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if ($pathFull.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathFull.Substring($baseFull.Length)
    }
    return $Path
}

$resolvedUsbRoot = [System.IO.Path]::GetFullPath($UsbRoot).TrimEnd("\")
if (-not (Test-Path -LiteralPath $resolvedUsbRoot)) {
    throw "UsbRoot not found: $UsbRoot"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $resolvedUsbRoot "START_HERE.html"
}

$bootWim = Join-Path $resolvedUsbRoot "sources\boot.wim"
$packageDirs = @(Get-ChildItem -LiteralPath $resolvedUsbRoot -Directory -Force | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName "WindowsDoctor")
})
$zipFiles = @(Get-ChildItem -LiteralPath $resolvedUsbRoot -File -Filter "*.zip" -Force)
$packageNames = @($packageDirs | ForEach-Object { $_.Name })
$unmatchedZipFiles = @($zipFiles | Where-Object {
    $zipBase = $_.BaseName
    -not (@($packageNames | Where-Object {
        $zipBase -eq $_ -or $zipBase.StartsWith("$($_)-", [System.StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0)
})

$packages = New-Object System.Collections.Generic.List[object]
foreach ($dir in $packageDirs) {
    $manifestPath = Join-Path $dir.FullName "portable-usb-manifest.json"
    $wdRoot = Join-Path $dir.FullName "WindowsDoctor"
    $guiReadyLauncher = Join-Path $dir.FullName "Start-WindowsDoctor-GUI-Ready.cmd"
    $lowResourceLauncher = Join-Path $dir.FullName "Start-WindowsDoctor-LowResource.cmd"
    $lowResourceSilentLauncher = Join-Path $dir.FullName "Start-WindowsDoctor-LowResource-Silent.vbs"
    $portableLauncher = Join-Path $dir.FullName "Start-WindowsDoctor-Portable.cmd"
    $guiPortableLauncher = Join-Path $dir.FullName "Start-WindowsDoctor-GUI-Portable.cmd"
    $stopLauncher = Join-Path $dir.FullName "Stop-WindowsDoctor-GUI-Ready.cmd"
    $nodeRuntime = Join-Path $dir.FullName "node-runtime\node.exe"
    $offlineDb = Join-Path $wdRoot "offline_database\windowsdoctor-kb.json"
    $normalizedDb = Join-Path $wdRoot "offline_database\windowsdoctor-kb-normalized.json"
    $exactZip = Join-Path $resolvedUsbRoot "$($dir.Name).zip"
    $relatedZips = @($zipFiles | Where-Object {
        $_.BaseName -eq $dir.Name -or $_.BaseName.StartsWith("$($dir.Name)-", [System.StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object LastWriteTime -Descending)
    $latestRelatedZip = @($relatedZips | Select-Object -First 1)

    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
        }
        catch {
            $manifest = $null
        }
    }

    $status = "PASS"
    $issues = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $portableLauncher)) {
        $status = "WARN"
        $issues.Add("missing text menu launcher")
    }
    if (-not (Test-Path -LiteralPath $offlineDb)) {
        $status = "WARN"
        $issues.Add("missing offline KB")
    }
    if (-not (Test-Path -LiteralPath $normalizedDb)) {
        $status = "WARN"
        $issues.Add("missing normalized KB")
    }

    $zipStatus = "WARN"
    $zipIssue = "no matching zip"
    $zipPath = ""
    if (Test-Path -LiteralPath $exactZip) {
        $zipItem = Get-Item -LiteralPath $exactZip
        $zipPath = $zipItem.FullName
        if ($zipItem.LastWriteTime -lt $dir.LastWriteTime) {
            $zipIssue = "exact zip older than package folder"
            $status = "WARN"
            $issues.Add($zipIssue)
        }
        else {
            $zipStatus = "PASS"
            $zipIssue = "exact zip available"
        }
    }
    elseif ($latestRelatedZip.Count -gt 0) {
        $zipPath = $latestRelatedZip[0].FullName
        $zipIssue = "related zip available: $($latestRelatedZip[0].Name)"
        $status = "WARN"
        $issues.Add("exact zip missing; $zipIssue")
    }
    else {
        $status = "WARN"
        $issues.Add($zipIssue)
    }

    $packages.Add([PSCustomObject]@{
        Name = $dir.Name
        Path = $dir.FullName
        ManifestPath = if (Test-Path -LiteralPath $manifestPath) { $manifestPath } else { "" }
        Status = $status
        Issues = $issues.ToArray()
        FileCount = if ($manifest -and $manifest.FileCount) { [int]$manifest.FileCount } else { 0 }
        Bytes = if ($manifest -and $manifest.Bytes) { [int64]$manifest.Bytes } else { 0 }
        IncludeNodeRuntime = Test-Path -LiteralPath $nodeRuntime
        ZipStatus = $zipStatus
        ZipIssue = $zipIssue
        ZipPath = $zipPath
        RelatedZipCount = $relatedZips.Count
        TextLauncher = if (Test-Path -LiteralPath $portableLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $portableLauncher } else { "" }
        LowResourceLauncher = if (Test-Path -LiteralPath $lowResourceLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $lowResourceLauncher } else { "" }
        LowResourceSilentLauncher = if (Test-Path -LiteralPath $lowResourceSilentLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $lowResourceSilentLauncher } else { "" }
        GuiReadyLauncher = if (Test-Path -LiteralPath $guiReadyLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $guiReadyLauncher } else { "" }
        GuiPortableLauncher = if (Test-Path -LiteralPath $guiPortableLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $guiPortableLauncher } else { "" }
        StopLauncher = if (Test-Path -LiteralPath $stopLauncher) { Get-RelativeName -Base $resolvedUsbRoot -Path $stopLauncher } else { "" }
    })
}

$rows = New-Object System.Collections.Generic.List[string]
foreach ($pkg in $packages) {
    $actions = New-Object System.Collections.Generic.List[string]
    if ($pkg.LowResourceSilentLauncher) { $actions.Add("<strong>&#20302;&#36039;&#28304;</strong><br><code>$([string](ConvertTo-HtmlText $pkg.LowResourceSilentLauncher))</code>") }
    elseif ($pkg.LowResourceLauncher) { $actions.Add("<strong>&#20302;&#36039;&#28304;</strong><br><code>$([string](ConvertTo-HtmlText $pkg.LowResourceLauncher))</code>") }
    if ($pkg.GuiReadyLauncher) { $actions.Add("<code>$([string](ConvertTo-HtmlText $pkg.GuiReadyLauncher))</code>") }
    if ($pkg.TextLauncher) { $actions.Add("<code>$([string](ConvertTo-HtmlText $pkg.TextLauncher))</code>") }
    if ($pkg.StopLauncher) { $actions.Add("<code>$([string](ConvertTo-HtmlText $pkg.StopLauncher))</code>") }
    $issueText = if (@($pkg.Issues).Count -gt 0) { [string]::Join(", ", @($pkg.Issues)) } else { "ready" }
    $zipText = "$($pkg.ZipStatus): $($pkg.ZipIssue)"
    $rows.Add(@"
      <tr>
        <td><strong>$(ConvertTo-HtmlText $pkg.Name)</strong></td>
        <td><span class="status $($pkg.Status.ToLowerInvariant())">$($pkg.Status)</span></td>
        <td>$(ConvertTo-HtmlText $issueText)<br><code>$(ConvertTo-HtmlText $zipText)</code></td>
        <td>$([string]::Join("<br>", $actions.ToArray()))</td>
      </tr>
"@)
}
if ($rows.Count -eq 0) {
    $rows.Add('      <tr><td colspan="4">No WindowsDoctor packages found.</td></tr>')
}

$winPeStatus = if (Test-Path -LiteralPath $bootWim) { "PASS" } else { "WARN" }
$winPeDetail = if (Test-Path -LiteralPath $bootWim) { "sources\boot.wim" } else { "WinPE boot.wim not found" }
$zipInventoryStatus = if ($unmatchedZipFiles.Count -eq 0) { "PASS" } else { "WARN" }
$zipInventoryDetail = if ($unmatchedZipFiles.Count -eq 0) { "all root zip files match package folders" } else { "unmatched zip files: " + [string]::Join(", ", @($unmatchedZipFiles | Select-Object -ExpandProperty Name)) }
$generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

$html = @"
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>WindowsDoctor USB Selector</title>
  <style>
    body { margin: 0; font-family: "Microsoft JhengHei", Arial, sans-serif; background: #f5f7fb; color: #172033; }
    main { max-width: 1080px; margin: 0 auto; padding: 28px 18px 42px; }
    h1 { margin: 0 0 8px; font-size: 32px; }
    .lead { margin: 0 0 22px; color: #42526b; font-size: 18px; }
    .panel { background: #fff; border: 1px solid #d8e0ec; border-radius: 8px; padding: 16px; margin: 14px 0; }
    table { width: 100%; border-collapse: collapse; background: #fff; border: 1px solid #d8e0ec; }
    th, td { text-align: left; border-bottom: 1px solid #e8edf5; padding: 12px; vertical-align: top; }
    th { background: #eef3f9; }
    code { display: inline-block; background: #eef3f9; border-radius: 5px; padding: 3px 6px; margin: 2px 0; }
    .status { display: inline-block; min-width: 56px; text-align: center; border-radius: 6px; padding: 3px 8px; font-weight: 700; }
    .pass { background: #dff4e5; color: #155724; }
    .warn { background: #fff3cd; color: #7a5600; }
    .fail { background: #f8d7da; color: #721c24; }
  </style>
</head>
<body>
  <main>
    <h1>WindowsDoctor USB Selector</h1>
    <p class="lead">&#36984;&#25799;&#21487;&#29992;&#22871;&#20214;&#65292;&#20006;&#30906;&#35469; WinPE &#33287; GUI-ready &#29376;&#24907;&#12290;</p>

    <section class="panel">
      <strong>&#24314;&#35696;&#20837;&#21475;:</strong>
      &#20808;&#20351;&#29992; <code>Start-WindowsDoctor-LowResource-Silent.vbs</code>&#12290;&#27492;&#27169;&#24335;&#21482;&#21855;&#21205; Broker &#33287;&#38748;&#24907;&#20302;&#36039;&#28304; console&#65292;&#19981;&#21855;&#21205; Next dev GUI&#12290;
      <br>
      <strong>WinPE:</strong>
      <span class="status $($winPeStatus.ToLowerInvariant())">$winPeStatus</span>
      <code>$(ConvertTo-HtmlText $winPeDetail)</code>
      <br>
      <strong>Zip inventory:</strong>
      <span class="status $($zipInventoryStatus.ToLowerInvariant())">$zipInventoryStatus</span>
      <code>$(ConvertTo-HtmlText $zipInventoryDetail)</code>
    </section>

    <table>
      <thead>
        <tr>
          <th>&#22871;&#20214;</th>
          <th>&#29376;&#24907;</th>
          <th>&#25688;&#35201;</th>
          <th>&#20837;&#21475;</th>
        </tr>
      </thead>
      <tbody>
$([string]::Join("`r`n", $rows.ToArray()))
      </tbody>
    </table>

    <section class="panel">
      <strong>&#23433;&#20840;&#25552;&#37266;:</strong>
      &#27492;&#38913;&#21482;&#21015;&#20986;&#22871;&#20214;&#33287;&#20837;&#21475;&#65292;&#19981;&#22519;&#34892;&#20462;&#24489;&#12290;&#20219;&#20309;&#20462;&#24489;&#37117;&#24517;&#38920;&#26377; <code>RUN</code> &#30906;&#35469;&#12290;
      <br>
      <strong>Generated:</strong> $(ConvertTo-HtmlText $generatedAt)
    </section>
  </main>
</body>
</html>
"@

[System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.UTF8Encoding]::new($false))

$result = [PSCustomObject]@{
    Status = "PASS"
    UsbRoot = $resolvedUsbRoot
    OutputPath = $OutputPath
    PackageCount = $packages.Count
    WinPEBootWim = Test-Path -LiteralPath $bootWim
    ZipFileCount = $zipFiles.Count
    UnmatchedZipCount = $unmatchedZipFiles.Count
    UnmatchedZipFiles = @($unmatchedZipFiles | Select-Object -ExpandProperty FullName)
    Packages = $packages.ToArray()
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

if ($Json) {
    $resultJson
}
else {
    $result | Format-List
}
