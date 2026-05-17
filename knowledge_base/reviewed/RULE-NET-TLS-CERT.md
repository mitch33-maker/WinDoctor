---
description: "TLS 或憑證信任造成連線失敗"
---
# TLS 或憑證信任造成連線失敗
- EventID/Code: NET_TLS_CERT
- Trigger: [TLS, 憑證, certificate, 0x80072F8F, SSL]
- Script: "N/A"

## 分析細節
TLS/憑證錯誤常與系統時間、根憑證、Proxy 攔截或舊 TLS 設定有關。先確認日期時間、Windows Update 根憑證與公司 Proxy，不自動降低 TLS 安全性。
