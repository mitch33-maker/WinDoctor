---
ID: RES-BOOT-001
Title: Windows 引導損壞 (BCD/Winload)
Tags: [Boot, WinPE, BCD]
ErrorCode: "0xc000000f"
Severity: Critical
AutoRepair: false
Diagnostic_Logic: |
  1. Boot from WindowsDoctor PE USB.
Remediation_Steps: scripts/Repair-WDBoot.ps1
---

# Windows 引導修復 (離線)

## 症狀
開機出現藍屏或黑屏，提示 `BOOTMGR is missing` 或 `BCD Error (0xc000000f)`。

## 修復
此問題無法在本機系統內修復，必須使用 **WindowsDoctor 救援隨身碟** 開機：
1. 使用 USB 開機。
2. 系統會自動啟動診斷中心。
3. 選擇「引導修復」或執行 `Repair-WDBoot.ps1`。
