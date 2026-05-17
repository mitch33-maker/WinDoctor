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

$resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd("\")
$checks = New-Object System.Collections.Generic.List[object]

$adminService = Join-Path $resolvedRoot "gui\broker\services\admin.js"
$routes = Join-Path $resolvedRoot "gui\broker\routes.js"
$api = Join-Path $resolvedRoot "gui\src\lib\windowsDoctorApi.ts"
$types = Join-Path $resolvedRoot "gui\src\types\windows-doctor.ts"
$settings = Join-Path $resolvedRoot "gui\src\components\SettingsPanel.tsx"
$doc = Join-Path $resolvedRoot "MANAGEMENT_SYSTEM.md"
$profile = Join-Path $resolvedRoot "nas\windowsdoctor-management-profile.json"

Add-Check $checks "admin-service-exists" (Test-Path -LiteralPath $adminService) $adminService
Add-Check $checks "management-doc-exists" (Test-Path -LiteralPath $doc) $doc
Add-Check $checks "management-profile-exists" (Test-Path -LiteralPath $profile) $profile

$adminText = if (Test-Path -LiteralPath $adminService) { Get-Content -Raw -Encoding UTF8 -LiteralPath $adminService } else { "" }
$routesText = if (Test-Path -LiteralPath $routes) { Get-Content -Raw -Encoding UTF8 -LiteralPath $routes } else { "" }
$apiText = if (Test-Path -LiteralPath $api) { Get-Content -Raw -Encoding UTF8 -LiteralPath $api } else { "" }
$typesText = if (Test-Path -LiteralPath $types) { Get-Content -Raw -Encoding UTF8 -LiteralPath $types } else { "" }
$settingsText = if (Test-Path -LiteralPath $settings) { Get-Content -Raw -Encoding UTF8 -LiteralPath $settings } else { "" }

Add-Check $checks "roles-defined" ($adminText -match "viewer" -and $adminText -match "operator" -and $adminText -match "admin" -and $adminText -match "maintainer") "viewer/operator/admin/maintainer"
Add-Check $checks "token-hashing" ($adminText -match "pbkdf2Sync" -and $adminText -match "timingSafeEqual") "PBKDF2 and constant-time compare"
Add-Check $checks "audit-jsonl" ($adminText -match "admin_audit_events\.jsonl" -and $adminText -match "recordAdminAudit") "audit jsonl"
Add-Check $checks "operation-classes" ($adminText -match "read_only" -and $adminText -match "run_gated" -and $adminText -match "maintainer_only") "operation classification"
Add-Check $checks "management-routes" ($routesText -match "/api/admin/status" -and $routesText -match "/api/admin/accounts" -and $routesText -match "/api/admin/audit") "admin routes"
Add-Check $checks "frontend-api" ($apiText -match "getAdminStatus" -and $apiText -match "createAdminAccount" -and $apiText -match "getAdminAudit") "frontend API client"
Add-Check $checks "frontend-types" ($typesText -match "AdminStatus" -and $typesText -match "AdminAccount" -and $typesText -match "AdminAudit") "frontend types"
Add-Check $checks "settings-management-ui" ($settingsText -match "getAdminStatus" -and $settingsText -match "createAdminAccount" -and $settingsText -match "getAdminAudit") "settings management UI"

if (Test-Path -LiteralPath $profile) {
    $profileData = Get-Content -Raw -Encoding UTF8 -LiteralPath $profile | ConvertFrom-Json
    Add-Check $checks "nas-optional" ($profileData.policies.nasServerRequired -eq $false) "nasServerRequired=$($profileData.policies.nasServerRequired)"
    Add-Check $checks "external-token-policy" ($profileData.policies.externalAccessRequiresToken -eq $true) "externalAccessRequiresToken=$($profileData.policies.externalAccessRequiresToken)"
}

$status = if (@($checks | Where-Object { $_.Status -ne "PASS" }).Count -eq 0) { "PASS" } else { "FAIL" }
$checkArray = @()
foreach ($check in $checks) { $checkArray += $check }
$result = [PSCustomObject]@{
    Status = $status
    Phase = "management-system-readiness"
    Root = $resolvedRoot
    CheckCount = $checkArray.Count
    Checks = $checkArray
    SafetyPolicy = [PSCustomObject]@{
        NoGuiStarted = $true
        NoBrokerStarted = $true
        NoRepairExecuted = $true
        NasRequired = $false
    }
    ReportPath = $ReportPath
}

$jsonText = $result | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $parent = Split-Path -Parent $ReportPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($ReportPath, $jsonText, $utf8NoBom)
}

if ($Json) { $jsonText } else { $checks | Format-Table -AutoSize }
if ($status -ne "PASS") { exit 1 }
