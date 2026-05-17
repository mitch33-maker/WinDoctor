---
description: "DCOM 權限異常 (Event ID 10016)"
---
# DCOM 權限異常
- EventID/Code: 10016
- Trigger: ["DistributedCOM", "Event ID: 10016", "DCOM"]
- Script: "N/A"

## 分析細節
這是 Windows 系統中十分常見且通常屬於良性的事件日誌。當特定應用程式（如背景背景服務）嘗試以 Local Activation 權限啟動 COM 伺服器，但權限不足時便會觸發。
這並不影響系統運作，可透過登錄檔修改抑制，但微軟官方建議忽略即可。
