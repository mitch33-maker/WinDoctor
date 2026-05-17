---
description: "MTU 或封包碎片造成 VPN/網站連線異常"
---
# MTU 或封包碎片造成 VPN/網站連線異常
- EventID/Code: NET_MTU_FRAGMENT
- Trigger: [MTU, fragment, VPN 網站打不開, 部分網站無法連線]
- Script: "N/A"

## 分析細節
MTU 過大可能導致 VPN、PPPoE 或特定網站連線卡住。需以 ping 分段測試確認路徑 MTU，不應未確認就全域修改介面 MTU。
