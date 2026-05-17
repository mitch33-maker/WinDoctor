param(
    [string]$Root = "E:\WindowsDoctor",
    [string]$SourcePackPath = "",
    [string]$ReportPath = "",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not $SourcePackPath) {
    $SourcePackPath = Join-Path $Root "offline_database\known-windows-repair-sources.json"
}

if (-not (Test-Path -LiteralPath $SourcePackPath)) {
    throw "Source pack not found: $SourcePackPath"
}

function Test-MicrosoftOfficialUrl {
    param([string]$Url)
    return ($Url -match '^https://(learn|support)\.microsoft\.com/')
}

$retrievedDate = "2026-05-17"

$newSources = @(
    [PSCustomObject]@{
        id = "MS-LEARN-SETUPDIAG"
        vendor = "Microsoft"
        title = "SetupDiag"
        url = "https://learn.microsoft.com/en-us/windows/deployment/upgrade/setupdiag"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-FIX-CORRUPTION"
        vendor = "Microsoft"
        title = "Fix Windows Update corruptions and installation failures"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/fix-windows-update-errors"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-CLIENT-TROUBLESHOOT"
        vendor = "Microsoft"
        title = "Windows Update issues troubleshooting"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-client/installing-updates-features-roles/windows-update-issues-troubleshooting"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-DOWNLOAD-ERRORS"
        vendor = "Microsoft"
        title = "Troubleshoot Windows Update download errors"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-download-errors"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-0x80070002"
        vendor = "Microsoft"
        title = "Troubleshoot Windows Update error 0x80070002"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-0x80070002"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-0x80070490"
        vendor = "Microsoft"
        title = "Troubleshoot Windows Update error 0x80070490"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-0x80070490"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-0x800f0823"
        vendor = "Microsoft"
        title = "Troubleshoot Windows Update error code 0x800f0823"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-update-error-0x800f0823"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-WU-0x800f0831"
        vendor = "Microsoft"
        title = "Troubleshoot Windows Update installation error 0x800f0831"
        url = "https://learn.microsoft.com/en-us/troubleshoot/windows-server/installing-updates-features-roles/troubleshoot-windows-installation-error"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-WINDOWS-STOP-CODE"
        vendor = "Microsoft"
        title = "Troubleshooting Windows unexpected restarts and stop code errors"
        url = "https://support.microsoft.com/help/14238"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-WINDOWS-UPDATE-COMMON"
        vendor = "Microsoft"
        title = "Troubleshoot problems updating Windows"
        url = "https://support.microsoft.com/en-us/windows/troubleshoot-problems-updating-windows-188c2b0f-10a7-d72f-65b8-32d177eb136c"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-UPGRADE-INSTALL-ERRORS-2026"
        vendor = "Microsoft"
        title = "Get help with Windows upgrade and installation errors"
        url = "https://support.microsoft.com/en-us/windows/get-help-with-windows-upgrade-and-installation-errors-ea144c24-513d-a60e-40df-31ff78b3158a"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-SFC-DISM"
        vendor = "Microsoft"
        title = "Use the System File Checker tool to repair missing or corrupted system files"
        url = "https://support.microsoft.com/help/929833"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-PRINTER-CONNECTION"
        vendor = "Microsoft"
        title = "Fix printer connection and printing problems in Windows"
        url = "https://support.microsoft.com/en-us/windows/fix-printer-connection-and-printing-problems-in-windows-fb830bff-7702-6349-33cd-9443fe987f73"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-PRINTER-NOT-FOUND"
        vendor = "Microsoft"
        title = "Fix printer not found and printer not recognized errors in Windows"
        url = "https://support.microsoft.com/en-us/windows/fix-printer-not-found-and-printer-not-recognized-errors-in-windows-031ec613-4221-4a99-bc57-afb70b2b6af0"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-DEVICE-MANAGER-CODES"
        vendor = "Microsoft"
        title = "Error codes in Device Manager in Windows"
        url = "https://support.microsoft.com/en-us/topic/error-codes-in-device-manager-in-windows-524e9e89-4dee-8883-0afa-6bca0456324e"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-SUPPORT-GRAPHICS-CODE43"
        vendor = "Microsoft"
        title = "Fix graphics device problems with error code 43"
        url = "https://support.microsoft.com/en-us/windows/fix-graphics-device-problems-with-error-code-43-6f6ae1ec-0bbe-a848-142e-0c6190502842"
        retrievedDate = $retrievedDate
    },
    [PSCustomObject]@{
        id = "MS-LEARN-GETHELP-CLI"
        vendor = "Microsoft"
        title = "Command line version of Get Help"
        url = "https://learn.microsoft.com/en-us/troubleshoot/microsoft-365/admin/miscellaneous/get-help-command-line-overview"
        retrievedDate = $retrievedDate
    }
)

