import { readApiResponse } from "@/lib/api";
import type { AdminAccountList, AdminAudit, AdminStatus, AiTriageResult, EventLogAnalysis, Finding, HealthData, IssuePlan, LockStatus, OfflineToolPlan, RepairPlan, RuleIndexItem, VisionResult, VisionStatus, WorkStatus } from "@/types/windows-doctor";

const BASE_URL = "http://localhost:3001";

async function apiGet<T>(path: string): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`);
  return readApiResponse<T>(res, `GET ${path}`);
}

async function apiPost<T>(path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return readApiResponse<T>(res, `POST ${path}`);
}

async function apiGetWithToken<T>(path: string, token: string): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : undefined,
  });
  return readApiResponse<T>(res, `GET ${path}`);
}

async function apiPostWithToken<T>(path: string, token: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return readApiResponse<T>(res, `POST ${path}`);
}

export const windowsDoctorApi = {
  getLockStatus: () => apiGet<LockStatus>("/api/vault/lock-status"),
  getAdminStatus: () => apiGet<AdminStatus>("/api/admin/status"),
  getAdminAccounts: (token: string) => apiGetWithToken<AdminAccountList>("/api/admin/accounts", token),
  getAdminAudit: (token: string) => apiGetWithToken<AdminAudit>("/api/admin/audit", token),
  createAdminAccount: (token: string, body: { adminId: string; displayName: string; role: string; token: string; note?: string }) => apiPostWithToken<AdminAccountList>("/api/admin/accounts", token, body),
  setAdminDisabled: (token: string, body: { adminId: string; disabled: boolean; reason?: string }) => apiPostWithToken<AdminAccountList>("/api/admin/disable", token, body),
  writeManagementProfile: (token: string) => apiPostWithToken<{ Status: string }>("/api/admin/profile/write", token),
  getRules: () => apiGet<RuleIndexItem[]>("/api/rules"),
  getAllowlist: () => apiGet<{ scripts: string[] }>("/api/repair/allowlist"),
  getVisionStatus: () => apiGet<VisionStatus>("/api/vision/status"),
  analyzeVision: () => apiPost<VisionResult>("/api/vision-analyze"),
  learn: (body: { title: string; errorCode: string; description: string }) => apiPost<{ id: string; webSolution?: string; mode?: string }>("/api/learn", body),
  importNotebookLM: (sourcePack: unknown) => apiPost<{
    status: string;
    inputPath: string;
    reports: Record<string, string>;
    sourcePackValidation: { Status?: string; SourceCount?: number; RecordCount?: number };
    importResult: { Status?: string; SourceCount?: number; RecordCount?: number };
    exportResult: { Status?: string; NotebookLMRecords?: number; TotalRecords?: number };
    normalizedValidation: { Status?: string; TotalRecords?: number; NotebookLMRecords?: number };
  }>("/api/notebooklm/import", { sourcePack }),
  getHealth: () => apiGet<HealthData>("/api/health"),
  analyze: () => apiGet<Finding[]>("/api/analyze"),
  repair: (script: string) => apiPost<{ status: string; output: string }>("/api/repair", { script }),
  getRepairPlan: () => apiGet<RepairPlan>("/api/repair-plan"),
  executeRepairPlan: (confirmToken: string) => apiPost<RepairPlan>("/api/repair-plan/execute", { confirmToken }),
  getWorkStatus: () => apiGet<WorkStatus>("/api/work/status"),
  cancelWork: () => apiPost<WorkStatus>("/api/work/cancel"),
  startRepairPlanWork: (body: { execute: boolean; confirmToken?: string }) => apiPost<WorkStatus>("/api/work/repair-plan", body),
  startOfflineDiagnosticWork: (body: { component: string; execute: boolean; confirmToken?: string }) => apiPost<WorkStatus>("/api/work/offline-diagnostics", body),
  getAiTriage: () => apiGet<AiTriageResult>("/api/ai/triage"),
  analyzeEventLogs: (body?: { recentHours?: number; maxEvents?: number; top?: number; logName?: string[] }) => apiPost<EventLogAnalysis>("/api/event-logs/analyze", body || {}),
  getOfflineTools: () => apiGet<{ Status: string; ToolCount: number; Tools: unknown[] }>("/api/offline-tools"),
  selectOfflineTools: (component: string) => apiPost<OfflineToolPlan>("/api/offline-tools/select", { component }),
  buildIssuePlan: (problemText: string) => apiPost<IssuePlan>("/api/ai/plan", { problemText }),
  startIssueDiagnosticWork: (problemText: string) => apiPost<WorkStatus>("/api/work/diagnose", { problemText }),
  requestElevation: () => apiPost<{ status?: string; elevated?: boolean; message?: string }>("/api/sentry/elevate"),
  saveCredential: (username: string, password: string) => apiPost<{ status: string; message: string }>("/api/vault/save", { username, password }),
  bindLock: () => apiPost<{ status: string }>("/api/vault/lock-bind"),
  setKbPath: (path: string) => apiPost<{ status: string; path: string }>("/api/config/kb", { path }),
  syncNas: () => apiPost<{ status: string; data: string }>("/api/sync", { nas: true }),
};
