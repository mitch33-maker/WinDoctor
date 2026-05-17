import type { RepairPlan } from "@/types/windows-doctor";

type OneClickRepairPanelProps = {
  plan: RepairPlan | null;
  loading: boolean;
  runToken: string;
  onRunTokenChange: (value: string) => void;
  onPreview: () => void;
  onExecute: () => void;
};

export function OneClickRepairPanel({ plan, loading, runToken, onRunTokenChange, onPreview, onExecute }: OneClickRepairPanelProps) {
  const safeScripts = plan?.SafeBatchScripts || [];
  const canExecute = runToken === "RUN" && safeScripts.length > 0 && !loading;
  const guidance = plan?.OperatorGuidance;

  return (
    <section className="max-w-6xl mx-auto mt-8 p-5 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-xl">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-blue-300">One-click repair v3</h2>
          <p className="text-sm text-gray-400">
            Safe batch only, RUN required, stop on first failure.
          </p>
        </div>
        <div className="flex flex-col sm:flex-row gap-2">
          <button
            onClick={onPreview}
            disabled={loading}
            className="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-sm font-bold"
          >
            {loading ? "Checking..." : "Preview"}
          </button>
          <input
            value={runToken}
            onChange={(event) => onRunTokenChange(event.target.value)}
            placeholder="RUN"
            className="px-3 py-2 rounded-lg bg-black/30 border border-white/10 text-sm w-24"
          />
          <button
            onClick={onExecute}
            disabled={!canExecute}
            className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-500 disabled:opacity-40 text-sm font-bold"
          >
            Execute
          </button>
        </div>
      </div>

      {plan && (
        <div className="mt-4 grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Mode</div>
            <div className="font-mono">{plan.Mode}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Safe batch</div>
            <div className="font-mono">{plan.SafeBatchScriptCount}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Active</div>
            <div className="font-mono">{plan.ActiveRecommendedRepairCount}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Manual</div>
            <div className="font-mono">{plan.ManualReviewCount ?? plan.ManualReviewRecommendations.length}</div>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500">Engine</div>
            <div className="font-mono">v{plan.DecisionEngineVersion}</div>
          </div>
        </div>
      )}

      {safeScripts.length > 0 && (
        <div className="mt-4 text-sm">
          <div className="text-gray-400 mb-2">Safe batch scripts</div>
          <div className="flex flex-wrap gap-2">
            {safeScripts.map((script) => (
              <code key={script} className="px-2 py-1 rounded bg-green-500/10 text-green-300 border border-green-500/20">
                {script}
              </code>
            ))}
          </div>
        </div>
      )}

      {guidance && (
        <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500 mb-1">Evidence scoring</div>
            <p className="text-gray-300">{guidance.EvidenceScoring}</p>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500 mb-1">Dry-run impact</div>
            <p className="text-gray-300">{guidance.DryRunImpact}</p>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500 mb-1">RUN gate</div>
            <p className="text-gray-300">{guidance.RunGate}</p>
          </div>
          <div className="p-3 rounded-lg bg-black/20 border border-white/10">
            <div className="text-gray-500 mb-1">Rollback guidance</div>
            <p className="text-gray-300">{guidance.RollbackGuidance}</p>
          </div>
        </div>
      )}

      {plan && safeScripts.length === 0 && (
        <p className="mt-4 text-sm text-gray-400">
          No active low-risk repair is eligible for safe batch execution.
        </p>
      )}
    </section>
  );
}
