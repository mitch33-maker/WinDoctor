---
description: "系統時間同步失敗"
---
# 系統時間同步失敗
- EventID/Code: SYS_TIME_SYNC
- Trigger: [時間同步, Time-Service, W32Time, Kerberos time skew]
- Script: "Repair-Services.bat"

## 分析細節
時間錯誤會造成 TLS、網域登入、Kerberos 與更新失敗。先確認時區、NTP 來源與 Windows Time 服務，再依環境政策修正。
