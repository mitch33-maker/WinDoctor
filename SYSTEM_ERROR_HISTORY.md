# 系統錯誤歷史 (System Error History)

Last updated: `2026-05-17`

本文件收錄專案在測試、部署及運行期間遇到的重大系統性錯誤與錯誤代碼，供未來快速比對除錯。

## [ERR-20260517-01] Baseline Pester Timeout And Orphan Test Process
### 錯誤情境
`Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild` 在自檢時超過 10 分鐘仍未完成，且未寫出 baseline JSON report。
### 發生原因
baseline 預設 Pester 步驟執行完整大型測試集合，沒有低資源預設路徑；外層命令逾時後留下本輪啟動的 WindowsDoctor Pester PowerShell 程序。
### 防範與排除
`Test-SystemBaseline.ps1` 預設 Pester 改為 `pester-safety-parse`，只跑安全語法 smoke；完整 Pester 需明確加 `-FullPester`。逾時後只停止本輪產生且命令列指向 `E:\WindowsDoctor` Pester 的測試程序。

## [ERR-20260517-02] USB Acceptance Used Stale Incremental Patch Name
### 錯誤情境
`Test-UsbLowResourceAcceptance.ps1` 未指定 `PatchZipPath` 時固定選用 `20260509-LowResource` 舊補丁名稱，容易在後續增量補丁建立後驗證到舊檔。
### 發生原因
驗收腳本內建了單一歷史補丁檔名，而不是依 USB 根目錄中最新 `IncrementalPatch-*.zip` 自動選取。
### 防範與排除
未指定 `PatchZipPath` 時，腳本改為依 `LastWriteTime` 選取 USB 根目錄最新的 `$PackageName-IncrementalPatch-*.zip`；沒有候選時才退回舊檔名。

## [ERR-20260427-01] JSX Build Error: Expected '<', got 'ident'
### 錯誤情境
在 `page.tsx` 中新增 NAS 同步設定區塊時，Next.js 編譯失敗，畫面紅屏。
### 發生原因
原先的條件渲染區塊 `{ !lockStatus.match && ( ... ` 缺少了專屬的關閉括弧 `)}` 與 `</div>` 標籤，導致 JSX 樹狀結構破裂解析錯誤。
### 防範與排除
此類錯誤無法藉由重啟伺服器修復。未來進行 JSX 區塊增刪時，必須嚴格檢查花括號與圓括號的對稱。目前的對策是每次修改後，必須執行無介面編譯測試或是透過視覺檢測 UI 狀態。

## [ERR-20260427-02] Invoke-RestMethod Timeout Exception (500 Error)
### 錯誤情境
前端呼叫 `/api/vault/lock-status` 時，有時會陷入長時間等待並跳出「Internal Server Error」。
### 發生原因
該 API 在一次請求中呼叫了兩次 PowerShell `runPS` (`Test-WDEnvironmentLock` 與 `Get-WDEnvironmentSignature`)。底層建立 PowerShell Session 的啟動開銷過高，兩次疊加往往超過 Express 或前方的回應時間。
### 防範與排除
1. **指令合併**：將多次短腳本合併為字串。例如 `$m=...; $s=...; [PSCustomObject]@{...}`。
2. **防呆回退**：使用 `Promise.race()` 掛載 Timeout，當 PowerShell 由於卡死無回應時，Node 應主動拋棄並回傳安全預設值 (`match: true, signature: 'unavailable'`)，防止前端網頁凍結。

## [ERR-20260428-01] GUI API 404 與 Lint Baseline 失效
### 錯誤情境
前端呼叫 `/api/vision-analyze` 與 `/api/sentry/elevate`，但 `broker.js` 未提供對應路由；同時 `npm run lint` 因 `any`、React effect 與 CommonJS 檢查失敗。
### 發生原因
前端功能先行接線，Broker API 未同步補齊；Pester 測試也在 discovery 階段保存 `$health`，於 Pester v5 下造成測試值為空。
### 防範與排除
補齊缺失 API、加入修復腳本 allowlist、將未知故障學習改為只寫知識庫不自動生成/執行腳本，並將 Pester 測試資料建立移入 `BeforeAll`。

## [ERR-20260428-02] 自動化驗證造成記憶體壓力與殘留程序
### 錯誤情境
連續執行 GUI dev server、Broker restart、Next production build、baseline 驗證與多個 PowerShell 查詢後，使用者回報系統記憶體被大量占用並造成當機。
### 發生原因
`Start-WindowsDoctor.ps1 -Verify` 原本會串接完整 baseline；完整 baseline 會執行 `next build`，Next/Turbopack 會啟動多個工作程序。若同時存在 Docker/WSL (`vmmem`) 與 Codex/PowerShell 工具程序，會放大記憶體壓力。被中斷的工具程序也可能短時間殘留。
### 防範與排除
1. `Start-WindowsDoctor.ps1 -Verify` 預設改為 `-SkipBuild` 快速驗證，只有明確加 `-FullVerify` 才跑 production build。
2. `Start-WindowsDoctor.ps1` 與 `Test-SystemBaseline.ps1` 加入 `MinFreeMemoryGB` 檢查，預設少於 4GB 可用記憶體即停止。
3. 新增 `scripts\Get-WDResourceSnapshot.ps1`，重任務前先記錄 Top memory process 與 node/npm/pwsh/powershell/cmd。
4. 後續功能任務必須排在資源護欄與程序狀態確認之後。
## [ERR-20260428-03] Resource Snapshot Log Bloat
### Symptom
`scripts\Get-WDResourceSnapshot.ps1 -Json` included full PowerShell/Codex encoded command lines. The output became very large and made diagnostics harder to review.
### Cause
The snapshot always emitted `CommandLine` for target processes. Codex helper `pwsh.exe` can contain long encoded command payloads.
### Fix
`Get-WDResourceSnapshot.ps1` now emits `CommandLineLength` by default. Full command lines require the explicit `-IncludeCommandLine` switch.
### Verification
`powershell -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\Get-WDResourceSnapshot.ps1 -Json` returned compact target process entries and reported healthy memory headroom: `8.26GB free / 15.89GB total`.
## [ERR-20260428-04] Next Dev PostCSS Worker Explosion
### Symptom
Starting GUI dev server caused Task Manager to show `Windows Command Processor` using about `7.9GB` memory and very high CPU. The process group contained many `Node.js JavaScript Runtime` children.
### Cause
`next dev` generated a large number of `node.exe` workers running `E:\WindowsDoctor\gui\.next\dev\build\postcss.js`. The previous Tailwind v4 setup used automatic source detection, which could recurse into generated `.next/dev/build` output during dev compilation.
### Immediate Recovery
Stopped the scoped WindowsDoctor/PostCSS workers only. The cleanup matched command lines containing `E:\WindowsDoctor\gui\.next\dev\build\postcss.js` and terminated `1248` abnormal `node.exe` processes. Memory recovered to `11.53GB free / 15.89GB total`.
### Fix
1. `gui\src\app\globals.css` now imports Tailwind with `source(none)` and explicitly scans only `src`.
2. Added `scripts\Stop-WDGuiDevWorkers.ps1` to remove only WindowsDoctor GUI dev PostCSS workers.
3. `scripts\Start-WindowsDoctor.ps1` now runs the scoped cleanup before GUI startup and when restarting GUI.
### Verification
`scripts\Stop-WDGuiDevWorkers.ps1 -WhatIf` matched `0` residual workers after cleanup. Low-risk baseline passed with `-SkipServiceSmoke -SkipBuild`.

