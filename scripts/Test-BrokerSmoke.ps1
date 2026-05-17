param(
    [string]$BaseUrl = "http://localhost:3001"
)

$ErrorActionPreference = "Stop"

function Invoke-SmokeJson {
    param(
        [string]$Name,
        [string]$Uri,
        [string]$Method = "Get",
        [string]$Body = ""
    )

    try {
        $params = @{
            Uri    = $Uri
            Method = $Method
        }
        if ($Body) {
            $params.ContentType = "application/json"
            $params.Body = $Body
        }
        $result = Invoke-RestMethod @params
        [PSCustomObject]@{ Name = $Name; Status = "PASS"; Detail = ($result | ConvertTo-Json -Compress -Depth 4) }
    }
    catch {
        $bodyText = $_.ErrorDetails.Message
        $statusCode = $null
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        [PSCustomObject]@{ Name = $Name; Status = "FAIL"; Detail = "HTTP=$statusCode BODY=$bodyText ERROR=$($_.Exception.Message)" }
    }
}

$results = @()
$results += Invoke-SmokeJson -Name "health" -Uri "$BaseUrl/api/health"
$results += Invoke-SmokeJson -Name "vision" -Uri "$BaseUrl/api/vision-analyze" -Method "Post"
$results += Invoke-SmokeJson -Name "elevate" -Uri "$BaseUrl/api/sentry/elevate" -Method "Post"
$results += Invoke-SmokeJson -Name "allowlist" -Uri "$BaseUrl/api/repair/allowlist"
$results += Invoke-SmokeJson -Name "rules" -Uri "$BaseUrl/api/rules"

try {
    Invoke-RestMethod -Uri "$BaseUrl/api/repair" -Method Post -ContentType "application/json" -Body '{"script":"..\\bad.bat"}' | Out-Null
    $results += [PSCustomObject]@{ Name = "repair-block"; Status = "FAIL"; Detail = "Unexpected success" }
}
catch {
    $statusCode = $null
    if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
    if ($statusCode -eq 400 -and $_.ErrorDetails.Message -match "Script not allowed") {
        $results += [PSCustomObject]@{ Name = "repair-block"; Status = "PASS"; Detail = "Blocked unsafe script" }
    }
    else {
        $results += [PSCustomObject]@{ Name = "repair-block"; Status = "FAIL"; Detail = "HTTP=$statusCode BODY=$($_.ErrorDetails.Message)" }
    }
}

$results | Format-Table -AutoSize
if ($results.Status -contains "FAIL") { exit 1 }
