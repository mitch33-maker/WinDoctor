---
description: "Windows 系統檔案或 CBS 元件存放區損毀"
---
# Windows 系統檔案或 CBS 元件存放區損毀
- EventID/Code: CBS_CORRUPTION
- Trigger: ["CBS", "DISM", "SFC", "Windows Resource Protection", "The component store is repairable", "0x800f081f", "0x80073712"]
- Script: "Repair-SystemIntegrity.bat"

## 分析細節
常見於 Windows Update 失敗、系統檔案缺失、元件存放區損毀或非預期斷電後。可先引導使用者備份重要資料，接著以系統管理員權限執行 DISM 與 SFC 修復。若離線來源缺失，需提供對應版本 Windows ISO 作為修復來源。