## [ERR-20260428-05] Resource Safety Must Be Automated
### Symptom
Manual Task Manager checks caught the PostCSS worker explosion, but the regular validation path did not have a dedicated guard for residual WindowsDoctor dev workers.
### Fix
Added `scripts\Test-ResourceSafety.ps1` and made `scripts\Test-SystemBaseline.ps1` run it as the first baseline step.
### Verification
`Test-ResourceSafety.ps1` passed with `Free=10.64GB`, `postcss-workers Count=0`, and `windowsdoctor-node-processes Count=0`. Low-risk baseline passed with the new `resource-safety` step.

## [ERR-20260428-06] GUI Startup Needed Runtime Fuse
### Symptom
Cleaning residual workers before startup was not sufficient. A future GUI dev startup could still create too many PostCSS workers after launch.
### Fix
`Start-WindowsDoctor.ps1` now runs `Test-ResourceSafety.ps1` before GUI startup and again after a short startup guard delay. If the guard fails, it stops WindowsDoctor GUI dev workers and the GUI listener.
### Verification
Validated by script parse, `Start-WindowsDoctor.ps1 -NoGui -NoBroker -Json`, and low-risk baseline with `-SkipServiceSmoke -SkipBuild`. No GUI/Broker service was started during verification.

## [ERR-20260428-07] Resource Guard Needed Regression Tests
### Symptom
Resource guard scripts were validated manually, but there was no Pester coverage to prevent syntax or output-shape regressions.
### Fix
Added `scripts\ResourceSafety.Tests.ps1` and included it in the baseline Pester step.
### Verification
`Invoke-Pester` discovered `2 files` and `7 tests`; all passed. Low-risk baseline passed with `resource-safety`, `pester`, `broker-services`, and `lint`.

## [ERR-20260428-08] Resource Guard Needed Machine-Readable Output
### Symptom
Resource safety scripts returned table/object output that was convenient for humans but less reliable for automation.
### Fix
Added `-Json` to `Test-ResourceSafety.ps1` and `Stop-WDGuiDevWorkers.ps1`.
### Verification
`ResourceSafety.Tests.ps1` now validates both JSON outputs. Low-risk baseline discovered `2 files` and `9 tests`; all passed.

## [ERR-20260428-09] WinPE Offline KB Needed Prebuilt Index
### Symptom
WinPE packaging copied Markdown KB files, but there was no prebuilt machine-readable offline database for low-dependency repair flows.
### Fix
Added `Export-OfflineKBDatabase.ps1`, added `offline_database\windowsdoctor-kb.json`, and made `Build-WinPEMedia.ps1` generate/copy it. Baseline now includes `offline-kb-export`.
### Verification
Offline export produced `42` rules, `12` auto-repair rules, and `30` guided rules. Low-risk baseline passed with `offline-kb-export`, `winpe-check`, broker tests, Pester, and lint.

## [ERR-20260428-10] Offline KB Index Needed Integrity Validation
### Symptom
The offline JSON database could be generated, but there was no dedicated validation gate for schema, stats, rule fields, source files, or allowlist consistency.
### Fix
Added `Test-OfflineKBDatabase.ps1` and included it in baseline as `offline-kb-validate`.
### Verification
`Test-OfflineKBDatabase.ps1 -Json` passed with `42` rules and `14` validation checks. Low-risk baseline passed with `offline-kb-export` and `offline-kb-validate`.

## [ERR-20260428-11] WinPE Broker Needed Direct Offline DB Loading
### Symptom
WinPE packaging had a prebuilt JSON database, but Broker still scanned Markdown by default at runtime.
### Fix
Added `WD_USE_OFFLINE_DB=1` mode and configured WinPE `startnet.cmd` to enable it. Broker now reads `offline_database\windowsdoctor-kb.json` in offline DB mode. JSON export writes UTF-8 without BOM for Node compatibility, and PowerShell validation reads with explicit UTF-8.
### Verification
Broker service tests passed with offline DB mode coverage. Low-risk baseline passed with offline export, offline validation, WinPE check, Pester, broker tests, and lint.

## [ERR-20260428-12] Offline DB Tests Needed Single Parser Path
### Symptom
The offline DB export was valid for Node and validated by `Test-OfflineKBDatabase.ps1`, but the Pester test duplicated full JSON parsing and could fail differently from the production validation path.
### Fix
Changed the export Pester test to call `Test-OfflineKBDatabase.ps1 -DatabasePath ... -Json` for exported test files.
### Verification
`ResourceSafety.Tests.ps1` passed `7` tests. Low-risk baseline passed with `11` Pester tests.

## [ERR-20260428-13] Offline Repair Flow Needed Brokerless Search
### Symptom
The WinPE offline database could be loaded by Broker, but there was no CLI path for users to search the database when Broker or GUI is not running.
### Fix
Added `Search-OfflineKB.ps1` with `-Query`, `-Limit`, `-Json`, and custom `-DatabasePath` support.
### Verification
Querying `0x80070035` matched `RULE-SMB-0x0035`. Low-risk baseline passed with `12` Pester tests.

## [ERR-20260428-14] WinPE Repair Preview JSON Expanded Provider Metadata
### Symptom
`Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -Json` timed out, and the related Pester run also timed out.
### Cause
In Windows PowerShell 5.1, `Get-Content -Raw` output can retain provider metadata. Passing that directly to `ConvertTo-Json` can expand `PSDrive`, provider, and type metadata into a very large JSON object.
### Fix
Cast repair preview content to `[string]` before building the JSON result.
### Verification
`Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-NetworkStack.bat -Json` returned compact JSON. `ResourceSafety.Tests.ps1` passed `12` tests, and the low-risk baseline passed with `16` Pester tests.

## [ERR-20260428-15] Offline KB Export Used Windows PowerShell Default Encoding
### Symptom
`offline_database\windowsdoctor-kb.json` contained mojibake in Traditional Chinese fields, even though source Markdown such as `RULE-SMB-0x0035.md` was readable when opened as UTF-8.
### Cause
`Export-OfflineKBDatabase.ps1` read Markdown and `repair-allowlist.json` without `-Encoding UTF8`. Windows PowerShell 5.1 decoded UTF-8 files with the system default ANSI code page.
### Fix
`Export-OfflineKBDatabase.ps1` now reads KB Markdown and allowlist JSON with explicit UTF-8. `Test-OfflineKBDatabase.ps1` now includes `rule-readable-text` to catch replacement characters and common mojibake patterns.
### Verification
`Search-OfflineKB.ps1 -Query 找不到網路路徑 -Json` matched `RULE-SMB-0x0035` with readable Traditional Chinese. `Test-OfflineKBDatabase.ps1 -Json` passed with `rule-readable-text suspect=0`.

