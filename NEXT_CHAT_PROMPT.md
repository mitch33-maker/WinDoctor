請在 `E:\WindowsDoctor` 繼續 WindowsDoctor 系統開發工作。

最新狀態 `2026-05-17 natural-language-ai-diagnostic-workflow`：
- 使用者要求朝「只輸入要解決的問題，即可得到修復結果」改進。
- 已新增自然語言問題入口：
  - `gui\broker\services\issuePlanner.js`
  - `gui\src\components\ProblemSolverPanel.tsx`
- 新 API：
  - `POST /api/ai/plan`
  - `POST /api/work/diagnose`
- 新流程：
  - 問題文字分類
  - KB rule match
  - AI triage summary
  - one-click repair preview v4
  - auto-repair safety policy gate
  - 使用者報告：summary / fixed / not fixed / next actions
  - 可放入 work window，顯示資源快照並可中斷
- 安全：
  - 此流程只做診斷與修復預覽。
  - 不執行 OS 修復。
  - 真正修復仍需 RUN gate。
- 驗證：
  - `npm run test:broker --prefix E:\WindowsDoctor\gui`: `PASS`
  - `npm run lint --prefix E:\WindowsDoctor\gui`: `PASS`
  - auto repair safety policy: `PASS`
- 後續建議：
  - 將 `ProblemSolverPanel` 的結果更細緻映射到印表機/Windows Update/網路專項檢查。
  - 選一個低風險可逆修復候選，補 pre-state/rollback/local validation，讓 auto-batch approved 從 `0` 提升到 `1`。

最新狀態 `2026-05-17 auto-repair-safety-gate-framework`：
- 使用者要求建置一鍵檢測並自動修復的升級條件：
  - 可逆
  - dry-run 可預估影響
  - 本機驗證證據
  - 不中斷關鍵裝置或服務
  - rollback guidance
  - allowlist review
  - 高風險仍需 RUN gate
- 已新增：
  - `AUTO_REPAIR_SAFETY_POLICY.md`
  - `scripts\repair-safety-policy.json`
  - `scripts\Test-AutoRepairSafetyPolicy.ps1`
- 已更新：
  - `scripts\Invoke-RecommendedRepairPlan.ps1` 到 `RepairPlanVersion=4` / `DecisionEngineVersion=4`
  - `scripts\Invoke-AllowedRepair.ps1` preview 會輸出 Safety metadata
  - USB sync / incremental patch 清單
  - `INDEX.md`
  - `OPERATIONS.md`
- 目前 auto-batch approved scripts = `0`，這是安全結果，不是錯誤。
  - 現有腳本會影響 network/services/boot/system integrity/update cache/maintenance。
  - 需逐項補 pre-state capture、rollback evidence、local validation PASS 後才能升級。
- 已驗證：
  - auto repair safety policy: `PASS`
  - recommended repair preview v4: `PASS`
  - allowlisted repair preview with Safety metadata: `PASS`
  - targeted Pester: `PASS`
- 證據：
  - `E:\WindowsDoctor\logs\auto-repair-safety-policy-20260517.json`
  - `E:\WindowsDoctor\logs\allowed-repair-preview-safety-policy-20260517.json`
  - `E:\WindowsDoctor\logs\recommended-repair-plan.safety-policy-20260517.json`
- 後續建議：
  - 先挑一個低風險且可逆的修復項目，加入 pre-state capture 與 rollback command。
  - 重新跑 `Test-AutoRepairSafetyPolicy.ps1`，確認是否可將該項提升為 `autoBatchAllowed=true`。

最新狀態 `2026-05-17 microsoft-official-repair-coverage`：
- 使用者要求朝 Windows 官方資料庫/文件搜尋，擴充可診斷與可修復問題，目標覆蓋 80% 以上，且不得把未驗證第三方流程直接套進正式系統。
- 已新增官方覆蓋率 gate：
  - `scripts\Test-RepairCoverageGoal.ps1`
- 已新增文件：
  - `REPAIR_COVERAGE_ROADMAP.md`
  - `THIRD_PARTY_REPAIR_REFERENCE.md`
- 已擴充 Microsoft Learn / Microsoft Support 官方參考來源：
  - Windows Update / upgrade errors
  - SFC / DISM 官方順序
  - printer connection / printer not found
  - Device Manager error codes / graphics Code 43
- 最新 normalized KB：
  - total records: `90`
  - Microsoft official reference records: `25`
  - component coverage: `100%`
  - Microsoft official component coverage: `88.89%`
  - auto-repair records: `21`
- 重要限制：
  - 這是 diagnostic/guided coverage，不代表 100% 自動修復。
  - auto-repair 仍只允許 reviewed allowlist。
  - GitHub/community code 只放入 quarantine reference，未匯入正式 allowlist。
- 驗證：
  - normalized KB: `PASS`
  - repair coverage goal: `PASS`
  - documentation memory system: `PASS`
  - documentation sync: `PASS`
  - low-risk system baseline: `PASS`
- 最新證據：
  - `E:\WindowsDoctor\logs\normalized-kb.official-coverage-20260517.json`
  - `E:\WindowsDoctor\logs\repair-coverage-goal.official-coverage-20260517.json`
  - `E:\WindowsDoctor\logs\documentation-sync.official-coverage-20260517.json`
  - `E:\WindowsDoctor\logs\system-baseline.official-coverage-20260517.json`
- 已同步：
  - local release package: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
  - USB package: `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
- 已產生並驗證增量補丁：
  - `E:\WindowsDoctor\releases\portable-usb\incremental-patches\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-20260517-OfficialCoverage.zip`
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-20260517-OfficialCoverage.zip`
- 後續建議：
  - 若要提升 auto-repair 比例，只能從 reviewed KB + dry-run evidence + allowlist review 逐項提升。
  - 優先補 boot 官方來源覆蓋，讓 Microsoft official component coverage 從 `88.89%` 提升到 `100%`。

最新狀態 `2026-05-17 self-healing-baseline-guard`：
- 使用者要求進入 Unattended Self-Healing Mode。
- 安全邊界仍維持：未提供明確 `RUN` token，不得執行 OS 修復、BCD、DISM、SFC、CHKDSK、清理或破壞性維護。
- 已修復低風險基線問題：
  - `Test-SystemBaseline.ps1` 預設 Pester 改為低資源安全語法 smoke。
  - 完整 Pester 改成明確 `-FullPester` 才執行。
- 已修復 USB 低資源驗收問題：
  - `Test-UsbLowResourceAcceptance.ps1` 未指定 `PatchZipPath` 時會自動選取 USB 根目錄最新增量補丁。
- 已停止本輪逾時後殘留的 WindowsDoctor Pester PowerShell 測試程序。
- `MEMORY_SYSTEM.md` 已改為 USB 代號自動偵測；本機目前 `F:` 不存在，偵測到 `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`。
- 驗證：
  - low-risk baseline: `PASS`
  - USB `G:` low-resource acceptance: `PASS`
  - startup resource: `NodeCount=1`, `PostCssWorkers=0`, `TotalWorkingSetMB=46.37..47.41`
  - real data import readiness: `WAITING`
  - TASK_HANDOFF archive readiness: `WAITING`, `3418/3500`

最新狀態 `2026-05-17 documentation-memory-system`：
- 已建立文件體系與長期記憶分層：
  - `MEMORY_SYSTEM.md`
  - `TASK_COMPLETION_LOG.md`
  - `skills\windowsdoctor-documentation-system\SKILL.md`
- 已新增任務完成自動紀錄腳本：
  - `scripts\Add-TaskCompletionRecord.ps1`
- 已新增文件記憶體系驗證腳本：
  - `scripts\Test-DocumentationMemorySystem.ps1`
