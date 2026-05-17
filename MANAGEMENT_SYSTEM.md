# WindowsDoctor Management System

Last updated: `2026-05-17`

## Purpose
WindowsDoctor management is local-first. It protects diagnosis, preview, repair execution, cleanup, real-data import, allowlist promotion, AI settings, USB publishing, and audit visibility without making NAS mandatory.

## Reference Model
The structure follows the useful parts of `TdccAutoV3`:
- management service profile
- viewer/operator/admin role split
- hashed admin tokens
- JSONL audit events
- management UI page
- optional NAS/runtime profile

WindowsDoctor does not copy TDCC licensing behavior. It uses the model only for local administration and repair safety.

## Roles
| Role | Allowed scope |
|---|---|
| `viewer` | read status, rules, reports, resource status, diagnostic results |
| `operator` | run previews, create diagnostic work, cancel work |
| `admin` | perform RUN-gated repair/cleanup/logoff/uninstall operations after explicit confirmation |
| `maintainer` | change KB promotion, allowlist, repair policy, release/package policy |

## Operation Classes
| Class | Minimum role | Meaning |
|---|---|---|
| `read_only` | viewer | no state change |
| `preview` | operator | estimates impact, writes reports only |
| `run_gated` | admin | changes system/application state and still requires `RUN` |
| `admin_only` | admin | manages admin accounts and audit visibility |
| `maintainer_only` | maintainer | changes trusted repair policy or release controls |

## Storage
- Admin account hashes: `management\admin_accounts.json`
- Audit events: `management\admin_audit_events.jsonl`
- Optional profile: `nas\windowsdoctor-management-profile.json`

Token hashes use PBKDF2-SHA256 and plaintext tokens are not written to disk.

## API
- `GET /api/admin/status`
- `GET /api/admin/accounts`
- `POST /api/admin/accounts`
- `POST /api/admin/disable`
- `GET /api/admin/audit`
- `POST /api/admin/profile/write`

External access must use a token. Environment tokens are:
- `WD_VIEWER_TOKEN`
- `WD_OPERATOR_TOKEN`
- `WD_ADMIN_TOKEN`
- `WD_MAINTAINER_TOKEN`

## NAS Policy
NAS is optional. It may store shared audit, package repository, and profile files later, but WindowsDoctor must remain usable from local disk and USB without NAS.

## Safety
- No repair or cleanup executes from management setup.
- RUN gate remains mandatory for state-changing actions.
- Maintainer role is required before policy or allowlist changes.
- Audit events are append-only JSONL records.
