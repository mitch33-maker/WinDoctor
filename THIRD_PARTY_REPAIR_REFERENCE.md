# Third Party Repair Reference Quarantine

Last updated: `2026-05-17`

本文件只保存第三方或 GitHub 成熟工具的參考方向。任何第三方流程不得直接進入 `knowledge_base\reviewed`、`offline_database\windowsdoctor-kb.json` 或 `scripts\repair-allowlist.json`。

## 1. 使用規則
- 只作為 compare/reference。
- 必須先對照 Microsoft 官方文件。
- 必須拆成 preview-first、evidence-first、RUN-gated 的小步驟。
- 未經本機驗證、回滾設計、風險分級與人工審查前，不得成為 auto-repair。

## 2. 已知參考
| 名稱 | 類型 | 可借鑑方向 | WindowsDoctor 狀態 |
|---|---|---|---|
| Reset Windows Update Tool / wureset | GitHub / Windows Update reset toolkit | Windows Update components reset、SFC、DISM、服務重啟流程 | `community_unverified` reference only |
| PSWindowsUpdate | PowerShell module | Windows Update 查詢、下載、安裝、隱藏更新的操作模型 | `community_unverified` reference only |
| AdminScripts | GitHub admin scripts | Windows Update history、Store、package 操作範例 | `community_unverified` reference only |

## 3. 晉升條件
1. 找到對應 Microsoft 官方文件。
2. 建立 diagnostic-only finding 或 guided rule。
3. 建立 dry-run / preview 輸出。
4. 加入 rollback guidance。
5. 通過本機測試與 USB low-resource acceptance。
6. 人工審查後才可考慮 allowlist；預設不允許自動修復。
