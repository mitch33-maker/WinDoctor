---
description: "IP 位址衝突"
---
# IP 位址衝突
- EventID/Code: NET_IP_CONFLICT
- Trigger: [IP 位址衝突, duplicate IP, address conflict, 4199]
- Script: "Repair-NetworkStack.bat"

## 分析細節
IP 衝突會造成網路斷線、連線不穩或 DNS 解析異常。若使用 DHCP，先釋放並更新租約；若使用固定 IP，需確認同網段內沒有重複設定。