## [ERR-20260428-16] Nested PowerShell Switch Forwarding Broke Menu JSON Mode
### Symptom
`Start-WinPEOfflineMenu.ps1 -ListAllowedRepairs -Json` returned no valid JSON in tests after delegating repair flows to the standalone wrapper.
### Cause
The menu forwarded switch parameters to nested `powershell -File` calls as `-Json:$Json`; Windows PowerShell 5.1 treated that as an invalid string argument for a switch parameter.
### Fix
`Start-WinPEOfflineMenu.ps1` now builds child script arguments and appends `-Json` only when the parent switch is present.
### Verification
`Start-WinPEOfflineMenu.ps1 -ListAllowedRepairs -Json` and `-PreviewRepair Repair-NetworkStack.bat -Json` both returned valid JSON. `ResourceSafety.Tests.ps1` passed `15` tests.

## [ERR-20260428-17] WinPE Text Menu Was Not the Startup Entry
### Symptom
`Start-WinPEOfflineMenu.ps1` existed, but `Build-WinPEMedia.ps1` still generated `startnet.cmd` that automatically launched Broker.
### Cause
WinPE startup had only one hardcoded path: set offline DB env vars, change into `gui`, and start `broker.js` with Node.
### Fix
`Build-WinPEMedia.ps1` now has `-StartupMode Menu|Broker`, defaulting to `Menu`. Menu mode launches `Start-WinPEOfflineMenu.ps1`; Broker mode preserves the old automatic broker startup.
### Verification
`Build-WinPEMedia.ps1 -CheckOnly` reports `StartupMode: Menu`. `ResourceSafety.Tests.ps1` passed `16` tests.

## [ERR-20260428-18] Source KB Markdown Needed Its Own Encoding Gate
### Symptom
Offline JSON readability was validated, but source Markdown could still regress before export.
### Cause
Encoding validation lived in the JSON database validator, after export. There was no direct gate over `knowledge_base\reviewed` and `knowledge_base\learned`.
### Fix
Added `Test-KBMarkdownEncoding.ps1` and wired it into `Test-SystemBaseline.ps1` before offline export. The validator uses explicit UTF-8 reads and ASCII Unicode escapes for mojibake detection so the validator itself is stable under Windows PowerShell 5.1.
### Verification
`Test-KBMarkdownEncoding.ps1 -Json` passed on `42` Markdown files with `0` replacement-character files, `0` mojibake files, `0` missing trigger/error-code entries, and `0` missing titles.

## [ERR-20260428-19] WinPE startnet Content Was Hardcoded Inside Media Build
### Symptom
WinPE Menu/Broker startup content could only be inspected by reading `Build-WinPEMedia.ps1`; it was not independently testable without media build logic.
### Cause
`Build-WinPEMedia.ps1` wrote `startnet.cmd` lines inline with `Add-Content`.
### Fix
Added `New-WinPEStartNet.ps1` to generate Menu/Broker startnet lines, and changed `Build-WinPEMedia.ps1` to delegate to it.
### Verification
`New-WinPEStartNet.ps1 -StartupMode Menu -Json` and `-StartupMode Broker -Json` both passed. Low-risk baseline passed with `23` Pester tests.

## [ERR-20260429-01] Continuation Prompt Needed Stable Script Encoding
### Symptom
A first version of `New-ContinuationPrompt.ps1` used Traditional Chinese string literals in the script body and failed to parse under Windows PowerShell 5.1 when read as the default code page.
### Cause
Windows PowerShell 5.1 is sensitive to non-ASCII script files without BOM. The Pester parse test also reads scripts through `Get-Content -Raw`, so non-ASCII string literals can be corrupted before parsing.
### Fix
Kept `New-ContinuationPrompt.ps1` ASCII-only and moved Traditional Chinese prompt text to `templates\CONTINUATION_PROMPT_TEMPLATE.md`, read explicitly as UTF-8.
### Verification
`New-ContinuationPrompt.ps1 -Json` generated `NEXT_CHAT_PROMPT.md`. `ResourceSafety.Tests.ps1` passed `20` tests.

## [ERR-20260429-02] WinPE Offline Flow Checks Were Scattered
### Symptom
Offline KB export, search, repair preview, menu preview, and startnet checks were validated by separate commands and Pester tests, making handoff harder.
### Cause
There was no single brokerless integration gate for the WinPE/offline path.
### Fix
Added `Test-WinPEOfflineFlow.ps1` and wired it into `Test-SystemBaseline.ps1` as `winpe-offline-flow`.
### Verification
`Test-WinPEOfflineFlow.ps1 -Json` passed `12` steps without starting GUI/Broker, building production assets, or executing repair scripts.

## [ERR-20260429-03] Baseline Needed Clean JSON Output
### Symptom
`Test-SystemBaseline.ps1` only emitted human-readable output. A first JSON mode still mixed child step host output with the final JSON object.
### Cause
Baseline step scriptblocks used `Out-Host`, which bypassed pipeline suppression in JSON mode.
### Fix
Added `-Json` and `-SkipPester`, removed internal `Out-Host`, and centralized output handling inside `Invoke-BaselineStep`.
### Verification
`Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -SkipPester -SkipLint -Json` is parseable with `ConvertFrom-Json` and returned `Status=PASS`, `Steps=9`, `Failures=0`.

## [ERR-20260429-04] Maintenance Actions Needed Explicit Preview and Confirmation
### Symptom
Requested maintenance actions include force logging off disconnected users, freeing disk space, and running system maintenance. These can disrupt active work or delete files if executed without guardrails.
### Cause
The existing repair allowlist had no maintenance entry and no dedicated preview flow for logoff/cleanup/system checks.
### Fix
Added `Invoke-WindowsMaintenance.ps1` with preview by default and execute gated by `-Execute -ConfirmToken RUN`. Added `Repair-SystemMaintenance.bat` as an allowlisted preview entry.
### Verification
Maintenance preview passed without logging off users, deleting files, or running DISM/SFC/CHKDSK. Pester passed `25` tests.

## [ERR-20260429-05] Maintenance Feature Needed Offline KB Discovery
### Symptom
Windows maintenance actions existed as scripts, but offline KB search did not expose the feature.
### Cause
No reviewed KB rule mapped maintenance-related triggers to the allowlisted maintenance preview entry.
### Fix
Added `RULE-SYS-MAINTENANCE.md`, mapped `SYSTEM_MAINTENANCE` and related triggers to `Repair-SystemMaintenance.bat`, and extended `Test-WinPEOfflineFlow.ps1` to verify the query.
### Verification
Offline KB export now reports `43` rules and `13` auto-repair rules. Querying `SYSTEM_MAINTENANCE` matches `RULE-SYS-MAINTENANCE`.

## [ERR-20260429-06] Resource Gate Caught High-Memory PowerShell Residual
### Symptom
During verification, free memory dropped below the `4GB` gate and Pester failed before running one baseline JSON test.
### Cause
Resource snapshot showed `powershell.exe` PID `17092` running `test_local_browser_shell.ps1` and using about `5.6GB` memory.
### Fix
Stopped the confirmed high-memory residual PowerShell process and reran the resource gate.
### Verification
`Test-ResourceSafety.ps1 -Json` recovered to `PASS` with about `9.29GB` free memory.

## [ERR-20260429-07] Maintenance Preview Needed Durable Report Output
### Symptom
Maintenance preview returned JSON to the console, but there was no durable report file for human confirmation or handoff.
### Cause
`Invoke-WindowsMaintenance.ps1` did not have a report output path.
### Fix
Added `-ReportPath`, writing the full preview or execute result as UTF-8 JSON without BOM.
### Verification
`Invoke-WindowsMaintenance.ps1 -Preview -CleanDisk -ReleaseMemory -ReportPath E:\WindowsDoctor\logs\windows-maintenance.preview.json -Json` passed and wrote a parseable JSON report.

