---
description: "WSD 印表機離線或連線不穩"
---
# WSD 印表機離線或連線不穩
- EventID/Code: WSD_PRINTER_OFFLINE
- Trigger: ["WSD", "printer offline", "Web Services Device", "SNMP status", "port monitor"]
- Script: "N/A"

## 分析細節
WSD 連線容易受 DHCP 位址變動、探索失敗或 SNMP 狀態影響。引導使用者改用固定 IP 的 Standard TCP/IP Port，並確認印表機保留 IP 或 DHCP reservation。
