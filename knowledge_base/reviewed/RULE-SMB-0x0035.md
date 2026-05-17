---
description: "網路共用硬碟連線失敗 (SMB 0x80070035)"
---
# 網路共用硬碟連線失敗
- EventID/Code: 0x80070035
- Trigger: ["0x80070035", "找不到網路路徑", "SMB", "共用資料夾", "NAS"]
- Script: "N/A"

## 分析細節
找不到網路路徑，多為 SMBv1 被禁用、網路探索遭 防火牆阻擋 或 NetBIOS 解析失敗所致。
解決方案：
1. 確認目標 IP 能否 Ping 通。
2. 開啟本機服務 `Function Discovery Provider Host` 與 `Function Discovery Resource Publication` 設為自動。
3. 檢查「控制台>程式和功能」是否啟用了 SMB 1.0/CIFS 檔案共用支援 (視 NAS 舊度而定，注意安全性)。
4. 清除本機 DNS 快取 `ipconfig /flushdns`。
