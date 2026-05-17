# 成功經驗庫 (Success Experience)

Last updated: `2026-05-17`

本文件記錄 `WindowsDoctor` 開發過程中所累積的「高價值」成功解除阻塞或優化架構的經驗。未來若遇到類似技術需求，應優先檢索此文件。

## [SUCCESS-20260427-01] 解決 Node.js EADDRINUSE Port 3001 背景卡死問題
### 問題描述
當修改 `broker.js` 並且需要在背景重新啟動時（尤其透過 PowerShell 的非同步指令），舊的 Broker 進程往往不會正常退出。若直接重新下 `node broker.js` 會報錯或前端會收到 `404 Not Found` (因為 3001 Port 仍被舊進程無效佔用)。
### 成功解決方案
切勿依賴簡單的 `Stop-Process -Name node`，因為可能誤殺其他環境。
**正確解法**：使用 `netstat` 與 `findstr` 精確捕捉該 Port 的 PID 並使用 `taskkill` 強制剔除：
```bat
for /f tokens^=5 %a in ('netstat -ano ^| findstr :3001 ^| findstr LISTENING') do taskkill /F /PID %a 2>nul
```
系統會自動將舊的釋放，隨後安全啟動新的 `node`，確保前端 API 長期穩定運作。

## [SUCCESS-20260427-02] NAS 雙向資料同步與 RAG 架構
### 問題描述
需要將使用者的本機 `knowledge_base/` 與 NAS 共享路徑同步，並支援環境變更防護。
### 成功解決方案
設計 `Sync-NASKnowledge.ps1` 腳本封裝 `robocopy`，並在前端提供獨立的 `/api/config/kb` 與 `/api/sync` 端點，此架構經證實能無痛且高效地處理雙向檔案同步，大幅降低 Token 消耗。

## [SUCCESS-20260517-01] 文件體系記憶化與完成紀錄
### 問題描述
文件、交接、錯誤歷史與成功經驗分散時，後續任務容易重讀大量歷史，或在完成工作後漏記證據與下一步。
### 成功解決方案
建立 `MEMORY_SYSTEM.md` 作為長期記憶分層，新增 `TASK_COMPLETION_LOG.md` 作為每件任務的短紀錄，並用 `scripts\Add-TaskCompletionRecord.ps1` 標準化完成紀錄。可重複流程沉澱到 `skills\windowsdoctor-documentation-system\SKILL.md`，後續文件/記憶任務可先讀最小集合，不必重掃所有歷史文件。
### 驗證方式
使用 `scripts\Test-DocumentationMemorySystem.ps1` 驗證索引、記憶文件、完成紀錄、操作命令與 skill 是否同步。

## [SUCCESS-20260517-02] 低資源自我修復驗收策略
### 問題描述
全面自檢若直接跑完整 Pester 或固定歷史補丁檔名，會造成長時間卡住、報告缺失，或 USB 驗收驗證錯誤版本。
### 成功解決方案
將 `Test-SystemBaseline.ps1` 預設調整為低資源 Pester safety smoke，完整 Pester 改由 `-FullPester` 明確啟用；`Test-UsbLowResourceAcceptance.ps1` 改為自動選取 USB 根目錄最新增量補丁。此做法保留完整測試入口，同時讓無人值守自檢能穩定寫出 JSON 證據。
### 驗證方式
以 `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -Json` 驗證低風險基線，並以 USB low-resource acceptance 驗證 Broker-only 啟動、release validation 與最新增量補丁。

## [SUCCESS-20260517-03] 官方來源覆蓋率與第三方隔離
### 問題描述
擴充修復能力時，容易把 GitHub/community 腳本直接變成正式修復流程，造成不可控風險；同時「80% 覆蓋率」若沒有 gate，會變成無法驗證的描述。
### 成功解決方案
以 Microsoft Learn / Microsoft Support 為優先來源，將官方資料匯入 public reference records，並新增 `scripts\Test-RepairCoverageGoal.ps1` 檢查目標元件覆蓋率。GitHub/community 只記錄於 `THIRD_PARTY_REPAIR_REFERENCE.md`，未經 review、dry-run evidence 與 allowlist 決策前不得進入正式 auto-repair。
### 驗證方式
使用 `Export-NormalizedKBDatabase.ps1`、`Test-NormalizedKBDatabase.ps1` 與 `Test-RepairCoverageGoal.ps1` 驗證 normalized KB、官方來源完整性與 coverage target。

## [SUCCESS-20260517-04] 自動修復升級 Gate 機器化
### 問題描述
一鍵自動修復若只依 allowlist 或官方來源判斷，仍可能執行會中斷網路、服務、開機或系統完整性的動作。
### 成功解決方案
新增 `scripts\repair-safety-policy.json`，把可逆性、dry-run impact、本機驗證、關鍵中斷、rollback guidance、allowlist review 與 RUN gate 改成機器可驗證條件。`Invoke-RecommendedRepairPlan.ps1` v4 只允許 policy-approved 項目進入 auto batch，並在 preview 內輸出 `AutoRepairSafety.BlockReasons`。
### 驗證方式
使用 `scripts\Test-AutoRepairSafetyPolicy.ps1` 驗證 policy 覆蓋所有 allowlist 腳本，並用 `Invoke-RecommendedRepairPlan.ps1` 確認未達標腳本停留在 preview/manual。

## [SUCCESS-20260517-05] 自然語言問題入口產品化
### 問題描述
使用者不應需要知道 Event ID、DISM、SFC、KB rule 或 allowlist，才能取得診斷與修復建議。
### 成功解決方案
新增 `gui\broker\services\issuePlanner.js` 與 `ProblemSolverPanel.tsx`，讓使用者輸入一句問題描述即可產生分類、KB 比對、repair preview、安全 gate 結果與可讀報告。`/api/work/diagnose` 會把同一流程放入工作視窗，沿用資源快照與可中斷能力。
### 驗證方式
以 `npm run test:broker --prefix E:\WindowsDoctor\gui` 驗證自然語言分類與 issue plan，以 `npm run lint --prefix E:\WindowsDoctor\gui` 驗證前端與 Broker 程式碼。

## [SUCCESS-20260517-06] 專項診斷與低風險 Auto-Batch 候選
### 問題描述
自然語言入口若只做 KB 比對，無法回報印表機、Windows Update、網路等類型的本機即時狀態；auto-batch 也需要先從不影響 Windows OS 的低風險項目開始。
### 成功解決方案
新增 `scripts\Test-SpecializedIssueDiagnostics.ps1`，讓 AI issue plan 依分類執行唯讀專項診斷並回傳檢查數與狀態。新增 `Repair-WDReportCache.bat` 與 `RULE-WD-REPORT-CACHE.md`，只處理 WindowsDoctor 本身的報告快取，通過 safety policy 成為第一個 `autoBatchAllowed=true` 候選，但執行仍需 `RUN`。
### 驗證方式
使用 `Test-SpecializedIssueDiagnostics.ps1` 驗證 printer/windows_update/network，使用 `Test-AutoRepairSafetyPolicy.ps1` 驗證 `AllowlistedCount=7`、`PolicyScriptCount=7`、`AutoBatchAllowedCount=1`，並以 broker tests/lint 驗證 AI plan 整合。
