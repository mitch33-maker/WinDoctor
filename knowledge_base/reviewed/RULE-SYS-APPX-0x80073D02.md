---
description: "Microsoft Store 或 AppX 套件更新被使用中程序鎖定"
---
# Microsoft Store 或 AppX 套件更新被使用中程序鎖定
- EventID/Code: 0x80073D02
- Trigger: ["0x80073D02", "AppX", "Microsoft Store", "package could not be installed because resources it modifies are currently in use"]
- Script: "N/A"

## 分析細節
常見於內建 App 正在執行、Store 更新卡住或多使用者登入狀態。引導使用者關閉相關 App、登出其他使用者或重開機後再更新；不建議自動移除 AppX 套件。
