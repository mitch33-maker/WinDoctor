import type { WorkStatus } from "@/types/windows-doctor";

type WorkStatusPanelProps = {
  workStatus: WorkStatus | null;
  loading: boolean;
  onRefresh: () => void;
  onCancel: () => void;
};

export function WorkStatusPanel({ workStatus, loading, onRefresh, onCancel }: WorkStatusPanelProps) {
  const item = workStatus?.active || workStatus?.last || null;
  const latest = item?.latestResource;
  const summary = item?.result?.summary;
  const offlineDiagnostics = item?.result?.offlineDiagnostics;

  return (
    <section className="max-w-6xl mx-auto mt-8 p-5 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-cyan-300">即時工作視窗</h2>
          <p className="text-sm text-gray-400">
            {item ? `${item.currentStep} · ${item.status}` : "目前沒有執行中的工作"}
          </p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={onRefresh}
            disabled={loading}
            className="px-4 py-2 rounded-lg bg-slate-700 hover:bg-slate-600 disabled:opacity-50 text-sm font-bold"
          >
            更新
          </button>
          <button
            onClick={onCancel}
            disabled={!item?.canCancel || loading}
            className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 disabled:opacity-40 text-sm font-bold"
          >
            中斷
          </button>
        </div>
      </div>

      {item && (
        <div className="mt-4 grid grid-cols-2 md:grid-cols-6 gap-3 text-sm">
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">狀態</div>
            <div className="font-mono">{item.status}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">CPU</div>
            <div className="font-mono">{latest?.overallCpuPercent ?? "-"} %</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Free RAM</div>
            <div className="font-mono">{latest?.freeMemoryGB ?? "-"} GB</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Node</div>
            <div className="font-mono">{latest?.windowsDoctorNodeProcessCount ?? 0}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Total WS</div>
            <div className="font-mono">{latest?.windowsDoctorTotalWorkingSetMB ?? 0} MB</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Max WS</div>
            <div className="font-mono">{latest?.windowsDoctorMaxProcessWorkingSetMB ?? 0} MB</div>
          </div>
        </div>
      )}

      {item?.error && (
        <p className="mt-4 text-sm text-red-300 break-words">{item.error}</p>
      )}

      {offlineDiagnostics && (
        <div className="mt-5 rounded-lg border border-emerald-500/20 bg-emerald-950/10 p-4 text-sm">
          <div className="flex flex-col gap-1 md:flex-row md:items-center md:justify-between">
            <div className="font-bold text-emerald-200">離線診斷工具</div>
            <div className="font-mono text-xs text-emerald-100">
              {offlineDiagnostics.Mode} · tools={offlineDiagnostics.ToolCount} · executed={String(offlineDiagnostics.Executed)}
            </div>
          </div>
          <div className="mt-3 grid grid-cols-1 gap-2 md:grid-cols-2">
            {offlineDiagnostics.PlannedTools.map((tool) => (
              <div key={tool.Id} className="rounded-md border border-white/10 bg-black/30 p-3">
                <div className="flex items-center justify-between gap-3">
                  <div className="font-semibold text-white">{tool.Name}</div>
                  <div className="text-xs text-slate-300">{tool.Status}</div>
                </div>
                <code className="mt-2 block break-all rounded border border-white/10 bg-black/40 p-2 text-xs text-slate-200">
                  {tool.CommandPreview || "No command preview"}
                </code>
              </div>
            ))}
          </div>
        </div>
      )}

      {summary && (
        <div className="mt-5 grid grid-cols-1 lg:grid-cols-3 gap-4 text-sm">
          <div>
            <div className="text-green-300 font-bold mb-2">已修復</div>
            {summary.repaired.length === 0 ? <p className="text-gray-500">沒有執行修復或沒有可安全修復項目。</p> : summary.repaired.map((entry) => (
              <div key={`${entry.id}-${entry.script}`} className="mb-2 rounded-lg bg-green-500/10 border border-green-500/20 p-3">
                <div className="font-semibold">{entry.title}</div>
                <code className="text-xs text-green-200">{entry.script}</code>
              </div>
            ))}
          </div>
          <div>
            <div className="text-yellow-300 font-bold mb-2">無法自動修復</div>
            {summary.notRepaired.length === 0 ? <p className="text-gray-500">沒有未修復項目。</p> : summary.notRepaired.slice(0, 6).map((entry) => (
              <div key={`${entry.id}-${entry.reason}`} className="mb-2 rounded-lg bg-yellow-500/10 border border-yellow-500/20 p-3">
                <div className="font-semibold">{entry.title}</div>
                <div className="text-xs text-yellow-100">{entry.reason}</div>
              </div>
            ))}
          </div>
          <div>
            <div className="text-blue-300 font-bold mb-2">後續建議</div>
            <ul className="space-y-2 text-gray-300">
              {summary.nextSteps.map((step) => <li key={step}>{step}</li>)}
            </ul>
          </div>
        </div>
      )}

      {item?.reportPath && (
        <p className="mt-4 text-xs text-gray-500 break-all">Report: {item.reportPath}</p>
      )}
    </section>
  );
}