- USB 同步與增量補丁清單已納入新記憶文件、完成紀錄、skill 與驗證腳本。
- 後續文件/交接/記憶任務可先套用 `skills\windowsdoctor-documentation-system\SKILL.md`，讀取最小文件集合，避免重讀全部歷史。
- 每件任務完成後應執行 `Add-TaskCompletionRecord.ps1`，並引用實際 `logs\*.json` 證據。
- 安全限制仍維持：
  - 每次工作前先跑 Resource Safety。
  - 未明確提供 `RUN` 不執行修復或破壞性維護。
  - 不自行啟動 GUI/Broker。
  - 不執行 production build。

最新狀態 `2026-05-09 low-resource-incremental-patch-delivery`：
- 使用者要求繼續以無人值守模式完成多項建議任務，並讓系統朝高效能、低資源消耗方向改進。
- 已新增低資源交付方式：
  - `scripts\New-PortableIncrementalPatch.ps1`
  - `scripts\Test-PortableIncrementalPatch.ps1`
- 目的：
  - 小型 USB incremental patch zip。
  - 避免每次小改都重壓完整 GUI-ready package。
  - patch manifest 內含 SHA-256。
  - 可驗證 patch zip、manifest 與 package root 一致性。
  - 不包含 target-specific `portable-usb-manifest.json`。
- 已同步文件：
  - `INDEX.md`
  - `PERFORMANCE_POLICY.md`
  - `OPERATIONS.md`
  - `TASK_HANDOFF.md`
- USB 代號目前為 `F:`。
- 已同步並驗證：
  - `F:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
  - `F:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3\Start-WindowsDoctor-LowResource-Silent.vbs`
  - `F:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-20260509-LowResource.zip`
- USB selector 已改為低資源入口優先。
- `scripts\Start-WindowsDoctor.ps1` now detects portable `node-runtime\node.exe` for USB package roots.
- USB sync list now includes `gui\broker\services\work.js`.
- USB sync list now includes `scripts\Test-ResourceSafety.ps1`, so USB low-resource startup reports include working-set fields.
- Added `scripts\Test-UsbLowResourceEntry.ps1` for non-starting USB low-resource entry acceptance.
- Added `scripts\Test-UsbLowResourceAcceptance.ps1` for full low-resource USB acceptance.
- `scripts\Start-WindowsDoctor.ps1` now cleans up the just-started Broker process if Broker readiness times out.
- `START_HERE.html` generator now uses HTML entities for low-resource recommendation text to avoid encoding drift.
- 驗證結果：
  - local incremental patch: `PASS`, `FileCount=43`, `ZipBytes=182458`
  - local patch verify: `PASS`
  - USB `F:` patch verify: `PASS`
  - USB `F:` release validation: `PASS`
  - USB `F:` low-resource startup: `PASS`, `NodeCount=1`, `PostCssWorkers=0`, `TotalWorkingSetMB=45.93..47.22`
  - USB `F:` final release validation: `PASS`
- 最新證據：
  - `E:\WindowsDoctor\logs\low-resource-startup-f-usb-final-20260509.json`
  - `E:\WindowsDoctor\logs\release-validation-f-low-resource-final-20260509.json`
  - `E:\WindowsDoctor\logs\usb-selector-final-low-resource-first-f-20260509.json`
  - `E:\WindowsDoctor\logs\usb-low-resource-entry-final-f-20260509.json`
  - `E:\WindowsDoctor\logs\release-validation-final-low-entry-f-20260509.json`
  - `E:\WindowsDoctor\logs\usb-low-resource-acceptance-f-20260509.json`
- Latest acceptance:
  - full USB low-resource acceptance: `PASS`
  - incremental patch: `FileCount=51`; zip size may change after documentation sync, use the latest `portable-incremental-patch.*.json` report as source of truth.
- 下輪先執行 Resource Safety，再驗證：
  - `Invoke-Pester -Path E:\WindowsDoctor\scripts\ResourceSafety.Tests.ps1 -FullName '*parses safety scripts*'`
  - `New-PortableIncrementalPatch.ps1`
  - `Test-DocumentationSync.ps1`

歷史狀態 `2026-05-09 performance-policy-default-low-resource-entry`：
- 使用者指定方向：本系統目標朝高效能、低消耗資源改進。
- 已新增：
  - `PERFORMANCE_POLICY.md`
  - `Start-WindowsDoctor-DevGui.cmd`
  - `Start-WindowsDoctor-DevGui-Silent.vbs`
- 已改預設入口：
  - `Start-WindowsDoctor.cmd`
  - `Start-WindowsDoctor-Silent.vbs`
- 新預設行為：
  - 只啟動 Broker。
  - 開啟 `docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html`。
  - 不啟動 Next dev GUI。
  - 不產生 PostCSS worker。
- Dev GUI 保留為明確開發入口：
  - `Start-WindowsDoctor-DevGui-Silent.vbs`
- 安全限制：未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 low-resource-broker-only-console`：
- 使用者要求無人值守完成下一步建議任務。
- 已完成低資源啟動模式，未執行 production build：
  - `docs\WINDOWSDOCTOR_LOW_RESOURCE_CONSOLE.html`
  - `Start-WindowsDoctor-LowResource.cmd`
  - `Start-WindowsDoctor-LowResource-Silent.vbs`
  - `scripts\Test-LowResourceStartup.ps1`
- 行為：
  - 只啟動 Broker。
  - 不啟動 Next dev GUI。
  - 不產生 PostCSS worker。
  - HTML console 直接呼叫 Broker API。
  - 可看 health、AI triage、work window、修復預覽工作、取消工作。
- 安全限制：未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 postcss-startup-grace-window`：
- 使用者要求無人值守完成建議任務：讓 dev 模式短暫允許 1 個 PostCSS worker，但限制持續秒數與 working set。
- 已更新：
  - `scripts\Watch-WDResourceSafety.ps1`
  - `scripts\Start-WindowsDoctor.ps1`
  - `Start-WindowsDoctor.cmd`
  - `Start-WindowsDoctor-Silent.vbs`
  - `OPERATIONS.md`
  - `TASK_HANDOFF.md`
- 新策略：
  - GUI startup watchdog 允許 `MaxPostCssWorkers=1`。
  - 最多允許 `45` 秒。
  - 超過即停止 GUI dev server 與 GUI listener。
  - 同時仍套用 memory、node count、total working set、single-process working set 預算。
- 安全限制：未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 local-ai-triage-assistant`：
- 使用者要求新增 AI 功能。
- 新增本機離線 AI triage：
  - `gui\broker\services\aiAssistant.js`
  - `gui\src\components\AiAssistantPanel.tsx`
- 新增 API：
  - `GET /api/ai/triage`
- 行為：
  - 綜合 local health、recent system events、KB rules、repair plan preview、resource safety。
  - 輸出 overall risk、finding count、safe batch count、ranked findings、next actions。
  - 不呼叫外部 AI。
  - 不執行修復。
  - repair execution 仍只能走 `RUN` gate 與 work window。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 repair-report-interruptible-work-window`：
- 使用者要求新增修復報告與即時工作視窗，顯示目前工作與資源消耗，並可中斷避免死機；完成後顯示已修復、無法修復與後續建議。
- 新增 Broker work queue：
  - `gui\broker\services\work.js`
- 新增 API：
  - `GET /api/work/status`
  - `POST /api/work/cancel`
  - `POST /api/work/repair-plan`
- 新增 GUI：
  - `gui\src\components\WorkStatusPanel.tsx`
- 行為：
  - 同一時間只允許一個 active work。
  - repair preview / RUN-gated repair execution 會進入 work window。
  - 工作期間記錄 resource snapshots。
  - GUI 顯示目前工作、步驟、free memory、Node count、total/max working set。
  - 可按「中斷」取消目前工作。
  - 完成後顯示 repaired、notRepaired、nextSteps。
  - `RUN` gate 仍保留，未提供 RUN 不執行修復。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 resource-control-budget-hardening`：
