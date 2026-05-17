---
description: "預設閘道遺失或路由不完整"
---
# 預設閘道遺失或路由不完整
- EventID/Code: NET_GATEWAY_MISSING
- Trigger: [無預設閘道, default gateway missing, 不能上網, 路由遺失]
- Script: "Repair-NetworkStack.bat"

## 分析細節
網卡有 IP 但沒有可用預設閘道時，常見症狀是只能連內網或完全無法上網。先檢查 DHCP、固定 IP、VPN 路由與網卡狀態；可使用網路堆疊修復重置 TCP/IP、Winsock 與 DNS 快取。
