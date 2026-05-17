---
description: "WinHTTP Proxy 或系統 Proxy 設定造成連線失敗"
---
# WinHTTP Proxy 或系統 Proxy 設定造成連線失敗
- EventID/Code: WINHTTP_PROXY
- Trigger: ["WinHTTP", "proxy", "0x80072EFD", "0x80072EE2", "407 Proxy Authentication Required", "proxy server isn't responding"]
- Script: "Repair-NetworkStack.bat"

## 分析細節
常見於公司代理伺服器、VPN、惡意軟體或舊 Proxy 設定殘留。自動修復可重設 WinHTTP/網路堆疊；若為公司環境，需引導使用者確認合法 Proxy 位址與認證。
