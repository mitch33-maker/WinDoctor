---
ID: HW-BIOS-001
Title: Secure Boot 未開啟 (影響 Win11 快取/安全性)
Tags: [BIOS, SecureBoot, Windows11]
ErrorCode: "SecureBootDisabled"
Severity: Medium
AutoRepair: false
Diagnostic_Logic: |
  1. Check Confirm-SecureBootUEFI status.
Remediation_Steps: scripts/Maintenance-Daily.ps1
---

# BIOS Secure Boot 引導修復

## 診斷結果
偵測到您目前的系統未開啟 Secure Boot (安全啟動)，這可能會導致部分軟體（如高階遊戲、加密軟體）無法正常運作。

## 視覺引導建議
1. 重新開機並按下 `Del` 或 `F2` 進入 BIOS。
2. 切換至 **Security** (安全) 或 **Boot** (啟動) 分頁。
3. 找到 **Secure Boot** 選項並將其設定為 **Enabled**。
4. 按下 `F10` 儲存並離開。

> [!TIP]
> 建議使用 **WindowsDoctor 手機端拍照功能** 拍下 BIOS 畫面，AI 將自動辨識您的主機板型號並高亮標註設定位置。
