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

## Promotion Boundary
Packaging a tool does not add it to:
- `scripts\repair-allowlist.json`
- `knowledge_base\reviewed`
- one-click repair execution

Any execution path still requires reviewed KB, preview, dry-run impact, rollback guidance, local validation, allowlist review, and RUN gate.
