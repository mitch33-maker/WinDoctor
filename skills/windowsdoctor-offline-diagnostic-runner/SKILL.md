---
name: windowsdoctor-offline-diagnostic-runner
description: Use when extending, validating, or packaging WindowsDoctor offline Microsoft diagnostic tool automation, including offline tool auto-selection, RUN-gated sequential diagnostic runner, output-to-evidence conversion, work-window integration, USB sync, and incremental patch validation. This skill preserves preview-first behavior and prevents tool execution unless the operator explicitly provides RUN.
---

# WindowsDoctor Offline Diagnostic Runner Skill

Use this skill in `E:\WindowsDoctor` when the task involves:
- offline Microsoft diagnostic tool packaging or validation.
- automatic tool selection from a user problem category.
- `Invoke-OfflineDiagnosticTools.ps1`.
- `Convert-OfflineDiagnosticToolOutput.ps1`.
- `New-OfflineDiagnosticUserReport.ps1`.
- work-window integration for offline diagnostics.
- USB GUI-ready sync or incremental patch for offline diagnostic features.

## Required Safety Gate
Run before any work:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-ResourceSafety.ps1 -Json
```

Stop if this fails.

## Minimal Read Set
Read only what is needed, in this order:
1. `INDEX.md`
2. `SECURITY_POLICY.md`
3. `REPAIR_TOOL_PACKAGING_POLICY.md`
4. Latest `TASK_HANDOFF.md` section for offline diagnostic tools
5. Task-specific files:
   - `gui\broker\services\offlineTools.js`
   - `scripts\Invoke-OfflineDiagnosticTools.ps1`
   - `scripts\Convert-OfflineDiagnosticToolOutput.ps1`
   - `scripts\New-OfflineDiagnosticUserReport.ps1`
   - `gui\broker\services\work.js`
   - `gui\src\components\ProblemSolverPanel.tsx`
   - `gui\src\components\WorkStatusPanel.tsx`

## Non-Negotiable Safety Rules
- Default behavior must be preview-only.
- Do not execute external tools unless the user explicitly provides `RUN`.
- Do not run repair scripts from this workflow.
- Do not install tools.
- Do not change PATH, services, registry, scheduled tasks, drivers, accounts, network, boot, or storage.
- Do not update `scripts\repair-allowlist.json` from tool packaging or diagnostic evidence.
- Do not start GUI/Broker unless the user explicitly asks.
- Do not run production build.
- Do not import unverified third-party tools into reviewed KB or auto-repair.

## Runner Pattern
For preview:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-OfflineDiagnosticTools.ps1 -Root E:\WindowsDoctor -Component performance -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-tools-preview.latest.json -Json
```

For actual diagnostic execution, require explicit user-provided `RUN`:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-OfflineDiagnosticTools.ps1 -Root E:\WindowsDoctor -Component performance -Execute -ConfirmToken RUN -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-tools-execute.latest.json -Json
```

The runner must:
- select tools by component.
- accept comma-separated `-ToolId` batches.
- validate package SHA-256 before use.
- run tools sequentially.
- run Resource Safety before and after each tool.
- run only reviewed console tools automatically: `setupdiag`, `sigcheck64`, `tcpvcon64`, `handle64`, `autorunsc64`.
- keep GUI tools extract-only unless a future reviewed console mode is added.
- enforce `MaxToolSeconds` and `MaxOutputKB` limits.
- write JSON evidence.
- keep `NoRepairExecuted=true`.

Safe low-risk batch diagnostic example:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-OfflineDiagnosticTools.ps1 -Root E:\WindowsDoctor -ToolId setupdiag,sigcheck,tcpview,handle,autoruns -OutputRoot E:\WindowsDoctor\logs\offline-diagnostic-safe-cli-real-run-YYYYMMDD -MaxToolSeconds 60 -MaxOutputKB 512 -Execute -ConfirmToken RUN -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-safe-cli-real-run-YYYYMMDD.json -Json
```

## Output Conversion Pattern

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Convert-OfflineDiagnosticToolOutput.ps1 -Root E:\WindowsDoctor -InputRoot "$env:LOCALAPPDATA\WindowsDoctor\OfflineDiagnostics" -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-output-conversion.latest.json -Json
```

Converted output is diagnostic evidence only. It may suggest KB matching or manual review, but must not become automatic repair without reviewed KB, dry-run impact, rollback guidance, local validation, allowlist review, and RUN gate.

To create an external diagnostic evidence pack for the existing import gate:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Convert-OfflineDiagnosticToolOutput.ps1 -Root E:\WindowsDoctor -InputRoot "$env:LOCALAPPDATA\WindowsDoctor\OfflineDiagnostics" -ExternalPackPath E:\WindowsDoctor\incoming\external-diagnostics\offline-diagnostic-evidence.latest.json -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-output-conversion.latest.json -Json
```

The converter may parse SetupDiag, Sigcheck, TCPView, Handle, and Autoruns evidence. Non-core tool evidence must use `manual-external` adapter flow when imported into normalized diagnostics.

## User Report Pattern

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-OfflineDiagnosticUserReport.ps1 -Root E:\WindowsDoctor -ConversionReportPath E:\WindowsDoctor\logs\offline-diagnostic-output-conversion.latest.json -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-user-report.latest.json -Json
```

The report classifies findings into `no_issue_detected`, `evidence_found`, `manual_review_required`, `repair_candidate_preview_only`, and `blocked_by_policy`.

The report is diagnostic-only and must keep `repairAllowed=false`, `script=N/A`, and no cleanup or repair actions.

## Validation Checklist
Use the smallest safe set that covers the change:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-OfflineToolAutomation.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\offline-tool-automation.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-OfflineDiagnosticRunnerSkill.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\offline-diagnostic-runner-skill.latest.json -Json
npm run test:broker --prefix E:\WindowsDoctor\gui
npm run lint --prefix E:\WindowsDoctor\gui
powershell -NoProfile -ExecutionPolicy RemoteSigned -Command "Invoke-Pester -Path 'E:\WindowsDoctor\scripts\ResourceSafety.Tests.ps1' -FullName '*parses safety scripts*'"
```

If documentation or memory changed:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-DocumentationMemorySystem.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\documentation-memory-system.latest.json -Json
```

## USB Sync Pattern
When files must reach the GUI-ready USB package, first confirm the visible USB/package root. Current known package root is usually:

```text
G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3
```

Then sync and patch:

```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Sync-GuiReadyUsbPatch.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -SourceRoot E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\gui-ready-sync.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-PortableIncrementalPatch.ps1 -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -OutputRoot E:\WindowsDoctor\releases\portable-usb\incremental-patches -PatchName WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-YYYYMMDD-OfflineDiagnosticRunner -ReportPath E:\WindowsDoctor\logs\incremental-patch.latest.json -Json
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-PortableIncrementalPatch.ps1 -PatchZipPath E:\WindowsDoctor\releases\portable-usb\incremental-patches\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3-IncrementalPatch-YYYYMMDD-OfflineDiagnosticRunner.zip -PackageRoot G:\WindowsDoctor-PortableUSB-GUI-READY-20260508-OneClickV3 -ReportPath E:\WindowsDoctor\logs\incremental-patch-verify.latest.json -Json
```

## Completion Routine
After non-trivial work:
1. Update `TASK_HANDOFF.md` and `NEXT_CHAT_PROMPT.md` with current state.
2. Update `SUCCESS_EXPERIENCE.md` if a new reusable pattern was proven.
3. Add a completion record with `scripts\Add-TaskCompletionRecord.ps1`.
4. Run final Resource Safety.
5. Commit and push when the user requested unattended completion or remote sync.
