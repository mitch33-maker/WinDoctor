---
description: "遠端桌面 RDP 連線失敗"
---
# 遠端桌面 RDP 連線失敗
- EventID/Code: NET_RDP_3389
- Trigger: [RDP, 遠端桌面, 3389, CredSSP, NLA]
- Script: "N/A"

## 分析細節
RDP 失敗可能來自防火牆、NLA、服務未啟動、帳號權限或網路路由。基於安全性，不自動開啟 RDP 或放寬驗證；應由管理者確認政策後處理。
