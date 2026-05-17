# 成功經驗庫 (Success Experience)

Last updated: `2026-05-17`

本文件記錄 `WindowsDoctor` 開發過程中所累積的「高價值」成功解除阻塞或優化架構的經驗。未來若遇到類似技術需求，應優先檢索此文件。

## [SUCCESS-20260517-15] Safe CLI 離線真實診斷批次
### 問題描述
離線工具已能 RUN-gated 執行，但 zip 內多數工具是 GUI 或混合工具；若直接啟動可能造成使用者互動、資源失控或誤判輸出。實測也發現 Sysinternals 輸出可能是 UTF-16，若用 UTF-8 解析會產生錯誤摘要。
### 成功解決方案
在 `Invoke-OfflineDiagnosticTools.ps1` 中只允許 reviewed console 工具自動執行：SetupDiag、Sigcheck、TCPVCon、Handle、Autorunsc；加入 comma-separated `-ToolId`、`MaxToolSeconds`、`MaxOutputKB`。GUI 類工具維持 extract-only。`Convert-OfflineDiagnosticToolOutput.ps1` 改為 UTF-16 aware，並只讀實際輸出檔。
### 驗證方式
以真實 RUN diagnostic-only 批次執行 5 項工具，逐項 Resource Safety PASS；輸出轉 external diagnostics pack 後，`Test-ExternalDiagnosticsPack.ps1` 驗證 PASS，5 findings 全部維持 manual review / diagnostic-only。

## [SUCCESS-20260517-14] 離線診斷輸出 evidence gate
### 問題描述
離線工具 runner 若只留下原始輸出，後續仍需人工判讀；但若直接把工具結果轉成修復，會破壞 reviewed KB、allowlist 與 RUN gate。
### 成功解決方案
擴充 `Convert-OfflineDiagnosticToolOutput.ps1`，解析 SetupDiag、Sigcheck、TCPView 的關鍵 evidence，並可輸出 external diagnostics pack。匯入 gate 仍強制 `repairAllowed=false`、`script=N/A`、`actionType=manual_review`。
### 驗證方式
使用樣本輸出產生 evidence pack，經 `Test-ExternalDiagnosticsPack.ps1` 與 `Import-ExternalDiagnosticsPack.ps1` 驗證 PASS；未執行任何外部工具或修復。

## [SUCCESS-20260517-13] 離線診斷 runner 流程 skill 化
### 問題描述
離線工具封裝、自動選用、RUN-gated runner、輸出 evidence、USB patch 與完成紀錄已成為可重複流程；若只留在聊天或交接紀錄中，後續仍會重讀文件並可能漏掉安全 gate。
### 成功解決方案
新增 `skills\windowsdoctor-offline-diagnostic-runner\SKILL.md`，把最小讀取集合、禁止事項、preview/RUN 路徑、輸出轉換、驗證命令、USB sync 與 completion routine 固化成專用 skill。
### 驗證方式
更新 `Test-DocumentationMemorySystem.ps1` 驗證新 skill 已登錄、含 Resource Safety 與 RUN gate，並同步 USB 與增量 patch。

## [SUCCESS-20260517-12] RUN-gated 離線診斷 runner
### 問題描述
離線介面能自動選工具後，還需要安全地把工具使用接到工作視窗；若直接由 UI 執行工具，容易造成資源暴衝、工具並行、無法中斷或誤把診斷變成修復。
### 成功解決方案
新增 `Invoke-OfflineDiagnosticTools.ps1` 作為唯一 runner 邊界，預設 preview-only，實際執行必須 `RUN`。runner 依元件選工具、驗 SHA-256、序列化處理、每項工具前後跑 Resource Safety，並將結果交給 `Convert-OfflineDiagnosticToolOutput.ps1` 轉成診斷 evidence。Broker 工作視窗只接這個 runner。
### 驗證方式
以 preview 模式驗證 runner，不執行外部工具；再用 broker service tests、lint、Pester parse 與 `Test-OfflineToolAutomation.ps1` 確認接線與安全邊界。

