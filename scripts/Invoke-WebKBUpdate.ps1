# WindowsDoctor Web-KB Fetcher (RAG Skill Ported from ROY)
# Goal: Fetch latest troubleshooting context from Microsoft Support or target domains

param(
    [string[]]$Keywords = @("Windows 10 Spooler error", "TPM 2.0 Secure Boot fix"),
    [string]$OutputPath = "e:\WindowsDoctor\knowledge_base"
)

$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

foreach ($word in $Keywords) {
    $searchUrl = "https://www.bing.com/search?q=" + [uri]::EscapeDataString($word + " site:support.microsoft.com")
    Write-Host "Searching external KB for: $word" -ForegroundColor Cyan
    
    try {
        $page = Invoke-WebRequest -Uri $searchUrl -UserAgent $UserAgent -TimeoutSec 10 -ErrorAction Stop
        # 簡單提取關鍵字段落 (模擬 RAG 提取)
        $links = $page.Links | Where-Object { $_.href -match "support.microsoft.com" } | Select-Object -First 2
        
        foreach ($link in $links) {
            $id = "WEB-" + (Get-Random -Maximum 99999)
            $content = @"
---
ID: $id
Title: External KB - $word
ErrorCode: $($word -replace '^.*(0x[0-9A-Fa-f]+).*$', '$1')
Description: Auto-synced from Microsoft Support link $($link.href)
Remediation: scripts/Maintenance-Daily.ps1
AutoRepair: false
Source: $($link.href)
---
### 外部診斷建議
本條目由 WindowsDoctor Web-Sync 技能自動從 Microsoft Support 擷取。
建議優先確認系統更新狀態，並參考連結中的硬體相容性清單。
"@
            $content | Out-File (Join-Path $OutputPath "$id.md") -Encoding utf8
            Write-Host "Saved Web KB: $id" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Search failed for $word : $($_.Exception.Message)" -ForegroundColor Red
    }
}
