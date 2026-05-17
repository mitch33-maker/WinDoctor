---
description: "Windows Update 更新機制異常 (0x80244018)"
---
# Windows Update 更新機制異常
- EventID/Code: 0x80244018
- Trigger: ["0x80244018", "Windows Update", "SoftwareDistribution"]
- Script: "Repair-WUSoftwareDistribution.bat"

## 分析細節
偵測到 Windows Update 下載快取損毀或網路攔截。
系統底層的 BITS 服務或 SoftwareDistribution 資料夾可能發生鎖死。原子修復會安全地清除更新快取並重啟基礎結構服務。