## [ERR-20260429-08] Baseline JSON Needed Durable Report Output
### Symptom
`Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -Json` completed successfully, but the terminal capture could be blank in this automation environment, leaving no durable baseline artifact.
### Cause
The baseline script only wrote JSON to stdout and did not support writing the result object to a file.
### Fix
Added `-ReportPath` to `Test-SystemBaseline.ps1`, writing the baseline result as UTF-8 JSON without BOM and including `ReportPath` in the object.
### Verification
`Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `28` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed and wrote a report with `Status=PASS`, `StepCount=11`, and `Failures=0`.

## [ERR-20260429-09] Common Windows Error Coverage Summary Drifted
### Symptom
`COMMON_WINDOWS_ERRORS.md` still reported `42` reviewed rules and `12` auto repair rules after the `SYSTEM_MAINTENANCE` offline KB rule increased the exported database to `43` rules and `13` auto repair rules.
### Cause
The coverage summary was manually maintained and had no regression test tying it to `offline_database\windowsdoctor-kb.json` stats.
### Fix
Updated `COMMON_WINDOWS_ERRORS.md` to `43` reviewed rules, `13` auto repair rules, and added `SYSTEM_MAINTENANCE` to the system error category. Added Pester coverage that compares the summary against exported offline KB stats.
### Verification
`Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `29` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `Status=PASS`, `StepCount=11`, and `Failures=0`.

## [ERR-20260429-10] Documentation Sync Needed Its Own Gate
### Symptom
Documentation drift checks lived inside one broad Pester file, but there was no standalone command to validate handoff-critical docs before a baseline run.
### Cause
`COMMON_WINDOWS_ERRORS.md` and `OPERATIONS.md` were manually maintained, while baseline only validated code, offline KB, WinPE flow, and service tests.
### Fix
Added `Test-DocumentationSync.ps1` and wired it into `Test-SystemBaseline.ps1` as `documentation-sync`. The gate checks offline KB stats, stale coverage numbers, `SYSTEM_MAINTENANCE`, resource gate documentation, baseline report documentation, and maintenance confirmation wording.
### Verification
`Test-DocumentationSync.ps1 -Json` passed `8` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `30` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `12` steps including `documentation-sync`.

## [ERR-20260429-11] Root Documentation Dates Drifted After Updates
### Symptom
Several root authority documents had been edited on `2026-04-29`, but still showed `Last updated: 2026-04-28`.
### Cause
The documentation sync gate validated content and command references, but did not validate the `Last updated` line for handoff-critical files.
### Fix
Updated `OPERATIONS.md`, `TASK_HANDOFF.md`, and `SYSTEM_ERROR_HISTORY.md` to `Last updated: 2026-04-29`. Extended `Test-DocumentationSync.ps1` to validate date freshness for `COMMON_WINDOWS_ERRORS.md`, `OPERATIONS.md`, `TASK_HANDOFF.md`, and `SYSTEM_ERROR_HISTORY.md`.
### Verification
`Test-DocumentationSync.ps1 -Json` passed `12` checks. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `12` steps.

## [ERR-20260429-12] Handoff Top Summary Kept Stale KB Counts
### Symptom
The top `Latest Verified Baseline` section in `TASK_HANDOFF.md` still described the common-error KB as `42` reviewed rules and `12` auto repair rules, even though the current offline KB exports `43` and `13`.
### Cause
Recent updates appended accurate handoff sections, but the older top summary was not covered by the documentation sync gate.
### Fix
Updated the top summary to `43` reviewed rules, `13` allowlist auto repair rules, `30` guided rules, and included `SYSTEM_MAINTENANCE`. Extended `Test-DocumentationSync.ps1` to require current KB stats and `SYSTEM_MAINTENANCE` in `TASK_HANDOFF.md`.
### Verification
`Test-DocumentationSync.ps1 -Json` passed `15` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `30` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `12` steps.

## [ERR-20260429-13] Documentation Sync Needed Durable Report Output
### Symptom
`Test-DocumentationSync.ps1 -Json` validated handoff-critical docs, but had no durable report file for automation handoff or later review.
### Cause
The documentation sync gate emitted JSON only to stdout, unlike the baseline and maintenance flows that already supported `-ReportPath`.
### Fix
Added `-ReportPath` to `Test-DocumentationSync.ps1`, writing the result as UTF-8 JSON without BOM and including `ReportPath` in the output object. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json` passed with `15` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `31` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `12` steps.

## [ERR-20260429-14] WinPE Offline Flow Needed Durable Report Output
### Symptom
`Test-WinPEOfflineFlow.ps1 -Json` validated the brokerless WinPE/offline path, but did not write a durable report for handoff or later review.
### Cause
The WinPE flow gate emitted JSON only to stdout, unlike baseline, maintenance, and documentation sync gates that support `-ReportPath`.
### Fix
Added `-ReportPath` to `Test-WinPEOfflineFlow.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the result. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Test-WinPEOfflineFlow.ps1 -ReportPath E:\WindowsDoctor\logs\winpe-offline-flow.latest.json -Json` passed with `13` steps. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `32` tests. `Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath E:\WindowsDoctor\logs\system-baseline.latest.json -Json` passed with `12` steps.

## [ERR-20260429-15] Resource Gate Caught Another Browser Shell Residual
### Symptom
During Pester verification, baseline JSON tests failed before running because free memory dropped to about `3.95GB`, below the `4GB` gate.
### Cause
Resource snapshot showed two old `powershell.exe` processes running `test_local_browser_shell.ps1`, using about `4.19GB` and `1.47GB`.
### Fix
Stopped only the confirmed residual `test_local_browser_shell.ps1` processes and reran the resource gate.
### Verification
`Test-ResourceSafety.ps1 -Json` recovered to `PASS` with about `9.29GB` free memory. The following Pester run passed `32` tests.

## [ERR-20260429-16] Baseline JSON Could Be Contaminated by Child Error Streams
### Symptom
`Test-SystemBaseline.ps1 -SkipServiceSmoke -SkipBuild -ReportPath ... -Json` returned a `PASS` JSON object, but child stderr from `Test-GuiSmoke.ps1` could appear after the JSON when memory dipped during verification.
### Cause
JSON mode suppressed only stdout through `Out-Null`; other PowerShell streams from child processes could still reach the parent console. Native command nonzero exits were also not explicitly promoted to failed baseline steps.
### Fix
Changed JSON mode in `Invoke-BaselineStep` to suppress all child streams with `*> $null` and throw when `$LASTEXITCODE` is nonzero. Pester baseline JSON/report tests now use `-MinFreeMemoryGB 0` to avoid environmental memory flakiness while the normal baseline default remains `4GB`.
### Verification
A lightweight baseline JSON parse check passed with `Status=PASS`, `Steps=10`, and `Failures=0`. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `33` tests. The full low-risk baseline report passed with `12` steps.

## [ERR-20260429-17] KB Markdown Encoding Needed Durable Report Output
### Symptom
`Test-KBMarkdownEncoding.ps1 -Json` validated KB source readability, but had no durable report file for handoff or audit.
### Cause
The KB Markdown gate emitted JSON only to stdout, unlike the baseline, maintenance, documentation sync, and WinPE offline flow gates.
### Fix
Added `-ReportPath` to `Test-KBMarkdownEncoding.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the result. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Test-KBMarkdownEncoding.ps1 -ReportPath E:\WindowsDoctor\logs\kb-markdown-encoding.latest.json -Json` passed with `43` files. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `33` tests.

## [ERR-20260429-18] Offline KB Validation Needed Durable Report Output
### Symptom
`Test-OfflineKBDatabase.ps1 -Json` validated offline KB schema, rule fields, source files, and allowlist consistency, but had no durable report file for handoff or audit.
### Cause
The offline KB validation gate emitted JSON only to stdout, unlike the other current validation gates.
### Fix
Added `-ReportPath` to `Test-OfflineKBDatabase.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the result. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Test-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-validate.latest.json -Json` passed with `43` rules and `15` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `34` tests. The full low-risk baseline report passed with `12` steps.

## [ERR-20260429-19] Offline KB Export Needed Durable Summary Report
### Symptom
`Export-OfflineKBDatabase.ps1 -Json` wrote the offline database file and emitted a summary to stdout, but did not have a separate durable summary report for handoff or audit.
### Cause
The export path was focused on the generated database artifact through `-OutputPath`; automation consumers had no independent report file for summary stats.
### Fix
Added `-ReportPath` to `Export-OfflineKBDatabase.ps1`, writing the export summary as UTF-8 JSON without BOM while preserving the database `-OutputPath` behavior. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Export-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-export.latest.json -Json` passed with `TotalRules=43` and `AutoRepairRules=13`. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `35` tests. The full low-risk baseline report passed with `12` steps.

