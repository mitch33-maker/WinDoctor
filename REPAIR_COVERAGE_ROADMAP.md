# WindowsDoctor Repair Coverage Roadmap

Last updated: `2026-05-17`

本文件定義 WindowsDoctor 擴充可診斷、可引導、可修復問題的長期路線。目標是先達到 80% 以上常見類別覆蓋，再逐步提高，但不以犧牲安全性換取 100% 自動修復。

## 1. 覆蓋定義
| 層級 | 定義 | 是否可自動修復 |
|---|---|---|
| Diagnostic coverage | 能辨識錯誤碼、症狀、事件或外部診斷輸出 | 否 |
| Guided coverage | 能提供官方來源支持的下一步、風險與人工操作建議 | 否 |
| Auto-repair coverage | 有 reviewed KB、allowlist script、preview、RUN gate、rollback guidance | 僅低風險 |

80% 目標先以 diagnostic/guided coverage 衡量；auto-repair 只允許低風險、可回滾、已驗證項目。

## 2. 當前覆蓋基線
最新驗證：
- Report: `E:\WindowsDoctor\logs\repair-coverage-goal.final2-20260517.json`
- Component coverage: `100%`
- Microsoft official coverage: `88.89%`
- Normalized KB records: `90`
- Microsoft official reference records: `25`
- Auto-repair records: `21`

覆蓋元件：
- `windows_update`
- `system_integrity`
- `network`
- `storage`
- `boot`
- `printer`
- `application`
- `system`
- `hardware`

## 3. 官方來源優先順序
1. Microsoft Support / Microsoft Learn。
2. Windows 內建診斷輸出：SetupDiag、DISM、SFC、Get Help、Event Log。
3. Vendor official 文件。
4. Enterprise exports：Intune、Wazuh、RMM。
5. GitHub / community tools only as quarantined reference.

## 4. GitHub / 第三方處理
第三方成熟工具可用來理解常見流程，但不得直接匯入正式系統：
- `THIRD_PARTY_REPAIR_REFERENCE.md` 只作隔離參考。
- 必須先找到 Microsoft 官方對應來源。
- 必須拆成 preview-first / RUN-gated / rollback-guided 小步驟。
- 未通過本機與 USB low-resource acceptance 前不得進入 reviewed auto-repair。

## 5. 驗證命令
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Update-MicrosoftOfficialRepairSources.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\microsoft-official-sources.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Export-NormalizedKBDatabase.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\normalized-kb-export.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-NormalizedKBDatabase.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\normalized-kb-validate.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-RepairCoverageGoal.ps1 -Root E:\WindowsDoctor -TargetPercent 80 -ReportPath E:\WindowsDoctor\logs\repair-coverage-goal.latest.json -Json
```

## 6. 下一步
- 持續加入 Microsoft official reference records。
- 對真實 SetupDiag / DISM / SFC / Get Help 輸出做 diagnostic-only 匯入。
- 對高命中、低風險、可回滾的 guided 規則建立 preview-first repair candidates。
- 不追求 100% 自動修復；100% 只能作為 diagnostic/guided coverage 的長期方向。
