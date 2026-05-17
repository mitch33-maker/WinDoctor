---
ID: ENT-PRN-001
Title: 印表機後台列印服務 (Spooler) 故障
Tags: [Printer, Spooler, Enterprise]
ErrorCode: "SpoolerStopped"
Severity: Medium
AutoRepair: true
Diagnostic_Logic: |
  1. Check if Print Spooler service is Running.
Remediation_Steps: scripts/Repair-PrinterSpooler.ps1
---

# 印表機後台列印服務故障

## 症狀
無法搜尋到印表機，或列印工作卡死在佇列中。

## 修復
重置 Spooler 服務並清理 `PRINTERS` 暫存資料夾。
