# WindowsDoctor Security Policy

Last updated: `2026-05-09`

## 1. Repair Execution Policy
- GUI repair execution must go through `/api/repair`.
- `/api/repair` may execute only scripts listed in `scripts/repair-allowlist.json`.
- Allowed repair scripts must match `Repair-*.bat`.
- Dynamic scripts, path traversal, PowerShell repair scripts, and unknown generated scripts are denied.
- `/api/learn` is learn-only and must write `Script: "N/A"` unless a human-reviewed repair script is later promoted.
- One-click repair execution must remain preview-first and must reject execution unless the operator explicitly provides `RUN`.

## 1.1 Operator Safety Gates
- Every unattended work session must first run `scripts\Test-ResourceSafety.ps1 -Json`.
- GUI/Broker startup is not part of unattended validation unless explicitly requested.
- Production build is not part of unattended validation unless explicitly requested.
- Repair, cleanup, destructive maintenance, BCD/boot changes, and system maintenance must not execute without explicit `RUN`.
- Real-data intake may validate candidate files, but must not import or rebuild KB until real user-provided evidence exists and the operator asks for import.

## 2. Knowledge Base Trust Levels
- `knowledge_base/reviewed`: trusted for diagnosis; may reference allowlisted repair scripts.
- `knowledge_base/learned`: unreviewed learn-only cases; no executable repair scripts.
- `knowledge_base/archived`: ignored by Broker; retained for audit/history only.

## 3. Broker Security Boundaries
- Broker reads repair policy from `scripts/repair-allowlist.json`.
- Broker normalizes KB script references; only `Repair-*.bat` or `N/A` are valid.
- Broker executes repair scripts with fixed `cmd.exe` arguments through `spawn`, not dynamic shell string execution.
- Repair execution uses a timeout (`WD_REPAIR_TIMEOUT_MS`, default 120000 ms) to avoid hanging privileged actions.
- Credential vault data is encrypted with AES-GCM using the local machine UUID-derived key.
- Environment lock status is advisory for the GUI and should not be treated as a complete access-control system.
- Management roles are `viewer`, `operator`, `admin`, and `maintainer`.
- Management account tokens are stored only as PBKDF2-SHA256 hashes under `management\admin_accounts.json`.
- Management audit events are append-only JSONL records under `management\admin_audit_events.jsonl`.
- NAS is optional for management; local disk and USB operation must remain available without NAS.
- External management access requires token-based authorization.
- Windows event log analysis is read-only; it may write JSON/CSV evidence but must not change services, registry, drivers, accounts, storage, network, or repair state.
- Event-log repair hints remain preview-first and must still pass allowlist, dry-run impact, rollback guidance, local validation, and RUN gate before execution.
- Optional repair/diagnostic tool packaging must validate manifest metadata, HTTPS source URL, source trust level, SHA-256 hash, license note, execution policy, and `autoRunAllowed=false`.
- Tool packaging must not install, execute, register services, change PATH, add scheduled tasks, or update `scripts\repair-allowlist.json`.
- Microsoft offline diagnostic acquisition must verify SHA-256 and Authenticode signatures where executable files are present, and must exclude high-risk remote execution or destructive tools from default packaging.
- Offline UI automatic tool selection may recommend packaged diagnostic tools and show sequential command previews, but must not execute, extract, install, or promote any tool into repair allowlist without a separate reviewed RUN-gated diagnostic runner.

## 4. Antivirus And EDR Compatibility
- Standard operations use `ExecutionPolicy RemoteSigned`; `ExecutionPolicy Bypass`, encoded commands, and `Invoke-Expression` are prohibited in repository scripts.
- GUI/Broker startup is visible by default. Hidden windows require explicit `-Hidden`.
- Learn-only ingestion cannot create executable scripts or modify the repair allowlist.
- API keys and secrets must come from environment variables or local vault storage; they must not be written into source files.

## 5. Network And Vision
- Vision defaults to mock fallback.
- `WD_VISION_PROVIDER` may select a provider, but no API key should be hard-coded.
- Gemini Vision keys must be supplied through `GEMINI_API_KEY` or `WD_GEMINI_API_KEY`; status APIs must not expose key values.
- Vision provider calls must use timeout and fallback to mock on missing keys, timeout, provider errors, or empty responses.
- `WD_SEARCH_TIMEOUT_MS` bounds web search time during learn-only ingestion.

## 6. Promotion Rule
To promote a learned case into executable repair:
1. Create or review a `Repair-*.bat` script.
2. Confirm the script ends with `exit /b 0`.
3. Add it to `scripts/repair-allowlist.json`.
4. Move the KB rule from `learned` to `reviewed`.
5. Run `scripts\Test-SystemBaseline.ps1`.