$newRules = @(
    [PSCustomObject]@{
        id = "MS-SETUPDIAG-UPGRADE-FAILURE"
        title = "SetupDiag Windows upgrade failure analysis"
        component = "windows_update"
        symptoms = @("Windows feature update failed", "Windows upgrade rollback", "setup log root cause needed")
        errorCodes = @()
        eventIds = @()
        triggerTerms = @("SetupDiag", "upgrade failure", "rollback", "setupact.log", "setuperr.log")
        recommendedActions = @("Run SetupDiag against Windows Setup logs", "Import SetupDiag output as diagnostic-only evidence")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-SETUPDIAG")
    },
    [PSCustomObject]@{
        id = "MS-WU-CORRUPTION-COMMON-CODES"
        title = "Windows Update corruption common error code set"
        component = "windows_update"
        symptoms = @("Windows Update corruption", "servicing stack or component store update failure")
        errorCodes = @("0x80070002", "0x800f0831", "0x80073712", "0x800f081f")
        eventIds = @()
        triggerTerms = @("Windows Update corruption", "CBS_E_STORE_CORRUPTION", "ERROR_FILE_NOT_FOUND", "DISM")
        recommendedActions = @("Collect CBS.log and Windows Update logs", "Run DISM/SFC checks as diagnostic or explicit RUN repair only")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-FIX-CORRUPTION", "MS-LEARN-DISM-REPAIR-IMAGE")
    },
    [PSCustomObject]@{
        id = "MS-WU-DOWNLOAD-CONNECTION-ERRORS"
        title = "Windows Update download connection errors"
        component = "windows_update"
        symptoms = @("Windows Update scan or download cannot reach update service", "update download timeout")
        errorCodes = @("0x80072EFD", "0x80072EFE", "0x80D02002")
        eventIds = @()
        triggerTerms = @("0x80072EFD", "0x80072EFE", "0x80D02002", "Windows Update download", "server connection")
        recommendedActions = @("Check network connectivity and proxy configuration", "Collect Windows Update logs before any repair")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-DOWNLOAD-ERRORS")
    },
    [PSCustomObject]@{
        id = "MS-WU-0x80070002-MISSING-FILES"
        title = "Windows Update 0x80070002 missing or corrupt files"
        component = "windows_update"
        symptoms = @("Windows Update error 0x80070002", "missing update files", "incomplete previous update")
        errorCodes = @("0x80070002")
        eventIds = @()
        triggerTerms = @("0x80070002", "ERROR_FILE_NOT_FOUND", "missing files", "incomplete previous update")
        recommendedActions = @("Collect Windows Update and CBS evidence", "Validate component store before repair")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-0x80070002")
    },
    [PSCustomObject]@{
        id = "MS-WU-0x80070490-DRIVER-FAILURE"
        title = "Windows Update 0x80070490 driver operation failure"
        component = "windows_update"
        symptoms = @("Windows Update error 0x80070490", "driver failure during update", "pending update blocks installation")
        errorCodes = @("0x80070490")
        eventIds = @()
        triggerTerms = @("0x80070490", "driver failure", "pending updates", "servicing stack")
        recommendedActions = @("Inspect update and driver installation evidence", "Back up OS disk before advanced repair")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-0x80070490")
    },
    [PSCustomObject]@{
        id = "MS-WU-0x800f0823-SERVICING-STACK"
        title = "Windows Update 0x800f0823 servicing stack required"
        component = "windows_update"
        symptoms = @("Windows Update error 0x800f0823", "CBS_E_NEW_SERVICING_STACK_REQUIRED", "servicing stack mismatch")
        errorCodes = @("0x800f0823")
        eventIds = @()
        triggerTerms = @("0x800f0823", "CBS_E_NEW_SERVICING_STACK_REQUIRED", "servicing stack")
        recommendedActions = @("Confirm CBS.log servicing stack requirement", "Install required servicing stack or cumulative update path")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-0x800f0823")
    },
    [PSCustomObject]@{
        id = "MS-WU-0x800f0831-MANIFEST-MISSING"
        title = "Windows Update 0x800f0831 manifest or package corruption"
        component = "windows_update"
        symptoms = @("Windows Update error 0x800f0831", "missing manifest", "CBS store corruption")
        errorCodes = @("0x800f0831")
        eventIds = @()
        triggerTerms = @("0x800f0831", "CBS_E_STORE_CORRUPTION", "manifest", "package missing")
        recommendedActions = @("Inspect CBS.log for missing package identity", "Use DISM/SFC only under explicit repair workflow")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-WU-0x800f0831", "MS-LEARN-WU-FIX-CORRUPTION")
    },
    [PSCustomObject]@{
        id = "MS-STOPCODE-BSOD-EVIDENCE"
        title = "Windows unexpected restart and stop code evidence"
        component = "system"
        symptoms = @("unexpected restart", "stop code", "blue screen or black screen failure")
        errorCodes = @()
        eventIds = @()
        triggerTerms = @("stop code", "PAGE_FAULT_IN_NONPAGED_AREA", "MEMORY_MANAGEMENT", "unexpected restart", "BSOD")
        recommendedActions = @("Record stop code and faulting module", "Review driver and hardware evidence before repair")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-WINDOWS-STOP-CODE")
    },
    [PSCustomObject]@{
        id = "MS-GETHELP-CLI-M365-DIAGNOSTIC"
        title = "Get Help command line Microsoft 365 diagnostic source"
        component = "application"
        symptoms = @("Microsoft 365 Apps issue", "Outlook issue", "Teams issue", "Office activation issue")
        errorCodes = @()
        eventIds = @()
        triggerTerms = @("Get Help command line", "Microsoft 365", "Office activation", "Outlook", "Teams")
        recommendedActions = @("Run Get Help command-line scenario outside WindowsDoctor", "Import output as external diagnostic evidence")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-LEARN-GETHELP-CLI")
    },
    [PSCustomObject]@{
        id = "MS-WU-COMMON-ERROR-MAP"
        title = "Windows Update common error code map"
        component = "windows_update"
        symptoms = @("Windows Update failed", "Windows Update download or install error", "Windows Update common error code")
        errorCodes = @("0x8007000d", "0x800705b4", "0x80240034", "0x800f0922", "0x80070057", "0x80080005", "0xC1900101", "0x8007000E", "0x800F081F", "0x80073712", "0x80246007", "0x80070002", "0x80070003", "0x80070422")
        eventIds = @()
        triggerTerms = @("Windows Update", "0x8007000d", "0x800705b4", "0x80240034", "0x800f0922", "0x80070057", "0x80080005", "0xC1900101", "0x8007000E", "0x800F081F", "0x80073712", "0x80246007", "0x80070422")
        recommendedActions = @("Map the error code to Microsoft official guidance", "Run Windows Update troubleshooter first", "Collect Windows Update logs before repair", "Use DISM/SFC only through explicit RUN repair workflow")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-WINDOWS-UPDATE-COMMON", "MS-LEARN-WU-CLIENT-TROUBLESHOOT")
    },
    [PSCustomObject]@{
        id = "MS-WU-0x80070422-SERVICE-DISABLED"
        title = "Windows Update 0x80070422 service disabled or stopped"
        component = "windows_update"
        symptoms = @("Windows Update service disabled", "Windows Update service stopped", "Windows Update error 0x80070422")
        errorCodes = @("0x80070422")
        eventIds = @()
        triggerTerms = @("0x80070422", "Windows Update service is disabled", "wuauserv", "service disabled")
        recommendedActions = @("Check Windows Update service state", "Confirm policy or enterprise management before enabling services", "Use explicit RUN gate before changing service startup")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-WINDOWS-UPDATE-COMMON")
    },
    [PSCustomObject]@{
        id = "MS-WU-0xC1900101-DRIVER-UPGRADE"
        title = "Windows upgrade 0xC1900101 likely driver rollback"
        component = "windows_update"
        symptoms = @("Windows upgrade rollback", "driver compatibility issue", "Windows upgrade error 0xC1900101")
        errorCodes = @("0xC1900101")
        eventIds = @()
        triggerTerms = @("0xC1900101", "driver", "upgrade rollback", "incompatible driver", "SetupDiag")
        recommendedActions = @("Run SetupDiag and review driver evidence", "Update or remove incompatible drivers only after confirmation", "Do not auto-remove drivers")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-WINDOWS-UPDATE-COMMON", "MS-LEARN-SETUPDIAG")
    },
    [PSCustomObject]@{
        id = "MS-SFC-DISM-OFFICIAL-SEQUENCE"
        title = "Official DISM and SFC system file repair sequence"
        component = "system_integrity"
        symptoms = @("system file corruption", "component store corruption", "SFC found corrupt files", "DISM source repair required")
        errorCodes = @("0x800f081f", "0x80073712")
        eventIds = @()
        triggerTerms = @("sfc /scannow", "DISM.exe /Online /Cleanup-image /Restorehealth", "Windows Resource Protection", "corrupt files")
        recommendedActions = @("Run DISM RestoreHealth before SFC when following official support guidance", "Capture CBS.log and DISM.log", "Keep RestoreHealth and SFC repair behind explicit RUN")
        script = "N/A"
        actionType = "manual_review"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-SFC-DISM", "MS-LEARN-DISM-REPAIR-IMAGE")
    },
    [PSCustomObject]@{
        id = "MS-WU-GETHELP-TROUBLESHOOTER-FIRST"
        title = "Windows Update troubleshooter and Get Help first-line path"
        component = "windows_update"
        symptoms = @("Windows Update problem", "Windows Update error without local evidence", "Windows 11 Update troubleshooting")
        errorCodes = @()
        eventIds = @()
        triggerTerms = @("Windows Update troubleshooter", "Get Help", "Other troubleshooters", "Windows Update problem")
        recommendedActions = @("Use Microsoft Get Help or Windows Update troubleshooter first", "Import resulting output as diagnostic evidence", "Do not invent findings when no output is available")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-WINDOWS-UPDATE-COMMON", "MS-LEARN-WU-CLIENT-TROUBLESHOOT")
    },
    [PSCustomObject]@{
        id = "MS-PRINTER-SPOOLER-AND-CONNECTION"
        title = "Printer connection, recognition, and spooler troubleshooting"
        component = "printer"
        symptoms = @("printer not found", "printer not recognized", "print job stuck", "Print Spooler issue")
        errorCodes = @()
        eventIds = @()
        triggerTerms = @("printer not found", "printer not recognized", "Print Spooler", "print queue", "printer troubleshooter")
        recommendedActions = @("Check printer connection and power", "Restart Print Spooler only through reviewed workflow", "Use Get Help printer troubleshooter", "Update or reinstall printer driver after confirmation")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-PRINTER-CONNECTION", "MS-SUPPORT-PRINTER-NOT-FOUND")
    },
    [PSCustomObject]@{
        id = "MS-HARDWARE-DEVICE-MANAGER-CODES"
        title = "Device Manager hardware error codes"
        component = "hardware"
        symptoms = @("Device Manager error code", "yellow exclamation device", "device driver problem", "hardware not working")
        errorCodes = @("Code 1", "Code 3", "Code 42", "Code 43", "Code 44", "Code 45")
        eventIds = @()
        triggerTerms = @("Device Manager", "Code 43", "device driver", "hardware problem", "yellow exclamation")
        recommendedActions = @("Record Device Manager code and device name", "Update, roll back, or reinstall driver only after confirmation", "Contact hardware vendor when Microsoft guidance requires vendor support")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-DEVICE-MANAGER-CODES")
    },
    [PSCustomObject]@{
        id = "MS-HARDWARE-GRAPHICS-CODE43"
        title = "Graphics device Code 43 driver or hardware failure"
        component = "hardware"
        symptoms = @("graphics device error code 43", "GPU driver problem", "display adapter not working")
        errorCodes = @("Code 43")
        eventIds = @()
        triggerTerms = @("Code 43", "graphics device", "display adapter", "driver rollback", "uninstall device")
        recommendedActions = @("Update graphics driver", "Roll back recent driver when appropriate", "Uninstall/reinstall device only after confirmation", "Treat hardware failure as manual review")
        script = "N/A"
        actionType = "guided"
        repairAllowed = $false
        riskLevel = "manual_review"
        sourceIds = @("MS-SUPPORT-GRAPHICS-CODE43", "MS-SUPPORT-DEVICE-MANAGER-CODES")
    }
)

