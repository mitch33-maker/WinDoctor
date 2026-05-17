# 系統文件總索引 (Document Index)

Last updated: `2026-05-17`

本文件為 WindowsDoctor 的文件入口點，所有對架構、經驗與交接狀態的檢索，均應從此處路由。

## 1. 架構與設計 (Architecture & Design)
| 文件 | 描述 | RAG 權重 |
|---|---|---|
| [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) | 系統藍圖、模組架構與資料流 | High |
| [DOCUMENTATION_ARCHITECTURE.md](DOCUMENTATION_ARCHITECTURE.md) | 文件讀取順序、安全 gate、角色分層與可持續性規則 | High |
| [MEMORY_SYSTEM.md](MEMORY_SYSTEM.md) | 長期記憶分層、任務完成紀錄、skill 化規則與最小讀取路徑 | High |
| [PERFORMANCE_POLICY.md](PERFORMANCE_POLICY.md) | 高效能、低資源消耗的預設執行策略與資源預算 | High |
| [WINDOWS_RESOURCE_ORGANIZER_PLAN.md](WINDOWS_RESOURCE_ORGANIZER_PLAN.md) | Windows 資源整理、登出、清理、強制移除與同質軟體功能的安全分級計畫 | High |
| [AUTO_REPAIR_SAFETY_POLICY.md](AUTO_REPAIR_SAFETY_POLICY.md) | 一鍵自動修復升級 gate、可逆性、dry-run、rollback、allowlist review 與 RUN gate | High |
| [REPAIR_COVERAGE_ROADMAP.md](REPAIR_COVERAGE_ROADMAP.md) | 80%/100% 診斷與修復覆蓋率目標、官方來源優先與第三方隔離策略 | High |
| [EXTERNAL_REPAIR_TOOLS_STRATEGY.md](EXTERNAL_REPAIR_TOOLS_STRATEGY.md) | 外部維修工具、官方診斷來源與 WindowsDoctor 架構定位 | High |
| [API_CONTRACT.md](API_CONTRACT.md) | Broker API contract 與回應格式 | High |
| [COMMON_WINDOWS_ERRORS.md](COMMON_WINDOWS_ERRORS.md) | Windows 常見故障 KB 覆蓋範圍與安全邊界 | High |
| [VERSION_POLICY.md](VERSION_POLICY.md) | 版本格式、進位規則與升版同步位置 | High |

## 2. 狀態與交接 (State & Handoff)
| 文件 | 描述 | RAG 權重 |
|---|---|---|
| [TASK_HANDOFF.md](TASK_HANDOFF.md) | 最新通過驗證的基線狀態、未決問題與下一步建議 | High |

## 3. 安全與治理 (Security & Governance)
| 文件 | 描述 | RAG 權重 |
|---|---|---|
| [SECURITY_POLICY.md](SECURITY_POLICY.md) | 修復執行、allowlist、learn-only 與安全邊界 | High |
| [MANAGEMENT_SYSTEM.md](MANAGEMENT_SYSTEM.md) | 本機優先管理系統、角色權限、審計紀錄、optional NAS profile | High |
| [EVENT_LOG_ANALYSIS.md](EVENT_LOG_ANALYSIS.md) | MIS 事件日誌解讀、Provider/Event ID 摘要、KB 對應與唯讀安全政策 | High |
| [REPAIR_TOOL_PACKAGING_POLICY.md](REPAIR_TOOL_PACKAGING_POLICY.md) | 修復/診斷工具安全包裝、來源信任、SHA-256 驗證與隔離政策 | High |
| [KB_GOVERNANCE.md](KB_GOVERNANCE.md) | reviewed / learned / archived 晉升與歸檔規則 | High |
| [OPERATIONS.md](OPERATIONS.md) | 啟動、重啟、驗證、WinPE preflight 操作指令 | High |
| [DOCS_ARCHITECTURE_AUDIT.md](DOCS_ARCHITECTURE_AUDIT.md) | 文件體系安全性、效率與可持續性稽核紀錄 | High |

