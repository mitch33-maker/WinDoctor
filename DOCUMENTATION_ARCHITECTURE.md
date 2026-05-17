# WindowsDoctor Documentation Architecture

Last updated: `2026-05-17`

## 1. 目標
文件體系必須同時滿足三個條件：
- 最安全：任何工作先經資源安全 gate；修復、破壞性維護、production build、GUI/Broker 啟動都必須被明確隔離。
- 最有效率：新接手者先讀少量權威入口，再依任務進入操作、狀態、錯誤、KB 或 USB 文件。
- 可持續：狀態、歷史、操作手冊、稽核紀錄分層保存，避免單一檔案同時承擔所有用途。

## 2. 權威讀取順序
1. `AGENTS.md`；若磁碟沒有此檔，沿用使用者提示詞限制。
2. `INDEX.md`
3. `DOCUMENTATION_ARCHITECTURE.md`
4. `MEMORY_SYSTEM.md`
5. `OPERATIONS.md`
6. `TASK_HANDOFF.md`
7. `SYSTEM_ERROR_HISTORY.md`
8. `COMMON_WINDOWS_ERRORS.md`
9. `EXTERNAL_REPAIR_TOOLS_STRATEGY.md`
10. `NEXT_CHAT_PROMPT.md`

## 3. 文件角色
| 類型 | 權威文件 | 用途 |
|---|---|---|
| 入口 | `INDEX.md` | 文件路由、讀取順序、工具索引 |
| 架構 | `SYSTEM_DESIGN.md`, `DOCUMENTATION_ARCHITECTURE.md`, `PERFORMANCE_POLICY.md` | 系統架構、效能策略與文件治理 |
| 操作 | `OPERATIONS.md` | 可執行命令、驗收流程、日常維運 |
| 安全 | `SECURITY_POLICY.md`, `KB_GOVERNANCE.md` | 修復邊界、KB 晉升、allowlist 原則 |
| 狀態 | `TASK_HANDOFF.md`, `NEXT_CHAT_PROMPT.md` | 最新工作紀錄與下一輪提示 |
| 記憶 | `MEMORY_SYSTEM.md`, `TASK_COMPLETION_LOG.md`, `skills\windowsdoctor-documentation-system\SKILL.md` | 長期記憶分層、每件任務完成紀錄、可重用流程 |
| 經驗 | `SUCCESS_EXPERIENCE.md`, `SYSTEM_ERROR_HISTORY.md` | 已解問題、阻斷錯誤、驗證證據 |
| 使用者手冊 | `docs\*.html` | 操作者視覺化說明、USB 現場使用 |
| 稽核 | `DOCS_ARCHITECTURE_AUDIT.md` | 文件體系安全、效率、可持續性檢查紀錄 |

## 4. 安全規則
- 每次工作前先執行：
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```
- 沒有明確 `RUN` 時，不得執行修復或破壞性維護。
- 沒有明確要求時，不啟動 GUI/Broker。
- 不執行 production build；基線驗證使用 `-SkipBuild` 或既有低風險 gate。
- 真實資料匯入前只允許 readiness/validate；沒有真實資料時保持 `WAITING`，不得自行偽造實測資料。

## 5. 更新規則
- 完成重大功能：更新 `TASK_HANDOFF.md` 與 `NEXT_CHAT_PROMPT.md`。
- 完成任何任務：用 `scripts\Add-TaskCompletionRecord.ps1` 更新 `TASK_COMPLETION_LOG.md`。
- 成功流程可重複使用：更新 `SUCCESS_EXPERIENCE.md`，必要時更新 `skills\windowsdoctor-documentation-system\SKILL.md`。
- 變更操作流程：更新 `OPERATIONS.md`。
- 變更安全邊界：更新 `SECURITY_POLICY.md`。
- 變更文件體系或讀取順序：更新 `DOCUMENTATION_ARCHITECTURE.md`、`INDEX.md`、`DOCS_ARCHITECTURE_AUDIT.md`。
- 新增使用者手冊：放入 `docs\`，並在 `INDEX.md` 登錄。

## 6. 可持續性限制
- `TASK_HANDOFF.md` 是 append-only 交接紀錄，可長期保留，但最新狀態必須放在檔案最上方。
- 若 `TASK_HANDOFF.md` 超過 3500 行，下一步應新增年度或月份歸檔策略，保留檔首最新摘要。
- 使用 `scripts\Test-TaskHandoffArchiveReadiness.ps1` 檢查歸檔門檻與候選範圍；此腳本只產生 JSON 計畫，不搬移或改寫交接紀錄。
- `NEXT_CHAT_PROMPT.md` 應只保留下一輪必要上下文與高價值歷史，不應取代完整歷史文件。
- `TASK_COMPLETION_LOG.md` 只保存短紀錄與證據路徑，不取代 `TASK_HANDOFF.md` 或 `logs\*.json`。
- `skills\` 只保存可重用流程，不保存一次性聊天內容。
- `logs\*.json` 是驗證證據來源，不應手寫替代。