## [SUCCESS-20260517-11] 離線工具自動選用介面
### 問題描述
離線工具已被安全封裝，但一般使用者不知道何時應使用 SetupDiag、RAMMap、TCPView、Process Monitor 等工具；若只把工具放進 USB，仍無法達成高度智能自動化。
### 成功解決方案
新增 `offlineTools.js`，由自然語言問題分類自動映射到封裝工具，並在 `ProblemSolverPanel` 顯示工具用途、可用狀態與 sequential command preview。此層只做自動選用與預覽，不執行、不解壓縮、不安裝、不改 allowlist。
### 驗證方式
`Test-OfflineToolAutomation.ps1` 確認 service 不含 spawn/exec、工具 manifest 全部 `autoRunAllowed=false`、來源為 `microsoft_official`，並以 broker service tests、lint、targeted Pester parse 驗證。

## [SUCCESS-20260517-10] Microsoft 官方離線診斷工具包
### 問題描述
離線維修現場需要可攜診斷工具，但直接下載整包或第三方工具會引入遠端執行、破壞性清除與供應鏈風險。
### 成功解決方案
新增 `Save-OfflineRepairTools.ps1`，只下載 SetupDiag 與低風險 Microsoft Sysinternals 診斷工具，排除 PsExec、PsKill、SDelete、PsShutdown。流程會計算 SHA-256、檢查 Authenticode 簽章、產生 manifest，再用既有 repair-tool packaging 流程封裝到本機與 USB。
### 驗證方式
確認 `offline-repair-tools-acquisition-20260517.json`、本機 manifest verify、USB hash verify 均為 PASS；套件不安裝、不執行、不更新 allowlist。

## [SUCCESS-20260517-09] 修復工具安全包裝而非直接安裝
### 問題描述
使用者希望系統能自動包裝修復所需軟體，但外部工具若未驗證來源、雜湊、授權與用途，會形成供應鏈與誤執行風險。
### 成功解決方案
新增 `REPAIR_TOOL_PACKAGING_POLICY.md`、manifest 範本、`Test-RepairToolPackageManifest.ps1` 與 `New-RepairToolPackage.ps1`。包裝流程要求 HTTPS source URL、source trust level、SHA-256、license、allowedUse、manual/diagnostic execution policy，且強制 `autoRunAllowed=false`。包裝結果不安裝、不執行、不更新 repair allowlist。
### 驗證方式
用 dummy diagnostic tool 建立 sample package，確認 manifest validation、SHA-256、package creation 均 PASS，且 `NoInstall=true`、`NoExecute=true`、`RepairAllowlistUpdated=false`。

## [SUCCESS-20260517-08] MIS 可讀的事件日誌解讀層
### 問題描述
既有事件掃描能取得 System/Application 錯誤並對應 KB，但 MIS 需要更容易篩選的 Provider/Event ID 統計、主要事件清單、JSON/CSV 證據與明確安全分類。
### 成功解決方案
新增 `scripts\Analyze-WindowsEventLogs.ps1` 作為唯讀分析器，輸出 `ProviderSummary`、`EventIdSummary`、`Findings`、`PrimaryRuleId`、`RepairState` 與 JSON/CSV 報告；Broker 透過 `eventLogAnalyzer.js` 與 `POST /api/event-logs/analyze` 暴露功能，前端新增 `EventLogAnalysisPanel`。
### 驗證方式
使用實機唯讀事件日誌分析、targeted Pester、broker service tests、lint 驗證；任何修復建議仍停留在 preview/guided/learn-only，不直接執行。

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

## [SUCCESS-20260517-07] TdccAutoV3 管理架構移植為 WindowsDoctor Local-First 管理系統
### 問題描述
WindowsDoctor 需要管理使用者權限與後台控制，但不能因此讓 NAS 或外部服務變成必要依賴，也不能讓修復/清理繞過 RUN gate。
### 成功解決方案
參考 TdccAutoV3 的 management profile、角色、token hash 與 audit JSONL 模式，建立 WindowsDoctor local-first 管理系統。角色定義為 `viewer/operator/admin/maintainer`，管理 token 只保存 PBKDF2-SHA256 hash，操作稽核寫入 JSONL，NAS profile 僅作 optional storage。
### 驗證方式
使用 `scripts\Test-ManagementSystemReadiness.ps1` 驗證角色、token hashing、audit、API、前端管理 UI 與 NAS optional policy，並用 broker tests/lint/system baseline 驗證整合。