- 使用者要求研究最適合本系統的資源控制與程序啟動方式後改進。
- 結論：
  - 目前最適合採「PowerShell 軟預算 + watchdog 熔斷 + 啟動序列化」。
  - Windows Job Objects 可做硬限制，但需 Win32 API，對目前 portable PowerShell-first 架構風險較高，先不導入。
- 已加入：
  - `Test-ResourceSafety.ps1` 增加 working-set budget。
  - `Watch-WDResourceSafety.ps1` 監控 process count、total working set、single-process working set。
  - `Invoke-WDSequentialTaskQueue.ps1` 每項任務前後都套用同一組資源預算。
  - `Start-WindowsDoctor.ps1` 啟動 Broker/GUI 時設定 `NODE_OPTIONS=--max-old-space-size=384`。
  - Broker/GUI parent process 預設 `BelowNormal` priority。
- 預設預算：
  - `MaxWindowsDoctorNodeProcesses=8`
  - `MaxWindowsDoctorTotalWorkingSetMB=1200`
  - `MaxWindowsDoctorProcessWorkingSetMB=512`
  - `NodeMaxOldSpaceSizeMB=384`
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 resource-bounded-sequential-execution`：
- 使用者要求：系統執行時資源消耗要可控，程序必須一項完成後才跑下一項。
- 新增：
  - `E:\WindowsDoctor\scripts\Invoke-WDSequentialTaskQueue.ps1`
- 行為：
  - 一次只執行一個 named task。
  - 每項任務前後都跑 `Test-ResourceSafety.ps1`。
  - 預設 `MinFreeMemoryGB=4`。
  - 預設 `MaxWindowsDoctorNodeProcesses=8`。
  - 預設遇到第一個失敗立即停止。
  - 寫出 JSON report。
- 啟動流程也已改成序列化：
  - Broker 先啟動。
  - 等 port `3001` ready。
  - 中間延遲並重跑 resource safety。
  - 再啟動 GUI。
  - Broker/GUI parent process 預設 `BelowNormal` priority。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 windows-launcher-resource-watchdog`：
- 使用者回報：系統執行後仍可能消耗電腦資源到無法運作。
- 本輪修正：
  - 新增 `E:\WindowsDoctor\scripts\Watch-WDResourceSafety.ps1`
  - 新增 `E:\WindowsDoctor\scripts\Stop-WindowsDoctorServices.ps1`
  - `Start-WindowsDoctor.ps1` 啟動 GUI 後會啟動 hidden watchdog。
  - watchdog 預設監控 `600` 秒，每 `5` 秒檢查一次。
  - `MaxWindowsDoctorNodeProcesses` 預設從 `20` 降到 `8`。
  - 若 memory、PostCSS workers 或 WindowsDoctor node process 超限，會停止 GUI dev server 與 GUI port listener。
  - 根目錄 silent/cmd 啟動器已帶入 `-MaxGuiNodeProcesses 8 -ResourceWatchSeconds 900`。
  - stop launcher 改用 `Stop-WindowsDoctorServices.ps1`，會停 GUI dev workers 與 GUI/Broker listeners。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 task-handoff-archive-readiness`：
- 已新增非破壞性歸檔 readiness gate：
  - `E:\WindowsDoctor\scripts\Test-TaskHandoffArchiveReadiness.ps1`
- 腳本行為：
  - 計算 `TASK_HANDOFF.md` 行數。
  - 檢查最新日期狀態是否仍在檔案最上方。
  - 未達 `3500` 行時回報 `WAITING`。
  - 達門檻時回報 `ACTION_REQUIRED` 並提出候選歸檔路徑。
  - 不搬移、不改寫、不刪除交接歷史。
- 已更新測試與文件入口：
  - `scripts\ResourceSafety.Tests.ps1`
  - `scripts\Test-DocumentationSync.ps1`
  - `scripts\Sync-GuiReadyUsbPatch.ps1`
  - `OPERATIONS.md`
  - `INDEX.md`
  - `DOCUMENTATION_ARCHITECTURE.md`
  - `DOCS_ARCHITECTURE_AUDIT.md`
  - `TASK_HANDOFF.md`
- USB package 尚未在本步重新同步或重建 zip；`Sync-GuiReadyUsbPatch.ps1` 已補入新腳本與文件架構檔，下一次 validated USB sync 會帶入。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 documentation-architecture-audit`：
- 已新增文件治理與稽核紀錄：
  - `E:\WindowsDoctor\DOCUMENTATION_ARCHITECTURE.md`
  - `E:\WindowsDoctor\DOCS_ARCHITECTURE_AUDIT.md`
- 已更新：
  - `E:\WindowsDoctor\INDEX.md`
  - `E:\WindowsDoctor\SECURITY_POLICY.md`
  - `E:\WindowsDoctor\TASK_HANDOFF.md`
- 稽核結論：
  - Safety: `PASS`
  - Efficiency: `PASS after update`
  - Sustainability: `PASS with watch item`
- 根目錄與 `docs` Markdown/HTML 相對連結檢查：`0` broken links。
- 驗證：
  - `E:\WindowsDoctor\logs\documentation-sync.docs-architecture-20260509.json`: `PASS`
  - `E:\WindowsDoctor\logs\system-baseline.docs-architecture-20260509.json`: `PASS`
- Watch item: `TASK_HANDOFF.md` 接近 3000 行，超過 `3500` 行後應做期間歸檔。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 visual-manual`：
- 已新增圖解操作說明書：
  - `E:\WindowsDoctor\docs\WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html`
- 內容包含：
  - USB GUI-ready 啟動圖
  - WinPE 離線救援圖
  - one-click repair RUN gate 圖
  - real-data intake/import 圖
  - 應用場景範例
  - 常用驗收命令
- `Sync-GuiReadyUsbPatch.ps1` 已支援同步此手冊到 USB package。
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 real-data-intake`：
- 已新增 `scripts\Test-RealDataImportReadiness.ps1`。
- 已建立 intake directories:
  - `E:\WindowsDoctor\incoming\notebooklm`
  - `E:\WindowsDoctor\incoming\external-diagnostics`
  - `E:\WindowsDoctor\incoming\official-diagnostics`
- Current readiness:
  - `Status=WAITING`
  - `ReadyCount=0`
  - `FailedCount=0`
  - `CandidateCount=0`
  - report: `E:\WindowsDoctor\logs\real-data-import-readiness.latest.json`
- 此 gate 只驗證待匯入資料，不匯入、不修復、不重建 KB。
- Targeted Pester: `PASS`, `3 passed`
- 已同步到 USB package 並重建 patched zip。
- USB self-acceptance after readiness sync: `PASS`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper-usb-self-20260509-realdata-final.json`
- USB intake readiness:
  - `Status=WAITING`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\real-data-import-readiness-usb.json`

---

歷史狀態 `2026-05-09 one-click-guidance`：
- One-click repair operator guidance 已補：
  - `Invoke-RecommendedRepairPlan.ps1` now outputs `OperatorGuidance`.
  - GUI `OneClickRepairPanel` shows evidence scoring, dry-run impact, RUN gate, and rollback guidance.
  - Types and broker tests updated.
- Validation:
  - broker JS syntax: `PASS`
  - `npm run test:broker --prefix E:\WindowsDoctor\gui`: `PASS`
  - `npm run lint --prefix E:\WindowsDoctor\gui`: `PASS`
  - targeted Pester for recommended repair: `PASS`, `4 passed`
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 docs-final`：
- Final USB package after script and documentation sync:
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
  - patched zip: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
  - USB copy: `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
