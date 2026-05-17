# External Repair Tools Strategy

Last updated: `2026-05-17`

## 1. Decision
WindowsDoctor should remain a portable Windows repair console, not a full RMM, SIEM, or MDM replacement.

The best architecture is:
- USB and WinPE first for field repair and offline rescue.
- Official Microsoft diagnostics first where available.
- External tool outputs imported into the normalized KB pipeline.
- Repairs remain preview-first and allowlist-only.
- Learned, NotebookLM, community, or third-party findings must never become auto-repair without review.
- GitHub/community repair code is kept as quarantined reference until it has source review, local dry-run evidence, and an explicit allowlist decision.

## 2. Product Fit
| Product or Theory | Best Use | WindowsDoctor Position |
|---|---|---|
| Microsoft Intune Remediations | Enterprise detection/remediation scripts with reporting | Export WindowsDoctor rules into Intune format later |
| Windows Autopatch | Enterprise Windows, Microsoft 365 Apps, Edge, and Teams update governance | Reference only; do not duplicate patch-ring management |
| Windows Autopilot Reset | Return managed company devices to business-ready state | Recommend when repair is lower value than reset |
| SetupDiag | Windows update or upgrade failure root-cause analysis | Add importer/parser for results |
| Get Help command-line | Microsoft 365, Outlook, Teams, Office activation and scrub scenarios | Add optional external diagnostics adapter |
| DISM and SFC | Official Windows component store and protected-file repair | Keep as guided/manual or explicit RUN repair paths |
| Wazuh | Vulnerability detection, endpoint inventory, active response | Optional enterprise import source, not bundled by default |
| NinjaOne or similar RMM | Commercial endpoint monitoring, patching, remote support | Recommend for MSP/large fleet needs; do not rebuild inside WindowsDoctor |
| Boxstarter | Repeatable Windows setup after rebuild | Reference for rebuild workflows, not repair execution |
| Tron Script / Tweaking Windows Repair | Broad single-machine cleanup and repair | Reference only; do not integrate broad repair automation without explicit allowlist review |

## 3. Source Trust Levels
Every external record imported into normalized KB should carry a source trust level:

| Trust Level | Examples | Repair Policy |
|---|---|---|
| `microsoft_official` | Microsoft Learn, Microsoft Support, SetupDiag, Get Help CLI | Can become reviewed after local validation |
| `vendor_official` | Hardware vendor support, application vendor support | Manual review required |
| `enterprise_tool` | Intune, Wazuh, RMM export | Manual review required |
| `notebooklm_export` | NotebookLM source pack | Learn/reference only until reviewed |
| `local_learned` | WindowsDoctor unknown-error capture | Learn/reference only until reviewed |
| `community_unverified` | forums, broad cleanup tools | Reference only; never auto-repair directly |

## 4. Recommended Modules
### 4.1 ExternalDiagnosticsAdapter
Purpose: Normalize external diagnostic outputs into WindowsDoctor records.

Initial adapters:
- `setupdiag`
- `gethelpcmd`
- `dism`
- `sfc`
- `eventlog`
- `intune-remediation-export`
- `wazuh-vulnerability-export`

Output shape should include:
- `adapterName`
- `sourceTrustLevel`
- `rawFindingId`
- `errorCode`
- `component`
- `symptom`
- `evidence`
- `recommendedAction`
- `riskLevel`
- `repairAllowed=false` by default

### 4.2 RepairDecisionEngine
Purpose: separate diagnosis confidence from repair execution.

Required states:
- `auto_repair_allowed`
- `preview_repair_only`
- `manual_review_required`
- `recommend_reset_or_reinstall`
- `capture_to_learned_kb`
- `external_tool_required`

### 4.3 EnterpriseExport
Purpose: reuse WindowsDoctor rules in enterprise tools without turning WindowsDoctor into the enterprise tool.

Export targets:
- Intune Remediation detection/remediation scripts
- Wazuh active response scripts
- portable PowerShell repair bundle
- CSV/JSON support handoff bundle

Current Intune baseline:
- exporter: `scripts\Export-IntuneRemediationPackage.ps1`
- validator: `scripts\Test-IntuneRemediationPackage.ps1`
- export includes only allowlisted `low` risk `auto_repair` records
- export excludes BCD, boot, SystemIntegrity, SystemMaintenance, medium risk, manual review, NotebookLM, and external diagnostic imports
- export does not execute repairs

