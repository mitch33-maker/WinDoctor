---
description: "Winsock 或 TCP/IP 堆疊異常"
---
# Winsock 或 TCP/IP 堆疊異常
- EventID/Code: WINSOCK_STACK
- Trigger: ["Winsock", "TCP/IP", "socket error", "WSA", "0x8007274c", "network stack"]
- Script: "Repair-NetworkStack.bat"

## 分析細節
常見於 VPN、防毒網路過濾、Proxy 或不完整解除安裝造成網路 API 失敗。可使用 allowlist 網路重置腳本修復 Winsock 與 TCP/IP，再提示使用者重新啟動電腦。
