---
description: "Windows 系統維護、安全清理與離線預覽入口"
---
# Windows 系統維護與資源清理
- EventID/Code: SYSTEM_MAINTENANCE
- Trigger: ["SYSTEM_MAINTENANCE", "MAINTENANCE_CLEANUP", "LOGOFF_DISCONNECTED_USERS", "DISK_CLEANUP", "MEMORY_RELEASE", "DISM", "SFC", "CHKDSK", "系統維護", "登出中斷連線使用者", "硬碟清理", "記憶體釋放"]
- Script: "Repair-SystemMaintenance.bat"

## 分析細節
此規則提供 WinPE/offline 環境中的安全維護入口，可先預覽下列動作：
1. 找出符合條件的 disconnected user sessions。
2. 估算可清理的暫存檔與回收桶清理流程。
3. 顯示記憶體釋放提示。
4. 顯示 DISM / SFC / CHKDSK 的系統維護命令。

實際執行維護必須改用 `Invoke-WindowsMaintenance.ps1 -Execute -ConfirmToken RUN`，避免誤登出使用者或誤刪資料。
