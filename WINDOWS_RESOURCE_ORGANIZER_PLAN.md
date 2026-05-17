# Windows Resource Organizer Plan

Last updated: `2026-05-17`

## Goal
WindowsDoctor 的資源整理方向是高效能、低消耗、逐項執行、可預覽、可中斷、可回報。會影響使用者工作階段、Windows Update、系統檔、磁碟內容、程式移除或服務狀態的動作不得進入無條件自動修復。

## Current Coverage
| Requirement | Current status | Execution rule |
|---|---|---|
| 登出其他未使用帳號 | Partial | `Invoke-WindowsMaintenance.ps1 -ForceLogoffDisconnectedUsers` 只處理 disconnected、非目前 session、超過 idle 門檻；執行需 `RUN` |
| 釋放記憶體 | Partial | 以 resource safety、低資源啟動、工作視窗資源快照、登出 disconnected sessions 為主；不任意 kill 其他程式 |
| 釋放系統碟空間 | Partial | 目前可 preview/execute TEMP、Windows TEMP、回收桶；Windows Update cache 與 component cleanup 仍需 dry-run/rollback |
| 強制移除程式與殘留 | Not formalized | 只可先做 inventory 與 uninstall preview；不得 unattended 強制移除 |
| 同質軟體常見功能 | Reference only | 啟動項、瀏覽器快取、dump、log、大檔、重複檔案先做只讀盤點 |
| WindowsDoctor 建議控制 | Partial | 使用 sequential queue、resource snapshot、cancel、RUN gate、report-first |

## Safety Baseline
- Preview first.
- One action at a time.
- Stop on first failure.
- RUN gate for any state-changing action.
- No third-party/GitHub cleanup workflow enters formal execution before reviewed KB, dry-run evidence, rollback guidance, and allowlist review.
- Forced uninstall, registry cleanup, user profile deletion, Windows Update cache reset, component cleanup, and browser profile cleanup remain high-risk until separately reviewed.

## Near-Term Implementation
1. Add read-only resource organizer preview for session, memory, disk cleanup candidates, installed apps, startup apps, crash dumps, and large files.
2. Add GUI Resource Organizer panel with risk labels and explicit RUN-only execution.
3. Add per-action rollback guidance and evidence report.
4. Promote only low-risk WindowsDoctor-owned cleanup items first.