- USB package self-acceptance:
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper-usb-self-20260509-docs-final.json`
  - Summary: `PASS`
  - zip manifest: `PASS`, `missing=0`, `sizeMismatch=0`, `hashMismatch=0`
  - release validation: `PASS`
  - GUI-ready preflight: `PASS`
  - selector: `PASS`
- Final zip byte size is not hardcoded because syncing this prompt changes the archive size; use `Invoke-PortableUsbAcceptance.ps1` as source of truth.
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

---

歷史狀態 `2026-05-09 final`：
- 已完成 selector zip warning、optional hash manifest、acceptance summary、publish resume 測試覆蓋。
- `New-UsbPackageSelectorPage.ps1` now reports zip inventory and per-package `ZipStatus`, `ZipIssue`, `ZipPath`, `RelatedZipCount`.
- `Test-PortableUsbZipManifest.ps1` supports optional `-Hash`; default remains size-only for large GUI-ready packages.
- `Invoke-PortableUsbAcceptance.ps1` supports `-SummaryOnly`, `-HashManifest`, and `-MinFreeMemoryGB`, and emits a `Summary` object.
- Targeted Pester：`PASS`, `6 passed`, `0 failed`.
- USB package updated:
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
  - sync report: `E:\WindowsDoctor\logs\acceptance-oneclickv3\sync-gui-ready-usb-patch-20260509-final.json`
  - file count: `22953`
  - bytes: `542200856`
- Patched zip rebuilt before docs-final sync:
  - `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
  - superseded by docs-final archive above
- Final USB self-acceptance: `PASS`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper-usb-self-20260509-final.json`
  - Summary: `PASS`
  - zip manifest: `PASS`, `zipFiles=22953`, `missing=0`, `sizeMismatch=0`, `hashMismatch=0`
  - release validation: `PASS`
  - GUI-ready preflight: `PASS`
  - selector: `PASS`, `packages=5`, `winPeBootWim=True`
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

下一輪建議：
1. 將 one-click repair operator text 做最後整理：evidence scoring、dry-run impact、rollback guidance。
2. 若提供真實 NotebookLM JSON 或 SetupDiag/DISM/SFC/Get Help 輸出，執行 validate/import/normalized KB rebuild。
3. 若要新發佈正式 USB，先跑 `Invoke-PortableUsbAcceptance.ps1`，再用 `Publish-PortableUsbPackage.ps1 -ResumeExistingTarget` 處理中斷恢復。

---

歷史狀態 `2026-05-09`：
- 已新增並驗收 USB publish/acceptance hardening。
- 新增：
  - `scripts\Test-PortableUsbZipManifest.ps1`
  - `scripts\Invoke-PortableUsbAcceptance.ps1`
- 已更新：
  - `scripts\Publish-PortableUsbPackage.ps1`
  - `scripts\Test-PortableUsbReleaseValidation.ps1`
  - `scripts\Sync-GuiReadyUsbPatch.ps1`
  - `scripts\ResourceSafety.Tests.ps1`
- `Publish-PortableUsbPackage.ps1` 現在有 checkpoint-style phase report、`-ResumeExistingTarget`、post-expand zip manifest compare，且 USB zip cleanup 只在 validation PASS 後執行。
- `Test-PortableUsbReleaseValidation.ps1` 現在可用 `-ZipPath` 執行 `zip-manifest` 步驟。
- `Invoke-PortableUsbAcceptance.ps1` 會統一執行 resource safety、zip manifest compare、release validation、GUI-ready preflight、USB selector 與報告彙總。
- Targeted Pester：`PASS`，`5 passed`，`0 failed`。
- 已同步到 USB package：
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`
  - sync report: `E:\WindowsDoctor\logs\acceptance-oneclickv3\sync-gui-ready-usb-patch-20260509.json`
- 已建立 patched zip：
  - `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
  - `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-Patched20260509.zip`
  - size: `164711925`
- USB 自驗收：`PASS`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\acceptance-wrapper-usb-self-20260509.json`
  - zip manifest: `PASS`, `zipFiles=22953`, `missing=0`, `sizeMismatch=0`
  - release validation: `PASS`
  - GUI-ready preflight: `PASS`
  - selector: `PASS`, `packages=5`, `winPeBootWim=True`
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。

下一輪建議：
1. selector 加入 stale/unmatched zip warning。
2. `Test-PortableUsbZipManifest.ps1` 增加可選 hash compare，小包可用 hash，大包預設 size-only。
3. one-click repair 繼續補 evidence scoring、dry-run 說明、rollback guidance，仍維持 `RUN` gate。

---

請在 `E:\WindowsDoctor` 繼續 WindowsDoctor 系統開發工作。

全程使用繁體中文。模式：無人值守。資源安全優先。

每次工作前先執行：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```

限制：
- 不要直接啟動 GUI/Broker。
- 不要執行 production build。
- 不要執行修復或破壞性維護，除非使用者明確提供 `RUN`。

最新驗收狀態：
- `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3` 已完成重新展開與驗收。
- USB release validation: `PASS`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\release-validation.json`
  - payload checks: `22`
  - runtime self-test checks: `22`
  - recommended repair preview: `PASS`, `executed=False`, `safeScripts=0`, `recommended=5`
- GUI-ready target preflight: `PASS`
  - `E:\WindowsDoctor\logs\acceptance-oneclickv3\gui-ready-preflight.json`
  - memory/cache/ports `3000/3001`/node-runtime/PowerShell readiness passed
- USB selector/status page: `PASS`
  - `G:\START_HERE.html`
  - package count: `5`
  - WinPE `G:\sources\boot.wim`: present
- 安全限制已遵守：未啟動 GUI/Broker、未跑 production build、未執行修復。
- 注意：原 `Publish-PortableUsbPackage.ps1` 逾時，曾留下半展開 USB 目標；已停止殘留 publish process，並用本機 zip 重新 `Expand-Archive -Force` 補齊後驗收 PASS。
- 注意：`G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3.zip` 仍留在 USB，因原 publish cleanup phase 未完成。

下一輪建議任務：
1. 將 USB publish 流程改為 checkpoint/resumable：payload、zip、copy、expand、validate、selector、cleanup 分段寫報告。
2. 新增 post-expand manifest compare：zip entries 對 USB files，立即偵測 partial expand。
3. 新增 acceptance wrapper：資源安全、release validation、GUI-ready preflight、selector、報告彙總一鍵執行。
4. 設計 timeout-safe USB zip cleanup：只有驗收 PASS 或明確要求時移除 generated USB zip。
5. 持續完善 one-click repair：維持 `RUN` gate，補 evidence scoring、dry-run 說明、rollback guidance。
6. 真實資料匯入仍採受控模式：使用者提供 NotebookLM JSON 或 SetupDiag/DISM/SFC/Get Help 輸出，或只取 approved Microsoft official references；不要任意廣泛爬取第三方 Windows 資料庫。
7. full Pester 只在資源充足時跑；平時優先 targeted Pester + low-risk baseline。

---

請在 E:\WindowsDoctor 繼續 WindowsDoctor 系統開發工作。

請先讀取並遵守：
- AGENTS.md 指示；若磁碟上沒有 AGENTS.md，使用本提示詞中的限制作為有效規範
- TASK_HANDOFF.md
- OPERATIONS.md
- SYSTEM_ERROR_HISTORY.md
- COMMON_WINDOWS_ERRORS.md

重要限制：
- 全程使用繁體中文回覆。
- 資源安全優先。
- 不要直接啟動 GUI/Broker。
- 不要執行 production build。
- 每次工作前先執行：
  powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
- 若 PostCSS workers 不為 0、WindowsDoctor node processes 不為 0、或可用記憶體不足，先停止並處理資源問題。

