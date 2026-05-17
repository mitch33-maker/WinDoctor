---
description: "WMI Repository 異常造成管理工具或查詢失敗"
---
# WMI Repository 異常造成管理工具或查詢失敗
- EventID/Code: WMI_REPOSITORY
- Trigger: ["WMI", "Winmgmt", "repository is inconsistent", "0x80041010", "0x80041002", "Invalid class"]
- Script: "Repair-Services.bat"

## 分析細節
常見於系統管理工具、硬體監控、備份軟體或安全軟體無法讀取 Windows 管理資訊。可先重啟 WMI 相關服務；若仍失敗，再引導執行 WMI repository verify/salvage，避免直接刪除 repository。
