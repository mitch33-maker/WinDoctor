---
ID: BUG-WS-0x80070005
Title: Windows Update Access Denied (0x80070005)
Tags: [WindowsUpdate, Permission, Security]
ErrorCode: "0x80070005"
Severity: High
AutoRepair: true
Diagnostic_Logic: |
  1. Check permissions.
Remediation_Steps: scripts/Repair-WUSoftwareDistribution.ps1
---

# Windows Update 存取被拒 (0x80070005)

## 修復方法
(已啟用 AutoRepair，哨兵模式將自動重置組件)
