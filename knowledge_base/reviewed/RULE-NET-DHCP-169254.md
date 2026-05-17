---
description: "DHCP 失敗取得 169.254 APIPA 位址"
---
# DHCP 失敗取得 169.254 APIPA 位址
- EventID/Code: APIPA_169254
- Trigger: ["169.254", "APIPA", "DHCP", "Event ID: 1001", "unable to contact your DHCP server"]
- Script: "Repair-NetworkStack.bat"

## 分析細節
表示用戶端無法從 DHCP 伺服器取得有效 IP。自動流程可重設 Winsock/IP、釋放與更新 IP；若仍失敗，引導使用者檢查網路線、Wi-Fi、交換器、路由器 DHCP 範圍與 MAC 綁定。