目前建議的低風險續作方向：
1. 繼續補 WinPE/offline repair flow 的可測試腳本與文件。
2. 優先使用 `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild` 驗證。
3. 不要啟動 GUI/Broker，除非使用者明確要求。
4. 不要跑 production build，除非使用者明確要求。

最新資源安全快照：
```json
{
    "Status":  "FAIL",
    "Root":  "E:\\WindowsDoctor",
    "FreeMemoryGB":  3.47,
    "PostCssWorkerCount":  0,
    "WindowsDoctorNodeProcessCount":  0,
    "Checks":  [
                   {
                       "Name":  "free-memory",
                       "Status":  "FAIL",
                       "Detail":  "Free=3.47GB Required=4GB"
                   },
                   {
                       "Name":  "postcss-workers",
                       "Status":  "PASS",
                       "Detail":  "Count=0 Max=0"
                   },
                   {
                       "Name":  "windowsdoctor-node-processes",
                       "Status":  "PASS",
                       "Detail":  "Count=0 Max=20"
                   }
               ]
}
```

TASK_HANDOFF.md 末段：
```text
- No destructive maintenance was executed.

## 2026-04-30 Normalized Repair Knowledge Database v2
- User requested expanding repair database content from known online sources and building it in a structured, normalized way.
- Important scope note:
  - "all known online data" is not a finite or verifiable target.
  - Current implementation creates the normalized database architecture and seeds it with verified Microsoft public official references plus the existing reviewed local KB.
- Added source seed:
  - `offline_database\known-windows-repair-sources.json`
  - currently includes `6` Microsoft public official source records:
    - Microsoft Learn: Repair a Windows Image
    - Microsoft Learn: netsh winsock
    - Microsoft Support: Troubleshoot problems updating Windows
    - Microsoft Support: Get help with Windows upgrade and installation errors
    - Microsoft Learn: Data corruption and disk errors troubleshooting
    - Microsoft Learn: Application or service crashing behavior troubleshooting
- Added normalized export:
  - `scripts\Export-NormalizedKBDatabase.ps1`
  - output: `offline_database\windowsdoctor-kb-normalized.json`
  - schema: `schemaVersion=2`
  - normalized fields include:
    - `component`
    - `symptoms`
    - `errorCodes`
    - `eventIds`
    - `triggerTerms`
    - `recommendedActions`
    - `action.script`
    - `action.actionType`
    - `action.repairAllowed`
    - `action.riskLevel`
    - `provenance.sourceType`
    - `provenance.sourceIds`
- Added normalized validation:
  - `scripts\Test-NormalizedKBDatabase.ps1`
  - validates schema, required fields, unique ids, action types, risk levels, Microsoft official URL scope, source-reference integrity, public reference count, and component coverage.
- Integrated normalized DB gates into:
  - `Test-SystemBaseline.ps1`
  - `Test-PortableUsbReadiness.ps1`
  - `Test-PortableRuntimeSelfTest.ps1`
  - `Test-PortableUsbPayload.ps1`
  - `ResourceSafety.Tests.ps1`
  - `Test-DocumentationSync.ps1`
  - `OPERATIONS.md`
- Current normalized DB validation:
  - `Export-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-export.latest.json -Json`: `PASS`
  - `Test-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.latest.json -Json`: `PASS`
  - `TotalRecords=71`
  - `LocalRecords=63`
  - `PublicReferenceRecords=8`
  - `SourceCount=6`
  - `component coverage=7`
- Validation:
  - `Test-PortableRuntimeSelfTest.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-self-test.latest.json -Json`: `PASS`, `17` checks
  - `Test-PortableUsbReadiness.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-readiness.latest.json -Json`: `PASS`, `14` steps
  - `Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json`: `PASS`
  - `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1`: `PASS`, `65` tests
- Final mature portable output with normalized KB v2:
  - folder: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260430-NormalizedKBv2-Final`
  - zip: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260430-NormalizedKBv2-Final.zip`
  - `FileCount=203`
  - `Bytes=1060881`
  - `ZipBytes=332705`
  - `SkipNodeModules=true`
- Final release validation:
  - `Test-PortableUsbReleaseValidation.ps1 -PackageRoot E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260430-NormalizedKBv2-Final -ReportPath E:\WindowsDoctor\logs\portable-usb-release-validation-normalizedkbv2-final.latest.json -Json`: `PASS`
  - payload validation: `PASS`, `16` checks
  - runtime self-test: `PASS`, `17` checks
  - recommended repair preview: `PASS`, `Mode=preview`, `Executed=false`, `safeScripts=0`, `recommended=5`
- Final low-risk baseline:
  - `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json`: `PASS`, `15` steps
- No USB write was performed unless `F:\` returns.
- No repair execution was performed during validation.
- No GUI/Broker was started.
- No production build was executed.
- No destructive maintenance was executed.

## 2026-05-08 Architecture Fit Check
- User asked whether the current system still fits Windows repair needs and whether architecture changes are required.
- Resource gate:
  - `Test-ResourceSafety.ps1 -Json`: `PASS`
  - `FreeMemoryGB=4.51`
  - `PostCssWorkerCount=0`
  - `WindowsDoctorNodeProcessCount=0`
- Low-risk baseline, without GUI/Broker startup and without production build:
  - `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -SkipPester -SkipLint -ReportPath E:\WindowsDoctor\logs\system-baseline.architecture-check.latest.json -Json`: `PASS`
  - `13` steps checked in the report output, including resource safety, KB export/validation, documentation sync, WinPE offline flow, portable USB readiness, GUI smoke offline, WinPE check, and broker services.
- Repair database validation:
  - `Test-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-validate.architecture-check.json -Json`: `PASS`
  - `TotalRules=64`
  - `reviewed=63`
  - `learned=1`
  - `autoRepair=20`
  - `guided/manual=44`
- Normalized KB validation:
  - `Test-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.architecture-check.json -Json`: `PASS`
  - `TotalRecords=73`
  - `PublicReferenceRecords=8`
  - `NotebookLMRecords=1`
  - `SourceCount=7`
- WinPE offline repair path:
  - `Test-WinPEOfflineFlow.ps1 -ReportPath E:\WindowsDoctor\logs\winpe-offline-flow.architecture-check.json -Json`: `PASS`
  - confirms offline KB search, maintenance search, allowlist preview, WinPE menu preview, startnet menu/broker modes, and check-only mode.
- Documentation sync:
  - `Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.architecture-check.json -Json`: `PASS`
- USB package verification:
  - attempted `Test-PortableUsbReleaseValidation.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260503`
  - initial architecture-check session was blocked because `G:` was not visible
  - user later brought `G:` online
  - `Get-PSDrive -PSProvider FileSystem` confirmed `G:\`, `Free=28565094400`, `Used=2458075136`
  - first validation failed only on `no-next-build-cache` because `G:\WindowsDoctor-PortableUSB-GUI-READY-20260503\WindowsDoctor\gui\.next` existed
  - removed the portable package `.next` cache after verifying the resolved path was under `G:\WindowsDoctor-PortableUSB-GUI-READY-20260503\WindowsDoctor\gui`
  - re-run `Test-PortableUsbReleaseValidation.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260503 -ReportPath E:\WindowsDoctor\logs\portable-usb-release-validation-gui-ready-g-drive.latest.json -Json`: `PASS`
  - payload validation: `PASS`, `16` checks
  - runtime self-test: `PASS`, `17` checks
  - recommended repair preview: `PASS`, `Executed=false`, `safeScripts=0`, `recommended=5`
- Architecture conclusion:
  - current architecture is adequate for current repair requirements
  - no major architecture rewrite is required before continued use
  - normal Windows GUI-ready mode, WinPE offline mode, normalized KB, NotebookLM source-pack import, unknown-error learned KB capture, allowlist-only repair gating, and report-based validation are already covered
- Recommended hardening only, not blockers:
  - add target-PC preflight to the GUI-ready launcher for memory, cache write permission, port availability, PowerShell execution policy, and bundled Node runtime integrity
  - add a cache self-verify/repair step before launching from `%LOCALAPPDATA%\WindowsDoctorPortable\GUIREADY`
  - add a USB package selector/status page when multiple release folders exist on the same USB
  - keep learned and NotebookLM records as non-auto-repair until reviewed and explicitly allowlisted
  - add a simple stop/cleanup launcher for GUI-ready sessions
- No repair execution was performed during validation.
- No GUI/Broker was started.
- No production build was executed.
- No destructive maintenance was executed.

## 2026-05-03 G: Integrated USB: Normal Windows + WinPE
- User asked whether the two functions can be integrated into one USB.
- `G:\` now contains both:
  - WinPE boot media files, including `G:\sources\boot.wim`
  - normal Windows portable package: `G:\WindowsDoctor-NormalWindows-GUI-20260503`
- Added USB landing page:
  - source: `E:\WindowsDoctor\docs\START_HERE_USB.html`
  - USB copy: `G:\START_HERE.html`
- Normal Windows entrypoint:
  - `G:\WindowsDoctor-NormalWindows-GUI-20260503\Start-WindowsDoctor-Portable.cmd`
- Publish command used:
  - `powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Publish-PortableUsbPackage.ps1 -USBPath G:\ -PackageName WindowsDoctor-NormalWindows-GUI-20260503 -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-normal-gui-g.latest.json -Json`
- Publish result:
  - status: `PASS`
  - target: `G:\WindowsDoctor-NormalWindows-GUI-20260503`
  - target files: `210`
  - target bytes: `1135064`
  - zip-copy-expand: `true`
  - `IncludeNodeModules=false`
- Post-publish validation:
  - `Test-PortableUsbReleaseValidation.ps1 -PackageRoot G:\WindowsDoctor-NormalWindows-GUI-20260503 -ReportPath E:\WindowsDoctor\logs\portable-usb-release-validation-normal-g.latest.json -Json`: `PASS`
  - payload validation: `PASS`, `16` checks
  - runtime self-test: `PASS`, `17` checks
  - recommended repair preview: `PASS`, `Executed=false`, `safeScripts=0`, `recommended=4`
- WinPE offline validation:
  - `Test-WinPEOfflineFlow.ps1 -ReportPath E:\WindowsDoctor\logs\winpe-offline-flow.latest.json -Json`: `PASS`, `13` steps
- Final resource safety:
  - `Test-ResourceSafety.ps1 -Json`: `PASS`
  - `PostCssWorkerCount=0`
  - `WindowsDoctorNodeProcessCount=0`
- Attempted final low-risk baseline:
  - `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json`
  - result: timed out after approximately `5` minutes before returning a new result
  - stale prior report at `E:\WindowsDoctor\logs\system-baseline.latest.json` still showed an older `PASS`, but it was not counted as a fresh validation
  - leftover PowerShell validation child processes were stopped
  - resource safety after cleanup: `PASS`, `PostCssWorkerCount=0`, `WindowsDoctorNodeProcessCount=0`
- No GUI/Broker was started.
- No production build was executed.
- No repair execution or destructive maintenance was performed.

## 2026-05-01 NotebookLM Portable USB Published To F
- Resource safety before work:
  - `Test-ResourceSafety.ps1 -Json`: `PASS`
  - `FreeMemoryGB=6.47`
  - `PostCssWorkerCount=0`
  - `WindowsDoctorNodeProcessCount=0`
- `F:\` was present during this continuation, so the latest NotebookLM import portable package was published by zip-copy-expand flow.
- USB package:
  - `F:\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final-USB`
  - `TargetFileCount=205`
  - `TargetBytes=1078148`
  - `IncludeNodeModules=false`
  - `CopiedByZip=true`
  - `ExpandedOnUsb=true`
- Local source payload and zip generated for this USB publish:
  - folder: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final-USB`
  - zip: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final-USB.zip`
  - `ZipBytes=339853`
- Publish report:
  - `E:\WindowsDoctor\logs\portable-usb-publish-notebooklmimport-final-usb.latest.json`
- Post-expand release validation:
  - status: `PASS`
  - validation report: `E:\WindowsDoctor\logs\portable-usb-publish-validate.json`
  - payload validation report: `E:\WindowsDoctor\logs\portable-usb-release-payload.json`
  - runtime self-test report: `E:\WindowsDoctor\logs\portable-usb-release-runtime-self-test.json`
  - recommended repair preview report: `E:\WindowsDoctor\logs\portable-usb-release-recommended-repair.json`
- Final low-risk baseline after publish:
  - `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json`: `PASS`, `15` steps
- No repair execution was performed during validation.
- No GUI/Broker was started.
- No production build was executed.
- No destructive maintenance was executed.

## 2026-05-01 NotebookLM Source Pack Import
- User asked whether NotebookLM can be added as a database source.
- Current NotebookLM integration decision:
  - use exported NotebookLM notes/sources as an interchange JSON source pack
  - do not depend on an unofficial live NotebookLM API
  - keep runtime portable/offline
- Added:
  - `scripts\Import-NotebookLMSourcePack.ps1`
- NotebookLM import behavior:
  - input: exported JSON source pack from NotebookLM-derived notes/sources
  - output: `offline_database\notebooklm-repair-sources.json`
  - validates:
    - source IDs
    - source URLs
    - record IDs
    - action types
    - risk levels
    - repair script naming
    - source-reference integrity
  - normalizes record IDs with `NBLM-` prefix
  - normalizes source IDs with `NBLM-SRC-` prefix
- Integrated into normalized KB:
  - `Export-NormalizedKBDatabase.ps1` now accepts `-NotebookLMPackPath`
  - default path: `offline_database\notebooklm-repair-sources.json`
  - NotebookLM records are emitted with `provenance.sourceType=notebooklm_export`
  - `Test-NormalizedKBDatabase.ps1` validates notebooklm source URL shape
- Documentation:
  - `OPERATIONS.md` includes import command:
    - `Import-NotebookLMSourcePack.ps1 -InputPath <NOTEBOOKLM_SOURCE_PACK_JSON> -ReportPath E:\WindowsDoctor\logs\notebooklm-import.latest.json -Json`
- Validation:
  - `Export-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-export.latest.json -Json`: `PASS`
  - `Test-NormalizedKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.latest.json -Json`: `PASS`
  - `Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json`: `PASS`
  - `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1`: `PASS`
- Current normalized DB has no real NotebookLM imported records yet:
  - `NotebookLMRecords=0`
  - this is expected until a NotebookLM source pack JSON is provided/imported.
- Final mature portable output with NotebookLM import support:
  - folder: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final`
  - zip: `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final.zip`
  - `FileCount=204`
  - `Bytes=1076468`
  - `ZipBytes=338037`
  - `SkipNodeModules=true`
