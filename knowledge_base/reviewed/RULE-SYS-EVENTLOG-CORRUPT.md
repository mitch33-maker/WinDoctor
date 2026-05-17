---
description: "事件記錄服務或事件檔異常"
---
# 事件記錄服務或事件檔異常
- EventID/Code: SYS_EVENTLOG_CORRUPT
- Trigger: [EventLog, 事件記錄, 1101, 1105, event log corrupt]
- Script: "Repair-Services.bat"

## 分析細節
事件記錄異常會影響故障追蹤與稽核。先確認 Windows Event Log 服務狀態、磁碟空間與事件檔讀取權限；可透過服務修復腳本恢復常見服務設定。
