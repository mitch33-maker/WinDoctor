---
description: "系統核心檔案損毀 (CRITICAL_PROCESS_DIED)"
---
# 系統核心檔案損毀
- EventID/Code: 0x000000EF
- Trigger: ["CRITICAL_PROCESS_DIED", "藍屏", "Blue Screen", "0x000000EF"]
- Script: "Repair-SystemIntegrity.bat"

## 分析細節
關鍵的 Windows 系統行程在背景意外終止，引發藍屏 (BSOD)。
極高的機率是系統檔案如 ntoskrnl.exe 受損，或硬碟磁區發生邏輯壞軌。建議立即執行原子修復進行 `SFC /SCANNOW` 與 `DISM` 的核心映像修復程序。