- Final release validation:
  - `Test-PortableUsbReleaseValidation.ps1 -PackageRoot E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260501-NotebookLMImport-Final -ReportPath E:\WindowsDoctor\logs\portable-usb-release-validation-notebooklmimport-final.latest.json -Json`: `PASS`
  - payload validation: `PASS`, `16` checks
  - runtime self-test: `PASS`, `17` checks
  - recommended repair preview: `PASS`, `Mode=preview`, `Executed=false`, `safeScripts=0`, `recommended=5`
- Final low-risk baseline:
  - `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json`: `PASS`
- No USB write was performed unless `F:\` returns.
- No repair execution was performed during validation.
- No GUI/Broker was started.
- No production build was executed.
- No destructive maintenance was executed.
```

OPERATIONS.md 末段：
```text
- `-MinIdleMinutes` defaults to `30`.
- `-CleanDisk` removes temp files older than `24` hours and clears Recycle Bin only in execute mode.
- `-SystemMaintenance` runs `DISM /ScanHealth`, `sfc /verifyonly`, and `chkdsk C: /scan` only in execute mode.
- `Repair-SystemMaintenance.bat` is an allowlisted preview entry; direct execution of destructive maintenance still requires `Invoke-WindowsMaintenance.ps1 -Execute -ConfirmToken RUN`.

Execute an allowlisted repair script only after explicit confirmation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-AllowedRepair.ps1 -ScriptName Repair-NetworkStack.bat -Execute -ConfirmToken RUN
```

