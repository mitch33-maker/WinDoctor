---
description: "網路印表機連線錯誤 (0x00000709 / 0x0000011B)"
---
# 網路印表機連線錯誤
- EventID/Code: 0x00000709
- Trigger: ["0x00000709", "0x0000011B", "印表機", "Print Spooler", "RPC_S_SERVER_UNAVAILABLE"]
- Script: "N/A"

## 分析細節
通常發生於 Windows 10/11 的 PrintNightmare 安全性更新後，導致 RPC 驗證失敗而無法連線至網路印表機。
建議解法：
1. 進入 `regedit` 將 `RpcAuthnLevelPrivacyEnabled` (DWORD) 設為 0。
2. 重啟 Print Spooler 服務。
3. 若仍無法連線，請檢查分享端與用戶端的網路探索是否開啟。
