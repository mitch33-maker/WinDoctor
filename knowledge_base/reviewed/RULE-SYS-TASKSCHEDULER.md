---
description: "工作排程器任務失敗"
---
# 工作排程器任務失敗
- EventID/Code: SYS_TASKSCHEDULER
- Trigger: [Task Scheduler, 工作排程器, 101, 102, 201]
- Script: "Repair-Services.bat"

## 分析細節
排程任務失敗會影響備份、更新與維護作業。先確認 Task Scheduler 服務、帳號密碼、觸發條件與執行權限。
