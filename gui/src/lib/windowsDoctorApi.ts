import { readApiResponse } from "@/lib/api";
import type { AiTriageResult, Finding, HealthData, IssuePlan, LockStatus, RepairPlan, RuleIndexItem, VisionResult, VisionStatus, WorkStatus } from "@/types/windows-doctor";

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

export const windowsDoctorApi = {
  getLockStatus: () => apiGet<LockStatus>("/api/vault/lock-status"),
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
  getAiTriage: () => apiGet<AiTriageResult>("/api/ai/triage"),
  buildIssuePlan: (problemText: string) => apiPost<IssuePlan>("/api/ai/plan", { problemText }),
  startIssueDiagnosticWork: (problemText: string) => apiPost<WorkStatus>("/api/work/diagnose", { problemText }),
  requestElevation: () => apiPost<{ status?: string; elevated?: boolean; message?: string }>("/api/sentry/elevate"),
  saveCredential: (username: string, password: string) => apiPost<{ status: string; message: string }>("/api/vault/save", { username, password }),
  bindLock: () => apiPost<{ status: string }>("/api/vault/lock-bind"),
  setKbPath: (path: string) => apiPost<{ status: string; path: string }>("/api/config/kb", { path }),
  syncNas: () => apiPost<{ status: string; data: string }>("/api/sync", { nas: true }),
};