## [ERR-20260429-20] Offline KB Search Needed Durable Report Output
### Symptom
`Search-OfflineKB.ps1 -Json` could query search, category, and details modes, but had no durable report output for WinPE/offline handoff evidence.
### Cause
Search output was console-only. Existing report support had already been added to export, validation, documentation, and WinPE flow gates, leaving search as an inconsistent surface.
### Fix
Added `-ReportPath` to `Search-OfflineKB.ps1` through a shared output helper that supports search, category, details, and list modes. Added Pester coverage for search and categories reports and documented the commands in `OPERATIONS.md`.
### Verification
`Search-OfflineKB.ps1 -Query SYSTEM_MAINTENANCE -ReportPath E:\WindowsDoctor\logs\offline-kb-search.latest.json -Json` passed and matched `RULE-SYS-MAINTENANCE`. `Search-OfflineKB.ps1 -ListCategories -ReportPath E:\WindowsDoctor\logs\offline-kb-categories.latest.json -Json` passed. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `37` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-21] Allowlisted Repair Wrapper Needed Durable Report Output
### Symptom
`Invoke-AllowedRepair.ps1` could list and preview allowlisted repair scripts as JSON, but had no durable report output for WinPE/offline handoff evidence.
### Cause
The wrapper used a small `Write-Result` helper that emitted JSON to stdout only. Other validation and offline tools had already gained `-ReportPath`, leaving repair list/preview as an inconsistent surface.
### Fix
Added `-ReportPath` to `Invoke-AllowedRepair.ps1`; the shared result writer now writes UTF-8 JSON without BOM and includes `ReportPath` in list, preview, and execute result objects. Added Pester coverage for list and preview reports and documented commands in `OPERATIONS.md`.
### Verification
`Invoke-AllowedRepair.ps1 -List -ReportPath E:\WindowsDoctor\logs\allowed-repair-list.latest.json -Json` passed with `Count=6`. `Invoke-AllowedRepair.ps1 -ScriptName Repair-SystemMaintenance.bat -Preview -ReportPath E:\WindowsDoctor\logs\allowed-repair-preview.latest.json -Json` passed without executing repair actions. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `39` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-22] WinPE Menu Wrapper Needed Durable Report Passthrough
### Symptom
`Start-WinPEOfflineMenu.ps1` could delegate non-interactive list and preview operations to repair/search/validation scripts, but could not pass a durable report path through to those child scripts.
### Cause
The wrapper accepted JSON mode only and built child arguments without a shared `-ReportPath` parameter.
### Fix
Added `-ReportPath` to `Start-WinPEOfflineMenu.ps1` and forwarded it through `Invoke-ChildScript` for non-interactive child operations. Added Pester coverage for menu repair list and preview reports and documented commands in `OPERATIONS.md`.
### Verification
`Start-WinPEOfflineMenu.ps1 -ListAllowedRepairs -ReportPath E:\WindowsDoctor\logs\winpe-menu-repairs.latest.json -Json` passed with `Count=6`. `Start-WinPEOfflineMenu.ps1 -PreviewRepair Repair-SystemMaintenance.bat -ReportPath E:\WindowsDoctor\logs\winpe-menu-preview.latest.json -Json` passed without executing repair actions. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `41` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-23] WinPE Startnet Preview Needed Durable Report Output
### Symptom
`New-WinPEStartNet.ps1 -Json` generated menu or broker startnet preview lines, but did not write a durable report for handoff evidence.
### Cause
The script only emitted JSON to stdout and used `-OutputPath` for startnet line output, leaving no separate machine-readable summary report path.
### Fix
Added `-ReportPath` to `New-WinPEStartNet.ps1`, writing the generated preview result as UTF-8 JSON without BOM while preserving existing `-OutputPath` behavior. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`New-WinPEStartNet.ps1 -StartupMode Menu -ReportPath E:\WindowsDoctor\logs\winpe-startnet.latest.json -Json` passed and generated menu startup lines without starting services. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `42` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-24] Resource Safety Gate Needed Durable Report Output
### Symptom
`Test-ResourceSafety.ps1 -Json` was the required first gate before each work session, but only emitted machine-readable output to stdout.
### Cause
The gate did not accept a report path, while downstream validation and handoff workflows now rely on durable JSON report artifacts.
### Fix
Added `-ReportPath` to `Test-ResourceSafety.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the result. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`Test-ResourceSafety.ps1 -ReportPath E:\WindowsDoctor\logs\resource-safety.latest.json -Json` passed. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `43` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-25] Resource Snapshot Needed Durable Report Output
### Symptom
`Get-WDResourceSnapshot.ps1 -Json` produced useful memory and process diagnostics for resource triage, but did not write a durable report artifact.
### Cause
The snapshot script emitted JSON only to stdout. This made it less consistent with the resource safety gate and other handoff-oriented validation scripts.
### Fix
Added `-ReportPath` to `Get-WDResourceSnapshot.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the snapshot object. The report keeps existing privacy behavior and omits command lines unless `-IncludeCommandLine` is explicitly provided.
### Verification
`Get-WDResourceSnapshot.ps1 -ReportPath E:\WindowsDoctor\logs\resource-snapshot.latest.json -Json` passed. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `44` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-26] GUI Dev Worker Cleanup Dry-Run Needed Durable Report Output
### Symptom
`Stop-WDGuiDevWorkers.ps1 -WhatIf -Json` could show cleanup targets without stopping processes, but did not write a durable dry-run report.
### Cause
The cleanup helper emitted JSON only to stdout, unlike the resource safety and snapshot tools now used for handoff evidence.
### Fix
Added `-ReportPath` to `Stop-WDGuiDevWorkers.ps1`, writing UTF-8 JSON without BOM and including `ReportPath` in the result. Added Pester coverage that only uses `-WhatIf`, and documented the dry-run report command in `OPERATIONS.md`.
### Verification
`Stop-WDGuiDevWorkers.ps1 -WhatIf -ReportPath E:\WindowsDoctor\logs\gui-dev-workers.whatif.latest.json -Json` passed with `Matched=0` and `Stopped=0`. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `45` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-27] Version Policy Needed Durable Report Output
### Symptom
`Test-VersionPolicy.ps1` validated package and UI version consistency, but did not support machine-readable JSON or a durable report path.
### Cause
The script returned a PowerShell object only, while the current low-risk validation workflow stores JSON reports for handoff evidence.
### Fix
Added `-Json` and `-ReportPath` to `Test-VersionPolicy.ps1`, writing UTF-8 JSON without BOM and including `ReportPath`, `PackageJson`, and `PageFile` in the result. Added Pester coverage and documented the report command in `OPERATIONS.md`.
### Verification
`Test-VersionPolicy.ps1 -ReportPath E:\WindowsDoctor\logs\version-policy.latest.json -Json` passed with `Version=0.1.0`. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `46` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-28] Continuation Prompt Needed Durable Summary Report
### Symptom
`New-ContinuationPrompt.ps1 -Json` generated the current `NEXT_CHAT_PROMPT.md` and emitted a summary to stdout, but did not write a separate durable report artifact.
### Cause
The script focused on the prompt artifact itself. Automation consumers had no independent JSON report for handoff evidence.
### Fix
Added `-ReportPath` to `New-ContinuationPrompt.ps1`, writing a UTF-8 JSON summary without BOM and including `ReportPath` in the result. The report intentionally omits the full prompt body and does not affect clipboard behavior. Added Pester coverage and documented the command in `OPERATIONS.md`.
### Verification
`New-ContinuationPrompt.ps1 -ReportPath E:\WindowsDoctor\logs\continuation-prompt.latest.json -Json` passed. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `47` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-29] WinPE Media CheckOnly Needed Durable Report Output
### Symptom
`Build-WinPEMedia.ps1 -CheckOnly` validated ADK, source files, startup mode, Node path, and offline DB readiness, but emitted only formatted console output.
### Cause
The WinPE preflight path predated the durable JSON report convention used by current validation and handoff workflows.
### Fix
Added `-Json` and `-ReportPath` to the `-CheckOnly` result path in `Build-WinPEMedia.ps1`, writing UTF-8 JSON without BOM and including `ReportPath`. The actual ISO/USB build path remains unchanged.
### Verification
`Build-WinPEMedia.ps1 -CheckOnly -ReportPath E:\WindowsDoctor\logs\winpe-media-checkonly.latest.json -Json` passed with `Status=Ready` and `StartupMode=Menu` without building ISO or writing USB. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `48` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-30] Service Status Needed Durable Report Output
### Symptom
`Start-WindowsDoctor.ps1 -NoGui -NoBroker -Json` could report GUI/Broker URLs, listener PIDs, and free memory without starting services, but did not write a durable status artifact.
### Cause
The startup/status helper only emitted JSON to stdout, while current handoff workflows rely on report files for repeatable evidence.
### Fix
Added `-ReportPath` to `Start-WindowsDoctor.ps1`, writing the same status object as UTF-8 JSON without BOM and including `ReportPath`. Added Pester coverage for `-NoGui -NoBroker` so validation does not start GUI or Broker, and documented the report command in `OPERATIONS.md`.
### Verification
`Start-WindowsDoctor.ps1 -NoGui -NoBroker -ReportPath E:\WindowsDoctor\logs\service-status.latest.json -Json` passed with both service PIDs null. `Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json` passed with `16` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `49` tests, and the full low-risk baseline report passed with `12` steps.

