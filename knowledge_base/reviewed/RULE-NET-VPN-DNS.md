---
description: "VPN 連線後 DNS 或路由異常"
---
# VPN 連線後 DNS 或路由異常
- EventID/Code: VPN_DNS_ROUTE
- Trigger: ["VPN", "DNS suffix", "split tunnel", "route print", "NRPT", "Name Resolution Policy"]
- Script: "N/A"

## 分析細節
常見於 VPN 分割通道、DNS 後綴、公司網域解析或路由優先權錯誤。引導使用者收集 `ipconfig /all`、`route print` 與 VPN 用戶端狀態；避免自動刪除公司 VPN 設定。