## 5. Priority
1. Add SetupDiag result import.
2. Add DISM/SFC log summarizer.
3. Add Get Help command-line result import for Microsoft 365 issues.
4. Add source trust level to normalized KB records.
5. Add Intune Remediations export.
6. Add Wazuh inventory/vulnerability export import.

## 6. Safety Rules
- Do not auto-run third-party cleanup suites.
- Do not import unverified GitHub/community workflows into reviewed KB or auto-repair.
- Do not convert NotebookLM, learned, Wazuh, or RMM findings into allowlisted repairs automatically.
- Do not perform reset, reinstall, Office scrub, DISM RestoreHealth, SFC repair, CHKDSK repair, BCD repair, or destructive maintenance without explicit RUN confirmation.
- Keep SetupDiag and log parsing diagnostic-only.
- Keep Get Help command-line integration optional and scenario-scoped.
- Keep WindowsDoctor usable without internet, Microsoft 365 tenant, Intune, or Wazuh.

## 7. Current Conclusion
No major rewrite is required.

WindowsDoctor should evolve by adding import/export adapters and trust metadata around the existing portable repair engine.

## 7.1 Implemented Adapter Baseline
The first adapter baseline is diagnostic-only:
- template: `templates\EXTERNAL_DIAGNOSTICS_PACK_TEMPLATE.json`
- preflight: `scripts\Test-ExternalDiagnosticsPack.ps1`
- import: `scripts\Import-ExternalDiagnosticsPack.ps1`
- official log converter: `scripts\Convert-OfficialDiagnosticsToExternalPack.ps1`
- Microsoft official source updater: `scripts\Update-MicrosoftOfficialRepairSources.ps1`
- normalized KB integration: `Export-NormalizedKBDatabase.ps1`
- validation: `Test-NormalizedKBDatabase.ps1`

Imported external findings become `external_diagnostic_import` records with:
- `repairAllowed=false`
- `script=N/A`
- `actionType=manual_review`
- `provenance.sourceTrustLevel`
- `provenance.adapterName`

This supports SetupDiag, Get Help command-line, DISM, SFC, event logs, Intune exports, Wazuh exports, RMM exports, and manual external evidence without enabling automatic repair.

Microsoft official reference records are imported only from `learn.microsoft.com` and `support.microsoft.com`. They remain public reference records and do not update `scripts\repair-allowlist.json`.

Official diagnostic sample logs are available under `templates\SETUPDIAG_SAMPLE.log`, `templates\DISM_SAMPLE.log`, `templates\SFC_SAMPLE.log`, and `templates\GETHELP_SAMPLE.log`.

## 8. Repair Coverage Baseline

The 2026-05-17 Microsoft official source expansion produces:
- normalized records: `90`
- Microsoft official reference records: `25`
- component coverage: `100%`
- Microsoft official component coverage: `88.89%`
- target coverage gate: `80%`

This is diagnostic/guided coverage, not a promise that 100% of Windows problems can be safely auto-repaired. Auto-repair remains allowlist-only, preview-first, resource-gated, and RUN-gated for destructive or high-risk actions.

## 9. References
- Microsoft Intune Remediations: https://learn.microsoft.com/en-us/intune/device-management/tools/deploy-remediations
- Windows Autopilot Reset: https://learn.microsoft.com/en-us/autopilot/windows-autopilot-reset
- Windows Autopatch: https://learn.microsoft.com/en-us/windows/deployment/windows-autopatch/
- Microsoft Get Help command-line: https://learn.microsoft.com/en-us/troubleshoot/microsoft-365/admin/miscellaneous/get-help-command-line-overview
- Microsoft SetupDiag: https://learn.microsoft.com/en-in/windows/deployment/upgrade/setupdiag
- Microsoft DISM image repair: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image
- Microsoft SFC support article: https://support.microsoft.com/help/929833
- Wazuh Vulnerability Detection: https://documentation.wazuh.com/current/user-manual/capabilities/vulnerability-detection/index.html
- Wazuh Active Response: https://documentation.wazuh.com/current/user-manual/capabilities/active-response/index.html
- Boxstarter: https://boxstarter.org/