WinPE menu wrapper for repair preview:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -Json
```

WinPE menu wrapper for repair list report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -ListAllowedRepairs -ReportPath E:\WindowsDoctor\logs\winpe-menu-repairs.latest.json -Json
```

WinPE menu wrapper for repair preview report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -ReportPath E:\WindowsDoctor\logs\winpe-menu-preview.latest.json -Json
```

WinPE offline KB contents:
- `knowledge_base\reviewed`
- `knowledge_base\learned`
- `offline_database\windowsdoctor-kb.json`
- `scripts\repair-allowlist.json`
- allowlisted `scripts\Repair-*.bat`

WinPE Broker offline DB mode:
- `Build-WinPEMedia.ps1` sets `WD_USE_OFFLINE_DB=1`.
- Default `StartupMode` is `Menu`, which launches `scripts\Start-WinPEOfflineMenu.ps1` without GUI/Broker.
- Use `-StartupMode Broker` only when WinPE should start `gui\broker.js`.
- Broker reads `offline_database\windowsdoctor-kb.json` instead of scanning Markdown at runtime.
- Local default remains Markdown mode unless `WD_USE_OFFLINE_DB=1` is set.

Low-risk GUI smoke. This does not start services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline
```

Low-risk GUI smoke report. This does not start services:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline -ReportPath E:\WindowsDoctor\logs\gui-smoke-offline.latest.json -Json
```

## 4. Individual Checks
```powershell
npm run lint --prefix E:\WindowsDoctor\gui
npm run build --prefix E:\WindowsDoctor\gui
npm run test:broker --prefix E:\WindowsDoctor\gui
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path E:\WindowsDoctor\core\WindowsDoctor.Tests.ps1"
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-BrokerSmoke.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-GuiSmoke.ps1 -AllowOffline
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-VersionPolicy.ps1
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly
```

Version policy JSON report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-VersionPolicy.ps1 -ReportPath E:\WindowsDoctor\logs\version-policy.latest.json -Json
```

## 5. Ports
- GUI: `http://localhost:3000`
- Broker: `http://localhost:3001`

## 6. WinPE Preflight
Run before creating ISO or USB media:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly
```

Machine-readable preflight report:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Build-WinPEMedia.ps1 -CheckOnly -ReportPath E:\WindowsDoctor\logs\winpe-media-checkonly.latest.json -Json
```
```

SYSTEM_ERROR_HISTORY.md 末段：
```text
## [ERR-20260430-03] Portable Scan Output Needed Readable Recommendations
### Symptom
The USB scan JSON included KB recommendation data, but the interactive menu path still risked showing complex PowerShell objects in a table.
### Cause
`Test-SystemErrorScan.ps1` used default table formatting for non-JSON output after adding nested `KbMatches`.
### Fix
Changed non-JSON scan output to a readable Traditional Chinese diagnostic list. Each finding now shows status, detail, rule hint, KB recommendation count, matched rule IDs, action type, and repair script.
### Verification
Direct USB execution of `F:\WindowsDoctor-PortableUSB-MATURE-20260430-ScanKB-UI\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -ScanSystem` displayed Traditional Chinese labels and KB recommendations. USB payload validation passed with `13` checks and USB runtime self-test passed with `11` checks.

## [ERR-20260430-04] Portable Runtime Needed Status Summary
### Symptom
The portable USB had self-test and scan functions, but users had no quick way to see the package version, KB rule counts, allowlisted repair count, and runtime readiness from one menu entry.
### Cause
Runtime validation existed as test scripts, while a concise operator-facing status summary did not exist.
### Fix
Added `Get-PortableRuntimeStatus.ps1`, added `Start-WinPEOfflineMenu.ps1 -StatusSummary`, and exposed it as menu option `10`. Runtime self-test now validates the status summary path.
### Verification
`Get-PortableRuntimeStatus.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-status.latest.json -Json` passed with `Version=0.1.0`, `TotalRules=63`, and `AllowlistRepairs=6`. `Start-WinPEOfflineMenu.ps1 -StatusSummary -ReportPath E:\WindowsDoctor\logs\winpe-menu-status.latest.json -Json` passed. `Test-PortableRuntimeSelfTest.ps1` passed with `13` checks, Pester passed `59` tests, and the low-risk baseline passed with `13` steps.

## [ERR-20260430-05] Field Test Hit Misspelled System Scan File Name
### Symptom
Real testing reported: `the argument 'e:\windowsdoctor\scripts\test-systemerroescan.ps1' to the -file parameter does not exist.`
### Cause
The correct script is `Test-SystemErrorScan.ps1`. The reported path uses a misspelled `ErroeScan` variant. Source search did not find current references to the misspelled name, so this likely came from an old package, manual command, or stale shortcut path.
### Fix
Added compatibility wrapper scripts `Test-SystemErroeScan.ps1` and `Test-SystemErrorsScan.ps1`. Both forward to `Test-SystemErrorScan.ps1` with the same key parameters, so common typo/stale entrypoints no longer fail with missing file.
### Verification
Both compatibility wrappers passed with `KbRuleCount=63`. Pester passed `60` tests, and the low-risk baseline passed with `13` steps.

## [ERR-20260430-06] Users Needed One-Click Repair Guidance
### Symptom
The portable menu had scan, search, preview, and explicit repair execution entries, but users still had to decide which repair script matched scan results.
### Cause
The scan-to-KB match layer exposed recommendations, but there was no operator-facing plan that grouped recommended allowlisted repairs into safe batch versus manual review.
### Fix
Added `Invoke-RecommendedRepairPlan.ps1` and menu option `11`. The flow previews recommended repairs by default, executes only with `RUN`, and excludes high-risk BCD/boot, system integrity, and maintenance cleanup from the default one-click batch.
### Verification
The recommended repair preview passed with `RecommendedRepairCount=5`, `SafeBatchScriptCount=2`, and `Executed=false`. Pester passed `63` tests, and the low-risk baseline passed with `13` steps. No repair execution was performed during validation.

## [ERR-20260430-07] USB Publish Needed Full Post-Expand Release Validation
### Symptom
The USB publish flow validated payload structure after zip-copy-expand, but the required post-publish operator checks were still separate commands: payload validation, portable runtime self-test, and one-click repair preview.
### Cause
`Publish-PortableUsbPackage.ps1` called only `Test-PortableUsbPayload.ps1` after expanding the package. Runtime self-test and recommended repair preview were verified elsewhere, so the USB-return publish path could miss one of the required checks.
### Fix
Added `Test-PortableUsbReleaseValidation.ps1` to validate an expanded portable package root. It runs payload validation, runtime self-test from the package's own `WindowsDoctor` root, and recommended repair preview without executing repairs. `Publish-PortableUsbPackage.ps1` now calls this release validation gate after zip-copy-expand.
### Verification
The new gate passed against `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260430-OneClick`: payload validation `13` checks, runtime self-test `15` checks, and recommended repair preview `Mode=preview`, `Executed=false`. Pester passed `64` tests.

