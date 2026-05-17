---
description: "離線檔案快取造成網路磁碟同步或存取異常"
---
# 離線檔案快取造成網路磁碟同步或存取異常
- EventID/Code: OFFLINE_FILES
- Trigger: ["Offline Files", "CSC", "Sync Center", "conflict", "The process cannot access the file because it is being used by another process"]
- Script: "N/A"

## 分析細節
常見於筆電離線檔案、同步中心衝突或網路磁碟快取損壞。引導使用者先備份本機離線變更，再處理同步衝突；不應自動清除 CSC 快取。
