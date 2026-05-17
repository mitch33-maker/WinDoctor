---
description: "WindowsDoctor AI workflow report cache is stale or corrupted"
---
# WindowsDoctor AI workflow report cache repair
- EventID/Code: WD_REPORT_CACHE
- Trigger: ["WD_REPORT_CACHE", "gui-work-issue-diagnostic", "AI workflow report cache", "WindowsDoctor report cache"]
- Script: "Repair-WDReportCache.bat"

## 分析細節
WindowsDoctor 的自然語言診斷工作會寫入 `logs\gui-work-issue-diagnostic.latest.json`。若該報告快取損毀或阻礙 UI 顯示，可將最新報告移到 `.wd-backup\report-cache`，再讓系統重新產生報告。此修復只影響 WindowsDoctor 自身的報告快取，不修改 Windows OS 設定、服務、網路、驅動或使用者資料。
