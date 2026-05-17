---
ID: ENT-DRV-001
Title: 硬體驅動程式缺失或衝突 (Yellow Bang)
Tags: [Hardware, Driver, PnP]
ErrorCode: "DeviceError"
Severity: High
AutoRepair: false
Diagnostic_Logic: |
  1. Check ConfigManagerErrorCode in Win32_PnPEntity.
Remediation_Steps: scripts/Maintenance-Daily.ps1
---

# 硬體驅動程式故障

## 症狀
裝置管理員出現黃色驚嘆號，硬體無法正常運作。

## 修復指引
1. 檢查具體錯誤代碼 (如 Code 28: 缺少驅動)。
2. 使用 Windows Update 或 官方網站更新驅動。
3. 嘗試在裝置管理員中「解除安裝裝置」後重新掃描。
