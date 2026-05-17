import type { IssuePlan, WorkStatus } from "@/types/windows-doctor";

type Props = {
  problemText: string;
  loading: boolean;
  plan: IssuePlan | null;
  workStatus: WorkStatus | null;
  onTextChange: (value: string) => void;
  onPreview: () => void;
  onStartWork: () => void;
};

export function ProblemSolverPanel({ problemText, loading, plan, workStatus, onTextChange, onPreview, onStartWork }: Props) {
  const active = workStatus?.active?.type === "issue-diagnostic" ? workStatus.active : null;
  const lastIssuePlan = workStatus?.last?.result?.issuePlan || null;
  const displayPlan = lastIssuePlan || plan;

  return (
    <section className="max-w-6xl mx-auto mb-8 border border-blue-500/30 bg-blue-950/20 rounded-lg p-4 md:p-5">
      <div className="flex flex-col gap-4">
        <div>
          <h2 className="text-lg font-semibold text-white">AI 一鍵問題處理</h2>
          <p className="text-sm text-slate-300 mt-1">輸入你要解決的 Windows 問題，系統會自動分類、比對 KB、建立診斷計畫與安全修復預覽。</p>
        </div>
        <textarea
          value={problemText}
          onChange={(event) => onTextChange(event.target.value)}
          placeholder="例如：印表機不能列印、Windows Update 失敗、電腦很慢、裝置管理員 Code 43"
          className="min-h-24 resize-y rounded-md border border-white/15 bg-black/40 px-3 py-3 text-sm text-white outline-none focus:border-blue-400"
        />
        <div className="flex flex-wrap gap-3">
          <button
            onClick={onPreview}
            disabled={loading || !problemText.trim()}
            className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? "分析中" : "建立安全預覽"}
          </button>
          <button
            onClick={onStartWork}
            disabled={loading || !problemText.trim() || !!active}
            className="rounded-md border border-blue-400/60 px-4 py-2 text-sm font-medium text-blue-100 disabled:cursor-not-allowed disabled:opacity-50"
          >
            放入即時工作視窗
          </button>
        </div>
      </div>

      {active && (
        <div className="mt-4 rounded-md border border-cyan-500/30 bg-cyan-950/20 p-3 text-sm text-cyan-100">
          目前工作：{active.currentStep}
          {active.latestResource ? `，可用記憶體 ${active.latestResource.freeMemoryGB ?? "?"}GB` : ""}
        </div>
      )}

      {displayPlan && (
        <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-3">
          <div className="rounded-md border border-white/10 bg-black/30 p-3">
            <div className="text-xs uppercase text-slate-400">分類</div>
            <div className="mt-1 text-base font-semibold text-white">{displayPlan.Classification.label}</div>
            <div className="text-sm text-slate-300">信心 {displayPlan.Classification.confidence}%</div>
          </div>
          <div className="rounded-md border border-white/10 bg-black/30 p-3">
            <div className="text-xs uppercase text-slate-400">可自動修復候選</div>
            <div className="mt-1 text-2xl font-semibold text-white">{displayPlan.RepairPreview.Outcome.autoRepairReady.length}</div>
            <div className="text-sm text-slate-300">真正執行仍需 RUN</div>
          </div>
          <div className="rounded-md border border-white/10 bg-black/30 p-3">
            <div className="text-xs uppercase text-slate-400">需人工/補證據</div>
            <div className="mt-1 text-2xl font-semibold text-white">{displayPlan.UserReport.NotFixed.length}</div>
            <div className="text-sm text-slate-300">已阻擋高風險自動修復</div>
          </div>
          <div className="rounded-md border border-white/10 bg-black/30 p-3">
            <div className="text-xs uppercase text-slate-400">專項診斷</div>
            <div className="mt-1 text-2xl font-semibold text-white">{displayPlan.SpecializedDiagnostics?.CheckCount ?? 0}</div>
            <div className="text-sm text-slate-300">{displayPlan.SpecializedDiagnostics?.Status ?? "UNKNOWN"}</div>
          </div>
          <div className="md:col-span-3 rounded-md border border-white/10 bg-black/30 p-3">
            <div className="text-sm font-medium text-white">{displayPlan.UserReport.Summary}</div>
            <ul className="mt-2 list-disc pl-5 text-sm text-slate-300">
              {displayPlan.UserReport.NextActions.map((item) => <li key={item}>{item}</li>)}
            </ul>
          </div>
        </div>
      )}
    </section>
  );
}
