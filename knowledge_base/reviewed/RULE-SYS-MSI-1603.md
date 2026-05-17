---
description: "Windows Installer 安裝失敗 1603"
---
# Windows Installer 安裝失敗 1603
- EventID/Code: 1603
- Trigger: ["1603", "Windows Installer", "MSI", "Fatal error during installation", "Event ID: 11708"]
- Script: "N/A"

## 分析細節
通常與權限不足、舊版產品殘留、安裝目錄被鎖定、服務未啟動或防毒攔截有關。引導使用者先重新開機、確認磁碟空間與管理員權限，再檢查安裝記錄中的 Return value 3。