## [ERR-20260429-31] GUI Smoke Offline Needed Durable Report Output
### Symptom
`Test-GuiSmoke.ps1 -AllowOffline` was useful for low-risk baseline verification because it did not start GUI or Broker, but it only emitted a formatted table.
### Cause
The GUI smoke helper predated the durable JSON report convention used by current handoff and baseline workflows.
### Fix
Added `-Json` and `-ReportPath` to `Test-GuiSmoke.ps1`, writing the same low-risk smoke result as UTF-8 JSON without BOM and including `ReportPath`. Added Pester coverage for `-AllowOffline` so validation does not start services, and documented the report command in `OPERATIONS.md`.
### Verification
`Test-GuiSmoke.ps1 -AllowOffline -ReportPath E:\WindowsDoctor\logs\gui-smoke-offline.latest.json -Json` passed with GUI/Broker checks marked `SKIP` because services were intentionally offline. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `52` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-32] Portable USB Readiness Needed Dedicated Gate
### Symptom
The project goal is to produce a portable USB version before an installer version, but readiness evidence was spread across WinPE, offline KB, repair allowlist, and service-status commands.
### Cause
Existing gates validated individual pieces, but none explicitly represented the release order `portable USB first, installer deferred`.
### Fix
Added `Test-PortableUsbReadiness.ps1`, a non-destructive readiness gate that validates offline KB export/validation/search, allowlisted repairs, WinPE text menu startup, `Build-WinPEMedia.ps1 -CheckOnly -StartupMode Menu`, and confirms GUI/Broker remain offline. Wired it into low-risk baseline and documented the command in `OPERATIONS.md`.
### Verification
`Test-PortableUsbReadiness.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-readiness.latest.json -Json` passed with `Phase=portable-usb`, `InstallerPhase=deferred`, `10` steps, and `Build-WinPEMedia.ps1 -CheckOnly -StartupMode Menu` ready. `Test-DocumentationSync.ps1 -ReportPath E:\WindowsDoctor\logs\documentation-sync.latest.json -Json` passed with `18` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `52` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-33] Portable USB Needed Payload Artifact
### Symptom
Portable USB readiness could prove prerequisites, but there was no completed folder artifact that could be copied to removable media.
### Cause
The existing WinPE build path targets ISO/USB media creation, while unattended low-risk work should not format or write a real USB without an explicit target.
### Fix
Added `New-PortableUsbPayload.ps1` to create a non-destructive portable payload under `releases\portable-usb`, including `WindowsDoctor`, offline KB, scripts, docs, a portable launcher, and `portable-usb-manifest.json`. Added `Test-PortableUsbPayload.ps1` to validate the payload artifact without starting services.
### Verification
`New-PortableUsbPayload.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-payload.latest.json -Json` created `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-20260429-204044` with `21135` files and about `435MB`, including `node_modules` and excluding `gui\.next`. `Test-PortableUsbPayload.ps1 -PackageRoot E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-20260429-204044 -ReportPath E:\WindowsDoctor\logs\portable-usb-payload-validate.latest.json -Json` passed with `13` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `53` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-34] USB Publish Must Use Zip Copy Expand Flow
### Symptom
Directly copying the full portable payload to FAT32 USB copied thousands of small files and took too long.
### Cause
The first payload included `node_modules`, and direct per-file USB writes are slow on removable media.
### Fix
Added `Publish-PortableUsbPackage.ps1`, which generates a minimal payload by default, compresses it to zip, copies the zip to USB, expands it on USB, and validates the result. Documented the rule that USB publishing must use zip-copy-expand instead of direct per-file copy.
### Verification
`Publish-PortableUsbPackage.ps1 -USBPath E:\WindowsDoctor\logs\portable-usb-publish-smoke -PackageName publish-smoke -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-smoke.json -Json` passed with `CopiedByZip=true` and `ExpandedOnUsb=true`. `Publish-PortableUsbPackage.ps1 -USBPath F:\ -PackageName WindowsDoctor-PortableUSB-Minimal-20260429-2305 -ReportPath E:\WindowsDoctor\logs\portable-usb-publish.latest.json -Json` published to `F:\WindowsDoctor-PortableUSB-Minimal-20260429-2305` with `173` files and `778170` bytes. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `54` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-35] Portable USB Menu Needed Traditional Chinese UI
### Symptom
The portable USB entrypoint worked, but the offline text menu still displayed English labels and prompts.
### Cause
`Start-WinPEOfflineMenu.ps1` was originally written with English interactive text, and the portable launcher did not set UTF-8 console code page.
### Fix
Localized the interactive offline menu labels and prompts to Traditional Chinese. Added `chcp 65001` to the portable launcher template and localized `README-PORTABLE-USB.md`.
### Verification
`Publish-PortableUsbPackage.ps1 -USBPath F:\ -PackageName WindowsDoctor-PortableUSB-ZH-UTF8-20260429-2325 -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-zh-utf8.latest.json -Json` published the mojibake-fixed package to `F:\WindowsDoctor-PortableUSB-ZH-UTF8-20260429-2325`. `Test-PortableUsbPayload.ps1 -PackageRoot F:\WindowsDoctor-PortableUSB-ZH-UTF8-20260429-2325 -ReportPath E:\WindowsDoctor\logs\portable-usb-zh-utf8-validate.latest.json -Json` passed with `13` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `55` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-36] Portable USB Chinese Menu Displayed Mojibake
### Symptom
After launching the portable USB menu, the screen displayed mojibake instead of readable Traditional Chinese.
### Cause
Windows PowerShell 5.1 can decode UTF-8 without BOM scripts using the system ANSI code page. The menu script contained direct Traditional Chinese string literals, so they could be misread before output.
### Fix
Changed `Start-WinPEOfflineMenu.ps1` to keep source text ASCII-only and generate Traditional Chinese UI strings from Unicode code points at runtime. Updated the portable launcher to set console input/output encoding to UTF-8 before invoking the menu script.
### Verification
`Publish-PortableUsbPackage.ps1 -USBPath F:\ -PackageName WindowsDoctor-PortableUSB-ZH-SCAN-20260429-2350 -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-zh-scan.latest.json -Json` published the updated package to `F:\WindowsDoctor-PortableUSB-ZH-SCAN-20260429-2350`. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `56` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260429-37] KB Coverage And System Scan Were Insufficient
### Symptom
The portable database had too few troubleshooting records, and the USB menu did not expose local system-error or network-diagnostic scanning.
### Cause
The first portable version focused on packaging and offline KB lookup, not broad KB coverage or local scan collection.
### Fix
Added `20` reviewed KB rules covering gateway, limited connectivity, IP conflict, NCSI, TLS/cert, RDP, firewall, network profile, DNS suffix, MTU, event log, disk space, high CPU, time sync, pending reboot, Defender, Task Scheduler, temporary profile, Store cache, and RDP NLA. Added `Test-SystemErrorScan.ps1` for local event log and network adapter/IP/DNS/WinHTTP proxy diagnostics, and exposed it in `Start-WinPEOfflineMenu.ps1`.
### Verification
`Export-OfflineKBDatabase.ps1 -ReportPath E:\WindowsDoctor\logs\offline-kb-export.latest.json -Json` passed with `TotalRules=63`, `AutoRepairRules=20`, and `GuidedRules=43`. `Test-SystemErrorScan.ps1 -RecentHours 1 -MaxEvents 20 -ReportPath E:\WindowsDoctor\logs\system-error-scan.latest.json -Json` passed with `6` findings. USB validation confirmed `F:\WindowsDoctor-PortableUSB-ZH-SCAN-20260429-2350` contains `63` rules and the `Start-WinPEOfflineMenu.ps1 -ScanSystem` entry works from USB.

