# Windows 常見故障資料庫覆蓋範圍

Last updated: `2026-04-29`

本文件摘要 `knowledge_base\reviewed` 中可供單機診斷、引導修復與 allowlist 自動修復的常見 Windows 故障規則。

## 1. 規則統計
- Reviewed KB rules: `65`
- Allowlist 自動修復: `21`
- 引導修復 / 人工確認: `44`

## 2. 覆蓋分類
| 分類 | 規則範圍 | 自動化政策 |
|---|---|---|
| 系統錯誤 | CBS/SFC/DISM、NTFS、WMI、MSI 1603、AppX/Store、Windows Update、DCOM、SCM、SYSTEM_MAINTENANCE | 只對既有 allowlist 腳本自動修復，其餘引導使用者 |
| 網路錯誤 | DNS、DHCP/APIPA、Winsock、WinHTTP Proxy、Wi-Fi、VPN DNS/Route | 網路堆疊類可用 `Repair-NetworkStack.bat`，VPN/公司 Proxy 僅引導 |
| 硬體錯誤 | SMART、USB Code 43、GPU TDR、ACPI Battery、驅動衝突 | 不自動修硬體，優先備份、原廠驅動與硬體檢測 |
| 開機錯誤 | BCD、INACCESSIBLE_BOOT_DEVICE、BitLocker Recovery、WinRE、Safe Mode loop | BCD 類可使用 `Repair-BCDBoot.bat`，加密/分割區問題只引導 |
| 網路硬碟 | SMB 0x80070035、1219、Guest disabled、SMB signing/version、Offline Files | 不自動放寬 SMB 安全，不自動清除離線快取 |
| 印表機 | Spooler、0x00000709、0x0000011B、WSD offline、Access denied、Driver package | 服務重啟可自動化；安全性原則與驅動刪除只引導 |

## 3. 安全邊界
- `knowledge_base\reviewed` 可參與診斷。
- `Script: "N/A"` 表示只提供引導，不自動執行修復。
- 只有 `scripts\repair-allowlist.json` 內的 `Repair-*.bat` 能由 `/api/repair` 執行。
- 不自動啟用 SMB1、不自動放寬 Guest SMB、不自動降低 Point and Print/RPC 安全性、不繞過 BitLocker。

## 4. 使用方式
1. 單機診斷時讀取 Broker `/api/analyze` 或 KB Markdown 規則。
2. 若命中規則且 `repairAllowed=true`，GUI 可顯示自動修復按鈕。
3. 若 `repairAllowed=false`，GUI 應顯示引導步驟與風險提醒。
4. 新增修復腳本前必須先通過人工審查，再加入 allowlist。

## 5. ActionType
Broker `/api/analyze` 會將命中結果標記為：
- `auto_repair`: 可透過 allowlist 腳本自動修復。
- `guided`: 只提供操作指引。
- `manual_review`: 有腳本參照但未通過 allowlist，需人工確認。
- `learn`: 未知問題，進入 learn-only 流程。

## 6. WinPE 離線使用狀態
- `knowledge_base\reviewed` 會被 `scripts\Build-WinPEMedia.ps1` 複製進 WinPE。
- `scripts\Export-OfflineKBDatabase.ps1` 會產生 `offline_database\windowsdoctor-kb.json`。
- `scripts\Test-OfflineKBDatabase.ps1` 會驗證離線 JSON schema、統計、規則欄位、來源檔與 allowlist 一致性。
- `offline_database\windowsdoctor-kb.json` 目前包含 `65` 筆規則、`21` 筆可自動修復規則、`44` 筆引導修復規則。
- WinPE 啟動時 Broker 會以 `WD_ROOT_DIR=X:\WindowsDoctor` 讀取離線 KB。
- WinPE 啟動時會設定 `WD_USE_OFFLINE_DB=1`，Broker 會優先讀取 `offline_database\windowsdoctor-kb.json`。
- Broker `/api/rules` 與 `/api/analyze` 不需要網路即可使用 reviewed/learned 規則。
- 不啟動 Broker 時，可用 `scripts\Search-OfflineKB.ps1 -Query <錯誤碼或關鍵字>` 直接查離線資料庫。
- 自動修復仍受 `scripts\repair-allowlist.json` 限制。
## 7. Portable Scan Recommendation Output
- `scripts\Test-SystemErrorScan.ps1` now joins diagnostic findings with `offline_database\windowsdoctor-kb.json`.
- Each finding includes `KbMatches` with rule id, title, action type, allowlist status, and repair script.
- The scan remains diagnostic-only. Repairs still require `Invoke-AllowedRepair.ps1` or menu option 7 plus explicit `RUN`.
- Current verified scan matching: `65` KB rules available, `11` KB matches from the latest local scan.
