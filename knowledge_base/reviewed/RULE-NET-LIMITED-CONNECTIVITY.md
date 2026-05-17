---
description: "網路受限或無網際網路連線"
---
# 網路受限或無網際網路連線
- EventID/Code: NET_LIMITED_CONNECTIVITY
- Trigger: [網路受限, limited connectivity, no internet, 無網際網路]
- Script: "Repair-NetworkStack.bat"

## 分析細節
Windows 顯示網路受限通常與 DHCP、DNS、預設閘道、NCSI 判斷或網卡驅動狀態有關。先確認 IP 設定與 DNS，再視需要執行網路堆疊修復。
