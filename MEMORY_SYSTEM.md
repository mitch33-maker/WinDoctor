# WindowsDoctor Memory System

Last updated: `2026-05-17`

本文件定義 WindowsDoctor 的長期記憶體系。目標是讓後續開發者先讀最少文件，仍能遵守安全限制、避免重複錯誤，並把可重用經驗沉澱成 skill。

## 1. 記憶分層
| 層級 | 權威位置 | 用途 | 更新時機 |
|---|---|---|---|
| Session safety | `scripts\Test-ResourceSafety.ps1`、`SECURITY_POLICY.md` | 每次工作前確認資源與修復邊界 | 每次工作前驗證 |
| Current state | `TASK_HANDOFF.md`、`NEXT_CHAT_PROMPT.md` | 最新狀態、未決事項、下一輪提示 | 重大任務完成後 |
| Completion log | `TASK_COMPLETION_LOG.md` | 每件完成任務的短紀錄、證據、後續項目 | 每件任務完成後 |
| Error memory | `SYSTEM_ERROR_HISTORY.md` | 阻斷錯誤、根因、防範方式 | 發生 crash、資源失控、驗證阻斷後 |
| Success memory | `SUCCESS_EXPERIENCE.md` | 成功解決的可重複模式 | 解決困難問題或建立可重用流程後 |
| Reusable skill | `skills\windowsdoctor-documentation-system\SKILL.md` | 下一輪可直接套用的工作流程 | 成功模式穩定後 |
| Machine evidence | `logs\*.json` | 驗證結果的機器可讀來源 | 驗證腳本產生，不手寫 |

## 2. 最小讀取路徑
一般任務只需依序讀取：
1. `INDEX.md`
2. `DOCUMENTATION_ARCHITECTURE.md`
3. `MEMORY_SYSTEM.md`
4. `TASK_HANDOFF.md` 檔首最新區塊
5. 任務相關文件

若任務涉及修復、安全、資源、USB、真實資料匯入或 production build，必須額外讀取：
- `SECURITY_POLICY.md`
- `OPERATIONS.md`
- `PERFORMANCE_POLICY.md`
- `EXTERNAL_REPAIR_TOOLS_STRATEGY.md`

## 3. 任務完成紀錄規則
每件任務完成後執行：

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Add-TaskCompletionRecord.ps1 -Title "task title" -Summary "short summary" -EvidencePath "E:\WindowsDoctor\logs\example.json" -Status PASS -Json
```

必要欄位：
- `Title`: 任務名稱。
- `Status`: `PASS`、`WAITING`、`BLOCKED` 或 `PARTIAL`。
- `Summary`: 一句話說明完成內容。
- `EvidencePath`: 驗證報告、log 或其他證據；可多筆。

禁止事項：
- 不得手寫替代 `logs\*.json` 驗證結果。
- 不得把未實測資料寫成已驗證。
- 不得把 learned、NotebookLM、Wazuh、RMM 或第三方資料直接升級為 auto-repair。
- 不得在沒有 `RUN` 時記錄「已修復系統」。

## 4. Skill 化規則
成功經驗符合任一條件時，應沉澱成 skill：
- 同一流程被重複執行兩次以上。
- 曾避免資源耗盡、啟動錯誤、文件漂移或安全邊界破壞。
- 下一輪可用固定步驟完成，且不依賴臨時聊天上下文。

skill 必須包含：
- 觸發時機。
- 必讀文件最小集合。
- 必跑安全 gate。
- 禁止事項。
- 完成後要更新的文件與 log。

## 5. 長期可持續規則
- `TASK_HANDOFF.md` 保持最新狀態在最上方；超過門檻前只用 `Test-TaskHandoffArchiveReadiness.ps1` 產生計畫。
- `TASK_COMPLETION_LOG.md` 只保留短紀錄，不取代 `TASK_HANDOFF.md`。
- `SUCCESS_EXPERIENCE.md` 只收錄高價值模式，不收錄每次小修改。
- `SYSTEM_ERROR_HISTORY.md` 只收錄會造成阻斷、錯誤重現或安全風險的事件。
- `logs\*.json` 是驗證證據來源；文件只引用路徑與摘要。

## 6. 目前基線
- 預設使用低資源路徑。
- 不啟動 Next dev GUI。
- 不跑 production build。
- 不執行修復或破壞性維護，除非操作員明確提供 `RUN`。
- USB 代號需以 `Get-PSDrive -PSProvider FileSystem` 或套件實際路徑自動偵測；本輪偵測到 `G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3`，`F:` 不存在。
