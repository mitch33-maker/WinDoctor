import type { AiTriageResult } from "@/types/windows-doctor";

type AiAssistantPanelProps = {
  triage: AiTriageResult | null;
  loading: boolean;
  onRun: () => void;
};

export function AiAssistantPanel({ triage, loading, onRun }: AiAssistantPanelProps) {
  return (
    <section className="max-w-6xl mx-auto mt-8 p-5 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-violet-300">AI 本機研判助手</h2>
          <p className="text-sm text-gray-400">離線規則、資源狀態與 repair decision engine 綜合判斷</p>
        </div>
        <button
          onClick={onRun}
          disabled={loading}
          className="px-4 py-2 rounded-lg bg-violet-600 hover:bg-violet-500 disabled:opacity-50 text-sm font-bold"
        >
          {loading ? "研判中..." : "執行 AI 研判"}
        </button>
      </div>

      {triage && (
        <>
          <div className="mt-4 grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Risk</div>
              <div className="font-mono">{triage.Summary.OverallRisk}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Findings</div>
              <div className="font-mono">{triage.Summary.FindingCount}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Safe batch</div>
              <div className="font-mono">{triage.Summary.SafeBatchScriptCount}</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Free RAM</div>
              <div className="font-mono">{triage.ResourceSafety.FreeMemoryGB ?? "-"} GB</div>
            </div>
            <div className="p-3 rounded-lg bg-black/20 border border-white/10">
              <div className="text-gray-500">Node WS</div>
              <div className="font-mono">{triage.ResourceSafety.WindowsDoctorTotalWorkingSetMB ?? 0} MB</div>
            </div>
          </div>

          <div className="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-4 text-sm">
            <div>
              <div className="text-violet-200 font-bold mb-2">建議順序</div>
              <div className="space-y-2">
                {triage.NextActions.map((action) => (
                  <div key={action} className="rounded-lg bg-violet-500/10 border border-violet-500/20 p-3 text-gray-200">{action}</div>
                ))}
              </div>
            </div>
            <div>
              <div className="text-violet-200 font-bold mb-2">主要命中</div>
              <div className="space-y-2">
                {triage.Findings.slice(0, 4).map((finding) => (
                  <div key={`${finding.ruleId}-${finding.description}`} className="rounded-lg bg-black/20 border border-white/10 p-3">
                    <div className="font-semibold">{finding.title}</div>
                    <div className="text-xs text-gray-400">{finding.actionType} · {finding.riskLevel}</div>
                    <p className="mt-1 text-xs text-gray-300 line-clamp-2">{finding.recommendation}</p>
                  </div>
                ))}
                {triage.Findings.length === 0 && <p className="text-gray-500">目前沒有高風險事件命中。</p>}
              </div>
            </div>
          </div>

          <p className="mt-4 text-xs text-gray-500">
            {triage.Model} · External AI: {triage.SafetyPolicy.ExternalAi} · Repair: {triage.SafetyPolicy.RepairExecution}
          </p>
        </>
      )}
    </section>
  );
}