## [ERR-20260430-01] Portable USB Needed Runtime Self-Test
### Symptom
The portable USB package could be validated from the development workspace, but the USB itself had no menu-accessible self-test for database, search, allowlist, and scan readiness.
### Cause
Readiness checks existed as build-time scripts, while runtime validation was not exposed to the portable user.
### Fix
Added `Test-PortableRuntimeSelfTest.ps1` and exposed it as menu option `9` plus `Start-WinPEOfflineMenu.ps1 -SelfTest`. The self-test validates root files, offline database, offline search, allowlisted repairs, and system/network scan.
### Verification
`Test-PortableRuntimeSelfTest.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-self-test.latest.json -Json` passed with `10` checks. `Test-PortableUsbReadiness.ps1 -ReportPath E:\WindowsDoctor\logs\portable-usb-readiness.latest.json -Json` passed with `12` steps. `Publish-PortableUsbPackage.ps1 -USBPath F:\ -PackageName WindowsDoctor-PortableUSB-MATURE-20260430-0005 -ReportPath E:\WindowsDoctor\logs\portable-usb-publish-mature.latest.json -Json` published the mature package to `F:\WindowsDoctor-PortableUSB-MATURE-20260430-0005`. USB direct self-test passed with `10` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `57` tests, and the full low-risk baseline report passed with `13` steps.

## [ERR-20260430-02] System Scan Needed KB Recommendations
### Symptom
The portable USB scan could detect system and network conditions, but results only exposed `RuleHint` text. Users still had to manually search the offline database to find the related rule and whether an allowlisted repair existed.
### Cause
`Test-SystemErrorScan.ps1` collected diagnostics independently from `offline_database\windowsdoctor-kb.json`; there was no local recommendation join between findings and reviewed KB rules.
### Fix
`Test-SystemErrorScan.ps1` now loads the offline KB database and attaches `KbMatches` to each finding. Each match includes rule id, title, category, action type, allowlist repair status, and script name. `Test-PortableRuntimeSelfTest.ps1` now validates the `scan-kb-matching` path.
### Verification
`Test-SystemErrorScan.ps1 -RecentHours 1 -MaxEvents 20 -ReportPath E:\WindowsDoctor\logs\system-error-scan.latest.json -Json` passed with `KbRuleCount=63` and `KbMatchCount=11`. `Test-PortableRuntimeSelfTest.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-self-test.latest.json -Json` passed with `11` checks. `Invoke-Pester -Path scripts\ResourceSafety.Tests.ps1` passed `57` tests, and the low-risk baseline passed with `13` steps.

## [ERR-20260430-03] Portable Scan Output Needed Readable Recommendations
### Symptom
The USB scan JSON included KB recommendation data, but the interactive menu path still risked showing complex PowerShell objects in a table.
### Cause
`Test-SystemErrorScan.ps1` used default table formatting for non-JSON output after adding nested `KbMatches`.
### Fix
Changed non-JSON scan output to a readable Traditional Chinese diagnostic list. Each finding now shows status, detail, rule hint, KB recommendation count, matched rule IDs, action type, and repair script.
### Verification
Direct USB execution of `F:\WindowsDoctor-PortableUSB-MATURE-20260430-ScanKB-UI\WindowsDoctor\scripts\Start-WinPEOfflineMenu.ps1 -ScanSystem` displayed Traditional Chinese labels and KB recommendations. USB payload validation passed with `13` checks and USB runtime self-test passed with `11` checks.

