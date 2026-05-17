# WindowsDoctor API Contract

Last updated: `2026-04-28`

Base URL: `http://localhost:3001`

## 0. Response Envelope
All current Broker routes return one of:
```json
{ "ok": true, "data": {} }
```
```json
{ "ok": false, "error": { "code": "ERROR_CODE", "message": "..." } }
```

## 1. Health
`GET /api/health`

Returns system health object:
```json
{
  "ok": true,
  "data": {
    "Timestamp": "2026-04-28 13:00:00",
    "OS": "Windows_NT 10.0.19045",
    "Version": "10.0.19045",
    "RAM_Total_GB": 15.89,
    "Disks": [],
    "IsAdmin": true
  }
}
```

## 2. Analyze
`GET /api/analyze`

Returns finding array:
```json
{
  "ok": true,
  "data": [
    {
      "EventID": "Match",
      "Source": "System Log",
      "Description": "...",
      "MatchedRule": "RULE-WU-0x8024",
      "Diagnosis": "...",
      "SuggestedFix": "Repair-WUSoftwareDistribution.bat",
      "ActionType": "auto_repair"
    }
  ]
}
```

`ActionType` values:
- `auto_repair`: allowlist repair script is available.
- `guided`: guidance only, no script execution.
- `manual_review`: script reference exists but is not allowlisted.
- `learn`: unknown issue, learn-only workflow.

## 3. Rules
`GET /api/rules`

Returns indexed KB rules from `reviewed` and `learned`:
```json
{
  "ok": true,
  "data": [
    {
      "id": "RULE-WU-0x8024",
      "title": "Windows Update 更新機制異常",
      "category": "reviewed",
      "triggers": ["0x80244018"],
      "script": "Repair-WUSoftwareDistribution.bat",
      "repairAllowed": true
    }
  ]
}
```

## 4. Repair Allowlist
`GET /api/repair/allowlist`

```json
{ "ok": true, "data": { "scripts": ["Repair-NetworkStack.bat"] } }
```

## 5. Repair
`POST /api/repair`

Body:
```json
{ "script": "Repair-NetworkStack.bat" }
```

Success:
```json
{ "ok": true, "data": { "status": "success", "output": "..." } }
```

Denied:
```json
{ "ok": false, "error": { "code": "SCRIPT_NOT_ALLOWED", "message": "Script not allowed" } }
```

## 6. Learn
`POST /api/learn`

Body:
```json
{ "title": "Case title", "errorCode": "0x00000000", "description": "..." }
```

Writes a learn-only KB rule into `knowledge_base/learned`.

## 7. Vision
`POST /api/vision-analyze`

Returns current vision adapter result. Default provider is mock. If `WD_VISION_PROVIDER=gemini` but no API key is available or the provider fails, the Broker returns mock fallback without exposing secrets.

## 8. Management
`GET /api/admin/status`

Returns management mode, role classes, audit count, local profile, and NAS optional policy. This endpoint is read-only.

`GET /api/admin/accounts`

Requires admin token through `Authorization: Bearer <token>`. Returns public admin account records only; token hashes are never returned.

`POST /api/admin/accounts`

Requires admin token. Body:
```json
{ "adminId": "ops1", "displayName": "Operator", "role": "operator", "token": "new-token" }
```

`POST /api/admin/disable`

Requires admin token. Body:
```json
{ "adminId": "ops1", "disabled": true, "reason": "rotation" }
```

`GET /api/admin/audit`

Requires admin token. Returns append-only management audit events.

`POST /api/admin/profile/write`

Requires maintainer token. Writes `nas/windowsdoctor-management-profile.json`. NAS remains optional.

Gemini config:
- `WD_VISION_PROVIDER=gemini`
- `GEMINI_API_KEY` or `WD_GEMINI_API_KEY`
- `WD_GEMINI_MODEL` optional, default `gemini-1.5-flash`
- `WD_VISION_TIMEOUT_MS` optional, default `12000`

`GET /api/vision/status`

```json
{ "ok": true, "data": { "provider": "mock", "configured": true, "fallback": "mock", "timeoutMs": 12000 } }
```

## 8. Config And Sync
- `GET /api/config/kb`
- `POST /api/config/kb`
- `POST /api/sync`

## 9. Vault
- `POST /api/vault/save`
- `GET /api/vault/lock-status`
- `POST /api/vault/lock-bind`
