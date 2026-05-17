---
description: "印表機驅動套件不相容或安裝失敗"
---
# 印表機驅動套件不相容或安裝失敗
- EventID/Code: PRINTER_DRIVER_PACKAGE
- Trigger: ["printer driver", "Type 3", "Type 4", "driver package", "0x00000002", "0x0000007e"]
- Script: "N/A"

## 分析細節
常見於舊 Type 3 驅動、32/64 位元不相容、列印伺服器驅動版本不一致。引導使用者移除錯誤驅動後安裝原廠通用驅動或 Type 4 驅動；避免自動刪除整個 driver store。
