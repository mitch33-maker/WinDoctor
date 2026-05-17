---
description: "Windows 防火牆封鎖連線"
---
# Windows 防火牆封鎖連線
- EventID/Code: NET_FIREWALL_BLOCK
- Trigger: [防火牆封鎖, firewall blocked, 5152, 5157]
- Script: "N/A"

## 分析細節
防火牆封鎖常見於新程式、遠端管理、檔案分享或印表機連線。不可自動關閉防火牆；應檢查具體應用、連接埠、設定檔與企業政策。