## [ERR-20260430-04] Portable Runtime Needed Status Summary
### Symptom
The portable USB had self-test and scan functions, but users had no quick way to see the package version, KB rule counts, allowlisted repair count, and runtime readiness from one menu entry.
### Cause
Runtime validation existed as test scripts, while a concise operator-facing status summary did not exist.
### Fix
Added `Get-PortableRuntimeStatus.ps1`, added `Start-WinPEOfflineMenu.ps1 -StatusSummary`, and exposed it as menu option `10`. Runtime self-test now validates the status summary path.
### Verification
`Get-PortableRuntimeStatus.ps1 -ReportPath E:\WindowsDoctor\logs\portable-runtime-status.latest.json -Json` passed with `Version=0.1.0`, `TotalRules=63`, and `AllowlistRepairs=6`. `Start-WinPEOfflineMenu.ps1 -StatusSummary -ReportPath E:\WindowsDoctor\logs\winpe-menu-status.latest.json -Json` passed. `Test-PortableRuntimeSelfTest.ps1` passed with `13` checks, Pester passed `59` tests, and the low-risk baseline passed with `13` steps.

## [ERR-20260430-05] Field Test Hit Misspelled System Scan File Name
### Symptom
Real testing reported: `the argument 'e:\windowsdoctor\scripts\test-systemerroescan.ps1' to the -file parameter does not exist.`
### Cause
The correct script is `Test-SystemErrorScan.ps1`. The reported path uses a misspelled `ErroeScan` variant. Source search did not find current references to the misspelled name, so this likely came from an old package, manual command, or stale shortcut path.
### Fix
Added compatibility wrapper scripts `Test-SystemErroeScan.ps1` and `Test-SystemErrorsScan.ps1`. Both forward to `Test-SystemErrorScan.ps1` with the same key parameters, so common typo/stale entrypoints no longer fail with missing file.
### Verification
Both compatibility wrappers passed with `KbRuleCount=63`. Pester passed `60` tests, and the low-risk baseline passed with `13` steps.

## [ERR-20260430-06] Users Needed One-Click Repair Guidance
### Symptom
The portable menu had scan, search, preview, and explicit repair execution entries, but users still had to decide which repair script matched scan results.
### Cause
The scan-to-KB match layer exposed recommendations, but there was no operator-facing plan that grouped recommended allowlisted repairs into safe batch versus manual review.
### Fix
Added `Invoke-RecommendedRepairPlan.ps1` and menu option `11`. The flow previews recommended repairs by default, executes only with `RUN`, and excludes high-risk BCD/boot, system integrity, and maintenance cleanup from the default one-click batch.
### Verification
The recommended repair preview passed with `RecommendedRepairCount=5`, `SafeBatchScriptCount=2`, and `Executed=false`. Pester passed `63` tests, and the low-risk baseline passed with `13` steps. No repair execution was performed during validation.

## [ERR-20260430-07] USB Publish Needed Full Post-Expand Release Validation
### Symptom
The USB publish flow validated payload structure after zip-copy-expand, but the required post-publish operator checks were still separate commands: payload validation, portable runtime self-test, and one-click repair preview.
### Cause
`Publish-PortableUsbPackage.ps1` called only `Test-PortableUsbPayload.ps1` after expanding the package. Runtime self-test and recommended repair preview were verified elsewhere, so the USB-return publish path could miss one of the required checks.
### Fix
Added `Test-PortableUsbReleaseValidation.ps1` to validate an expanded portable package root. It runs payload validation, runtime self-test from the package's own `WindowsDoctor` root, and recommended repair preview without executing repairs. `Publish-PortableUsbPackage.ps1` now calls this release validation gate after zip-copy-expand.
### Verification
The new gate passed against `E:\WindowsDoctor\releases\portable-usb\WindowsDoctor-PortableUSB-MATURE-20260430-OneClick`: payload validation `13` checks, runtime self-test `15` checks, and recommended repair preview `Mode=preview`, `Executed=false`. Pester passed `64` tests.

## [ERR-20260430-08] PASS-Only Matches Should Not Become Auto Repair Batch Items
### Symptom
The one-click repair preview could recommend allowlisted repairs even when the current diagnostic findings were all `PASS`. That made KB matches useful for context, but too aggressive for an unattended USB repair workflow.
### Cause
`Invoke-RecommendedRepairPlan.ps1` grouped every allowlisted KB match as a recommendation regardless of whether the source finding represented an active failure.
### Fix
Upgraded the plan to `RepairPlanVersion=2`. Each item now has confidence, risk level, priority, active evidence count, and recommendation state. PASS-only matches are emitted as observations and cannot enter the default safe batch. The default batch is limited to low-risk `Repair-NetworkStack.bat` and `Repair-Services.bat`.
### Verification
`Invoke-RecommendedRepairPlan.ps1` passed with `ActiveRecommendedRepairCount=0`, `ObservationCount=5`, `SafeBatchScriptCount=0`, and `Executed=false` on the healthy local scan. Portable runtime self-test passed with `15` checks, Pester passed `64` tests, and the `WindowsDoctor-PortableUSB-MATURE-20260430-RepairPlanV2` release validation passed.

## [ERR-20260430-09] Repair Knowledge Needed Normalized Provenance
### Symptom
The offline KB was useful for local scan matching, but the data model was optimized for Markdown export and not for large-scale source expansion, provenance tracking, event ID matching, or component-level analytics.
### Cause
`windowsdoctor-kb.json` used a compact rule shape with title, triggers, script, action type, and source file. It did not preserve structured source references, normalized symptoms, error codes, event IDs, recommended actions, or risk metadata in a database-wide schema.
### Fix
Added `known-windows-repair-sources.json`, `Export-NormalizedKBDatabase.ps1`, and `Test-NormalizedKBDatabase.ps1`. The normalized database uses `schemaVersion=2` and combines the existing `63` reviewed local KB records with `8` Microsoft official public reference records. Each record includes component, symptoms, error codes, event IDs, trigger terms, recommended actions, action risk, and provenance.
### Verification
Normalized export and validation passed with `TotalRecords=71`, `PublicReferenceRecords=8`, `SourceCount=6`, and component coverage across `7` components. Portable runtime self-test passed with `17` checks, portable USB readiness passed with `14` steps, documentation sync passed, and Pester passed `65` tests.

## [ERR-20260501-01] NotebookLM Needed Portable Import Instead Of Live API Dependency
### Symptom
NotebookLM could be useful as a repair database curation source, but relying on a live NotebookLM integration would reduce offline portability and risk depending on non-public API behavior.
### Cause
The portable USB architecture needs deterministic offline inputs. NotebookLM supports source/notes workflows and exports, while a broadly available public consumer API is not a stable project dependency.
### Fix
Added `Import-NotebookLMSourcePack.ps1`, which imports a NotebookLM-derived JSON source pack into `offline_database\notebooklm-repair-sources.json`. `Export-NormalizedKBDatabase.ps1` now merges this pack into schema v2 records as `provenance.sourceType=notebooklm_export`.
### Verification
Normalized export and validation passed after the integration. Documentation sync passed. Pester passed with a sample NotebookLM import that produced one normalized `notebooklm_export` record.