## 3.1 操作手冊 (Operator Manuals)
| 文件 | 描述 | RAG 權重 |
|---|---|---|
| [docs/WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html](docs/WINDOWSDOCTOR_VISUAL_OPERATION_MANUAL.html) | 圖像式操作說明書、USB GUI-ready、WinPE、RUN gate、真實資料匯入與應用場景 | High |
| [docs/START_HERE_USB.html](docs/START_HERE_USB.html) | USB 現場入口頁 | High |
| [docs/WINDOWSDOCTOR_NOTEBOOKLM_GUI_USER_GUIDE.html](docs/WINDOWSDOCTOR_NOTEBOOKLM_GUI_USER_GUIDE.html) | NotebookLM 與 GUI 使用說明 | Medium |
| [docs/WINDOWSDOCTOR_USB_KIDS_GUIDE.html](docs/WINDOWSDOCTOR_USB_KIDS_GUIDE.html) | 簡化版 USB 操作說明 | Medium |

## 4. 經驗與記憶 (Experience & Memory)
| 文件 | 描述 | RAG 權重 |
|---|---|---|
| [SUCCESS_EXPERIENCE.md](SUCCESS_EXPERIENCE.md) | 成功解決的複雜問題模式，避免重新發明輪子 | Medium |
| [SYSTEM_ERROR_HISTORY.md](SYSTEM_ERROR_HISTORY.md) | 系統測試或運行期間發生的底層錯誤與解決方案 | Medium |
| [TASK_COMPLETION_LOG.md](TASK_COMPLETION_LOG.md) | 每件完成任務的短紀錄、證據與後續項目 | Medium |
| [THIRD_PARTY_REPAIR_REFERENCE.md](THIRD_PARTY_REPAIR_REFERENCE.md) | GitHub/第三方成熟工具隔離參考，不直接進正式修復 | Medium |
| [skills/windowsdoctor-documentation-system/SKILL.md](skills/windowsdoctor-documentation-system/SKILL.md) | 文件體系、交接、記憶與完成紀錄的可重用 skill | Medium |

## 5. 標準化工具
| 工具 | 描述 |
|---|---|
| `scripts\New-KBRule.ps1` | 依模板建立標準 KB 規則 |
| `scripts\New-RepairScript.ps1` | 依模板建立標準 Batch 修復腳本，可選擇加入 allowlist |
| `scripts\Start-WindowsDoctor.ps1` | 啟動 GUI/Broker 並可選擇執行 baseline 驗證 |
| `scripts\Test-VersionPolicy.ps1` | 驗證版本格式、進位上限與 GUI/package 同步 |
| `scripts\Test-BrokerSmoke.ps1` | Broker API smoke test |
| `scripts\Test-GuiSmoke.ps1` | 低風險 GUI/Broker smoke test，不自動啟動服務 |
| `scripts\Test-SystemBaseline.ps1` | lint/build/Pester/smoke/WinPE preflight 整體驗證 |
| `scripts\Test-TaskHandoffArchiveReadiness.ps1` | 檢查 `TASK_HANDOFF.md` 是否達到歸檔門檻，只輸出計畫，不搬移內容 |
| `scripts\Add-TaskCompletionRecord.ps1` | 完成任務後追加短紀錄與證據路徑到 `TASK_COMPLETION_LOG.md` |
| `scripts\Test-DocumentationMemorySystem.ps1` | 驗證文件記憶體系、completion log、skill 與操作命令是否已登錄 |
| `scripts\Test-RepairCoverageGoal.ps1` | 驗證 normalized KB 的元件覆蓋率與官方來源覆蓋率是否達標 |
| `scripts\Test-AutoRepairSafetyPolicy.ps1` | 驗證自動修復 policy 是否覆蓋 allowlist、rollback、RUN gate 與 auto-batch 安全條件 |
| `scripts\Test-SpecializedIssueDiagnostics.ps1` | 對印表機、Windows Update、網路、開機、效能、硬體與系統完整性執行唯讀專項診斷 |
| `scripts\Test-WindowsResourceOrganizerCapability.ps1` | 驗證 Windows 資源整理需求覆蓋狀態、風險分級與下一步，不執行清理或移除 |
| `scripts\Test-ManagementSystemReadiness.ps1` | 驗證管理系統角色、token hash、audit、API、前端與 NAS optional policy |
| `scripts\Analyze-WindowsEventLogs.ps1` | 唯讀分析 Windows 事件日誌，輸出 MIS JSON/CSV 摘要、KB 對應與處理分類 |
| `scripts\Test-RepairToolPackageManifest.ps1` | 驗證修復工具包裝 manifest、來源信任、SHA-256 與 no-autorun policy |
| `scripts\New-RepairToolPackage.ps1` | 將已驗證工具封裝到隔離 repair-tools 套件，不安裝、不執行 |
| `scripts\Save-OfflineRepairTools.ps1` | 下載 Microsoft 官方離線診斷工具、驗證 SHA-256/簽章並封裝 |
| `scripts\Test-OfflineToolAutomation.ps1` | 驗證離線介面可自動選用診斷工具、顯示命令預覽，且不安裝、不執行、不改 allowlist |
| `scripts\Invoke-OfflineDiagnosticTools.ps1` | RUN-gated 離線診斷工具序列化 runner；預設只產生 preview |
| `scripts\Convert-OfflineDiagnosticToolOutput.ps1` | 將離線診斷工具輸出轉成 WindowsDoctor JSON 證據，不執行修復 |
| `scripts\Test-LowResourceStartup.ps1` | 驗證 Broker-only 低資源模式，不啟動 Next dev GUI |
| `scripts\New-PortableIncrementalPatch.ps1` | 建立小型 USB 增量 patch zip，避免重壓完整 GUI-ready package |
| `scripts\Test-PortableIncrementalPatch.ps1` | 驗證增量 patch zip、manifest 與 package root 內容一致 |
| `scripts\Test-UsbLowResourceEntry.ps1` | 驗證 USB 低資源入口、selector 順序與啟動器安全參數 |
| `scripts\Test-UsbLowResourceAcceptance.ps1` | 串接低資源入口、啟動、release validation、patch 與收尾資源安全驗收 |
| `scripts\Build-WinPEMedia.ps1 -CheckOnly` | WinPE 包裝前置條件檢查 |

