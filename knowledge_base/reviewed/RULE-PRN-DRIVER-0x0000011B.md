---
description: "網路印表機 0x0000011B 或 RPC 加密相容性問題"
---
# 網路印表機 0x0000011B 或 RPC 加密相容性問題
- EventID/Code: 0x0000011B
- Trigger: ["0x0000011B", "RpcAuthnLevelPrivacyEnabled", "network printer", "Windows cannot connect to the printer"]
- Script: "N/A"

## 分析細節
常見於 Windows 更新後列印伺服器與用戶端 RPC 加密政策不一致。優先建議更新列印伺服器與用戶端、改用受支援驅動；涉及降低 RPC 安全性的登錄調整不得自動套用。
