# Auto Repair Safety Policy

Last updated: `2026-05-17`

## Goal

WindowsDoctor's final target is one-click detection with automatic repair where the repair is safe enough to automate.

Automatic repair is not enabled by source trust alone. A rule can be Microsoft-official and still remain preview/manual until its executable repair path passes all safety gates.

## Required Gates

A repair script can enter unattended auto batch only when all conditions are true:
- action is reversible or has a proven backout path.
- preview/dry-run can show expected impact.
- local validation evidence is `PASS`.
- action does not interrupt critical devices, network, boot, display, input, or core services.
- rollback guidance is present.
- allowlist review status is `APPROVED`.
- execution remains gated by `-Execute -ConfirmToken RUN`.

High-risk repairs cannot enter unattended auto batch even when they have official references. They remain manual-review and RUN-gated.

## Machine-Readable Policy

Authoritative policy file:
```text
scripts\repair-safety-policy.json
```

Validation:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-AutoRepairSafetyPolicy.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\auto-repair-safety-policy.latest.json -Json
```

One-click preview:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Invoke-RecommendedRepairPlan.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\recommended-repair-plan.latest.json -Json
```

## Current Baseline

As of `2026-05-17`:
- allowlisted repair scripts: `6`
- scripts with safety policy: `6`
- scripts approved for unattended auto batch: `0`
- all scripts still require `RUN` before execution.

This is intentional. Existing repair scripts can affect network, services, boot, system integrity, update cache, or maintenance state. They need pre-state capture and rollback evidence before any can be promoted to unattended auto batch.

## Promotion Path

For each repair script:
1. Add pre-state capture.
2. Add preview impact report.
3. Add rollback/backout instructions or command.
4. Prove local validation with JSON evidence.
5. Confirm no critical interruption.
6. Change `allowlistReviewStatus` to `APPROVED`.
7. Change `autoBatchAllowed` to `true` only for low-risk scripts.

The safest next candidates are narrow, non-destructive checks that repair only local application state or reversible configuration. Network reset, printer queue clearing, service restarts, DISM/SFC, boot repair, and update cache reset should stay manual until their rollback evidence is complete.
