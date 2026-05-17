---
description: "系統磁碟空間不足"
---
# 系統磁碟空間不足
- EventID/Code: SYS_DISK_LOWSPACE
- Trigger: [磁碟空間不足, low disk space, 2013, C 槽滿]
- Script: "Repair-SystemMaintenance.bat"

## 分析細節
系統碟空間不足會造成更新失敗、暫存檔寫入失敗與效能下降。先清點大型檔案與 Windows Update 暫存；系統維護腳本只做受控預覽/維護入口。
