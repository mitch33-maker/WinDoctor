---
description: "列印佇列卡住或 Spooler 無法清除"
---
# 列印佇列卡住或 Spooler 無法清除
- EventID/Code: PRINT_QUEUE_STUCK
- Trigger: ["print queue", "stuck print job", "Spooler", "splwow64", "win32spl"]
- Script: "Repair-Services.bat"

## 分析細節
列印工作卡住可能造成所有印表機無法列印。可重啟列印服務；若需清除 spool 目錄，應先確認沒有重要未列印文件，並提示使用者重新送印。
