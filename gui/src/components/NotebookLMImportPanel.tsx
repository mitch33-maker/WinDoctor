import { ChangeEvent, useMemo, useState } from "react";
import { windowsDoctorApi } from "@/lib/windowsDoctorApi";

type NotebookLMSource = {
  id?: unknown;
  vendor?: unknown;
  title?: unknown;
  url?: unknown;
  sourceType?: unknown;
};

type NotebookLMRecord = {
  id?: unknown;
  title?: unknown;
  component?: unknown;
  symptoms?: unknown;
  errorCodes?: unknown;
  eventIds?: unknown;
  triggerTerms?: unknown;
  recommendedActions?: unknown;
  script?: unknown;
  actionType?: unknown;
  repairAllowed?: unknown;
  riskLevel?: unknown;
  sourceIds?: unknown;
};

type NotebookLMPack = {
  notebookTitle?: unknown;
  sources?: unknown;
  records?: unknown;
};

type ValidationIssue = {
  tone: "ok" | "warning" | "error";
  label: string;
};

type ImportResult = Awaited<ReturnType<typeof windowsDoctorApi.importNotebookLM>>;

function asObject(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function normalizeId(value: unknown, prefix: string): string {
  const normalized = asString(value).replace(/[^A-Za-z0-9_.-]/g, "-").replace(/^-+|-+$/g, "");
  if (!normalized) return "";
  return normalized.startsWith(prefix) ? normalized : `${prefix}${normalized}`;
}

function readPack(raw: unknown): { title: string; sources: NotebookLMSource[]; records: NotebookLMRecord[] } {
  const pack = (asObject(raw) || {}) as NotebookLMPack;
  return {
    title: asString(pack.notebookTitle) || "NotebookLM Repair Sources",
    sources: asArray(pack.sources).map((item) => asObject(item) || {}),
    records: asArray(pack.records).map((item) => asObject(item) || {}),
  };
}

function validatePack(pack: { sources: NotebookLMSource[]; records: NotebookLMRecord[] }): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  const sourceIds = new Set<string>();

  if (pack.sources.length === 0) issues.push({ tone: "error", label: "缺少 sources" });
  if (pack.records.length === 0) issues.push({ tone: "error", label: "缺少 records" });

  for (const source of pack.sources) {
    const sourceId = normalizeId(source.id, "NBLM-SRC-");
    const sourceUrl = asString(source.url);
    if (!sourceId) issues.push({ tone: "error", label: "來源缺少 id" });
    if (sourceId && sourceIds.has(sourceId)) issues.push({ tone: "error", label: `重複來源 ${sourceId}` });
    if (sourceId) sourceIds.add(sourceId);
    if (sourceUrl && !/^(https?|file):\/\//.test(sourceUrl)) issues.push({ tone: "error", label: `${sourceId || "來源"} URL 不支援` });
  }

  for (const record of pack.records) {
    const recordId = normalizeId(record.id, "NBLM-");
    const actionType = asString(record.actionType) || "guided";
    const riskLevel = asString(record.riskLevel) || "manual_review";
    const script = asString(record.script) || "N/A";
    const sourceRefs = asArray(record.sourceIds).map((value) => normalizeId(value, "NBLM-SRC-")).filter(Boolean);
    const signalCount = asArray(record.symptoms).length + asArray(record.errorCodes).length + asArray(record.eventIds).length + asArray(record.triggerTerms).length;

    if (!recordId) issues.push({ tone: "error", label: "紀錄缺少 id" });
    if (!["auto_repair", "guided", "manual_review"].includes(actionType)) issues.push({ tone: "error", label: `${recordId || "紀錄"} actionType 無效` });
    if (!["low", "medium", "manual_review"].includes(riskLevel)) issues.push({ tone: "error", label: `${recordId || "紀錄"} riskLevel 無效` });
    if (script !== "N/A" && !/^Repair-[A-Za-z0-9_.-]+\.bat$/.test(script)) issues.push({ tone: "error", label: `${recordId || "紀錄"} script 無效` });
    if (sourceRefs.length === 0) issues.push({ tone: "error", label: `${recordId || "紀錄"} 缺少 sourceIds` });
    if (sourceRefs.some((sourceId) => !sourceIds.has(sourceId))) issues.push({ tone: "error", label: `${recordId || "紀錄"} 來源對應失敗` });
    if (signalCount === 0) issues.push({ tone: "warning", label: `${recordId || "紀錄"} 缺少診斷訊號` });
  }

  if (issues.length === 0) issues.push({ tone: "ok", label: "格式可接入" });
  return issues;
}

export function NotebookLMImportPanel() {
  const [activeTab, setActiveTab] = useState<"source-pack" | "enterprise">("source-pack");
  const [fileName, setFileName] = useState("");
  const [jsonText, setJsonText] = useState("");
  const [parseError, setParseError] = useState("");
  const [busy, setBusy] = useState(false);
  const [importResult, setImportResult] = useState<ImportResult | null>(null);
  const [importError, setImportError] = useState("");
  const [enterprise, setEnterprise] = useState({ projectNumber: "", location: "global", endpoint: "global", notebookId: "" });

  const rawPack = useMemo(() => {
    if (!jsonText.trim()) return null;
    try {
      return JSON.parse(jsonText) as unknown;
    } catch {
      return null;
    }
  }, [jsonText]);

  const parsed = useMemo(() => rawPack ? readPack(rawPack) : null, [rawPack]);
  const issues = useMemo(() => parsed ? validatePack(parsed) : [], [parsed]);
  const errorCount = issues.filter((issue) => issue.tone === "error").length;
  const warningCount = issues.filter((issue) => issue.tone === "warning").length;
  const actionCount = parsed?.records.filter((record) => asString(record.script) !== "N/A").length || 0;
  const canImport = Boolean(rawPack && !parseError && errorCount === 0);

  const onFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setFileName(file.name);
    setImportResult(null);
    setImportError("");
    const text = await file.text();
    try {
      JSON.parse(text);
      setParseError("");
    } catch {
      setParseError("JSON 解析失敗");
    }
    setJsonText(text);
  };

  const importSourcePack = async () => {
    if (!rawPack || !canImport) return;
    setBusy(true);
    setImportResult(null);
    setImportError("");
    try {
      setImportResult(await windowsDoctorApi.importNotebookLM(rawPack));
    } catch (error) {
      setImportError(error instanceof Error ? error.message : "匯入失敗");
    } finally {
      setBusy(false);
    }
  };

  const enterpriseUrl = enterprise.notebookId
    ? `https://notebooklm.cloud.google.com/${enterprise.location}/notebook/${enterprise.notebookId}?project=${enterprise.projectNumber}`
    : `https://notebooklm.cloud.google.com/${enterprise.location}/?project=${enterprise.projectNumber}`;

  return (
    <section className="max-w-6xl mx-auto mt-8 overflow-hidden rounded-2xl border border-[#dadce0] bg-[#f8fafd] text-[#202124] shadow-[0_18px_60px_rgba(0,0,0,0.28)]">
      <div className="grid grid-cols-1 lg:grid-cols-[260px_1fr_320px] min-h-[560px]">
        <aside className="border-b lg:border-b-0 lg:border-r border-[#e8eaed] bg-white p-4">
          <div className="flex items-center gap-3 pb-5">
            <div className="grid h-10 w-10 grid-cols-2 gap-1" aria-hidden="true">
              <span className="rounded-full bg-[#4285f4]" />
              <span className="rounded-full bg-[#ea4335]" />
              <span className="rounded-full bg-[#fbbc04]" />
              <span className="rounded-full bg-[#34a853]" />
            </div>
            <div>
              <p className="text-xs font-medium text-[#5f6368]">NotebookLM</p>
              <h2 className="text-lg font-semibold">資料接入</h2>
            </div>
          </div>

          <div className="space-y-2">
            <button
              type="button"
              onClick={() => setActiveTab("source-pack")}
              className={`w-full rounded-full px-4 py-2 text-left text-sm font-semibold ${activeTab === "source-pack" ? "bg-[#e8f0fe] text-[#1967d2]" : "text-[#3c4043] hover:bg-[#f1f3f4]"}`}
            >
              Source Pack
            </button>
            <button
              type="button"
              onClick={() => setActiveTab("enterprise")}
              className={`w-full rounded-full px-4 py-2 text-left text-sm font-semibold ${activeTab === "enterprise" ? "bg-[#e8f0fe] text-[#1967d2]" : "text-[#3c4043] hover:bg-[#f1f3f4]"}`}
            >
              Enterprise API
            </button>
          </div>

          <div className="mt-6 rounded-xl border border-[#e8eaed] bg-[#f8fafd] p-4">
            <p className="text-xs font-semibold text-[#5f6368]">目前狀態</p>
            <p className="mt-2 text-2xl font-semibold">{parsed?.records.length || 0}</p>
            <p className="text-xs text-[#5f6368]">待接入紀錄</p>
          </div>
        </aside>

        <div className="p-5 md:p-7">
          {activeTab === "source-pack" ? (
            <div className="space-y-5">
              <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
                <div>
                  <p className="text-xs font-medium text-[#5f6368]">Repair Knowledge Source Pack</p>
                  <h3 className="text-2xl font-semibold">{parsed?.title || "尚未載入資料"}</h3>
                  <p className="mt-1 text-xs text-[#5f6368]">{fileName || "templates\\NOTEBOOKLM_SOURCE_PACK_TEMPLATE.json"}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <label className="inline-flex cursor-pointer items-center justify-center rounded-full bg-[#1a73e8] px-5 py-2.5 text-sm font-semibold text-white hover:bg-[#1765cc]">
                    選取 JSON
                    <input type="file" accept="application/json,.json" className="sr-only" onChange={onFileChange} />
                  </label>
                  <button
                    type="button"
                    onClick={importSourcePack}
                    disabled={!canImport || busy}
                    className="rounded-full bg-[#202124] px-5 py-2.5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:bg-[#bdc1c6]"
                  >
                    {busy ? "匯入中" : "匯入並重建"}
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div className="rounded-xl bg-white p-4 shadow-sm">
                  <p className="text-[11px] text-[#5f6368]">來源</p>
                  <p className="text-2xl font-semibold">{parsed?.sources.length || 0}</p>
                </div>
                <div className="rounded-xl bg-white p-4 shadow-sm">
                  <p className="text-[11px] text-[#5f6368]">紀錄</p>
                  <p className="text-2xl font-semibold">{parsed?.records.length || 0}</p>
                </div>
                <div className="rounded-xl bg-white p-4 shadow-sm">
                  <p className="text-[11px] text-[#5f6368]">修復參照</p>
                  <p className="text-2xl font-semibold">{actionCount}</p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_1fr]">
                <div className="rounded-xl border border-[#e8eaed] bg-white">
                  <div className="border-b border-[#e8eaed] px-4 py-3 text-sm font-semibold">Sources</div>
                  <div className="max-h-[260px] overflow-auto p-3">
                    {(parsed?.sources || []).map((source, index) => (
                      <div key={`${asString(source.id)}-${index}`} className="rounded-lg px-3 py-2 hover:bg-[#f8fafd]">
                        <p className="text-sm font-semibold">{asString(source.title) || asString(source.id) || "Untitled source"}</p>
                        <p className="truncate text-xs text-[#5f6368]">{asString(source.url) || "local source"}</p>
                      </div>
                    ))}
                    {!parsed && <p className="px-3 py-8 text-center text-sm text-[#5f6368]">請載入 JSON</p>}
                  </div>
                </div>

                <div className="rounded-xl border border-[#e8eaed] bg-white">
                  <div className="border-b border-[#e8eaed] px-4 py-3 text-sm font-semibold">Records</div>
                  <div className="max-h-[260px] overflow-auto p-3">
                    {(parsed?.records || []).map((record, index) => (
                      <div key={`${asString(record.id)}-${index}`} className="rounded-lg px-3 py-2 hover:bg-[#f8fafd]">
                        <p className="text-sm font-semibold">{asString(record.title) || asString(record.id) || "Untitled record"}</p>
                        <p className="text-xs text-[#5f6368]">{asString(record.component) || "general"} | {asString(record.actionType) || "guided"}</p>
                      </div>
                    ))}
                    {!parsed && <p className="px-3 py-8 text-center text-sm text-[#5f6368]">等待 source pack</p>}
                  </div>
                </div>
              </div>

              <textarea
                value={jsonText}
                onChange={(event) => {
                  setJsonText(event.target.value);
                  setImportResult(null);
                  setImportError("");
                  try {
                    if (event.target.value.trim()) JSON.parse(event.target.value);
                    setParseError("");
                  } catch {
                    setParseError("JSON 解析失敗");
                  }
                }}
                spellCheck={false}
                placeholder="貼上 NotebookLM source pack JSON"
                className="min-h-[150px] w-full resize-y rounded-xl border border-[#dadce0] bg-white p-4 font-mono text-xs outline-none focus:border-[#1a73e8]"
              />
            </div>
          ) : (
            <div className="space-y-5">
              <div>
                <p className="text-xs font-medium text-[#5f6368]">NotebookLM Enterprise</p>
                <h3 className="text-2xl font-semibold">官方 API 連線資訊</h3>
              </div>

              <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
                <label className="text-sm font-semibold">
                  Project number
                  <input className="mt-2 w-full rounded-xl border border-[#dadce0] bg-white px-4 py-3 outline-none focus:border-[#1a73e8]" value={enterprise.projectNumber} onChange={(event) => setEnterprise({ ...enterprise, projectNumber: event.target.value })} />
                </label>
                <label className="text-sm font-semibold">
                  Location
                  <input className="mt-2 w-full rounded-xl border border-[#dadce0] bg-white px-4 py-3 outline-none focus:border-[#1a73e8]" value={enterprise.location} onChange={(event) => setEnterprise({ ...enterprise, location: event.target.value })} />
                </label>
                <label className="text-sm font-semibold">
                  Endpoint
                  <input className="mt-2 w-full rounded-xl border border-[#dadce0] bg-white px-4 py-3 outline-none focus:border-[#1a73e8]" value={enterprise.endpoint} onChange={(event) => setEnterprise({ ...enterprise, endpoint: event.target.value })} />
                </label>
                <label className="text-sm font-semibold">
                  Notebook ID
                  <input className="mt-2 w-full rounded-xl border border-[#dadce0] bg-white px-4 py-3 outline-none focus:border-[#1a73e8]" value={enterprise.notebookId} onChange={(event) => setEnterprise({ ...enterprise, notebookId: event.target.value })} />
                </label>
              </div>

              <div className="rounded-xl bg-[#202124] p-4 font-mono text-xs leading-relaxed text-[#e8eaed]">
                <p>GET https://{enterprise.endpoint || "global"}-discoveryengine.googleapis.com/v1alpha/projects/{enterprise.projectNumber || "PROJECT_NUMBER"}/locations/{enterprise.location || "LOCATION"}/notebooks/{enterprise.notebookId || "NOTEBOOK_ID"}</p>
              </div>

              <button
                type="button"
                onClick={() => window.open(enterpriseUrl, "_blank", "noopener,noreferrer")}
                className="rounded-full bg-[#1a73e8] px-5 py-2.5 text-sm font-semibold text-white hover:bg-[#1765cc]"
              >
                開啟 NotebookLM
              </button>
            </div>
          )}
        </div>

        <aside className="border-t border-[#e8eaed] bg-white p-5 lg:border-l lg:border-t-0">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold">接入檢查</h3>
            <span className="text-xs text-[#5f6368]">{warningCount} warning / {errorCount} error</span>
          </div>

          <div className="mt-4 space-y-2">
            {parseError && <div className="rounded-xl bg-[#fce8e6] px-4 py-3 text-sm text-[#c5221f]">{parseError}</div>}
            {importError && <div className="rounded-xl bg-[#fce8e6] px-4 py-3 text-sm text-[#c5221f]">{importError}</div>}
            {importResult && (
              <div className="rounded-xl bg-[#e6f4ea] px-4 py-3 text-sm text-[#137333]">
                匯入完成：{importResult.importResult.RecordCount || 0} 筆，normalized records {importResult.normalizedValidation.TotalRecords || 0}
              </div>
            )}
            {!jsonText.trim() && <div className="rounded-xl border border-[#dadce0] bg-white px-4 py-3 text-sm text-[#5f6368]">等待 JSON source pack</div>}
            {issues.map((issue) => (
              <div
                key={issue.label}
                className={`rounded-xl px-4 py-3 text-sm ${
                  issue.tone === "error"
                    ? "bg-[#fce8e6] text-[#c5221f]"
                    : issue.tone === "warning"
                      ? "bg-[#fef7e0] text-[#b06000]"
                      : "bg-[#e6f4ea] text-[#137333]"
                }`}
              >
                {issue.label}
              </div>
            ))}
          </div>

          <div className="mt-6 rounded-xl border border-[#e8eaed] bg-[#f8fafd] p-4 text-xs leading-relaxed text-[#5f6368]">
            消費版 NotebookLM 以匯出 JSON source pack 接入。Enterprise API 需要 Google Cloud 專案、IAM 與 access token。
          </div>
        </aside>
      </div>
    </section>
  );
}
