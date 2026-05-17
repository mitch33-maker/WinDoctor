---
description: "Windows 開機引導 BCD 損毀 (0xc0000034)"
---
# Windows 開機引導 BCD 損毀
- EventID/Code: 0xc0000034
- Trigger: ["0xc0000034", "Boot Configuration Data", "WinPE", "開機失敗", "MBR"]
- Script: "Repair-BCDBoot.bat"

## 分析細節
(本規則設計為於 WinPE 救援環境觸發)
發生於系統啟動分區 (EFI/MBR) 中的 BCD 設定檔損毀或遺失，導致 Windows 無法載入核心。通常伴隨 BIOS 找不到開機硬碟的錯覺。
救援步驟：
1. 使用 WindowsDoctor WinPE 隨身碟開機進入命令字元。
2. 執行原子指令或手動輸入 `bootrec /fixmbr` 與 `bootrec /rebuildbcd`。
3. 若 EFI 分割區毀壞，則需執行 `bcdboot C:\Windows /s S: /f UEFI` 重建。
