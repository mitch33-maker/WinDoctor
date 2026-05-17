---
description: "Windows Recovery Environment 遺失或停用"
---
# Windows Recovery Environment 遺失或停用
- EventID/Code: WINRE_MISSING
- Trigger: ["Windows RE status: Disabled", "WinRE", "reagentc", "Recovery environment not found"]
- Script: "N/A"

## 分析細節
常見於分割區調整、映像部署、升級失敗或 recovery partition 遺失。引導使用者先以 `reagentc /info` 確認狀態，再依磁碟配置修復 WinRE 路徑；不可盲目建立或格式化分割區。