foreach ($source in $newSources) {
    if (-not (Test-MicrosoftOfficialUrl -Url $source.url)) {
        throw "Non-Microsoft official URL rejected: $($source.url)"
    }
}

$pack = Get-Content -Raw -Encoding UTF8 -LiteralPath $SourcePackPath | ConvertFrom-Json
$existingSourceIds = @($pack.sources | ForEach-Object { [string]$_.id })
$existingRuleIds = @($pack.rules | ForEach-Object { [string]$_.id })

$mergedSources = New-Object System.Collections.Generic.List[object]
foreach ($source in @($pack.sources)) {
    if (-not (Test-MicrosoftOfficialUrl -Url ([string]$source.url))) {
        throw "Existing non-Microsoft official URL rejected: $($source.url)"
    }
    $mergedSources.Add($source)
}
foreach ($source in $newSources) {
    if ($existingSourceIds -notcontains $source.id) {
        $mergedSources.Add($source)
    }
}

$mergedRules = New-Object System.Collections.Generic.List[object]
foreach ($rule in @($pack.rules)) {
    if ([bool]$rule.repairAllowed -eq $true -or [string]$rule.script -ne "N/A") {
        $rule.script = "N/A"
        $rule.repairAllowed = $false
        if ([string]$rule.actionType -eq "auto_repair") {
            $rule.actionType = "guided"
        }
        if (-not $rule.riskLevel) {
            $rule.riskLevel = "manual_review"
        }
    }
    $mergedRules.Add($rule)
}
foreach ($rule in $newRules) {
    if ($existingRuleIds -notcontains $rule.id) {
        if ([bool]$rule.repairAllowed -eq $true) {
            throw "Official source update refuses auto repair imports: $($rule.id)"
        }
        if ($rule.script -ne "N/A") {
            throw "Official source update refuses script binding: $($rule.id)"
        }
        foreach ($sourceId in @($rule.sourceIds)) {
            if (@($mergedSources | ForEach-Object { $_.id }) -notcontains $sourceId) {
                throw "Missing source reference $sourceId for $($rule.id)"
            }
        }
        $mergedRules.Add($rule)
    }
}

$updatedPack = [PSCustomObject]@{
    schemaVersion = 1
    sources = @($mergedSources.ToArray() | Sort-Object id)
    rules = @($mergedRules.ToArray() | Sort-Object id)
}

$packJson = $updatedPack | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($SourcePackPath, $packJson, [System.Text.UTF8Encoding]::new($false))

$result = [PSCustomObject]@{
    Status = "PASS"
    SourcePackPath = $SourcePackPath
    AddedSources = @($newSources | Where-Object { $existingSourceIds -notcontains $_.id } | ForEach-Object { $_.id })
    AddedRules = @($newRules | Where-Object { $existingRuleIds -notcontains $_.id } | ForEach-Object { $_.id })
    SourceCount = @($updatedPack.sources).Count
    RuleCount = @($updatedPack.rules).Count
    ReportPath = $ReportPath
}

$resultJson = $result | ConvertTo-Json -Depth 6
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
