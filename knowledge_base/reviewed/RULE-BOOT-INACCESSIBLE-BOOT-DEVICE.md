---
description: "開機藍屏 INACCESSIBLE_BOOT_DEVICE"
---
# 開機藍屏 INACCESSIBLE_BOOT_DEVICE
- EventID/Code: INACCESSIBLE_BOOT_DEVICE
- Trigger: ["INACCESSIBLE_BOOT_DEVICE", "0x0000007B", "boot device", "storage controller", "AHCI", "RAID"]
- Script: "Repair-BCDBoot.bat"

## 分析細節
常見於儲存控制器模式變更、磁碟驅動錯誤、BCD 問題或系統磁碟故障。自動流程可在 WinRE/WinPE 引導檢查 BCD；若近期調整 BIOS AHCI/RAID，需先恢復原設定。
