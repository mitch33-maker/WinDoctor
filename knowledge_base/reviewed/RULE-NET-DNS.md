---
description: "網路 DNS 與閘道解析異常 (0x80072EE7)"
---
# 網路 DNS 與閘道解析異常
- EventID/Code: 0x80072EE7
- Trigger: ["0x80072EE7", "DNS", "無法連線至網際網路", "GetAddrInfo"]
- Script: "Repair-NetworkStack.bat"

## 分析細節
本機網卡能連線至路由器，但無法將域名關聯至 IP，或是 TCP/IP 堆疊發生錯亂。
原子修復會執行 `netsh winsock reset`、`netsh int ip reset` 以及 `ipconfig /release & /renew`，徹底重置網路堆疊環境。如果使用 DHCP，請確保分享器伺服器運作正常。
