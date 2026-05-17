---
description: "磁碟 SMART 或硬體預警"
---
# 磁碟 SMART 或硬體預警
- EventID/Code: SMART_WARNING
- Trigger: ["SMART", "PredictFailure", "disk health", "reallocated sector", "Current Pending Sector", "Event ID: 52"]
- Script: "N/A"

## 分析細節
代表磁碟可能已出現硬體退化。系統應優先引導備份資料與更換磁碟，不應自動執行高寫入量修復。修復前需確認備份完整性與硬體健康報告。