## 6. Broker 模組入口
| 路徑 | 描述 |
|---|---|
| `gui\broker.js` | Broker 啟動器 |
| `gui\broker\routes.js` | API route 註冊 |
| `gui\broker\services\` | health、KB、repair、vision、learn、vault 服務層 |
| `gui\src\components\` | 前端模組化 UI 元件 |
| `gui\src\types\windows-doctor.ts` | 前端共享型別 |
| `gui\src\lib\api.ts` | API envelope 解析 helper |
| `gui\src\lib\windowsDoctorApi.ts` | 前端 Broker API 標準 client |
| `gui\broker\tests\services.test.js` | Broker KB/repair service 單元測試 |

## 7. Knowledge Base 分層
| 路徑 | 描述 |
|---|---|
| `knowledge_base\reviewed` | 正式審核規則，參與診斷 |
| `knowledge_base\learned` | learn-only 新增規則，需審核後才可加修復腳本 |
| `knowledge_base\archived` | 測試/過期規則，不參與診斷 |

## 8. 重複文件處理
| 路徑 | 狀態 |
|---|---|
| `docs\SUCCESS_EXPERIENCE.md` | Redirect，權威文件為根目錄 `SUCCESS_EXPERIENCE.md` |
| `docs\SYSTEM_ERROR_HISTORY.md` | Redirect，權威文件為根目錄 `SYSTEM_ERROR_HISTORY.md` |

## 9. 自動化文檔更新規則
1. 每當完成一個重大 Feature，必須更新 `TASK_HANDOFF.md`。
2. 每當解決一個困難的 Bug 或架構挑戰，必須記錄於 `SUCCESS_EXPERIENCE.md`。
3. 任何引發環境 Crash 或阻斷流程的錯誤，必須記錄於 `SYSTEM_ERROR_HISTORY.md`。
4. 任何安全邊界或修復執行政策變更，必須更新 `SECURITY_POLICY.md`。
5. 任何 KB 分層、晉升或歸檔規則變更，必須更新 `KB_GOVERNANCE.md`。
6. 任何版本變更，必須遵守 `VERSION_POLICY.md` 並同步 `gui\package.json`、GUI 顯示與 `TASK_HANDOFF.md`。
7. 每件任務完成後，必須用 `scripts\Add-TaskCompletionRecord.ps1` 在 `TASK_COMPLETION_LOG.md` 留下短紀錄與證據路徑。
8. 可重複成功流程必須沉澱到 `SUCCESS_EXPERIENCE.md`，穩定後建立或更新 `skills\*\SKILL.md`。
