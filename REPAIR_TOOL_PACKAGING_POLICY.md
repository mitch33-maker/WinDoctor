# Repair Tool Packaging Policy

Last updated: `2026-05-17`

## Purpose
Package optional repair or diagnostic tools for portable WindowsDoctor use without silently installing or executing them.

This policy is for tool packaging only. It does not approve any tool for automatic repair execution.

## Safety Rules
- No tool is installed by packaging.
- No tool is executed by packaging.
- Every packaged file must match an expected SHA-256 hash.
- Every tool must declare publisher, version, source URL, trust level, license, allowed use, and execution policy.
- Default execution policy is `manual_only` or `diagnostic_only`.
- `autoRunAllowed` must be `false`.
- Broad cleanup suites, debloat scripts, unsigned executables, unknown publishers, and community-only scripts are blocked from trusted packaging.
- Download is disabled unless an operator explicitly uses a script flag and the manifest already contains an expected SHA-256.
- Packaged tools stay under `releases\repair-tools` or the USB package as isolated evidence/tools, not as allowlisted repairs.

## Allowed Trust Levels
| Trust Level | Use |
|---|---|
| `microsoft_official` | Microsoft official tools and diagnostics |
| `vendor_official` | Hardware or application vendor official tools |
| `enterprise_internal` | Organization-owned internal tools with hash and owner |

Blocked trust levels:
- `community_unverified`
- `unknown`
- `advertising_bundle`
- `cracked_or_repacked`

## Required Manifest Fields
Each tool record must include:
- `id`
- `name`
- `version`
- `publisher`
- `sourceUrl`
- `sourceTrustLevel`
- `expectedSha256`
- `license`
- `allowedUse`
- `executionPolicy`
- `autoRunAllowed`
- `files`

## Workflow
1. Put candidate tool files under `incoming\repair-tools`.
2. Create a manifest from `templates\REPAIR_TOOL_PACKAGE_MANIFEST.template.json`.
3. Validate:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Test-RepairToolPackageManifest.ps1 -ManifestPath E:\WindowsDoctor\incoming\repair-tools\manifest.json -Json
```
4. Package:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\New-RepairToolPackage.ps1 -ManifestPath E:\WindowsDoctor\incoming\repair-tools\manifest.json -OutputRoot E:\WindowsDoctor\releases\repair-tools -Json
```

Microsoft official offline diagnostic acquisition:
```powershell
powershell -NoProfile -ExecutionPolicy RemoteSigned -File E:\WindowsDoctor\scripts\Save-OfflineRepairTools.ps1 -Root E:\WindowsDoctor -ReportPath E:\WindowsDoctor\logs\offline-repair-tools-acquisition.latest.json -Json
```

The built-in acquisition list includes only SetupDiag and selected Microsoft Sysinternals diagnostic tools. High-risk Sysinternals utilities such as PsExec, PsKill, SDelete, and PsShutdown are intentionally excluded.

## Promotion Boundary
Packaging a tool does not add it to:
- `scripts\repair-allowlist.json`
- `knowledge_base\reviewed`
- one-click repair execution

Any execution path still requires reviewed KB, preview, dry-run impact, rollback guidance, local validation, allowlist review, and RUN gate.

## Offline UI Auto-Selection
The offline interface may automatically select packaged diagnostic tools based on the user's problem category:
- Windows Update: SetupDiag and trace tools.
- Performance: RAMMap and Process Explorer.
- Network: TCPView and Process Explorer.
- Printer: Process Monitor and Handle.
- Boot, hardware, and system integrity: Sigcheck, Autoruns, or trace tools as diagnostic evidence.

This selection is not execution approval. The interface may display tool purpose, availability, package path, and a sequential command preview. It must not execute, extract, install, or add any selected tool to the repair allowlist unless a separate reviewed diagnostic runner is created and explicitly RUN-gated.
