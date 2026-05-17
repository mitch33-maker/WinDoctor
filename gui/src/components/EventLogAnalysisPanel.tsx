import type { EventLogAnalysis } from "@/types/windows-doctor";

type EventLogAnalysisPanelProps = {
  analysis: EventLogAnalysis | null;
  loading: boolean;
  onRun: () => void;
};

export function EventLogAnalysisPanel({ analysis, loading, onRun }: EventLogAnalysisPanelProps) {
  return (
    <section className="max-w-6xl mx-auto mt-8 p-5 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-sky-300">系統日誌解讀</h2>
          <p className="text-sm text-gray-400">唯讀分析 System/Application 事件、Provider、Event ID、KB 命中與處理分類</p>
        </div>
        <button
          onClick={onRun}
          disabled={loading}
          className="px-4 py-2 rounded-lg bg-sky-600 hover:bg-sky-500 disabled:opacity-50 text-sm font-bold"
        >
          {loading ? "分析中..." : "分析系統日誌"}
        </button>
      </div>

      {analysis && (
        <>
          <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Events</div>
              <div className="font-mono">{analysis.EventCount}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Errors</div>
              <div className="font-mono">{analysis.Summary.ErrorCount}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">KB matched</div>
              <div className="font-mono">{analysis.Summary.KbMatchedCount}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Preview</div>
              <div className="font-mono">{analysis.Summary.PreviewRequiredCount}</div>
            </div>
          </div>

          <div className="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-sky-200 font-bold mb-2">Top Provider</div>
              <div className="space-y-2">
                {analysis.ProviderSummary.slice(0, 6).map((item) => (
                  <div key={item.ProviderName} className="flex items-center justify-between rounded-lg bg-black/20 border border-white/10 p-3">
                    <span className="truncate">{item.ProviderName || "Unknown"}</span>
                    <span className="font-mono text-sky-200">{item.Count}</span>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <div className="text-sky-200 font-bold mb-2">主要事件</div>
              <div className="space-y-2">
                {analysis.Findings.slice(0, 5).map((finding) => (
                  <div key={`${finding.LogName}-${finding.ProviderName}-${finding.EventId}-${finding.TimeCreated}`} className="rounded-lg bg-black/20 border border-white/10 p-3">
                    <div className="flex items-center justify-between gap-3">
                      <span className="font-semibold truncate">{finding.ProviderName}</span>
                      <span className="font-mono text-xs text-gray-400">ID {finding.EventId}</span>
                    </div>
                    <div className="text-xs text-gray-400">{finding.LevelDisplayName} · {finding.PrimaryRuleId} · {finding.RepairState}</div>
                    <p className="mt-1 text-xs text-gray-300 line-clamp-2">{finding.PrimaryRecommendation}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>

          <div className="mt-4 text-xs text-gray-500">
            Report: {analysis.ReportPath || "-"} · CSV: {analysis.CsvPath || "-"} · Read-only: {String(analysis.SafetyPolicy.ReadOnly)}
          </div>
        </>
      )}
    </section>
  );
}
