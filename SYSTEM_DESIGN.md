# 系統設計與開發規格 (System Design)

Last updated: `2026-04-28`

## 1. 系統全貌
WindowsDoctor 是一套針對 Windows 10/11 的專家自動修復與診斷系統。
目前執行面以 Node.js Broker (`gui/broker.js`) 與前端 PWA (`gui/`) 為主；PowerShell (`core/`, `scripts/`) 保留為測試、建置、WinPE 與離線維護層。

## 2. 核心模組
### 2.1 PowerShell 維護層 (`WindowsDoctor.psm1`)
- **分析器**: 讀取 24 小時內的 Event Logs 並轉譯為故障標籤。
- **知識庫 (RAG)**: 使用 Markdown/YAML 存放於 `knowledge_base/`，並支援 NAS (`Sync-NASKnowledge`) 與 Web API 同步。
- **安全金庫**: 使用 Windows DPAPI (`Set-WDCredential`)，以本機機密形式保存密碼，支援系統發起 UAC 時的背景提權。
- **環境鎖定**: 鎖定當前子網段 IP 與主機板 UUID (`Set-WDEnvironmentLock`)，確保修復碟不被濫用。
- **限制**: 不作為 GUI 即時修復主路徑；企業防毒敏感環境優先走 Node 原生與 allowlist `.bat`。

### 2.2 Broker API (`broker.js`)
- Node.js 中介層 (Port 3001)。使用原生 `os`、`wmic`、`wevtutil`、`robocopy` 與 allowlist `.bat` 腳本處理 GUI 即時流程。
- `/api/repair` 僅允許 `scripts/repair-allowlist.json` 清單列出的 `.bat`，避免路徑穿越與未知腳本執行。
- 修復執行使用固定參數 `spawn` 與 timeout，不使用動態 shell 字串執行。
- `/api/learn` 只寫入知識庫，不自動生成或執行修復腳本。
- `/api/rules` 與 `/api/repair/allowlist` 提供 GUI/維運工具檢查目前規則與核准修復面。

### 2.2.1 Broker 模組結構
- `gui/broker.js`: Express 啟動器。
- `gui/broker/routes.js`: API route 註冊。
- `gui/broker/config.js`: 路徑、port、timeout 與 provider 設定。
- `gui/broker/state.js`: runtime KB path 狀態。
- `gui/broker/services/kb.js`: KB Markdown 解析與新舊格式兼容。
- `gui/broker/services/repair.js`: allowlist 與 Batch 執行政策。
- `gui/broker/services/system.js`: health、admin、event log 讀取。
- `gui/broker/services/vision.js`: Vision provider adapter，目前為 mock fallback。
- `gui/broker/services/learn.js`: learn-only 搜尋與 KB 寫入。
- `gui/broker/services/vault.js`: 憑證加密與環境鎖定。

### 2.4 Knowledge Base 分層
- `knowledge_base/reviewed`: 已審核、可參與診斷比對的正式規則。
- `knowledge_base/learned`: `/api/learn` 新增的 learn-only 規則，預設不含可執行修復腳本。
- `knowledge_base/archived`: 歷史測試或過期規則，不參與 Broker 診斷比對。
- Broker 只讀取 `reviewed` 與 `learned`，忽略 `archived`。

### 2.3 前端 PWA (`src/app/page.tsx`)
- 基於 Next.js / TailwindCSS 構建的單頁應用程式。
- 提供視覺診斷 Mock、問題文字回報、結果呈現與手動觸發 allowlist 修復按鈕。

### 2.3.1 Frontend Components
- `gui/src/app/page.tsx`: page orchestration and workflow state.
- `gui/src/components/DiagnosisResults.tsx`: diagnosis findings, learn trigger, repair trigger.
- `gui/src/components/VisionModal.tsx`: visual diagnosis modal.
- `gui/src/components/ReportModal.tsx`: problem report and learn-only ingestion modal.
- `gui/src/components/SystemMonitor.tsx`: local health, admin status, scan trigger.
- `gui/src/components/SettingsPanel.tsx`: vault, environment lock, NAS KB, rule index container.
- `gui/src/components/RuleIndexPanel.tsx`: KB rule and repair allowlist status.
- `gui/src/components/StatusToast.tsx`: in-page status notification replacing blocking alerts.
- `gui/src/components/DiagnosisResults.tsx`: includes health/analyze/connection failure UI and retry action.
- `gui/src/types/windows-doctor.ts`: shared frontend types.
- `gui/src/lib/api.ts`: API envelope unwrap/error helper.
- `gui/src/lib/windowsDoctorApi.ts`: frontend Broker client; page/components should call this layer instead of raw `fetch`.

## 3. 部署與運行
- 啟動 Frontend: `npm run dev --prefix e:\WindowsDoctor\gui -- -p 3000`
- 啟動 Backend: `node e:\WindowsDoctor\gui\broker.js` (Port 3001)

## 4. 未來擴展方向
- 支援直接產出整合了自動啟動 WindowsDoctor 的 WinPE ISO 映像檔。
- `/api/vision-analyze` 可替換為 Gemini Vision API；若未配置 API key，保留本機 mock 回應。
- WinPE 包裝前先執行 `scripts\Build-WinPEMedia.ps1 -CheckOnly` 驗證 ADK、來源與 Node。
- 外部工具不取代 WindowsDoctor 核心；依 `EXTERNAL_REPAIR_TOOLS_STRATEGY.md`，優先新增 SetupDiag、Get Help command-line、DISM/SFC、Intune/Wazuh 匯入或匯出 adapter，並以 source trust level 與 allowlist policy 控制修復風險。

## 5. 標準化產生器
- KB 規則：`scripts\New-KBRule.ps1`
- 修復腳本：`scripts\New-RepairScript.ps1`
- 修復 allowlist：`scripts\repair-allowlist.json`
- 完整基線：`scripts\Test-SystemBaseline.ps1`