## [ERR-20260430-08] PASS-Only Matches Should Not Become Auto Repair Batch Items
### Symptom
The one-click repair preview could recommend allowlisted repairs even when the current diagnostic findings were all `PASS`. That made KB matches useful for context, but too aggressive for an unattended USB repair workflow.
### Cause
`Invoke-RecommendedRepairPlan.ps1` grouped every allowlisted KB match as a recommendation regardless of whether the source finding represented an active failure.
### Fix
Upgraded the plan to `RepairPlanVersion=2`. Each item now has confidence, risk level, priority, active evidence count, and recommendation state. PASS-only matches are emitted as observations and cannot enter the default safe batch. The default batch is limited to low-risk `Repair-NetworkStack.bat` and `Repair-Services.bat`.
### Verification
`Invoke-RecommendedRepairPlan.ps1` passed with `ActiveRecommendedRepairCount=0`, `ObservationCount=5`, `SafeBatchScriptCount=0`, and `Executed=false` on the healthy local scan. Portable runtime self-test passed with `15` checks, Pester passed `64` tests, and the `WindowsDoctor-PortableUSB-MATURE-20260430-RepairPlanV2` release validation passed.

## [ERR-20260430-09] Repair Knowledge Needed Normalized Provenance
### Symptom
The offline KB was useful for local scan matching, but the data model was optimized for Markdown export and not for large-scale source expansion, provenance tracking, event ID matching, or component-level analytics.
### Cause
`windowsdoctor-kb.json` used a compact rule shape with title, triggers, script, action type, and source file. It did not preserve structured source references, normalized symptoms, error codes, event IDs, recommended actions, or risk metadata in a database-wide schema.
### Fix
Added `known-windows-repair-sources.json`, `Export-NormalizedKBDatabase.ps1`, and `Test-NormalizedKBDatabase.ps1`. The normalized database uses `schemaVersion=2` and combines the existing `63` reviewed local KB records with `8` Microsoft official public reference records. Each record includes component, symptoms, error codes, event IDs, trigger terms, recommended actions, action risk, and provenance.
### Verification
Normalized export and validation passed with `TotalRecords=71`, `PublicReferenceRecords=8`, `SourceCount=6`, and component coverage across `7` components. Portable runtime self-test passed with `17` checks, portable USB readiness passed with `14` steps, documentation sync passed, and Pester passed `65` tests.

## [ERR-20260501-01] NotebookLM Needed Portable Import Instead Of Live API Dependency
### Symptom
NotebookLM could be useful as a repair database curation source, but relying on a live NotebookLM integration would reduce offline portability and risk depending on non-public API behavior.
### Cause
The portable USB architecture needs deterministic offline inputs. NotebookLM supports source/notes workflows and exports, while a broadly available public consumer API is not a stable project dependency.
### Fix
Added `Import-NotebookLMSourcePack.ps1`, which imports a NotebookLM-derived JSON source pack into `offline_database\notebooklm-repair-sources.json`. `Export-NormalizedKBDatabase.ps1` now merges this pack into schema v2 records as `provenance.sourceType=notebooklm_export`.
### Verification
Normalized export and validation passed after the integration. Documentation sync passed. Pester passed with a sample NotebookLM import that produced one normalized `notebooklm_export` record.
```
請在 E:\WindowsDoctor 繼續 WindowsDoctor 系統開發工作。

全程使用繁體中文。模式：無人值守。資源安全優先。
不要直接啟動 GUI/Broker。不要執行 production build。
不要執行修復或破壞性維護，除非我明確提供 RUN。

每次工作前先執行：
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```

請先讀取並遵守：
- AGENTS.md；若磁碟沒有 AGENTS.md，沿用本提示詞限制
- TASK_HANDOFF.md
- OPERATIONS.md
- SYSTEM_ERROR_HISTORY.md
- COMMON_WINDOWS_ERRORS.md
- EXTERNAL_REPAIR_TOOLS_STRATEGY.md
- NEXT_CHAT_PROMPT.md

目前本輪新增：
- `scripts\Test-GuiReadyTargetPreflight.ps1`
- `scripts\Test-GuiReadyCache.ps1`
- `scripts\Stop-GuiReadySession.ps1`
- `scripts\New-UsbPackageSelectorPage.ps1`
- `scripts\Sync-GuiReadyUsbPatch.ps1`
- `New-PortableUsbPayload.ps1` 會產生 `Stop-WindowsDoctor-GUI-Ready.cmd`
- `Start-WindowsDoctor-GUI-Ready.cmd` 會先跑 target preflight，再做 GUIREADY cache self-repair。
- `Test-PortableUsbPayload.ps1` 與 `Test-PortableRuntimeSelfTest.ps1` 已補 GUI-ready 腳本存在性檢查。
- `Publish-PortableUsbPackage.ps1` 會在發佈後產生 USB selector/status page。
- `scripts\Update-MicrosoftOfficialRepairSources.ps1` 可匯入 Microsoft 官方修復參考，只允許 `learn.microsoft.com` / `support.microsoft.com`，不更新 allowlist。

目前最後狀態：
- `Test-ResourceSafety.ps1 -Json`: `FAIL`
- `FreeMemoryGB=3.10`
- `Required=4GB`
- `PostCssWorkerCount=0`
- `WindowsDoctorNodeProcessCount=0`
- PowerShell AST parse check: `PASS`
- `G:\START_HERE.html` selector/status 已產生，找到 4 個 WindowsDoctor 套件，WinPE boot.wim present。
- `G:\WindowsDoctor-PortableUSB-GUI-READY-20260503` 已同步 GUI-ready preflight/cache/stop/selector scripts 與新版 validation scripts。
- `Test-PortableUsbPayload.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260503`: `PASS`
- `Test-GuiReadyTargetPreflight.ps1` from G: package: `PASS`
- `Test-PortableUsbReleaseValidation.ps1` from G: package: `PASS`
  - payload checks: `22`
  - runtime self-test checks: `21`
  - recommended repair preview: `PASS`, `executed=False`
- Microsoft official source update：`PASS`
  - added sources: `9`
  - added rules: `9`
  - normalized KB `TotalRecords=82`
  - `PublicReferenceRecords=17`
  - `SourceCount=16`
  - `Test-NormalizedKBDatabase.ps1`: `PASS`
- RepairDecisionEngine v3：`PASS`
  - `RepairPlanVersion=3`
  - `DecisionEngineVersion=3`
  - `SafeBatchExecutionPolicy.StopOnFirstFailure=true`
  - execution without `RUN` rejected
  - current healthy scan: `SafeBatchScriptCount=0`, `Executed=false`
  - G: GUI-ready package synced and release validation PASS
- GUI one-click repair panel added:
  - Broker `GET /api/repair-plan`
  - Broker `POST /api/repair-plan/execute`
  - GUI panel `OneClickRepairPanel`
  - execution requires `RUN` and server-side v3 SafeBatch policy
  - broker service tests PASS
  - lint PASS
  - low-risk baseline PASS, 14 steps including lint
  - G: GUI-ready package synced and release validation PASS
- Final resource safety: `PASS`, `FreeMemoryGB=5.94`, `PostCssWorkerCount=0`, `WindowsDoctorNodeProcessCount=0`
- 未啟動 GUI/Broker
- 未執行 production build
- 未執行修復

下一步建議：
1. 等資源安全 PASS 後，跑 targeted validation：
   - `Test-GuiReadyTargetPreflight.ps1 -Root E:\WindowsDoctor -NodeRuntimePath <GUI_READY_PACKAGE>\node-runtime -Json`
   - `Test-PortableUsbPayload.ps1 -PackageRoot <PACKAGE_ROOT> -Json`
   - `Test-PortableRuntimeSelfTest.ps1 -Root <PACKAGE_ROOT>\WindowsDoctor -Json`
2. 若重新發佈 USB，使用 zip-copy-expand，然後跑 `Test-PortableUsbReleaseValidation.ps1`。
3. 資源足夠後再跑 documentation sync、portable runtime self-test 或 release validation。
