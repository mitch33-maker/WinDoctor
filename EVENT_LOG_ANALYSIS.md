# Windows Event Log Analysis

Last updated: `2026-05-17`

## Purpose
Provide MIS-friendly, read-only analysis for Windows Event Logs.

This feature helps an operator find the most relevant System/Application events, summarize noisy providers and Event IDs, match known WindowsDoctor KB rules, and decide whether the next step is guided review, repair preview, or learn-only intake.

## Safety
- Reads event logs only.
- Does not repair Windows.
- Does not change services, registry, drivers, users, storage, or network settings.
- Any repair suggestion remains preview-first and must pass allowlist, dry-run, rollback, local validation, and RUN gate policy.
- Unknown events stay learn-only until reviewed.

## MIS Workflow
1. Run the event log analysis.
2. Review `ProviderSummary` and `EventIdSummary`.
3. Open the highest-count or highest-severity event in `Findings`.
4. Use `PrimaryRuleId` to locate the matching reviewed KB rule.
5. Treat `RepairState` as a decision hint:
   - `preview_required`: repair preview may be available, but execution still requires gates.
   - `guided_or_manual_review`: use KB guidance, no automatic execution.
   - `learn_only`: record evidence and review before adding formal rules.

## Commands
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Analyze-WindowsEventLogs.ps1 -Root E:\WindowsDoctor -RecentHours 24 -MaxEvents 120 -Top 10 -ReportPath E:\WindowsDoctor\logs\windows-event-log-analysis.latest.json -CsvPath E:\WindowsDoctor\logs\windows-event-log-analysis.latest.csv -Json
```

Target specific logs:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Analyze-WindowsEventLogs.ps1 -Root E:\WindowsDoctor -LogName System,Application -RecentHours 48 -MaxEvents 200 -ReportPath E:\WindowsDoctor\logs\windows-event-log-analysis.48h.json -CsvPath E:\WindowsDoctor\logs\windows-event-log-analysis.48h.csv -Json
```

## Outputs
- JSON report: full MIS summary, KB matches, event findings, safety policy.
- CSV report: sortable table for spreadsheet review.
- Broker API: `POST /api/event-logs/analyze`.
- GUI panel: `系統日誌解讀`.
