---
description: "連線共用印表機存取被拒"
---
# 連線共用印表機存取被拒
- EventID/Code: PRINTER_ACCESS_DENIED
- Trigger: ["Access is denied", "printer access denied", "Point and Print", "Package Point and Print", "0x00000005"]
- Script: "N/A"

## 分析細節
通常與印表機分享權限、Point and Print 原則、驅動安裝權限或網域政策有關。引導使用者確認伺服器分享權限與驅動簽章；不應自動放寬 Point and Print 安全限制。
