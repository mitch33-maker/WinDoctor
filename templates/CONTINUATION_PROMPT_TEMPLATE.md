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
__RESOURCE_JSON__
```

TASK_HANDOFF.md 末段：
```text
__TASK_HANDOFF_TAIL__
```

OPERATIONS.md 末段：
```text
__OPERATIONS_TAIL__
```

SYSTEM_ERROR_HISTORY.md 末段：
```text
__SYSTEM_ERROR_HISTORY_TAIL__
```
