---
description: "DNS 尾碼或公司網域解析錯誤"
---
# DNS 尾碼或公司網域解析錯誤
- EventID/Code: NET_DNS_SUFFIX
- Trigger: [DNS suffix, DNS 尾碼, 公司網域, internal domain]
- Script: "N/A"

## 分析細節
內部系統名稱解析失敗常與 DNS suffix search list、VPN DNS、AD 網域 DNS 或 Split DNS 有關。不可自動覆寫公司 DNS，需依網管設定處理。
